import requests

# 1. 設定網址 (請確認網址跟妳 urls.py 寫的一樣)
url = "http://127.0.0.1:8000/medications/api/scan/"

# 2. 設定圖片路徑 (把這裡換成妳電腦裡圖片的真實路徑)
# 💡 小撇步：在 VS Code 檔案清單對圖片按右鍵選 "Copy Path" 就能拿到路徑
file_path = r"C:\Users\a0927\OneDrive\桌面\YXCCC的藥單.jpg"

# 3. 準備發射
try:
    with open(file_path, 'rb') as f:
        # 'prescription_img' 要對齊妳 views.py 寫的 Key
        files = {'prescription_img': f}
        print("🚀 正在發送圖片到 AI 辨識中，請稍候...")
        response = requests.post(url, files=files)
        
    # 4. 印出結果
    print("\n--- 測試結果 ---")
    print("狀態碼:", response.status_code)
    print("AI 回傳 JSON:", response.json())
except Exception as e:
    print(f"❌ 發生錯誤: {e}")