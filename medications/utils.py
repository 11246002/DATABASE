import requests
import os
import json
import google.generativeai as genai
from PIL import Image
from dotenv import load_dotenv
import re
from django.db.models import Q
# from .models import Drug

# 載入 .env 裡的環境變數
load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))


# ==========================================
# 1.取得藥單圖片，交給gemini辨識，並回傳JSON格式藥品清單
# ==========================================
def extract_drugs_from_image(image_file):
    
    print("👁️ [AI 視覺辨識] 正在閱讀前端傳來的藥單...")
    model = genai.GenerativeModel('gemini-2.5-flash')
    
    try:
        img = Image.open(image_file)
    except Exception as e:
        print(f"❌ 圖片開啟失敗：{e}")
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
        print(f"❌ Gemini 解析失敗：{e}")
        return []
    

# ==========================================
# 2.接收 AI 辨識出的核心藥名 (search_kw)，向資料庫查詢對應的詳細資料
# ==========================================
def search_drug_in_db(search_kw):    

    result = {
        "license": "無資料",
        "chinese_name": "查無官方名稱",
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
    # ⚠️ 這裡的 chinese_name 與 english_name 記得對齊同學的新欄位命名
    match_drug = Drug.objects.filter(
        Q(chinese_name__icontains=search_kw) | 
        Q(english_name__icontains=search_kw)
    ).first()
    
    if match_drug:
        
        result["license"] = getattr(match_drug, 'license', '無資料')
        result["chinese_name"] = getattr(match_drug, 'chinese_name', '查無官方名稱')
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


# ==========================================
# 3. 拿藥品成分做 FDA 交互作用、警語查詢 (打外部 API)
# ==========================================
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
        print(f"❌ FDA 查詢失敗 ({ingredient})：{e}")
        return "NO_DATA", "無資料"
    

    # ==========================================
# 4. AI 批次翻譯 FDA 警告
# ==========================================
def batch_translate_fda_warnings(drugs_to_translate):
   
    if not drugs_to_translate:
        return {} 
        
    print(f"🧠 [AI 批次翻譯] 發現 {len(drugs_to_translate)} 筆 FDA 英文資料，發送一次性請求...")
    payload = json.dumps(drugs_to_translate, ensure_ascii=False)
    
    prompt = f"""
        你是一位具備豐富臨床經驗的專業藥師。我會給你一個 JSON，裡面包含多個藥品的 FDA 英文仿單節錄。

        請幫我從這些資料中，精準「揪出」與其他藥物併用的衝突、以及重大疾病禁忌，並翻譯摘要成一般台灣長輩也能看懂的白話文。

        【嚴格排版規定】：
        1. 不要拆分成分與後果，必須將「衝突的成分或特定疾病」與「發生的後果」寫在同一行。
        2. 請挑選出 3~4 點「最嚴重或最常見」的交互作用或禁忌就好。
        3. 每一點的說明請控制在一句話以內。
        4. 開頭請統一使用「⚠️ 與【xxx】併用」或「⚠️ 【xxx】患者」。

        請回傳一個 JSON 陣列，格式如下：
        [
            {{
                "drug_name": "你收到的原藥品名稱",
                "summary": "⚠️ 與【阿斯匹靈】併用：會大幅增加嚴重胃出血的風險。\n⚠️ 【胃部疾病】患者：使用此藥引發嚴重出血的機率較高。"
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
        # 把結果轉成 dict 方便快速查找：{"Amoxicillin": "⚠️ ..."}
        return {item['drug_name']: item['summary'] for item in translated_list}
    except Exception as e:
        print(f"❌ 批次翻譯失敗：{e}")
        return {}