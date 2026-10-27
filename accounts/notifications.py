import os
import logging
from datetime import datetime, timedelta
from django.utils import timezone
from django.conf import settings
from .models import DeviceToken, OverdueNotificationLog, GroupMember, User

logger = logging.getLogger(__name__)

# ==========================================
# 1. Firebase Admin SDK 初始化 (支援金鑰檔或自動降級模擬模式)
# ==========================================
_firebase_initialized = False
_firebase_import_success = False

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    _firebase_import_success = True
except ImportError:
    _firebase_import_success = False
    logger.warning("[FCM] 未偵測到 firebase-admin 套件，系統將在無 SDK 模擬模式下運行。")

def get_firebase_credentials_path():
    """尋找 Firebase 憑證金鑰檔"""
    possible_paths = [
        getattr(settings, 'FIREBASE_CREDENTIALS_PATH', None),
        os.path.join(settings.BASE_DIR, 'med_project', 'firebase_credentials.json'),
        os.path.join(settings.BASE_DIR, 'firebase_credentials.json'),
        os.path.join(settings.BASE_DIR, 'serviceAccountKey.json'),
    ]
    for p in possible_paths:
        if p and os.path.exists(p):
            return p
    return None

def init_firebase_if_needed():
    """惰性初始化 Firebase Admin"""
    global _firebase_initialized
    if _firebase_initialized:
        return True
    if not _firebase_import_success:
        return False

    cred_path = get_firebase_credentials_path()
    if not cred_path:
        logger.info("[FCM] 尚未檢測到 firebase_credentials.json，系統將以本機模擬推播模式運作。")
        return False

    try:
        if not firebase_admin._apps:
            cred = credentials.Certificate(cred_path)
            firebase_admin.initialize_app(cred)
        _firebase_initialized = True
        logger.info(f"[FCM] Firebase Admin 初始化成功！金鑰路徑: {cred_path}")
        return True
    except Exception as e:
        logger.error(f"[FCM] Firebase 初始化失敗: {e}")
        return False


# ==========================================
# 2. 跨手機推播發送工具函式 (Multicast)
# ==========================================
def send_fcm_multicast(tokens, title, body, data_payload=None):
    """
    發送推播給多台裝置 Token
    """
    if not tokens:
        return {'status': 'error', 'message': '無有效裝置 Token', 'success_count': 0, 'failure_count': 0}

    # 確保資料格式全為字串 (FCM 規範)
    clean_data = {}
    if data_payload and isinstance(data_payload, dict):
        for k, v in data_payload.items():
            clean_data[str(k)] = str(v)

    is_live = init_firebase_if_needed()

    if is_live and _firebase_import_success:
        try:
            message = messaging.MulticastMessage(
                notification=messaging.Notification(title=title, body=body),
                data=clean_data,
                tokens=list(set(tokens)),
            )
            response = messaging.send_each_for_multicast(message)
            logger.info(f"[FCM 發送成功] 成功: {response.success_count}, 失敗: {response.failure_count}")
            return {
                'status': 'success',
                'mode': 'live_firebase',
                'success_count': response.success_count,
                'failure_count': response.failure_count,
                'total_tokens': len(tokens)
            }
        except Exception as e:
            logger.error(f"[FCM 發送例外] {e}")
            return {'status': 'error', 'mode': 'live_firebase', 'message': str(e), 'success_count': 0, 'failure_count': len(tokens)}

    # --- 模擬模式 (Mock Mode / 展場備用) ---
    print(f"\n=======================================================")
    print(f"🔔 [FCM 模擬推播發送]")
    print(f"📱 接收目標裝置 ({len(tokens)} 台): {tokens[:3]}...")
    print(f"📢 標題: {title}")
    print(f"💬 內容: {body}")
    print(f"📦 攜帶資料: {clean_data}")
    print(f"=======================================================\n")
    return {
        'status': 'success',
        'mode': 'mock_simulation',
        'success_count': len(tokens),
        'failure_count': 0,
        'total_tokens': len(tokens),
        'title': title,
        'body': body
    }


# ==========================================
# 3. 核心檢查與逾時推播掃描演算法
# ==========================================
def check_and_send_overdue_alerts(target_group_id=None, force=False, simulated_grace_minutes=30):
    """
    掃描群組成員之今日鬧鐘：
      - 條件 A: 當前時間 > 預定服藥時間 + 30 分鐘 (可自訂寬限期)
      - 條件 B: 長輩今日無打卡紀錄 (無 TakingRecord)
      - 條件 C: 今日該鬧鐘尚未送出逾時通知 (無 OverdueNotificationLog，若 force=True 則忽略)
    符合者立即推送通知給同家庭群組內的所有其他家屬成員。
    """
    from medications.models import Remind, TakingRecord

    today = timezone.localdate()
    now = timezone.localtime()

    # 撈取有效且未被軟刪除的提醒
    reminds_query = Remind.objects.filter(
        is_active=True,
        is_deleted=False
    ).select_related(
        'prescription_drug',
        'prescription_drug__prescription',
        'prescription_drug__prescription__user'
    )

    if target_group_id:
        member_uids = GroupMember.objects.filter(group_id=target_group_id).values_list('user_id', flat=True)
        reminds_query = reminds_query.filter(prescription_drug__prescription__user_id__in=member_uids)

    reminds = list(reminds_query)
    scanned_count = len(reminds)
    overdue_alerts = []

    # 批次撈取當日打卡與日誌 (防 N+1 查詢)
    remind_ids = [r.remind_id for r in reminds]
    taken_set = set(TakingRecord.objects.filter(
        remind_id__in=remind_ids,
        record_date=today,
        status__in=['已吃', 'taken', '已服藥']
    ).values_list('remind_id', flat=True))

    notified_set = set(OverdueNotificationLog.objects.filter(
        remind_id__in=remind_ids,
        record_date=today
    ).values_list('remind_id', flat=True))

    for remind in reminds:
        elderly_user = remind.prescription_drug.prescription.user
        drug_name = remind.prescription_drug.raw_name
        tag = remind.frequency_tag or '用藥時間'

        if not remind.remind_time:
            continue

        naive_dt = datetime.combine(today, remind.remind_time)
        expected_dt = timezone.make_aware(naive_dt, timezone.get_current_timezone())
        grace_dt = expected_dt + timedelta(minutes=simulated_grace_minutes)

        # 檢查條件 A: 是否已逾期
        if not force and now <= grace_dt:
            continue

        # 檢查條件 B: 今日是否已打卡吃藥
        if remind.remind_id in taken_set:
            continue

        # 檢查條件 C: 今日是否已經推播過
        if not force and remind.remind_id in notified_set:
            continue

        # 找到長輩所屬群組的所有「其他家屬成員」
        elderly_groups = list(GroupMember.objects.filter(user=elderly_user).values_list('group_id', flat=True))
        if target_group_id and target_group_id in elderly_groups:
            elderly_groups = [target_group_id]

        if not elderly_groups:
            continue

        caregiver_user_ids = list(GroupMember.objects.filter(
            group_id__in=elderly_groups
        ).exclude(user=elderly_user).values_list('user_id', flat=True))

        # 撈取家屬所有已登記之裝置 Token
        device_tokens = list(DeviceToken.objects.filter(
            user_id__in=caregiver_user_ids
        ).values_list('fcm_token', flat=True))

        time_str = remind.remind_time.strftime('%H:%M')
        display_name = elderly_user.nickname or elderly_user.user_name

        title = "⚠️ 長輩服藥逾時示警！"
        body = f"長輩【{display_name}】預定 {time_str} ({tag}) 服用的「{drug_name}」，已逾期未打卡，請前往關心！"

        alert_payload = {
            'remind_id': str(remind.remind_id),
            'elderly_user_id': str(elderly_user.user_id),
            'elderly_name': display_name,
            'drug_name': drug_name,
            'scheduled_time': time_str,
            'tag': tag,
            'type': 'medication_overdue'
        }

        push_result = {}
        if device_tokens:
            push_result = send_fcm_multicast(
                tokens=device_tokens,
                title=title,
                body=body,
                data_payload=alert_payload
            )

        # 記錄日誌，防止當日重複觸發騷擾
        OverdueNotificationLog.objects.update_or_create(
            remind=remind,
            record_date=today,
            defaults={'sent_at': now}
        )

        overdue_alerts.append({
            'remind_id': remind.remind_id,
            'elderly_name': display_name,
            'drug_name': drug_name,
            'scheduled_time': time_str,
            'caregivers_reached': len(device_tokens),
            'push_result': push_result
        })

    return {
        'status': 'success',
        'date': str(today),
        'scanned_reminds': scanned_count,
        'alerts_triggered': len(overdue_alerts),
        'alerts': overdue_alerts
    }
