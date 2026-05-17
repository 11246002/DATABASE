# medication/reminders.py
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .models import Remind, PrescriptionDrug # 記得匯入必要的 Model
import json

@csrf_exempt
def set_medication_reminder(request):
    """
    處理吃藥提醒設定的邏輯 [維護性：明確的註解說明]
    """
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            drug_id = data.get('prescription_drug_id')
            p_drug = PrescriptionDrug.objects.get(id=drug_id)
            
            new_remind = Remind.objects.create(
                prescription_drug=p_drug,
                frequency_tag=data.get('frequency_tag'),
                remind_time=data.get('remind_time')
            )
            
            return JsonResponse({
                'status': 'success', 
                'remind_id': new_remind.remind_id,
                'message': f'已成功設定 {p_drug.raw_name} 的提醒'
            }, status=201)
            
        except PrescriptionDrug.DoesNotExist:
            return JsonResponse({'status': 'error', 'message': '找不到該藥品紀錄'}, status=404)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=400)

    return JsonResponse({'status': 'error', 'message': '請使用 POST 方法'}, status=405)