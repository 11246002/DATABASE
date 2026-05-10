import requests
import json

# 1. 設定妳的 API 網址 (請確認對應妳的 urls.py 設定)
API_URL = "http://127.0.0.1:8000/medications/api/confirm_and_save/"

# 2. 模擬前端 (Flutter) 準備的 JSON 資料
payload_dict = {
  "user_id": 4,
  "hospital_name": "台大醫院",
  "visit_date": "2026-05-10",
  "confirmed_drugs": [
    {
      "raw_name": "Amoxicillin 500 ca",
      "search_keyword": "Amoxicillin",
      "frequency": "每日三次",
      "days": "3天",
      "total_amount": "9顆"
    },
    {
      "raw_name": "BROEN-C ENTERIC F.",
      "search_keyword": "BROEN-C ENTERIC",
      "frequency": "每日三次",
      "days": "3天",
      "total_amount": "9顆"
    },
    {
      "raw_name": "Med-A cap",
      "search_keyword": "Med-A",
      "frequency": "每日三次",
      "days": "3天",
      "total_amount": "9顆"
    },
    {
      "raw_name": "allegra 中化",
      "search_keyword": "allegra",
      "frequency": "每日三次",
      "days": "3天",
      "total_amount": "4.5顆"
    },
    {
      "raw_name": "Methylephedrine 30",
      "search_keyword": "Methylephedrine",
      "frequency": "每日三次",
      "days": "3天",
      "total_amount": "4.5顆"
    },
    {
      "raw_name": "Mylanta",
      "search_keyword": "Mylanta",
      "frequency": "每日三次",
      "days": "3天",
      "total_amount": "9顆"
    },
    {
      "raw_name": "Voren 50mg",
      "search_keyword": "Voren",
      "frequency": "每日三次",
      "days": "3天",
      "total_amount": "9顆"
    },
    {
      "raw_name": "Zyrtec 10mg",
      "search_keyword": "Zyrtec",
      "frequency": "每日一次",
      "days": "3天",
      "total_amount": "3顆"
    },
    {
      "raw_name": "Colotin 喉片",
      "search_keyword": "Colotin",
      "frequency": "每日一次",
      "days": "3天",
      "total_amount": "6片"
    }
  ]
}

# 3. 準備「包裹」
# (A) 把 JSON 字典轉成字串，放在 'data' 欄位裡
form_data = {
    'data': json.dumps(payload_dict)
}

# (B) 準備圖片檔案
# ⚠️ 注意：請隨便拿一張電腦裡的圖片，放在跟這個腳本同一個資料夾，並把檔名改成 'dummy.jpg'
# 或者把下面這行換成妳電腦裡真實圖片的路徑，例如 'C:/Users/Pictures/test.jpg'
image_path = r"C:\Users\a0927\OneDrive\桌面\YXCCC的藥單.jpg"

try:
    with open(image_path, 'rb') as img_file:
        files_data = {
            'prescription_img': img_file
        }
        
        print(f"🚀 正在發送 POST 請求至: {API_URL} ...")
        
        # 4. 發射！這行就等同於按下 Thunder Client 的 Send
        response = requests.post(API_URL, data=form_data, files=files_data)
        
        # 5. 印出結果
        print("-" * 30)
        print(f"✅ 伺服器狀態碼: {response.status_code}")
        
        # 嘗試解析回傳的 JSON
        try:
            print("📦 回傳資料:")
            print(json.dumps(response.json(), indent=4, ensure_ascii=False))
        except ValueError:
            print(f"❌ 伺服器沒有回傳 JSON，原始回應如下:\n{response.text}")

except FileNotFoundError:
    print(f"❌ 找不到圖片檔案：'{image_path}'。請隨便丟一張圖片到同一個資料夾，並改名為 {image_path}！")
except requests.exceptions.ConnectionError:
    print("❌ 連線失敗！請確認妳的 Django 伺服器 (runserver) 有打開！")