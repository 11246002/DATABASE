import os
import json
import google.generativeai as genai
from PIL import Image
from dotenv import load_dotenv

# 載入 .env 裡的環境變數
load_dotenv()
genai.configure(api_key=os.getenv("GEMINI_API_KEY"))

def extract_drugs_from_image(image_file):
    """
    接收從 Django views 傳來的圖片檔案，交給 Gemini 辨識，並回傳 JSON 格式的藥品清單。
    """
    print("👁️ [AI 視覺辨識] 正在閱讀前端傳來的藥單...")
    model = genai.GenerativeModel('gemini-2.5-flash')
    
    # 🌟 關鍵差異：直接用 PIL 開啟 Django 接收到的檔案物件
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