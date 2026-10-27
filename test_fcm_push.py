"""
測試 FCM 逾時推播通知模組 (可單獨執行測試)
執行方式: python test_fcm_push.py
"""
import os
import django

os.environ.setdefault('DJANGO_SETTINGS_MODULE', 'med_project.settings')
django.setup()

from accounts.models import User, Group, GroupMember, DeviceToken
from accounts.notifications import send_fcm_multicast, check_and_send_overdue_alerts

def test_push_pipeline():
    print("==================================================")
    print("1. 測試裝置 Token 綁定檢查")
    print("==================================================")
    first_user = User.objects.first()
    if not first_user:
        print("尚未建立任何使用者，請先建立測試帳號。")
        return

    # 模擬註冊一個測試 Token
    test_token, created = DeviceToken.objects.update_or_create(
        fcm_token="demo_mock_token_1234567890abcdef",
        defaults={
            'user': first_user,
            'platform': 'android'
        }
    )
    print(f"使用者: {first_user.user_name} (ID: {first_user.user_id})")
    print(f"裝置 Token: {test_token.fcm_token} ({'新增' if created else '已存在'})")

    print("\n==================================================")
    print("2. 測試單次推播發送 (Mock/Live)")
    print("==================================================")
    result = send_fcm_multicast(
        tokens=[test_token.fcm_token],
        title="⚠️ 展場測試：長輩服藥逾時示警！",
        body="長輩【阿公】預定 08:00 服用的「降血壓錠」，已逾期 30 分鐘未服用，請立即前往關心！",
        data_payload={'type': 'medication_overdue', 'remind_id': '1'}
    )
    print("發送結果:", result)

    print("\n==================================================")
    print("3. 測試全局逾時掃描引擎 (強制觸發模式)")
    print("==================================================")
    scan_res = check_and_send_overdue_alerts(force=True, simulated_grace_minutes=0)
    print("掃描結果:", scan_res)
    print("\n全部測試流程執行完成！")

if __name__ == '__main__':
    test_push_pipeline()
