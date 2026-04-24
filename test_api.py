import requests

# 這是你剛剛建好的 API 網址 (確認你的 Django 伺服器有在執行中)
url = 'http://127.0.0.1:8000/medications/api/scan/'

# 你準備的測試圖片檔名
image_path = 'test_img.jpg' 

print("🚀 準備發送圖片給 Django API...")

# 把圖片用二進位(rb)模式打開
with open(image_path, 'rb') as f:
    # 這裡的 'prescription_img' 必須跟你在 views.py 裡面設定的接收欄位一模一樣
    files = {'prescription_img': f}
    
    # 發送 POST 請求
    response = requests.post(url, files=files)

print("✅ 伺服器回傳狀態碼：", response.status_code)
# 印出你的 API 回傳的 JSON 辨識結果！
print("📝 辨識結果：")
print(response.json())