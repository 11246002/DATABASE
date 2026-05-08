import requests
import json

# 1. 定義 API 網址 (請確認 Django 已啟動：python manage.py runserver)
BASE_URL = "http://127.0.0.1:8000/accounts/api/"
REG_URL = f"{BASE_URL}register/"
LOGIN_URL = f"{BASE_URL}login/"

# 2. 準備測試帳號
test_data = {
    "user_name": "yuxuan_2026",
    "password": "password123"
}

def run_test():
    print("🚀 [開始測試帳號系統]...")

    # --- 步驟 A: 測試註冊 ---
    print("\n1. 正在嘗試註冊...")
    r_reg = requests.post(REG_URL, json=test_data)
    print(f"狀態碼: {r_reg.status_code}")
    print(f"回應內容: {r_reg.json()}")

    # --- 步驟 B: 測試重複註冊 (預防邏輯檢查) ---
    print("\n2. 測試重複註冊...")
    r_dup = requests.post(REG_URL, json=test_data)
    print(f"狀態碼: {r_dup.status_code} (預期應為 400)")
    print(f"回應內容: {r_dup.json()}")

    # --- 步驟 C: 測試登入 ---
    print("\n3. 正在嘗試登入...")
    r_login = requests.post(LOGIN_URL, json=test_data)
    print(f"狀態碼: {r_login.status_code}")
    
    if r_login.status_code == 200:
        res = r_login.json()
        print("✅ 登入成功！")
        print(f"取得 Role: {res['data']['role']}")
        print(f"取得 Token: {res['data']['token']}")
    else:
        print("❌ 登入失敗！")

if __name__ == "__main__":
    run_test()