import requests
import os
import json
import google.generativeai as genai
from PIL import Image
from dotenv import load_dotenv
import re
from datetime import timedelta
from django.db.models import Q
from .models import Drug, PrescriptionDrug, DrugWarning, MedicationHistory, PatientAllergy
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


def check_medication_time_overlap(pd1, pd2, buffer_days=7):
    """
    醫學時序重疊判斷 (Pharmacokinetic Clearance Window Check):
    判斷兩項藥品在服藥週期（包含藥物半衰期與體內代謝清除緩衝期 buffer_days，預設 7 天）是否有時程重疊。
    1. 同一張藥單開立之藥品必然重疊。
    2. 不同藥單以 [看診日, 看診日 + 天數 + 代謝緩衝期] 判定區間交集。
    3. 若任一藥物缺少看診時程資訊，採醫學安全保守原則視為重疊。
    """
    try:
        p1 = getattr(pd1, 'prescription', None)
        p2 = getattr(pd2, 'prescription', None)
        if not p1 or not p2:
            return True, "缺乏處方關聯，採保守比對"
        
        # 同一張藥單必然重疊
        if getattr(p1, 'prescription_id', None) == getattr(p2, 'prescription_id', None):
            return True, "同張處方藥品（同時服用）"

        v1 = p1.visit_date
        v2 = p2.visit_date
        if not v1 or not v2:
            return True, "看診日未詳載，採保守比對"

        d1 = v1.date() if hasattr(v1, 'date') else v1
        d2 = v2.date() if hasattr(v2, 'date') else v2

        days1 = pd1.days if pd1.days and pd1.days > 0 else 7
        days2 = pd2.days if pd2.days and pd2.days > 0 else 7

        end1 = d1 + timedelta(days=days1 + buffer_days)
        end2 = d2 + timedelta(days=days2 + buffer_days)

        # 兩區間是否有交集：max(start1, start2) <= min(end1, end2)
        has_overlap = max(d1, d2) <= min(end1, end2)
        if has_overlap:
            return True, "服藥週期重疊（實質併用衝突風險）"
        else:
            diff_days = abs((d1 - d2).days)
            return False, f"開立日期相隔 {diff_days} 天（已過藥物代謝期，非併用中衝突）"
    except Exception:
        return True, "時程計算異常，安全起見列入警示"


def extract_core_elements(element_str):
    if not element_str or str(element_str).lower() == 'nan':
        return set()
    raw_parts = [p.strip().upper() for p in element_str.split(';;') if p.strip()]
    cleaned = set()
    for p in raw_parts:
        base = re.sub(r'\(.*?\)', '', p).strip()
        tokens = [t for t in base.split() if t not in ['HCL', 'SODIUM', 'POTASSIUM', 'MALEATE', 'HBR', 'HYDROCHLORIDE', 'OXALATE', 'MONOHYDRATE', 'HEMIHYDRATE', 'ACETATE', 'SULFATE', 'TARTRATE', 'PHOSPHATE', 'DIPHOSPHATE']]
        if tokens:
            cleaned.add(' '.join(tokens))
        elif base:
            cleaned.add(base)
    return cleaned

DRUG_CLASS_MAP = {
    'nsaid': {'celecoxib', 'diclofenac', 'ibuprofen', 'naproxen', 'ketorolac', 'mefenamic', 'meloxicam', 'etodolac', 'aspirin', 'indomethacin', 'sulindac', 'ketoprofen'},
    '非類固醇': {'celecoxib', 'diclofenac', 'ibuprofen', 'naproxen', 'ketorolac', 'mefenamic', 'meloxicam', 'etodolac', 'aspirin', 'indomethacin', 'sulindac', 'ketoprofen'},
    'arb': {'candesartan', 'losartan', 'valsartan', 'irbesartan', 'olmesartan', 'telmisartan'},
    'ace': {'captopril', 'enalapril', 'lisinopril', 'ramipril'},
    '降血壓': {'candesartan', 'losartan', 'valsartan', 'irbesartan', 'olmesartan', 'telmisartan', 'amlodipine', 'nifedipine'},
    '抗凝血': {'warfarin', 'rivaroxaban', 'apixaban', 'dabigatran', 'edoxaban', 'heparin', 'clopidogrel'},
    'warfarin': {'warfarin'},
}


# 用藥安全檢查小工具：負責交叉比對過敏、重複用藥與藥物衝突（整合健康存摺資料）。
def check_user_medication_safety(user_id):
    try:
        user_obj = User.objects.filter(user_id=user_id).first()
        if not user_obj:
            return False, '找不到使用者'

        # 1. 整理過敏原（雙軌來源：使用者手動輸入 + 健康存摺 PatientAllergy）
        allergy_keywords = []
        if user_obj.allergies:
            allergy_keywords.extend([k.strip().lower() for k in user_obj.allergies.replace('，', ',').split(',') if k.strip()])

        # 🌟 整合健康存摺同步之過敏原
        bank_allergies = list(PatientAllergy.objects.filter(user=user_obj))
        for ba in bank_allergies:
            if ba.allergen_name and ba.allergen_name.strip():
                allergy_keywords.append(ba.allergen_name.strip().lower())

        # 2. 取得使用者在 App 中的當前用藥清單
        all_user_drugs = list(PrescriptionDrug.objects.filter(
            prescription__user=user_obj
        ).select_related('drug', 'prescription'))

        # 3. 取得健康存摺中的歷史藥歷 (MedicationHistory)
        bank_history_meds = list(MedicationHistory.objects.filter(user=user_obj))

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

        # 4. 開始精準比對
        for pd in all_user_drugs:
            # 整理這顆藥物自己的名字
            own_names = [pd.raw_name.lower()]
            if pd.drug and pd.drug.med_ch: own_names.append(pd.drug.med_ch.lower())
            if pd.drug and pd.drug.med_en: own_names.append(pd.drug.med_en.lower())
            if pd.drug and getattr(pd.drug, 'element', None): own_names.append(pd.drug.element.lower())

            # ==========================================
            # [A] 檢查過敏 (自填過敏原 + 健康存摺過敏原)
            # ==========================================
            for kw in allergy_keywords:
                if any(kw in name or name in kw for name in own_names if kw and name):
                    drug_results_map[pd.id]['is_severe_danger'] = True
                    # 判斷是來自健康存摺還是個人自填
                    is_from_bank = any(ba.allergen_name.strip().lower() == kw for ba in bank_allergies)
                    source_desc = "健保署健康存摺紀錄" if is_from_bank else "個人自填過敏原"

                    # 避免重複塞入相同的過敏警告
                    already_warned = any(w.get('conflict_target') == f"過敏原：{kw}" for w in drug_results_map[pd.id]['warnings'])
                    if not already_warned:
                        drug_results_map[pd.id]['warnings'].append({
                            'conflict_target': f"過敏原：{kw}",
                            'warning_desc': f"此藥物含有與您【{source_desc}】吻合之過敏原成分（{kw}），請勿服用！",
                            'is_allergy_conflict': True,
                            'is_drug_conflict': False,
                            'source': source_desc,
                            'conflicting_drug_names': [],
                            'conflicting_drug_ids': []
                        })

            # ==========================================
            # [B-1] 檢查跨處方重複用藥 (相同成分/相同藥物重複開立)
            # ==========================================
            pd_elems = extract_core_elements(pd.drug.element if pd.drug else '')
            for other_pd in all_user_drugs:
                if other_pd.id == pd.id:
                    continue

                is_overlapping, time_desc = check_medication_time_overlap(pd, other_pd)
                if not is_overlapping:
                    continue

                other_elems = extract_core_elements(other_pd.drug.element if other_pd.drug else '')
                shared_elems = pd_elems.intersection(other_elems) if (pd_elems and other_elems) else set()
                is_same_db_drug = (pd.drug_id and other_pd.drug_id and pd.drug_id == other_pd.drug_id)

                if is_same_db_drug or shared_elems:
                    dup_name = ", ".join(shared_elems) if shared_elems else (pd.drug.med_ch if pd.drug else pd.raw_name)
                    other_hosp = other_pd.prescription.hospital_name if other_pd.prescription and other_pd.prescription.hospital_name else "其他院所"
                    other_display = f"{other_pd.raw_name}（{other_hosp}）"
                    
                    already_warned = any(
                        other_pd.id in w.get('conflicting_drug_ids', []) and '重複用藥' in w.get('conflict_target', '')
                        for w in drug_results_map[pd.id]['warnings']
                    )
                    if not already_warned:
                        drug_results_map[pd.id]['is_severe_danger'] = True
                        drug_results_map[pd.id]['warnings'].append({
                            'conflict_target': f"重複用藥：{dup_name}",
                            'warning_desc': f"與【{other_hosp}】開立之【{other_pd.raw_name}】含有相同成分（{dup_name}）。重複併用恐致藥物過量蓄積與急性中毒！({time_desc})",
                            'is_allergy_conflict': False,
                            'is_drug_conflict': True,
                            'conflicting_drug_names': [other_display],
                            'conflicting_drug_ids': [other_pd.id]
                        })

            if not pd.drug:
                continue

            # ==========================================
            # [B-2] 檢查藥品衝突與交互作用（當前藥物 vs 當前其他藥物）
            # ==========================================
            warnings = DrugWarning.objects.filter(drug=pd.drug)
            for w in warnings:
                target = w.conflict_target.lower()
                target_expanded_keywords = set()
                for class_k, class_members in DRUG_CLASS_MAP.items():
                    if class_k in target:
                        target_expanded_keywords.update(class_members)
                
                hit_other_drug = False
                conflicting_pd_list = []
                historical_note_list = []

                for other_pd in all_user_drugs:
                    if other_pd.id == pd.id: 
                        continue 

                    other_names = [other_pd.raw_name.lower()]
                    if other_pd.drug and other_pd.drug.med_ch: other_names.append(other_pd.drug.med_ch.lower())
                    if other_pd.drug and other_pd.drug.med_en: other_names.append(other_pd.drug.med_en.lower())
                    if other_pd.drug and getattr(other_pd.drug, 'element', None): other_names.append(other_pd.drug.element.lower())

                    name_matched = any(name in target or target in name for name in other_names if name)
                    class_matched = any(any(kw in name for name in other_names if name) for kw in target_expanded_keywords)

                    if name_matched or class_matched:
                        # 🌟 時序重疊與代謝清除期檢核
                        is_overlapping, time_desc = check_medication_time_overlap(pd, other_pd)
                        if is_overlapping:
                            hit_other_drug = True
                            conflicting_pd_list.append((other_pd, time_desc))
                        else:
                            historical_note_list.append((other_pd, time_desc))

                if hit_other_drug:
                    drug_results_map[pd.id]['is_severe_danger'] = True
                    drug_results_map[pd.id]['warnings'].append({
                        'conflict_target': w.conflict_target,
                        'warning_desc': f"{w.warning_desc}（併用時程重疊）",
                        'is_allergy_conflict': False,
                        'is_drug_conflict': True,
                        'conflicting_drug_names': [
                            f"{cpd.raw_name}（{cpd.prescription.hospital_name}）" if cpd.prescription and cpd.prescription.hospital_name else cpd.raw_name 
                            for cpd, _ in conflicting_pd_list
                        ],
                        'conflicting_drug_ids': [cpd.id for cpd, _ in conflicting_pd_list]
                    })
                    for cpd, time_desc in conflicting_pd_list:
                        drug_results_map[cpd.id]['is_severe_danger'] = True
                        already_has_warning = any(
                            existing_w['conflict_target'] == f"反向衝突：{pd.raw_name}" 
                            for existing_w in drug_results_map[cpd.id]['warnings']
                        )
                        if not already_has_warning:
                            pd_hosp = pd.prescription.hospital_name if pd.prescription and pd.prescription.hospital_name else "其他院所"
                            drug_results_map[cpd.id]['warnings'].append({
                                'conflict_target': f"反向衝突：{pd.raw_name}",
                                'warning_desc': f"此藥物與您正在服用的【{pd_hosp}】開立之【{pd.raw_name}】產生交互作用：{w.warning_desc}（{time_desc}）",
                                'is_allergy_conflict': False,
                                'is_drug_conflict': True,
                                'conflicting_drug_names': [f"{pd.raw_name}（{pd_hosp}）"],
                                'conflicting_drug_ids': [pd.id]
                            })
                elif historical_note_list:
                    # 曾有開立紀錄但服藥時段未重疊（已過代謝期），僅列為衛教提示，不標記為 is_severe_danger
                    h_names = [
                        f"{hpd.raw_name}（{hpd.prescription.hospital_name}）" if hpd.prescription and hpd.prescription.hospital_name else hpd.raw_name 
                        for hpd, _ in historical_note_list
                    ]
                    drug_results_map[pd.id]['warnings'].append({
                        'conflict_target': f"歷史用藥提示：{w.conflict_target}",
                        'warning_desc': f"{w.warning_desc}（備註：系統檢測過去曾開立過相關藥物 {', '.join(h_names)}，但因服藥時程相隔久遠已過代謝期，若已停藥則無併用風險）。",
                        'is_allergy_conflict': False,
                        'is_drug_conflict': False,
                        'conflicting_drug_names': h_names,
                        'conflicting_drug_ids': [hpd.id for hpd, _ in historical_note_list]
                    })
                else:
                    drug_results_map[pd.id]['warnings'].append({
                        'conflict_target': w.conflict_target,
                        'warning_desc': w.warning_desc,
                        'is_allergy_conflict': False,
                        'is_drug_conflict': False,
                        'conflicting_drug_names': [],
                        'conflicting_drug_ids': []
                    })

                # ==========================================
                # [D] 檢查與【健康存摺歷史藥歷】的衝突
                # ==========================================
                conflicting_bank_meds = []
                for bmed in bank_history_meds:
                    b_names = [bmed.drug_name.lower()]
                    b_matched = any(bname in target or target in bname for bname in b_names if bname)
                    b_class_matched = any(any(kw in bname for bname in b_names if bname) for kw in target_expanded_keywords)
                    if b_matched or b_class_matched:
                        # 檢查健康存摺處方日 (rx_date) 與目前藥單是否具備時程重疊
                        b_overlap = True
                        if bmed.rx_date and pd.prescription and pd.prescription.visit_date:
                            try:
                                d_current = pd.prescription.visit_date.date() if hasattr(pd.prescription.visit_date, 'date') else pd.prescription.visit_date
                                d_bank = bmed.rx_date
                                end_bank = d_bank + timedelta(days=(bmed.days or 28) + 7)
                                end_current = d_current + timedelta(days=(pd.days or 7) + 7)
                                b_overlap = max(d_current, d_bank) <= min(end_current, end_bank)
                            except Exception:
                                b_overlap = True
                        if b_overlap:
                            conflicting_bank_meds.append(bmed)

                if conflicting_bank_meds:
                    drug_results_map[pd.id]['is_severe_danger'] = True
                    for cb in conflicting_bank_meds:
                        drug_results_map[pd.id]['warnings'].append({
                            'conflict_target': f"健康存摺藥歷衝突：{cb.drug_name}",
                            'warning_desc': f"此藥物與您在【{cb.hosp_name}】開立之健康存摺用藥【{cb.drug_name}】存在交互作用：{w.warning_desc}",
                            'is_allergy_conflict': False,
                            'is_drug_conflict': True,
                            'source': '健保署健康存摺藥歷',
                            'conflicting_drug_names': [f"{cb.drug_name}（健保存摺：{cb.hosp_name}）"],
                            'conflicting_drug_ids': [cb.history_id]
                        })

        final_result = list(drug_results_map.values())
        return True, final_result

    except Exception as e:
        return False, f"核心比對系統錯誤: {str(e)}"
