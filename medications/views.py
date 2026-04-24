from django.shortcuts import render

# Create your views here.
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .utils import extract_drugs_from_image

@csrf_exempt  # !!要記得刪不然錢錢會不見，暫時關閉 CSRF 驗證，等前端串接成功後再來加強安全性
def analyze_prescription_api(request):
    if request.method == 'POST':
        # 1. 接收前端傳來的圖片 (與前端約定好圖片的欄位名稱叫做 'prescription_img')
        image_file = request.FILES.get('prescription_img')
        
        if not image_file:
            return JsonResponse({'status': 'error', 'message': '未收到圖片檔，請確認欄位名稱是否為 prescription_img'}, status=400)

        # 2. 呼叫你的 utils.py 進行 AI 辨識
        drugs_list = extract_drugs_from_image(image_file)
        
        # 3. 回傳結果給前端
        if drugs_list:
            return JsonResponse({
                'status': 'success',
                'data': drugs_list  # 先直接把 AI 抓出來的原始陣列傳給前端看看
            }, status=200)
        else:
            return JsonResponse({'status': 'error', 'message': '圖片解析失敗或找不到藥品'}, status=400)
            
    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)