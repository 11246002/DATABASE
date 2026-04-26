from django.shortcuts import render

# Create your views here.
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db.models import Q
import json

# 把 utils.py 裡的所有工具都匯入
from .utils import (
    extract_drugs_from_image, 
    search_drug_in_db, 
    query_openfda_interactions, 
    batch_translate_fda_warnings
)

# ⚠️ 等同學建好資料庫後，記得把下面這行解除註解，並確認表單名稱
# from .models import Prescription, PrescriptionDrug, Warning, Drug


# ==========================================
# [第一階段 API] 流程 1 & 2：圖片辨識與草稿
# ==========================================
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


# ==========================================
# [第二階段 API] 流程 3 ~ 6：確認、查詢、翻譯、存檔
# ==========================================
@csrf_exempt 
def confirm_and_save_prescription_api(request):
    if request.method == 'POST':
        try:
            # 3. 收到前端確認好的資料 (解析 JSON)
            body_unicode = request.body.decode('utf-8')
            user_confirmed_data = json.loads(body_unicode)
            
            # 假設前端傳來的 JSON 裡面，藥品清單放在 'confirmed_drugs' 這個 key 裡
            drugs_list = user_confirmed_data.get('confirmed_drugs', [])
            
            final_report_data = []
            drugs_to_translate = []

            # 跑迴圈處理每一顆藥
            for drug in drugs_list:
                search_kw = drug.get('search_keyword', '')
                
                # 3-1. 到資料庫查詢詳細資料
                db_info = search_drug_in_db(search_kw)
                
                # 組合目前已知的所有資料
                report_item = {
                    "raw_name": drug.get('raw_name', ''),
                    "search_keyword": search_kw,
                    "frequency": drug.get('frequency', ''),
                    "days": drug.get('days', ''),
                    "total_amount": drug.get('total_amount', ''),
                    **db_info,  # 把 DB 查到的 7 大欄位直接併進來
                    "fda_result": [] # 預留給 FDA 警告的空陣列
                }
                
                # 4. 帶著藥物成分查詢 openFDA
                if db_info["element"] != "無資料":
                    status, fda_raw_text = query_openfda_interactions(db_info["element"])
                    if status == "HAS_CONFLICT":
                        # 有衝突就先收集起來，等一下整批翻譯
                        drugs_to_translate.append({
                            "drug_name": report_item["raw_name"],
                            "english_text": fda_raw_text
                        })
                
                final_report_data.append(report_item)

            # 5. 將這大筆資料拿去給 AI 翻譯整理成格式化資料
            translations_dict = batch_translate_fda_warnings(drugs_to_translate)

            # 把翻譯好的警告塞回每一顆藥的 fda_result 裡面
            for data in final_report_data:
                name = data["raw_name"]
                if name in translations_dict:
                    data["fda_result"] = translations_dict[name]

            # ----------------------------------------------------
            # 6. 存入資料庫 (等 models.py 好了解除這段多行註解)
            # ----------------------------------------------------
            """
            # (A) 建立一張新的藥單主檔
            # new_prescription = Prescription.objects.create(...)

            for data in final_report_data:
                # 去資料庫抓這顆藥的實體物件 (拿它的 ID)
                # db_drug = Drug.objects.filter(
                #     Q(chinese_name__icontains=data['search_keyword']) | 
                #     Q(english_name__icontains=data['search_keyword'])
                # ).first()
                
                # if db_drug:
                    # (B) 存入藥單藥品資料庫
                    # PrescriptionDrug.objects.create(
                    #     prescription_id=new_prescription,
                    #     drug_id=db_drug,
                    #     raw_name=data['raw_name'],
                    #     total_amount=data['total_amount'],
                    #     frequency=data['frequency'],
                    #     days=data['days']
                    # )
                    
                    # (C) 存入藥物警告表
                    # for w in data["fda_result"]:
                    #     Warning.objects.create(
                    #         drug_id=db_drug,
                    #         conflict_target=w['conflict_target'],
                    #         warning_desc=w['warning_desc']
                    #     )
            """

            # 6. 將所有資料傳回前端
            return JsonResponse({
                'status': 'success',
                'data': final_report_data
            }, status=200)

        except json.JSONDecodeError:
            return JsonResponse({'status': 'error', 'message': 'JSON 格式錯誤'}, status=400)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f"系統錯誤: {str(e)}"}, status=500)

    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)