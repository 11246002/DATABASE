from django.shortcuts import render

# Create your views here.
from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from django.db.models import Q
import json
from django.db import transaction
from django.utils import timezone


from .utils import (
    extract_drugs_from_image, 
    search_drug_in_db, 
    query_openfda_interactions, 
    batch_translate_fda_warnings,
    extract_int
)
from .models import Prescription, PrescriptionDrug, DrugWarning, Drug
from accounts.models import User


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
            # 1. 收到前端確認好的資料 (拆包裹)
            data_json_string = request.POST.get('data')
            if not data_json_string:
                return JsonResponse({'status': 'error', 'message': '未收到藥單資料'}, status=400)
                
            user_confirmed_data = json.loads(data_json_string)
            image_file = request.FILES.get('prescription_img')
            drugs_list = user_confirmed_data.get('confirmed_drugs', [])
            
            final_report_data = []
            drugs_to_translate = []

            # ----------------------------------------------------
            # 🌟 [優化版] 第一階段：準備資料與查詢 (加入快取機制)
            # ----------------------------------------------------
            for drug in drugs_list:
                search_kw = drug.get('search_keyword', '')
                db_info = search_drug_in_db(search_kw)
                
                # 【優化重點 1】提早去資料庫抓這顆藥的實體
                db_drug = Drug.objects.filter(
                    Q(med_ch__icontains=search_kw) | Q(med_en__icontains=search_kw)
                ).first()

                existing_fda_results = []
                need_fda_query = False

                # 【優化重點 2】檢查這顆藥是不是已經被查過、翻譯過了？
                if db_drug:
                    warnings = DrugWarning.objects.filter(drug=db_drug)
                    if warnings.exists():
                        # 資料庫已經有警告紀錄！直接拿出來用，不用查 FDA 了
                        print(f"⚡ 快取命中：直接從資料庫讀取 {search_kw} 的警告！省下 API 時間。")
                        for w in warnings:
                            existing_fda_results.append({
                                "conflict_target": w.conflict_target,
                                "warning_desc": w.warning_desc
                            })
                    else:
                        # 資料庫有這顆藥，但還沒查過警告
                        need_fda_query = True
                else:
                    # 資料庫連這顆藥都沒有，當然要查
                    need_fda_query = True

                # 組合資料
                report_item = {
                    "raw_name": drug.get('raw_name', ''),
                    "search_keyword": search_kw,
                    "frequency": drug.get('frequency', ''),
                    "days": drug.get('days', ''),
                    "total_amount": drug.get('total_amount', ''),
                    **db_info,  
                    "fda_result": existing_fda_results, # 先塞入已知的警告 (可能為空)
                    "db_drug_obj": db_drug # 【優化重點 3】順便把藥品實體存起來，等一下存檔直接用
                }
                
                # 【優化重點 4】只有當 need_fda_query 為 True 時，才去呼叫 openFDA
                if need_fda_query and db_info.get("element", "無資料") != "無資料":
                    status, fda_raw_text = query_openfda_interactions(db_info.get("element"))
                    if status == "HAS_CONFLICT":
                        drugs_to_translate.append({
                            "drug_name": report_item["raw_name"],
                            "english_text": fda_raw_text
                        })
                
                final_report_data.append(report_item)

            # 2. 將新發現的衝突拿去給 AI 翻譯 (如果全部都命中快取，這裡就不會執行，超省錢！)
            if drugs_to_translate:
                translations_dict = batch_translate_fda_warnings(drugs_to_translate)
                # 把翻譯好的警告塞回對應的藥裡面
                for data in final_report_data:
                    name = data["raw_name"]
                    if name in translations_dict:
                        data["fda_result"] = translations_dict[name]

            # ----------------------------------------------------
            # 🌟 [優化版] 第二階段：存入資料庫
            # ----------------------------------------------------
            from django.utils import timezone
            
            # [第一關] 確認使用者
            user_id = user_confirmed_data.get('user_id')
            try:
                user_obj = User.objects.get(id=user_id)
            except User.DoesNotExist:
                return JsonResponse({'status': 'error', 'message': f'找不到 ID 為 {user_id} 的使用者'}, status=404)

            # [第二關] 存入藥單主檔
            try:
                h_name = user_confirmed_data.get('hospital_name', '未指定醫院')
                v_date_str = user_confirmed_data.get('visit_date')
                if v_date_str:
                    from django.utils.dateparse import parse_date
                    v_date = parse_date(v_date_str)
                else:
                    v_date = timezone.now()

                new_prescription = Prescription.objects.create(
                    user=user_obj,
                    hospital_name=h_name,
                    visit_date=v_date,
                    image=image_file 
                )
            except Exception as e:
                return JsonResponse({'status': 'error', 'message': f'💥 [建立藥單主檔失敗] {str(e)}'}, status=500)

            # [第三關] 存入藥品明細與警告
            for data in final_report_data:
                # 【優化重點 5】直接把剛才找好的 db_drug_obj 拿出來用，並從字典裡移除 (以免轉 JSON 時報錯)
                db_drug = data.pop('db_drug_obj', None)

                if db_drug:
                    try:
                        PrescriptionDrug.objects.create(
                            prescription=new_prescription,
                            drug=db_drug,
                            raw_name=data.get('raw_name', ''),
                            total_amount=extract_int(data.get('total_amount')),
                            frequency=data.get('frequency', ''),
                            days=extract_int(data.get('days'))
                        )
                    except Exception as e:
                        return JsonResponse({'status': 'error', 'message': f'💥 [存入藥品明細失敗] {str(e)}'}, status=500)
                    
                    # 存入警告 (使用 get_or_create 確保絕對不會重複)
                    for w in data.get("fda_result", []):
                        try:
                            DrugWarning.objects.get_or_create(
                                drug=db_drug,
                                conflict_target=w['conflict_target'],
                                defaults={'warning_desc': w['warning_desc']}
                            )
                        except Exception as e:
                            return JsonResponse({'status': 'error', 'message': f'💥 [存入警告失敗] {str(e)}'}, status=500)

            # 3. 將所有資料傳回前端
            return JsonResponse({
                'status': 'success',
                'message': f'藥單與圖片已成功存檔！',
                'data': final_report_data
            }, status=200)

        except json.JSONDecodeError:
            return JsonResponse({'status': 'error', 'message': 'JSON 格式錯誤，請確認前端資料是否放在 data 欄位'}, status=400)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f"系統錯誤: {str(e)}"}, status=500)

    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)