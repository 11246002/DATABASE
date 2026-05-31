import requests
import os
import json
import google.generativeai as genai
from PIL import Image
from dotenv import load_dotenv
import re
from django.db.models import Q
from .models import Drug, PrescriptionDrug, DrugWarning
from accounts.models import User

load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))


# 取得藥單圖片，交給gemini辨識，並回傳JSON格式藥品清單
def extract_drugs_from_image(image_file):
    
    print(" [AI 視覺辨識] 正在閱讀前端傳來的藥單...")
    model = genai.GenerativeModel('gemini-2.5-flash')
    
    try:
        img = Image.open(image_file)
    except Exception as e:
        print(f" 圖片開啟失敗：{e}")
        return []
    
    prompt = """這是一張藥單照片。請擷取所有藥品資料並整理成 JSON。格式：
    {
        "raw_name": "原始藥名", 
        "search_keyword": "核心藥名(可以有多個名字，要保留英文名字，以利後續資料庫搜尋，以空格分開，例如: Amoxicillin 阿莫西林)", 
        "frequency": "服藥頻率(例如: 每日一次、三餐飯後、每六小時一次等)",
        "days": "服用天數(例如: 3天、7天)",
        "total_amount": "給藥總數量(例如: 21顆、1瓶)"
    }"""
    
    try:
        response = model.generate_content(
            [prompt, img], 
            generation_config=genai.GenerationConfig(response_mime_type="application/json")
        )
        return json.loads(response.text)
    except Exception as e:
        print(f" Gemini 解析失敗：{e}")
        return []
    

# 接收 AI 辨識出的核心藥名 (search_kw)，向資料庫查詢對應的詳細資料
def search_drug_in_db(search_kw):    

    result = {
        "drug_obj": None,
        "license": "無資料",
        "med_ch": "查無官方名稱",
        "element": "無資料",
        "indications": "無資料",
        "dosage_form": "未知劑型",         
        "has_appearance": False,  
        "color": "未記錄",
        "shape": "未記錄",
    }

    if not search_kw:
        return result

    # 1. 支援多個 search_keyword：用空白切開成陣列
    keyword_list = search_kw.split()
    match_drug = None

    # 2. 備援機制：依序使用每個詞進行搜尋，直到找到為止
    for kw in keyword_list:
        kw = kw.strip()
        if not kw:
            continue
            
        # 3. 加入主成分 (element) 搜尋
        match_drug = Drug.objects.filter(
            Q(med_ch__icontains=kw) | 
            Q(med_en__icontains=kw) |
            Q(element__icontains=kw)
        ).first()
        
        # 只要用其中一個詞查到了結果，就立刻中斷迴圈
        if match_drug:
            break
    
    if match_drug:
        
        result["drug_obj"] = match_drug  # 將實體放入回傳結果
        result["license"] = getattr(match_drug, 'license', '無資料')
        result["med_ch"] = getattr(match_drug, 'med_ch', '查無官方名稱')
        result["indications"] = getattr(match_drug, 'indications', '無資料')
        result["dosage_form"] = getattr(match_drug, 'dosage_form', '未知劑型')
        
        raw_color = getattr(match_drug, 'color', '')
        raw_shape = getattr(match_drug, 'shape', '')
        
        if raw_color or raw_shape:
            result["has_appearance"] = True
            result["color"] = raw_color if raw_color else "未記錄"
            result["shape"] = raw_shape if raw_shape else "未記錄"

        # 處理純淨主成分 (對應 element 欄位)
        raw_ing = getattr(match_drug, 'element', '')
        if raw_ing:
            # 用正規表達式清掉劑量單位
            pure_ingredient = re.sub(r'[0-9\.]+\s*(mg|ml|g|mcg|iu|u|%).*', '', raw_ing, flags=re.IGNORECASE).strip()
            result["element"] = pure_ingredient.split(';;')[0].split('(')[0].strip()

    return result


#  拿藥品成分做 FDA 交互作用、警語查詢 (打外部 API)
def query_openfda_interactions(ingredient):
    
    url = f"https://api.fda.gov/drug/label.json?search=openfda.generic_name:\"{ingredient}\"&limit=1"
    try:
        res = requests.get(url, timeout=10)
        if res.status_code == 200:
            results = res.json().get("results", [])
            if results:
                interactions = results[0].get("drug_interactions", [])
                return "HAS_CONFLICT", str(interactions) if interactions else "無交互衝突"
        return "NO_DATA", "無資料"
    except Exception as e:
        print(f" FDA 查詢失敗 ({ingredient})：{e}")
        return "NO_DATA", "無資料"
    

#  AI 批次翻譯 FDA 警告
def batch_translate_fda_warnings(drugs_to_translate):
    """
    將收集到的 FDA 英文警告丟給 Gemini，
    並強制 AI 將結果拆分成「衝突對象 (conflict_target)」與「警告描述 (warning_desc)」，
    方便後續直接存入 Warning 資料表。
    """
    if not drugs_to_translate:
        return {} 
        
    print(f" [AI 批次翻譯] 發現 {len(drugs_to_translate)} 筆 FDA 英文資料，發送一次性請求...")
    payload = json.dumps(drugs_to_translate, ensure_ascii=False)
    
    prompt = f"""
        你是一位具備豐富臨床經驗的專業藥師。我會給你一個 JSON，裡面包含多個藥品的 FDA 英文仿單節錄。

        請幫我從這些資料中，精準「揪出」與其他藥物併用的衝突、以及重大疾病禁忌，並翻譯摘要成一般台灣長輩也能看懂的白話文。

        【嚴格排版規定】：
        請將每一個警告拆分成兩個欄位：
        1. "conflict_target" (衝突對象)：例如「阿斯匹靈、抗凝血劑」、「胃部疾病患者」、「酒精」。字數越精簡越好。
        2. "warning_desc" (警告描述)：說明併用後會發生什麼事。例如「會大幅增加嚴重胃出血的風險」。請控制在一句話以內。
        
        請挑選出 3~4 點「最嚴重或最常見」的交互作用就好，沒有衝突就不要硬寫。

        請回傳一個 JSON 陣列，格式必須完全符合以下結構：
        [
            {{
                "drug_name": "你收到的原藥品名稱",
                "warnings": [
                    {{
                        "conflict_target": "阿斯匹靈、抗凝血劑",
                        "warning_desc": "會大幅增加嚴重胃出血的風險。"
                    }},
                    {{
                        "conflict_target": "肝功能不全患者",
                        "warning_desc": "可能導致急性肝衰竭，請小心使用。"
                    }}
                ]
            }}
        ]

        這是要翻譯的資料：
        {payload}
    """
    model = genai.GenerativeModel('gemini-2.5-flash')
    try:
        response = model.generate_content(
            prompt, 
            generation_config=genai.GenerationConfig(response_mime_type="application/json")
        )
        translated_list = json.loads(response.text)
        
        # 將結果整理成字典，方便主程式快速讀取
        # 格式會變成: {"Amoxicillin": [{"conflict_target": "...", "warning_desc": "..."}, ...]}
        return {item['drug_name']: item.get('warnings', []) for item in translated_list}
    except Exception as e:
        print(f" 批次翻譯與格式化失敗：{e}")
        return {}
    

# 將字串中的數字提取出來並轉為整數，例如 "9顆" -> 9, "3天" -> 3
def extract_int(text):
    
    if isinstance(text, int): 
        return text
    if not text:
        return 0
    nums = re.findall(r'\d+', str(text))
    return int(nums[0]) if nums else 0


# 用藥安全檢查小工具：負責交叉比對過敏與藥物衝突。
def check_user_medication_safety(user_id):
    try:
        user_obj = User.objects.filter(user_id=user_id).first()
        if not user_obj:
            return False, '找不到使用者'

        # 1. 整理過敏原
        allergy_keywords = []
        if user_obj.allergies:
            allergy_keywords = [k.strip().lower() for k in user_obj.allergies.replace('，', ',').split(',') if k.strip()]

        all_user_drugs = list(PrescriptionDrug.objects.filter(
            prescription__user=user_obj
        ).select_related('drug', 'prescription'))

        # 初始化字典
        drug_results_map = {}
        for pd in all_user_drugs:
            drug_results_map[pd.id] = {
                'prescription_id': pd.prescription.prescription_id,
                'prescription_drug_id': pd.id,
                'raw_name': pd.raw_name,
                'med_ch': pd.drug.med_ch if pd.drug else '未知藥品',
                'hospital': pd.prescription.hospital_name,
                'is_severe_danger': False,
                'warnings': []
            }

        # 2. 開始精準比對
        for pd in all_user_drugs:
            # 整理這顆藥物自己的名字
            own_names = [pd.raw_name.lower()]
            if pd.drug and pd.drug.med_ch: own_names.append(pd.drug.med_ch.lower())
            if pd.drug and pd.drug.med_en: own_names.append(pd.drug.med_en.lower())

            # ==========================================
            # [A] 檢查過敏 (獨立檢查：這顆藥本身是否為過敏原)
            # ==========================================
            hit_allergy = any(kw in name or name in kw for kw in allergy_keywords for name in own_names if kw and name)
            if hit_allergy:
                drug_results_map[pd.id]['is_severe_danger'] = True
                drug_results_map[pd.id]['warnings'].append({
                    'conflict_target': '個人過敏原',
                    'warning_desc': '此藥物含有您的過敏原成分，請勿服用！',
                    'is_allergy_conflict': True,
                    'is_drug_conflict': False,
                    'conflicting_drug_names': [], # 過敏不是藥物互撞，所以為空
                    'conflicting_drug_ids': []
                })

            if not pd.drug:
                continue

            # ==========================================
            # [B] 檢查藥品衝突與保留衛教資訊
            # ==========================================
            warnings = DrugWarning.objects.filter(drug=pd.drug)
            for w in warnings:
                target = w.conflict_target.lower()
                
                hit_other_drug = False
                conflicting_pd_list = [] # 🌟 用來收集到底撞到了哪些藥

                # 去檢查使用者的其他藥品
                for other_pd in all_user_drugs:
                    if other_pd.id == pd.id: 
                        continue 

                    other_names = [other_pd.raw_name.lower()]
                    if other_pd.drug and other_pd.drug.med_ch: other_names.append(other_pd.drug.med_ch.lower())
                    if other_pd.drug and other_pd.drug.med_en: other_names.append(other_pd.drug.med_en.lower())

                    # 如果警告目標命中了另一顆藥
                    if any(name in target or target in name for name in other_names if name):
                        hit_other_drug = True
                        conflicting_pd_list.append(other_pd) # 🌟 抓到了！把這顆藥加進名單

                # 無論有沒有撞到，都把這條警告塞進去（作為衛教資訊）
                # 🌟 如果有撞到，就把對方的名字和 ID 寫進去！
                drug_results_map[pd.id]['warnings'].append({
                    'conflict_target': w.conflict_target,
                    'warning_desc': w.warning_desc,
                    'is_allergy_conflict': False,
                    'is_drug_conflict': hit_other_drug,
                    'conflicting_drug_names': [cpd.raw_name for cpd in conflicting_pd_list],
                    'conflicting_drug_ids': [cpd.id for cpd in conflicting_pd_list]
                })

                # ==========================================
                # [C] 連坐法：雙向標示危險
                # ==========================================
                if hit_other_drug:
                    drug_results_map[pd.id]['is_severe_danger'] = True # 自己亮紅燈
                    
                    for cpd in conflicting_pd_list:
                        drug_results_map[cpd.id]['is_severe_danger'] = True # 對方也亮紅燈
                        
                        # 幫對方加入反向衝突提示
                        already_has_warning = any(
                            existing_w['conflict_target'] == f"反向衝突：{pd.raw_name}" 
                            for existing_w in drug_results_map[cpd.id]['warnings']
                        )
                        if not already_has_warning:
                            drug_results_map[cpd.id]['warnings'].append({
                                'conflict_target': f"反向衝突：{pd.raw_name}",
                                'warning_desc': f"此藥物與您正在服用的 {pd.raw_name} 產生交互作用，請參考該藥物的警告說明。",
                                'is_allergy_conflict': False,
                                'is_drug_conflict': True,
                                'conflicting_drug_names': [pd.raw_name], # 🌟 告訴對方是誰撞了他
                                'conflicting_drug_ids': [pd.id]          # 🌟 附上我的 ID
                            })

        # 回傳所有結果 (如果只要回傳危險的，可以保留過濾邏輯；如果全都要回傳，就直接 list(values))
        # 因為妳說「所有的藥都抓出來列衛教」，所以我們把所有使用者的藥品都回傳
        final_result = list(drug_results_map.values())

        return True, final_result

    except Exception as e:
        return False, f"核心比對系統錯誤: {str(e)}"
