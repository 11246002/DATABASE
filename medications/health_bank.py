# ==========================================
# 健康存摺同步服務（Health Bank Sync Module）
# ------------------------------------------
# 目前狀態：Mock 模擬模式（使用固定假資料）
# 未來對接：衛生福利部中央健康保險署 健康存摺 SDK
#
# 🔮 標記說明：
#   「🔮 FUTURE-SDK」 = 未來對接真實 SDK 時需要修改的區塊
#   「✅ KEEP」        = 對接真實 SDK 時可完全保留、不需更動
# ==========================================

from django.http import JsonResponse
from django.views.decorators.csrf import csrf_exempt
from .models import MedicationHistory, PatientAllergy
from accounts.models import User
import json


@csrf_exempt
def mock_health_bank_sync(request):
    """
    健康存摺同步 API

    前端必須傳遞 user_id：
    - Body JSON: {"user_id": 1}
    - 或 Query Param: ?user_id=1
    若未傳遞 user_id，則回傳 400 錯誤。
    """
    if request.method == "POST":
        user_id = None

        # 1. 優先從 Request Body 讀取 {"user_id": 1}
        if request.body:
            try:
                data = json.loads(request.body)
                user_id = data.get("user_id")
            except Exception:
                pass

        # 2. 次之從 Query Param 讀取 ?user_id=1
        if not user_id:
            user_id = request.GET.get("user_id")

        # 3. 驗證是否提供 user_id
        if not user_id:
            return JsonResponse({
                "status": "error",
                "message": "請提供 user_id（例如 JSON Body: {\"user_id\": 1} 或 Query: ?user_id=1）"
            }, status=400)

        # 4. 檢查該使用者是否存在於資料庫（專案的 User 主鍵欄位名稱為 user_id）
        user = User.objects.filter(user_id=user_id).first()
        if not user:
            return JsonResponse({
                "status": "error",
                "message": f"找不到 ID 為 {user_id} 的使用者"
            }, status=404)

        # ==================================================
        # 🔮 FUTURE-SDK [3/5]：資料來源（此區塊為唯一核心替換區）
        # ─── 目前：使用寫死的 Mock 假資料 ───
        # ─── 未來：改為向健保署 API 發送請求，取得真實藥歷資料 ───
        #
        # 未來的程式碼大致如下：
        # response = requests.get(
        #     f"{os.getenv('HEALTH_BANK_API_URL')}/patient/medications",
        #     headers={"Authorization": f"Bearer {health_bank_token}"}
        # )
        # if response.status_code != 200:
        #     return JsonResponse({"status": "error", "message": "健保署 API 回應異常"}, status=502)
        # sdk_payload = response.json()
        # ==================================================

        mock_sdk_payload = {
            "status_code": 200,
            "patient_info": {
                "masked_id": "A123***789",
                "name": "王大明"
            },
            "medication_records": [
                {
                    "hosp_name": "國泰綜合醫院",
                    "rx_date": "2026-08-20",
                    "drug_code": "BC24512100",
                    "drug_name": "Candesartan",
                    "dosage": "8mg",
                    "frequency": "QD",
                    "days": 28,
                    "indication": "降血壓"
                }
            ],
            "allergy_records": [
                {
                    "allergen_name": "Amoxicillin",
                    "reaction": "皮膚紅疹、搔癢",
                    "identified_date": "2024-05-10"
                }
            ]
        }

        # 🔮 FUTURE-SDK [4/5]：資料欄位對應（若健保署欄位名稱不同，在此處轉換）
        # ─── 目前：Mock 資料的欄位名稱已與資料表一致，無需轉換 ───
        # ─── 未來：可能需要將健保署的欄位名稱映射到我們的資料表欄位 ───
        #
        # 例如健保署可能回傳的是：
        # { "hospital": "...", "prescription_date": "...", "nhi_code": "..." }
        # 需要轉換成我們的：
        # { "hosp_name": "...", "rx_date": "...", "drug_code": "..." }

        # ✅ KEEP：將藥歷資料寫入 MedicationHistory 資料表
        # （無論資料來自 Mock 或真實 SDK，寫入邏輯完全相同）
        for med in mock_sdk_payload["medication_records"]:
            MedicationHistory.objects.update_or_create(
                user=user,
                drug_code=med["drug_code"],
                defaults={
                    "drug_name": med["drug_name"],
                    "dosage": med["dosage"],
                    "frequency": med["frequency"],
                    "days": med["days"],
                    "hosp_name": med["hosp_name"],
                    "rx_date": med["rx_date"],
                }
            )

        # ✅ KEEP：將過敏原資料寫入 PatientAllergy 資料表
        # （無論資料來自 Mock 或真實 SDK，寫入邏輯完全相同）
        for alg in mock_sdk_payload["allergy_records"]:
            PatientAllergy.objects.update_or_create(
                user=user,
                allergen_name=alg["allergen_name"],
                defaults={
                    "reaction": alg["reaction"],
                }
            )

        # ✅ KEEP：回傳結果給前端
        # （回應格式不變，前端不需要任何修改）
        return JsonResponse({
            "status": "success",
            "message": "已成功自健保署健康存摺同步歷史藥歷與過敏原！",
            "synced_medications": len(mock_sdk_payload["medication_records"]),
            "synced_allergies": len(mock_sdk_payload["allergy_records"])
        })

    # ✅ KEEP：錯誤處理
    return JsonResponse({"status": "error", "message": "僅支援 POST 請求"}, status=405)


# ==========================================
# 🔮 FUTURE-SDK [5/5]：對接準備度總覽
# ==========================================
#
# ┌─────────────────────────────────┬──────────┬──────────────────────────┐
# │ 項目                            │ 狀態     │ 說明                      │
# ├─────────────────────────────────┼──────────┼──────────────────────────┤
# │ MedicationHistory 資料表         │ ✅ 已建立 │ 欄位與健保署格式對齊       │
# │ PatientAllergy 資料表            │ ✅ 已建立 │ 結構化儲存過敏原           │
# │ API 端點 (POST /health-bank/)   │ ✅ 已建立 │ 前端串接方式未來不需更動   │
# │ 冪等寫入 (update_or_create)     │ ✅ 已實作 │ 重複同步不產生重複資料     │
# │ OAuth 授權流程                   │ 🔮 待實作 │ 需取得 SDK 審核後實作      │
# │ 健保署 API 串接                  │ 🔮 待實作 │ 替換 mock_sdk_payload 即可 │
# │ 欄位名稱映射                     │ 🔮 待確認 │ 依健保署實際回傳格式調整   │
# └─────────────────────────────────┴──────────┴──────────────────────────┘
