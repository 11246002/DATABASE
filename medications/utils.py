import requests
import os
import json
import google.generativeai as genai
from PIL import Image
from dotenv import load_dotenv
import re
from django.db.models import Q
from .models import Drug

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
        "search_keyword": "核心藥名", 
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

    # 執行模糊搜尋：使用 Q 物件同時搜尋中文或英文欄位
    match_drug = Drug.objects.filter(
        Q(med_ch__icontains=search_kw) | 
        Q(med_en__icontains=search_kw)
    ).first()
    
    if match_drug:
        
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