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
    extract_int,
    check_user_medication_safety
)
from .models import Prescription, PrescriptionDrug, DrugWarning, Drug
from accounts.models import User


# ==========================================
# 藥單圖片辨識 (初步辨識確認資料)
# ==========================================
@csrf_exempt
def analyze_prescription_api(request):
    if request.method == 'POST':
        image_file = request.FILES.get('prescription_img')
        
        if not image_file:
            return JsonResponse({'status': 'error', 'message': '未收到圖片檔，請確認欄位名稱是否為 prescription_img'}, status=400)


        drugs_list = extract_drugs_from_image(image_file)
        
        if drugs_list:
            return JsonResponse({
                'status': 'success',
                'data': drugs_list
            }, status=200)
        else:
            return JsonResponse({'status': 'error', 'message': '圖片解析失敗或找不到藥品'}, status=400)
            
    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)


# ==========================================
# 藥單確認與存檔 (資料庫比對、查詢警告並存檔)
# ==========================================
@csrf_exempt 
def confirm_and_save_prescription_api(request):
    if request.method == 'POST':
        try:
            
            data_json_string = request.POST.get('data')
            if not data_json_string:
                return JsonResponse({'status': 'error', 'message': '未收到藥單資料'}, status=400)
                
            user_confirmed_data = json.loads(data_json_string)
            image_file = request.FILES.get('prescription_img')
            drugs_list = user_confirmed_data.get('confirmed_drugs', [])
            
            final_report_data = []
            drugs_to_translate = []

            # 第一階段：準備資料與查詢
            for drug in drugs_list:
                search_kw = drug.get('search_keyword', '')
                db_info = search_drug_in_db(search_kw)
                
                db_drug = Drug.objects.filter(
                    Q(med_ch__icontains=search_kw) | Q(med_en__icontains=search_kw)
                ).first()

                existing_fda_results = []
                need_fda_query = False

                # 檢查這顆藥是不是已經被查過、翻譯過了？
                if db_drug:
                    warnings = DrugWarning.objects.filter(drug=db_drug)
                    if warnings.exists():
                        # 資料庫已經有警告紀錄！直接拿出來用，不用查 FDA 了
                        print(f"快取命中：直接從資料庫讀取 {search_kw} 的警告！")
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

                
                report_item = {
                    "raw_name": drug.get('raw_name', ''),
                    "search_keyword": search_kw,
                    "frequency": drug.get('frequency', ''),
                    "days": drug.get('days', ''),
                    "total_amount": drug.get('total_amount', ''),
                    **db_info,  
                    "fda_result": existing_fda_results, # 先塞入已知的警告 (可能為空)
                    "db_drug_obj": db_drug # 順便把藥品實體存起來，等一下存檔直接用
                }
                
                # 只有當 need_fda_query 為 True 時，才去呼叫 openFDA
                if need_fda_query and db_info.get("element", "無資料") != "無資料":
                    status, fda_raw_text = query_openfda_interactions(db_info.get("element"))
                    if status == "HAS_CONFLICT":
                        drugs_to_translate.append({
                            "drug_name": report_item["raw_name"],
                            "english_text": fda_raw_text
                        })
                
                final_report_data.append(report_item)

            # 2. 將新發現的衝突拿去給 AI 翻譯 (如果全部都命中快取，這裡就不會執行)
            if drugs_to_translate:
                translations_dict = batch_translate_fda_warnings(drugs_to_translate)
                # 把翻譯好的警告塞回對應的藥裡面
                for data in final_report_data:
                    name = data["raw_name"]
                    if name in translations_dict:
                        data["fda_result"] = translations_dict[name]

            
            #  第二階段：存入資料庫
            from django.utils import timezone
            
            # 確認使用者
            user_id = user_confirmed_data.get('user_id')
            try:
                user_obj = User.objects.get(user_id=user_id)
            except User.DoesNotExist:
                return JsonResponse({'status': 'error', 'message': f'找不到 ID 為 {user_id} 的使用者'}, status=404)

            # 存入藥單主檔
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

            # 存入藥品明細與警告
            for data in final_report_data:
                # 直接把剛才找好的 db_drug_obj 拿出來用，並從字典裡移除 (以免轉 JSON 時報錯)
                db_drug = data.pop('db_drug_obj', None)


                try:
                    pd_item = PrescriptionDrug.objects.create(
                        prescription=new_prescription,
                        drug=db_drug,
                        raw_name=data.get('raw_name', ''),
                        total_amount=extract_int(data.get('total_amount')),
                        frequency=data.get('frequency', ''),
                        days=extract_int(data.get('days'))
                    )
                    
                    data['id'] = pd_item.id
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


# ==========================================
# 藥單列表
# ==========================================
@csrf_exempt
def get_user_prescriptions_api(request, user_id):
    if request.method == 'GET':
        try:
            # 撈出該使用者的所有藥單，依日期由新到舊排序
            prescriptions = Prescription.objects.filter(user_id=user_id).order_by('-visit_date')
            
            data_list = []
            for p in prescriptions:
                data_list.append({
                    "prescription_id": p.prescription_id,
                    "hospital_name": p.hospital_name,
                    "visit_date": p.visit_date.strftime('%Y-%m-%d'),
                    "drug_count": PrescriptionDrug.objects.filter(prescription=p).count(),
                    "image_url": p.image.url if p.image else None
                })
                
            return JsonResponse({'status': 'success', 'data': data_list}, status=200)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)


# ==========================================
# 藥單詳情 (包含藥品明細與警告)
# ==========================================    
@csrf_exempt
def get_prescription_detail_api(request, prescription_id):
    if request.method == 'GET':
        try:
            # 找出這張藥單的所有藥品明細
            drugs_in_p = PrescriptionDrug.objects.filter(prescription_id=prescription_id)
            
            detailed_data = []
            for item in drugs_in_p:
                # 處理警告紀錄 (加上檢查，避免 item.drug 是空的)
                warning_list = []
                if item.drug:
                    warnings = DrugWarning.objects.filter(drug=item.drug)
                    for w in warnings:
                        warning_list.append({
                            "conflict_target": w.conflict_target,
                            "warning_desc": w.warning_desc
                        })
                
                #  組合藥品資訊 (加上 id，並處理藥品可能為空的狀況)
                detailed_data.append({
                    "id": item.id, 
                    "raw_name": item.raw_name,
                    "med_ch": item.drug.med_ch if item.drug else "系統查無此藥品資訊",
                    "med_en": item.drug.med_en if item.drug else "Unknown Drug",
                    "frequency": item.frequency,
                    "total_amount": item.total_amount,
                    "days": item.days,
                    "indications": item.drug.indications if item.drug else "請諮詢醫師或藥師了解用途",
                    "warnings": warning_list
                })
                
            return JsonResponse({'status': 'success', 'data': detailed_data}, status=200)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f"讀取詳情失敗: {str(e)}"}, status=500)
        
        

# ==========================================
# 手動建立空白藥單 (只有醫院和日期)
# ==========================================
@csrf_exempt
def create_manual_prescription_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body.decode('utf-8'))
            user_id = data.get('user_id')
            user_obj = User.objects.get(id=user_id)

            new_p = Prescription.objects.create(
                user=user_obj,
                hospital_name=data.get('hospital_name', '手動新增藥單'),
                visit_date=data.get('visit_date', timezone.now())
            )
            return JsonResponse({'status': 'success', 'prescription_id': new_p.prescription_id})
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)


# ==========================================
# 手動新增「單顆」藥品到藥單中 (包含 FDA 與 AI 邏輯)
# ==========================================
@csrf_exempt
def add_single_drug_api(request, prescription_id):
    if request.method == 'POST':
        try:
            data = json.loads(request.body.decode('utf-8'))
            raw_name = data.get('raw_name', '').strip()
            
            if not raw_name:
                return JsonResponse({'status': 'error', 'message': '請輸入藥品名稱'}, status=400)
                
            search_kw = raw_name
            
            # (A) 查詢資料庫與快取警告
            db_info = search_drug_in_db(search_kw)
            db_drug = Drug.objects.filter(Q(med_ch__icontains=search_kw) | Q(med_en__icontains=search_kw)).first()
            
           
            # (B) 處理警告 (先看快取)
            final_warnings = []
            if db_drug:
                warnings_in_db = DrugWarning.objects.filter(drug=db_drug)
            
                if warnings_in_db.exists():
                    for w in warnings_in_db:
                        final_warnings.append({"conflict_target": w.conflict_target, "warning_desc": w.warning_desc})
                else:
                    if db_info.get("element") != "無資料":
                        status, fda_raw = query_openfda_interactions(db_info["element"])
                        if status == "HAS_CONFLICT":
                            translated = batch_translate_fda_warnings([{"drug_name": search_kw, "english_text": fda_raw}])
                            final_warnings = translated.get(search_kw, [])
                            for tw in final_warnings:
                                DrugWarning.objects.get_or_create(drug=db_drug, conflict_target=tw['conflict_target'], defaults={'warning_desc': tw['warning_desc']})

            # (C) 存入明細表
            new_pd = PrescriptionDrug.objects.create(
                prescription_id=prescription_id,
                drug=db_drug,
                raw_name=raw_name, 
                total_amount=extract_int(data.get('total_amount', '0')),
                frequency=data.get('frequency', ''),
                days=extract_int(data.get('days', '0'))
            )
            
            # (D) 重新包裝回傳格式，完全對齊 confirm_and_save_prescription_api
            report_item = {
                "id": new_pd.id,
                "raw_name": raw_name,
                "search_keyword": search_kw, # 系統自己補上這個欄位回傳給前端，保持格式統一
                "frequency": data.get('frequency', ''),
                "days": data.get('days', ''),
                "total_amount": data.get('total_amount', ''),
                "fda_result": final_warnings,
                **db_info,  
            }

            return JsonResponse({
                'status': 'success',
                'message': '手動新增藥品成功！',
                'data': [report_item]
            }, status=200)

        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)
            
    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)


# ==========================================        
# 修改藥單的醫院名稱或日期 (不修改藥品明細)
# ==========================================
@csrf_exempt
def update_prescription_api(request, prescription_id):
    if request.method in ['PUT', 'POST']:
        try:
            p = Prescription.objects.get(prescription_id=prescription_id)
            
            body_unicode = request.body.decode('utf-8')
            data = json.loads(body_unicode)
         
            if 'hospital_name' in data:
                p.hospital_name = data['hospital_name']
                
            if 'visit_date' in data:
                from django.utils.dateparse import parse_date
                parsed_date = parse_date(data['visit_date'])
                if parsed_date:
                    p.visit_date = parsed_date

            p.save() 
            
            return JsonResponse({
                'status': 'success', 
                'message': '藥單資料更新成功',
                'data': {
                    'hospital_name': p.hospital_name,
                    'visit_date': p.visit_date.strftime('%Y-%m-%d')
                }
            })
            
        except Prescription.DoesNotExist:
            return JsonResponse({'status': 'error', 'message': '找不到該藥單'}, status=404)
        except json.JSONDecodeError:
            return JsonResponse({'status': 'error', 'message': 'JSON 格式錯誤'}, status=400)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f'更新失敗: {str(e)}'}, status=500)

    return JsonResponse({'status': 'error', 'message': '僅支援 PUT 或 POST 請求'}, status=405)


# ==========================================
# 刪除整張藥單 (會連動刪除該藥單下的所有藥品明細)
# ==========================================
@csrf_exempt
def delete_prescription_api(request, prescription_id):
    if request.method in ['DELETE', 'POST']:
        try:
            p = Prescription.objects.get(prescription_id=prescription_id)
            p.delete() 
            return JsonResponse({'status': 'success', 'message': f'藥單 {prescription_id} 已完全刪除'})
        except Prescription.DoesNotExist:
            return JsonResponse({'status': 'error', 'message': '找不到該藥單'}, status=404)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)
        

# ==========================================
# 只刪除藥單中的某「一顆」藥品紀錄
# ==========================================
@csrf_exempt
def delete_single_drug_api(request, pd_id):
    if request.method in ['DELETE', 'POST']:
        try:
            # pd_id 是 PrescriptionDrug 這張表的 ID
            drug_item = PrescriptionDrug.objects.get(id=pd_id)
            drug_item.delete()
            return JsonResponse({'status': 'success', 'message': '已從藥單中移除該藥品'})
        except PrescriptionDrug.DoesNotExist:
            return JsonResponse({'status': 'error', 'message': '找不到該藥品紀錄'}, status=404)
        except Exception as e:
            return JsonResponse({'status': 'error', 'message': str(e)}, status=500)
        

# ==========================================
# 總體用藥安全檢查 API (呼叫 utils 工具版)
# ==========================================
@csrf_exempt
def check_all_medications_safety_api(request):
    if request.method == 'POST':
        try:
            data = json.loads(request.body)
            user_id = data.get('user_id')

            if not user_id:
                return JsonResponse({'status': 'error', 'message': '缺少 user_id'}, status=400)

            # 🌟 核心：直接把 user_id 丟給小工具去運算，我們只負責收結果
            is_success, result = check_user_medication_safety(user_id)

            if is_success:
                return JsonResponse({
                    'status': 'success',
                    'message': '總體用藥安全檢查完成',
                    'data': result # 這裡的 result 是裝滿危險名單的 List
                }, status=200)
            else:
                # 如果 is_success 是 False，代表 result 裡面裝的是錯誤訊息
                status_code = 404 if '找不到' in result else 500
                return JsonResponse({'status': 'error', 'message': result}, status=status_code)

        except Exception as e:
            return JsonResponse({'status': 'error', 'message': f"API 解析錯誤: {str(e)}"}, status=500)

    return JsonResponse({'status': 'error', 'message': '僅支援 POST 請求'}, status=405)