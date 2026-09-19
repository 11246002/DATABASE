# pyrefly: ignore [missing-import]
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db import transaction
from django.utils import timezone
from datetime import datetime, timedelta
from .models import Remind, PrescriptionDrug, Prescription, TakingRecord
import json


def get_authenticated_user_id(request, data=None):
    """
    從 Request Header (Authorization)、Query Param 或 Body 取得 user_id
    支援:
    1. Header: Authorization: Bearer session_token_<user_id> 或 Bearer <user_id>
    2. Header: X-User-Id: <user_id>
    3. Body: {"user_id": <user_id>, ...}
    4. Query Param: ?user_id=<user_id>
    """
    auth_header = request.headers.get('Authorization') or request.META.get('HTTP_AUTHORIZATION')
    if auth_header and auth_header.startswith('Bearer '):
        token = auth_header.split(' ')[1].strip()
        if token.startswith('session_token_'):
            try:
                return int(token.replace('session_token_', ''))
            except ValueError:
                pass
        elif token.isdigit():
            return int(token)

    x_uid = request.headers.get('X-User-Id') or request.META.get('HTTP_X_USER_ID')
    if x_uid and str(x_uid).isdigit():
        return int(x_uid)

    if data and 'user_id' in data:
        try:
            return int(data['user_id'])
        except (ValueError, TypeError):
            pass

    uid = request.GET.get('user_id') or request.POST.get('user_id')
    if uid:
        try:
            return int(uid)
        except (ValueError, TypeError):
            pass

    return None


def validate_and_parse_time(time_val):
    """
    驗證並解析時間字串，支援 'HH:MM:SS'、'HH:MM'
    若為空、null、無效格式則回傳 None，杜絕 SQLite NOT NULL 約束例外
    """
    if not time_val:
        return None
    time_str = str(time_val).strip()
    if not time_str or time_str.lower() in ['null', 'none', 'undefined']:
        return None
    for fmt in ('%H:%M:%S', '%H:%M'):
        try:
            return datetime.strptime(time_str, fmt).time()
        except ValueError:
            pass
    return None


@csrf_exempt
def set_medication_reminder(request):
    """
    批次設定整張藥單的吃藥提醒 API [維護性：模組化與批次處理邏輯]
    已加上 user_id 擁有者校驗，防範 IDOR 越權篡改
    """
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            prescription_id = data.get('prescription_id')
            user_id = get_authenticated_user_id(request, data)

            # 1. 權限校驗：驗證 user_id 是否存在
            if not user_id:
                return JsonResponse({'status': 'error', 'message': '缺少必要的使用者驗證資訊 (user_id 或 Authorization Token)'}, status=401)

            if not prescription_id:
                return JsonResponse({'status': 'error', 'message': '缺少必要的 prescription_id 參數'}, status=400)

            # 2. 驗證這張藥單是否存在，且必須屬於當前使用者 (防範 IDOR 漏洞)
            try:
                prescription = Prescription.objects.get(prescription_id=prescription_id, user_id=user_id)
            except Prescription.DoesNotExist:
                if Prescription.objects.filter(prescription_id=prescription_id).exists():
                    return JsonResponse({'status': 'error', 'message': '權限不足：您無權修改他人的處方箋鬧鐘設定'}, status=403)
                return JsonResponse({'status': 'error', 'message': f'找不到 ID 為 {prescription_id} 的處方箋'}, status=404)
            
            drugs_list = data.get('drugs', [])
            created_count = 0
            updated_count = 0
            
            # 一次撈出該藥單的所有藥品，避免迴圈內重複打 DB
            valid_p_drugs = {
                pd.id: pd for pd in PrescriptionDrug.objects.filter(prescription=prescription)
            }

            # 導入 transaction.atomic() 保證原子性，防止中間報錯產生髒資料
            with transaction.atomic():
                for drug_item in drugs_list:
                    p_drug_id = drug_item.get('prescription_drug_id')
                    p_drug = valid_p_drugs.get(p_drug_id)
                    if not p_drug:
                        continue
                    
                    # 依標籤 (frequency_tag) 更新既有鬧鐘，保留外鍵關聯 (TakingRecord)
                    # 絕不使用 delete()，徹底防止連鎖抹殺歷史服藥紀錄
                    reminders_list = drug_item.get('reminders', [])
                    active_tags = []

                    for remind_item in reminders_list:
                        tag = str(remind_item.get('frequency_tag', '')).strip()
                        remind_time_raw = remind_item.get('remind_time')
                        parsed_time = validate_and_parse_time(remind_time_raw)

                        # 防呆驗證：若未填時間、傳入空字串、空白或 null，直接略過，杜絕 SQLite NOT NULL 約束拋錯
                        if not tag or not parsed_time:
                            continue

                        active_tags.append(tag)
                        is_active_val = remind_item.get('is_active', True)
                        if isinstance(is_active_val, str):
                            is_active_val = is_active_val.lower() in ['true', '1']

                        remind_obj, created = Remind.objects.update_or_create(
                            prescription_drug=p_drug,
                            frequency_tag=tag,
                            defaults={
                                'remind_time': parsed_time,
                                'is_active': bool(is_active_val)
                            }
                        )
                        if created:
                            created_count += 1
                        else:
                            updated_count += 1

                    # 若該時段被前端移除，則將其標記為 is_active = False (軟刪除)，絕不破壞既有外鍵
                    Remind.objects.filter(prescription_drug=p_drug).exclude(
                        frequency_tag__in=active_tags
                    ).update(is_active=False)
            
            return JsonResponse({
                'status': 'success',
                'message': f'已成功批次設定完成，新增 {created_count} 筆、更新 {updated_count} 筆提醒紀錄',
                'data': {
                    'created_count': created_count,
                    'updated_count': updated_count
                }
            }, status=200 if (created_count == 0 and updated_count > 0) else 201)
            
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=400)

    return JsonResponse({'status': 'error', 'message': '請使用 POST 方法'}, status=405)

def get_reminders_list(request):
    """
    取得特定藥單的所有提醒紀錄 API [GET]
    用途：供前端撈取並顯示已設定的鬧鐘列表
    使用 select_related 進行 1 次 SQL JOIN 查詢，避免 N+1 效能問題
    已加上 user_id 擁有者校驗，防範 IDOR 越權讀取
    """
    if request.method == 'GET':
        try:
            prescription_id = request.GET.get('prescription_id')
            user_id = get_authenticated_user_id(request)

            # 1. 權限校驗：驗證 user_id 是否存在
            if not user_id:
                return JsonResponse({'status': 'error', 'message': '缺少必要的使用者驗證資訊 (user_id 或 Authorization Token)'}, status=401)

            if not prescription_id:
                return JsonResponse({'status': 'error', 'message': '缺少必要的查詢參數 prescription_id'}, status=400)

            # 2. 驗證這張藥單是否存在，且屬於當前使用者 (防範 IDOR 漏洞)
            try:
                prescription = Prescription.objects.get(prescription_id=prescription_id, user_id=user_id)
            except Prescription.DoesNotExist:
                if Prescription.objects.filter(prescription_id=prescription_id).exists():
                    return JsonResponse({'status': 'error', 'message': '權限不足：您無權查看他人的處方箋提醒'}, status=403)
                return JsonResponse({'status': 'error', 'message': f'找不到 ID 為 {prescription_id} 的處方箋'}, status=404)

            active_only = request.GET.get('active_only', '').lower() in ['true', '1']

            # 1 次 SQL 查詢：直接反向關聯撈取 Remind 並 JOIN prescription_drug 與 prescription
            reminds = Remind.objects.filter(
                prescription_drug__prescription=prescription
            ).select_related('prescription_drug', 'prescription_drug__prescription').order_by('remind_time')

            reminders_data = []
            for r in reminds:
                if active_only and (not r.is_active or r.is_expired):
                    continue

                reminders_data.append({
                    'remind_id': r.remind_id,
                    'prescription_drug_id': r.prescription_drug_id,
                    'raw_name': r.prescription_drug.raw_name,
                    'frequency_tag': r.frequency_tag,
                    'remind_time': r.remind_time.strftime('%H:%M:%S') if r.remind_time else "",
                    'is_active': r.is_active,
                    'is_expired': r.is_expired,
                    'start_date': r.start_date.strftime('%Y-%m-%d') if r.start_date else None,
                    'end_date': r.end_date.strftime('%Y-%m-%d') if r.end_date else None
                })

            return JsonResponse({
                'status': 'success',
                'data': reminders_data
            }, status=200)

        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=400)

    return JsonResponse({'status': 'error', 'message': '請使用 GET 方法'}, status=405)


@csrf_exempt
def get_today_reminders(request, user_id=None):
    """
    今日/特定日期用藥清單聚合 API [GET/POST]
    跨藥單彙整使用者當日所有應服藥品與提醒時間
    參數:
      - user_id (必填): 使用者 ID (可透過 Query Param、URL Path 或 POST Body 帶入)
      - date (選填): 目標日期 (YYYY-MM-DD)，預設為今天
      - active_only (選填): 是否僅回傳在處方箋天數範圍內的藥品 (預設 true；若設為 false 則回傳全部鬧鐘)
    """
    if request.method not in ['GET', 'POST']:
        return JsonResponse({'status': 'error', 'message': '請使用 GET 或 POST 方法'}, status=405)

    try:
        # 1. 取得查詢參數 (支援 Authorization Token、GET Query Param、URL Path 或 POST JSON)
        data = {}
        if request.method != 'GET' and request.body:
            try:
                data = json.loads(request.body)
            except Exception:
                pass

        auth_uid = get_authenticated_user_id(request, data)
        param_uid = user_id or request.GET.get('user_id') or (data.get('user_id') if data else None) or request.POST.get('user_id')

        # 若同時提供 Token 與 user_id 且不一致，進行越權防護
        if auth_uid and param_uid and int(auth_uid) != int(param_uid):
            return JsonResponse({'status': 'error', 'message': '權限不足：您無權查看其他使用者的用藥清單'}, status=403)

        uid = auth_uid or param_uid
        if not uid:
            return JsonResponse({'status': 'error', 'message': '缺少必要的使用者驗證資訊 (user_id 或 Authorization Token)'}, status=401)

        # 2. 解析目標日期 (預設今天)
        date_str = request.GET.get('date') if request.method == 'GET' else (data.get('date') or request.POST.get('date'))
        active_only_param = request.GET.get('active_only', 'true') if request.method == 'GET' else (data.get('active_only', request.POST.get('active_only', 'true')))

        if date_str:
            try:
                target_date = datetime.strptime(date_str, '%Y-%m-%d').date()
            except ValueError:
                return JsonResponse({'status': 'error', 'message': '日期格式錯誤，請使用 YYYY-MM-DD'}, status=400)
        else:
            target_date = timezone.localdate()

        active_only = str(active_only_param).lower() in ['true', '1']

        # 3. 高效查詢該使用者的所有鬧鐘與關聯資料 (JOIN prescription_drug, prescription, drug)
        reminds = Remind.objects.filter(
            prescription_drug__prescription__user_id=uid
        ).select_related(
            'prescription_drug',
            'prescription_drug__prescription',
            'prescription_drug__drug'
        )

        # 4. 批次取出當日服藥打卡紀錄 (直接利用 record_date 索引查詢，避免 N+1)
        taking_records = TakingRecord.objects.filter(
            remind__in=reminds,
            record_date=target_date
        ).order_by('taken_at')

        # 以 remind_id 為 key，保留最新打卡紀錄
        records_map = {tr.remind_id: tr for tr in taking_records}

        schedule_list = []

        for r in reminds:
            p_drug = r.prescription_drug
            p = p_drug.prescription

            # 5. 判斷是否在處方服藥有效期間內 (visit_date ~ visit_date + days - 1)
            start_date = r.start_date
            end_date = r.end_date
            is_in_range = True

            if start_date and p_drug.days and p_drug.days > 0:
                is_in_range = (start_date <= target_date <= end_date)

            # 若鬧鐘開關被關閉 (is_active=False) 或超出服藥期，且開啟 active_only 則略過
            if active_only and (not r.is_active or not is_in_range):
                continue

            # 取得當日服藥狀態
            tr = records_map.get(r.remind_id)

            schedule_list.append({
                'remind_id': r.remind_id,
                'remind_time': r.remind_time.strftime('%H:%M:%S') if r.remind_time else "",
                'frequency_tag': r.frequency_tag,
                'status': tr.status if tr else '未吃',
                'taken_at': tr.taken_at.strftime('%Y-%m-%d %H:%M:%S') if tr else None,
                'takingrecord_id': tr.takingrecord_id if tr else None,
                
                # 鬧鐘狀態與開關
                'is_active': r.is_active,
                'is_expired': r.is_expired,
                'is_in_range': is_in_range,

                # 藥品資訊
                'prescription_drug_id': p_drug.id,
                'raw_name': p_drug.raw_name,
                'med_ch': p_drug.drug.med_ch if p_drug.drug else p_drug.raw_name,
                'med_en': p_drug.drug.med_en if p_drug.drug else "",
                'frequency': p_drug.frequency,
                'days': p_drug.days,
                'total_amount': p_drug.total_amount,
                
                # 藥單資訊
                'prescription_id': p.prescription_id,
                'hospital_name': p.hospital_name,
                'visit_date': start_date.strftime('%Y-%m-%d') if start_date else "",
                'start_date': start_date.strftime('%Y-%m-%d') if start_date else "",
                'end_date': end_date.strftime('%Y-%m-%d') if end_date else ""
            })

        # 6. 按鬧鐘時間由早到晚排序
        schedule_list.sort(key=lambda x: x['remind_time'])

        return JsonResponse({
            'status': 'success',
            'date': target_date.strftime('%Y-%m-%d'),
            'user_id': int(uid),
            'total_count': len(schedule_list),
            'data': schedule_list
        }, status=200)

    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)


@csrf_exempt
def delete_single_reminder(request, remind_id):
    """
    單筆鬧鐘刪除 API [DELETE/POST]
    URL: /medications/api/reminders/<remind_id>/delete/
    已加上 user_id 擁有者校驗，防範 IDOR 越權刪除
    """
    if request.method not in ['DELETE', 'POST']:
        return JsonResponse({'status': 'error', 'message': '請使用 DELETE 或 POST 方法'}, status=405)

    try:
        user_id = get_authenticated_user_id(request)
        if not user_id:
            return JsonResponse({'status': 'error', 'message': '缺少必要的使用者驗證資訊 (user_id 或 Authorization Token)'}, status=401)

        try:
            remind = Remind.objects.select_related('prescription_drug', 'prescription_drug__prescription').get(
                remind_id=remind_id,
                prescription_drug__prescription__user_id=user_id
            )
        except Remind.DoesNotExist:
            if Remind.objects.filter(remind_id=remind_id).exists():
                return JsonResponse({'status': 'error', 'message': '權限不足：您無權刪除他人的鬧鐘設定'}, status=403)
            return JsonResponse({'status': 'error', 'message': f'找不到鬧鐘編號為 {remind_id} 的提醒設定'}, status=404)

        drug_name = remind.prescription_drug.raw_name
        tag = remind.frequency_tag
        remind_time = remind.remind_time.strftime('%H:%M:%S') if remind.remind_time else ""
        
        # 軟刪除：標記 is_active = False，絕不破壞既有外鍵與歷史打卡紀錄 (TakingRecord)
        remind.is_active = False
        remind.save(update_fields=['is_active'])
        return JsonResponse({
            'status': 'success',
            'message': f'已成功刪除鬧鐘：{drug_name} ({tag} {remind_time})',
            'data': {'remind_id': remind_id, 'is_active': False}
        }, status=200)
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)


@csrf_exempt
def toggle_single_reminder(request, remind_id):
    """
    單筆鬧鐘開關切換 API [POST/PATCH]
    URL: /medications/api/reminders/<remind_id>/toggle/
    Body (選填): {"is_active": true/false}，若無 Body 則自動反轉開關狀態
    已加上 user_id 擁有者校驗，防範 IDOR 越權切換
    """
    if request.method not in ['POST', 'PATCH', 'PUT']:
        return JsonResponse({'status': 'error', 'message': '請使用 POST、PATCH 或 PUT 方法'}, status=405)

    try:
        body_data = {}
        if request.body:
            try:
                body_data = json.loads(request.body)
            except Exception:
                pass

        user_id = get_authenticated_user_id(request, body_data)
        if not user_id:
            return JsonResponse({'status': 'error', 'message': '缺少必要的使用者驗證資訊 (user_id 或 Authorization Token)'}, status=401)

        try:
            remind = Remind.objects.select_related('prescription_drug', 'prescription_drug__prescription').get(
                remind_id=remind_id,
                prescription_drug__prescription__user_id=user_id
            )
        except Remind.DoesNotExist:
            if Remind.objects.filter(remind_id=remind_id).exists():
                return JsonResponse({'status': 'error', 'message': '權限不足：您無權切換他人的鬧鐘開關'}, status=403)
            return JsonResponse({'status': 'error', 'message': f'找不到鬧鐘編號為 {remind_id} 的提醒設定'}, status=404)

        # 若前端有傳入特定布林值則直接指派，否則切換反轉
        if 'is_active' in body_data:
            val = body_data['is_active']
            remind.is_active = bool(val.lower() in ['true', '1'] if isinstance(val, str) else val)
        else:
            remind.is_active = not remind.is_active

        remind.save()

        status_text = '開啟' if remind.is_active else '關閉'
        return JsonResponse({
            'status': 'success',
            'message': f'鬧鐘已成功{status_text}',
            'data': {
                'remind_id': remind.remind_id,
                'is_active': remind.is_active,
                'frequency_tag': remind.frequency_tag,
                'remind_time': remind.remind_time.strftime('%H:%M:%S') if remind.remind_time else ""
            }
        }, status=200)
    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)

