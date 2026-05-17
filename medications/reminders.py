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