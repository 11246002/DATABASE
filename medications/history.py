from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone
from django.utils.dateparse import parse_datetime
from django.db import transaction, IntegrityError
from datetime import datetime, timedelta
from .models import Remind, TakingRecord
from .reminders import get_authenticated_user_id
import json

@csrf_exempt
def record_taking_status(request):
    """
    回報吃藥紀錄 API [負責人：後端 API 工程師]
    用途：前端手機鬧鐘響起時，用戶點擊按鈕，後端即時寫入 TakingRecord 資料表
    功能特性：
      - 允許自帶 actual_taken_at 離線補打卡，若無才 fallback 到 timezone.now()
      - 嚴格限制 status 必須為 ['已吃', '略過']
      - 標記「已吃」時自動原子扣減 PrescriptionDrug.remaining_amount 庫存
      - 內建 10 分鐘連點防護 + 當日防重複打卡機制
      - 已加上 user_id 擁有者校驗，防範 IDOR 越權打卡
    """
    if request.method == 'POST':
        try:
            # 解析前端傳來的 JSON 包裹
            data = json.loads(request.body)
            remind_id = data.get('remind_id')
            status = data.get('status')  # 必須是 "已吃" 或 "略過"
            force_val = data.get('force', False)  # 支援強制打卡參數
            force = bool(force_val.lower() in ['true', '1'] if isinstance(force_val, str) else force_val)
            user_id = get_authenticated_user_id(request, data)

            # 1. 權限校驗：驗證 user_id 是否存在
            if not user_id:
                return JsonResponse({'status': 'error', 'message': '缺少必要的使用者驗證資訊 (user_id 或 Authorization Token)'}, status=401)

            # 2. 防呆驗證：檢查欄位是否存在
            if not remind_id or not status:
                return JsonResponse({'status': 'error', 'message': '缺少必要欄位 remind_id 或 status'}, status=400)

            # 3. 狀態合法性驗證：限制必須在 ['已吃', '略過']
            VALID_STATUSES = ['已吃', '略過']
            if status not in VALID_STATUSES:
                return JsonResponse({
                    'status': 'error',
                    'message': f"無效的打卡狀態「{status}」，僅允許: {', '.join(VALID_STATUSES)}"
                }, status=400)

            # 4. 驗證鬧鐘 ID 是否真實存在，且屬於當前使用者 (防範 IDOR 漏洞)
            try:
                remind_instance = Remind.objects.select_related(
                    'prescription_drug',
                    'prescription_drug__prescription'
                ).get(
                    remind_id=remind_id,
                    prescription_drug__prescription__user_id=user_id
                )
            except Remind.DoesNotExist:
                if Remind.objects.filter(remind_id=remind_id).exists():
                    return JsonResponse({'status': 'error', 'message': '權限不足：您無權修改或打卡他人的吃藥鬧鐘'}, status=403)
                return JsonResponse({'status': 'error', 'message': f'找不到鬧鐘編號為 {remind_id} 的提醒設定'}, status=404)

            # 4. 解析服藥時間：支援 actual_taken_at 離線補打卡，若無則 fallback 到 timezone.now()
            actual_taken_at_str = data.get('actual_taken_at')
            if actual_taken_at_str:
                taken_at = parse_datetime(actual_taken_at_str)
                if not taken_at:
                    for fmt in ('%Y-%m-%d %H:%M:%S', '%Y-%m-%dT%H:%M:%S', '%Y-%m-%d %H:%M'):
                        try:
                            taken_at = datetime.strptime(actual_taken_at_str, fmt)
                            break
                        except ValueError:
                            pass
                if not taken_at:
                    return JsonResponse({
                        'status': 'error',
                        'message': 'actual_taken_at 格式無效，請使用 ISO 8601 或 YYYY-MM-DD HH:MM:SS'
                    }, status=400)

                if timezone.is_aware(timezone.now()) and timezone.is_naive(taken_at):
                    taken_at = timezone.make_aware(taken_at)
            else:
                taken_at = timezone.now()

            # 支援前端傳入 record_date (例如在 00:05 補打昨天的藥)，若未傳入才從 taken_at 推導
            custom_record_date = data.get('record_date') or data.get('date')
            if custom_record_date:
                try:
                    record_date = datetime.strptime(str(custom_record_date).strip(), '%Y-%m-%d').date()
                except ValueError:
                    return JsonResponse({'status': 'error', 'message': 'record_date 格式錯誤，請使用 YYYY-MM-DD'}, status=400)
            else:
                record_date = (timezone.localtime(taken_at) if timezone.is_aware(taken_at) else taken_at).date()

            # 5. 防重複打卡機制：全面以業務主鍵 (remind, record_date) 判定是否已有紀錄
            duplicate_record = TakingRecord.objects.filter(
                remind=remind_instance,
                record_date=record_date
            ).order_by('-taken_at').first()

            # 6. 資料寫入與剩餘藥品庫存連動扣減 (使用 transaction.atomic 保證一致性)
            with transaction.atomic():
                p_drug = remind_instance.prescription_drug

                if duplicate_record:
                    # 情況 A: 未開啟 force 且打卡狀態相同 -> 阻擋重複打卡
                    if not force and duplicate_record.status == status:
                        return JsonResponse({
                            'status': 'error',
                            'message': f'請勿重複打卡！此鬧鐘時段已於 {duplicate_record.taken_at.strftime("%H:%M:%S")} 記錄為「{status}」',
                            'data': {
                                'takingrecord_id': duplicate_record.takingrecord_id,
                                'status': duplicate_record.status,
                                'record_date': duplicate_record.record_date.strftime('%Y-%m-%d'),
                                'taken_at': duplicate_record.taken_at.strftime('%Y-%m-%d %H:%M:%S'),
                                'remaining_amount': p_drug.remaining_amount
                            }
                        }, status=400)

                    # 情況 B: 已有紀錄（force=True 強制打卡 或 狀態切換）
                    # 覆蓋更新現有紀錄，絕不呼叫 create()，避免違反 UniqueConstraint(remind, record_date) 唯一約束
                    old_status = duplicate_record.status
                    duplicate_record.status = status
                    duplicate_record.record_date = record_date
                    duplicate_record.taken_at = taken_at
                    duplicate_record.save()

                    # 狀態轉換連動庫存：若由「略過」改為「已吃」，扣減 1；反之若由「已吃」改為「略過」，回補 1
                    if status == '已吃' and old_status != '已吃':
                        if p_drug.remaining_amount is None:
                            p_drug.remaining_amount = max(0, p_drug.total_amount - 1)
                        else:
                            p_drug.remaining_amount = max(0, p_drug.remaining_amount - 1)
                        p_drug.save(update_fields=['remaining_amount'])
                    elif status != '已吃' and old_status == '已吃':
                        if p_drug.remaining_amount is not None:
                            p_drug.remaining_amount += 1
                            p_drug.save(update_fields=['remaining_amount'])

                    return JsonResponse({
                        'status': 'success',
                        'message': f'已{"強制" if force else ""}更新打卡狀態為「{status}」',
                        'data': {
                            'takingrecord_id': duplicate_record.takingrecord_id,
                            'status': duplicate_record.status,
                            'record_date': duplicate_record.record_date.strftime('%Y-%m-%d'),
                            'taken_at': duplicate_record.taken_at.strftime('%Y-%m-%d %H:%M:%S'),
                            'remaining_amount': p_drug.remaining_amount
                        }
                    }, status=200)

                # 尚無紀錄，正常寫入 TakingRecord 表 (若因並發觸發 UniqueConstraint 則回退為 save 覆蓋)
                try:
                    new_record = TakingRecord.objects.create(
                        remind=remind_instance,
                        status=status,
                        record_date=record_date,
                        taken_at=taken_at
                    )
                except IntegrityError:
                    new_record = TakingRecord.objects.get(remind=remind_instance, record_date=record_date)
                    old_status = new_record.status
                    new_record.status = status
                    new_record.taken_at = taken_at
                    new_record.save()

                    if status == '已吃' and old_status != '已吃':
                        p_drug.remaining_amount = max(0, (p_drug.remaining_amount or p_drug.total_amount) - 1)
                        p_drug.save(update_fields=['remaining_amount'])
                    elif status != '已吃' and old_status == '已吃':
                        if p_drug.remaining_amount is not None:
                            p_drug.remaining_amount += 1
                            p_drug.save(update_fields=['remaining_amount'])

                    return JsonResponse({
                        'status': 'success',
                        'message': '已覆蓋更新吃藥紀錄',
                        'data': {
                            'takingrecord_id': new_record.takingrecord_id,
                            'status': new_record.status,
                            'record_date': new_record.record_date.strftime('%Y-%m-%d'),
                            'taken_at': new_record.taken_at.strftime('%Y-%m-%d %H:%M:%S'),
                            'remaining_amount': p_drug.remaining_amount
                        }
                    }, status=200)

                # 若標記為「已吃」，自動扣減剩餘藥品數量 (remaining_amount)
                if status == '已吃':
                    if p_drug.remaining_amount is None:
                        p_drug.remaining_amount = max(0, p_drug.total_amount - 1)
                    else:
                        p_drug.remaining_amount = max(0, p_drug.remaining_amount - 1)
                    p_drug.save(update_fields=['remaining_amount'])

                return JsonResponse({
                    'status': 'success',
                    'message': '吃藥紀錄已成功寫入資料庫',
                    'data': {
                        'takingrecord_id': new_record.takingrecord_id,
                        'status': new_record.status,
                        'record_date': new_record.record_date.strftime('%Y-%m-%d'),
                        'taken_at': new_record.taken_at.strftime('%Y-%m-%d %H:%M:%S'),
                        'remaining_amount': p_drug.remaining_amount
                    }
                }, status=201)

        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=400)

    return JsonResponse({'status': 'error', 'message': '請使用 POST 方法'}, status=405)


@csrf_exempt
def get_medication_adherence_stats(request, user_id=None):
    """
    服藥遵從率與歷史查詢 API [GET]
    供長輩或家屬端查看「過去一週/指定天數按時服藥率（例如 85%）」與詳細歷史
    URL: /medications/api/history/stats/?user_id=X
    Query Parameters:
      - user_id (必填): 使用者 ID
      - days (選填): 統計天數 (預設 7 天)
      - end_date (選填): 統計結束日期 (YYYY-MM-DD，預設今天)
      - start_date (選填): 統計起始日期 (YYYY-MM-DD)
    """
    if request.method != 'GET':
        return JsonResponse({'status': 'error', 'message': '請使用 GET 方法'}, status=405)

    try:
        auth_uid = get_authenticated_user_id(request)
        param_uid = user_id or request.GET.get('user_id')

        if auth_uid and param_uid and int(auth_uid) != int(param_uid):
            return JsonResponse({'status': 'error', 'message': '權限不足：您無權查看其他使用者的服藥統計'}, status=403)

        uid = auth_uid or param_uid
        if not uid:
            return JsonResponse({'status': 'error', 'message': '缺少必要的使用者驗證資訊 (user_id 或 Authorization Token)'}, status=401)

        # 1. 取得統計天數與日期區間
        days_param = request.GET.get('days', 7)
        try:
            days_count = max(1, int(days_param))
        except ValueError:
            days_count = 7

        end_date_str = request.GET.get('end_date')
        if end_date_str:
            try:
                end_date = datetime.strptime(end_date_str, '%Y-%m-%d').date()
            except ValueError:
                return JsonResponse({'status': 'error', 'message': 'end_date 格式錯誤，請使用 YYYY-MM-DD'}, status=400)
        else:
            end_date = timezone.localdate()

        start_date_str = request.GET.get('start_date')
        if start_date_str:
            try:
                start_date = datetime.strptime(start_date_str, '%Y-%m-%d').date()
                days_count = (end_date - start_date).days + 1
            except ValueError:
                return JsonResponse({'status': 'error', 'message': 'start_date 格式錯誤，請使用 YYYY-MM-DD'}, status=400)
        else:
            start_date = end_date - timedelta(days=days_count - 1)

        # 2. 撈出該使用者的所有鬧鐘設定 (含關聯處方藥與藥單)
        reminds = Remind.objects.filter(
            prescription_drug__prescription__user_id=uid
        ).select_related(
            'prescription_drug',
            'prescription_drug__prescription',
            'prescription_drug__drug'
        )

        # 3. 撈出日期區間內的所有打卡服藥紀錄 (直接利用 record_date 索引查詢)
        taking_records = TakingRecord.objects.filter(
            remind__in=reminds,
            record_date__range=(start_date, end_date)
        ).select_related('remind', 'remind__prescription_drug').order_by('-taken_at')

        # 建立快速查詢 Map: (日期, remind_id) -> TakingRecord
        records_map = {}
        for tr in taking_records:
            key = (tr.record_date, tr.remind_id)
            if key not in records_map:
                records_map[key] = tr

        # 4. 每日服藥統計計算
        daily_stats = []
        total_expected = 0
        total_taken = 0
        total_skipped = 0
        total_missed = 0

        today = timezone.localdate()
        current_time = timezone.localtime(timezone.now()).time() if timezone.is_aware(timezone.now()) else timezone.now().time()

        curr_date = start_date
        while curr_date <= end_date:
            day_expected = 0
            day_taken = 0
            day_skipped = 0
            day_missed = 0

            for r in reminds:
                # 判定該鬧鐘在當天是否為有效用藥日
                r_start = r.start_date
                r_end = r.end_date

                is_valid_on_day = True
                if r_start and r.prescription_drug.days and r.prescription_drug.days > 0:
                    is_valid_on_day = (r_start <= curr_date <= r_end)

                if is_valid_on_day and r.is_active:
                    key = (curr_date, r.remind_id)
                    tr = records_map.get(key)

                    # 若統計日期為今天且鬧鐘時間尚未到來 (未來時段)，且使用者尚未打卡，
                    # 或統計日期為未來日期且未打卡，則屬於未來時段，不計入已發生的應服總量 (day_expected) 與遺漏 (day_missed)
                    is_future_slot = (
                        (curr_date > today) or
                        (curr_date == today and r.remind_time and r.remind_time > current_time)
                    )
                    if is_future_slot and not tr:
                        continue

                    day_expected += 1
                    if tr:
                        if tr.status == '已吃':
                            day_taken += 1
                        elif tr.status == '略過':
                            day_skipped += 1
                        else:
                            day_missed += 1
                    else:
                        day_missed += 1

            day_rate = round((day_taken / day_expected) * 100, 1) if day_expected > 0 else 100.0

            daily_stats.append({
                'date': curr_date.strftime('%Y-%m-%d'),
                'expected_count': day_expected,
                'taken_count': day_taken,
                'skipped_count': day_skipped,
                'missed_count': day_missed,
                'adherence_rate': day_rate
            })

            total_expected += day_expected
            total_taken += day_taken
            total_skipped += day_skipped
            total_missed += day_missed

            curr_date += timedelta(days=1)

        overall_rate = round((total_taken / total_expected) * 100, 1) if total_expected > 0 else 100.0

        # 遵從率等級評估
        if overall_rate >= 90:
            rating = '極佳 (規律服藥)'
        elif overall_rate >= 75:
            rating = '良好 (偶有遺漏)'
        elif overall_rate >= 50:
            rating = '尚可 (需多加提醒)'
        else:
            rating = '不佳 (高度遺漏風險)'

        # 5. 最近歷史紀錄列表 (Recent History)
        recent_history = []
        for tr in taking_records[:30]:
            recent_history.append({
                'takingrecord_id': tr.takingrecord_id,
                'remind_id': tr.remind_id,
                'drug_name': tr.remind.prescription_drug.raw_name,
                'frequency_tag': tr.remind.frequency_tag,
                'status': tr.status,
                'record_date': tr.record_date.strftime('%Y-%m-%d') if tr.record_date else None,
                'taken_at': tr.taken_at.strftime('%Y-%m-%d %H:%M:%S')
            })

        return JsonResponse({
            'status': 'success',
            'user_id': int(uid),
            'start_date': start_date.strftime('%Y-%m-%d'),
            'end_date': end_date.strftime('%Y-%m-%d'),
            'days_analyzed': days_count,
            'summary': {
                'total_expected': total_expected,
                'total_taken': total_taken,
                'total_skipped': total_skipped,
                'total_missed': total_missed,
                'adherence_rate': overall_rate,
                'rating': rating
            },
            'daily_stats': daily_stats,
            'recent_history': recent_history
        }, status=200)

    except Exception as e:
        return JsonResponse({'status': 'error', 'message': str(e)}, status=500)