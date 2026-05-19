from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.utils import timezone  # 用來抓取目前最準確的系統時間
from .models import Remind, TakingRecord
import json

@csrf_exempt
def record_taking_status(request):
    """
    回報吃藥紀錄 API [負責人：後端 API 工程師]
    用途：前端手機鬧鐘響起時，用戶點擊按鈕，後端即時寫入 TakingRecord 資料表
    """
    if request.method == 'POST':
        try:
            # 解析前端傳來的 JSON 包裹
            data = json.loads(request.body)
            remind_id = data.get('remind_id')
            status = data.get('status')  # 例如 "已吃", "略過"

            # 1. 防呆驗證：檢查前端有沒有漏傳欄位
            if not remind_id or not status:
                return JsonResponse({'status': 'error', 'message': '缺少必要欄位 remind_id 或 status'}, status=400)

            # 2. 驗證這個鬧鐘 ID 在資料庫（Remind 表）裡是不是真的存在
            try:
                remind_instance = Remind.objects.get(remind_id=remind_id)
            except Remind.DoesNotExist:
                return JsonResponse({'status': 'error', 'message': f'找不到鬧鐘編號為 {remind_id} 的提醒設定'}, status=404)

            # 3. 創建紀錄並存入倉庫（TakingRecord 表）
            # 這裡 taken_at 我們直接用 timezone.now() 自動抓取使用者按下按鈕的當下時間
            new_record = TakingRecord.objects.create(
                remind=remind_instance,
                status=status,
                taken_at=timezone.now() 
            )

            # 4. 回傳成功訊息給前端
            return JsonResponse({
                'status': 'success',
                'message': '吃藥紀錄已成功寫入資料庫',
                'data': {
                    'takingrecord_id': new_record.takingrecord_id,
                    'status': new_record.status,
                    'taken_at': new_record.taken_at.strftime('%Y-%m-%d %H:%M:%S') # 轉成可讀的時間字串
                }
            }, status=201)

        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=400)

    return JsonResponse({'status': 'error', 'message': '請使用 POST 方法'}, status=405)