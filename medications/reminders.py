from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .models import Remind, PrescriptionDrug, Prescription
import json

@csrf_exempt
def set_medication_reminder(request):
    """
    批次設定整張藥單的吃藥提醒 API [維護性：模組化與批次處理邏輯]
    """
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            prescription_id = data.get('prescription_id')
            
            # 驗證這張藥單是否存在
            try:
                prescription = Prescription.objects.get(prescription_id=prescription_id)
            except Prescription.DoesNotExist:
                return JsonResponse({'status': 'error', 'message': f'找不到 ID 為 {prescription_id} 的處方箋'}, status=404)
            
            drugs_list = data.get('drugs', [])
            created_count = 0
            
            # 第一層迴圈：跑每一顆藥 (Drug)
            for drug_item in drugs_list:
                p_drug_id = drug_item.get('prescription_drug_id')
                
                try:
                    p_drug = PrescriptionDrug.objects.get(id=p_drug_id, prescription=prescription)
                except PrescriptionDrug.DoesNotExist:
                    # 如果其中一顆藥對不上這張藥單，先跳過或報錯（這裡選擇跳過，提高系統容錯率）
                    continue
                
                reminders_list = drug_item.get('reminders', [])
                
                # 第二層迴圈：跑這顆藥的每一個提醒時間 (Reminder)
                for remind_item in reminders_list:
                    Remind.objects.create(
                        prescription_drug=p_drug,
                        frequency_tag=remind_item.get('frequency_tag'),
                        remind_time=remind_item.get('remind_time')
                    )
                    created_count += 1
            
            return JsonResponse({
                'status': 'success',
                'message': f'已成功批次設定完成，共建立 {created_count} 筆提醒紀錄'
            }, status=201)
            
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=400)

    return JsonResponse({'status': 'error', 'message': '請使用 POST 方法'}, status=405)

def get_reminders_list(request):
    """
    取得特定藥單的所有提醒紀錄 API [GET]
    用途：供前端撈取並顯示已設定的鬧鐘列表
    """
    if request.method == 'GET':
        try:
            # 1. 從網址列（URL Parameter）抓取 prescription_id
            prescription_id = request.GET.get('prescription_id')
            
            if not prescription_id:
                return JsonResponse({'status': 'error', 'message': '缺少必要的查詢參數 prescription_id'}, status=400)

            # 2. 透過 ORM 撈出所有屬於這張藥單的「處方藥品」
            # 這裡用 filter(prescription_id=...) 一口氣把這張藥單的所有藥撈出來
            drug_instances = PrescriptionDrug.objects.filter(prescription_id=prescription_id)
            
            # 3. 找出這些藥對應的所有提醒（Remind）
            # 我們利用「雙層迴圈」或「__in」語法，把所有鬧鐘打包成前端要的 JSON 格式
            reminders_data = []
            
            for drug in drug_instances:
                # 撈出這顆藥綁定的所有鬧鐘
                reminds = Remind.objects.filter(prescription_drug=drug)
                for r in reminds:
                    reminders_data.append({
                        'remind_id': r.remind_id,
                        'prescription_drug_id': drug.id,
                        'raw_name': drug.raw_name,  # 順便把藥品中文化名稱吐給前端，方便他們直接畫在畫面上
                        'frequency_tag': r.frequency_tag,
                        'remind_time': r.remind_time.strftime('%H:%M:%S') if r.remind_time else ""
                    })

            # 4. 回傳給前端
            return JsonResponse({
                'status': 'success',
                'data': reminders_data
            }, status=200)

        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=400)

    return JsonResponse({'status': 'error', 'message': '請使用 GET 方法'}, status=405)