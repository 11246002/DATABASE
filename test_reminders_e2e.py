"""
提醒功能 API 端到端測試 (E2E)

用法：
    python test_reminders_e2e.py                # 使用下方預設的三個 ID
    python test_reminders_e2e.py 5 12 30        # 依序帶入 USER_ID PRESCRIPTION_ID PRESCRIPTION_DRUG_ID

注意：
    1. 三個 ID 必須來自「同一組」關聯資料（該使用者的處方箋，且藥物屬於該處方箋）。
    2. 腳本會新增提醒、切換開關、寫入服藥紀錄、軟刪除一筆提醒，請使用測試資料。
"""
import sys
import requests

# ==========================================
# 設定區：只需要改這裡（或用命令列參數帶入）
# ==========================================
BASE_URL = "http://127.0.0.1:8000"
USER_ID = 3
PRESCRIPTION_ID = 1
PRESCRIPTION_DRUG_ID = 1
MORNING_TAG = "早餐後"   # 請與資料庫既有的 frequency_tag 寫法一致，否則會被當成新提醒而產生重複
EVENING_TAG = "晚餐後"
TIMEOUT = 10  # 每個請求最多等幾秒

if len(sys.argv) == 4:
    USER_ID, PRESCRIPTION_ID, PRESCRIPTION_DRUG_ID = (int(x) for x in sys.argv[1:4])
elif len(sys.argv) != 1:
    sys.exit("用法: python test_reminders_e2e.py [USER_ID PRESCRIPTION_ID PRESCRIPTION_DRUG_ID]")

TOTAL = 7
results = []  # (步驟, 標題, 是否通過, 備註)


def run_step(step, title, method, path, check=None, **kwargs):
    """發送請求並檢查：狀態碼 200/201、能解析 JSON、status == success、自訂欄位檢查。
    回傳 (解析後的 JSON 或 None, 是否通過)。"""
    print(f"\n[{step}/{TOTAL}] {title}  ({method} {path})")
    problems = []
    data = None

    try:
        res = requests.request(method, BASE_URL + path, timeout=TIMEOUT, **kwargs)
    except requests.exceptions.ConnectionError:
        sys.exit(f"❌ 連不上 {BASE_URL}，請確認 Django 伺服器（python manage.py runserver）有在執行。")
    except requests.exceptions.Timeout:
        problems.append(f"請求超過 {TIMEOUT} 秒沒回應")
        res = None

    if res is not None:
        print(f"   狀態碼: {res.status_code}")
        if res.status_code not in (200, 201):
            problems.append(f"狀態碼應為 200/201，實際為 {res.status_code}")

        try:
            data = res.json()
            print(f"   回應: {data.get('status')} - {data.get('message', '')}")
            if data.get("status") != "success":
                problems.append(f"JSON 的 status 應為 success，實際為 {data.get('status')!r}")
            elif check:
                problems += check(data)
        except ValueError:
            problems.append("回應不是合法 JSON")
            print(f"   回應原始文字: {res.text[:300]}")

    ok = not problems
    for p in problems:
        print(f"   ⚠️  {p}")
    print("   ✅ 通過" if ok else "   ❌ 失敗")
    results.append((step, title, ok, "；".join(problems)))
    return data, ok


def skip_step(step, title, reason):
    print(f"\n[{step}/{TOTAL}] {title}\n   ❌ 未執行：{reason}")
    results.append((step, title, False, reason))


def fetch_reminders():
    """重新查一次提醒列表（測試內部驗證用），失敗回傳 None。"""
    try:
        r = requests.get(BASE_URL + "/medications/api/reminders/list/",
                         params={"prescription_id": PRESCRIPTION_ID, "user_id": USER_ID}, timeout=TIMEOUT)
        return r.json().get("data")
    except Exception:
        return None


print(f"使用測試資料：user_id={USER_ID}, prescription_id={PRESCRIPTION_ID}, "
      f"prescription_drug_id={PRESCRIPTION_DRUG_ID}")

# ==========================================
# 1. 批次設定提醒
# ==========================================
set_payload = {
    "user_id": USER_ID,
    "prescription_id": PRESCRIPTION_ID,
    "drugs": [
        {
            "prescription_drug_id": PRESCRIPTION_DRUG_ID,
            "reminders": [
                {"frequency_tag": MORNING_TAG, "remind_time": "08:30:00", "is_active": True},
                {"frequency_tag": EVENING_TAG, "remind_time": "18:30:00", "is_active": True},
            ],
        }
    ],
}
_, step1_ok = run_step(1, "批次設定提醒", "POST", "/medications/api/reminders/set/", json=set_payload)


# ==========================================
# 2. 取得藥單提醒列表
# ==========================================
def find_target(items):
    """找出步驟 1 剛設定的『早上』提醒：同藥物、同標籤，取 remind_id 最大者。"""
    matches = [i for i in items
               if i.get("prescription_drug_id") == PRESCRIPTION_DRUG_ID and i.get("frequency_tag") == MORNING_TAG]
    return max(matches, key=lambda i: i.get("remind_id", 0)) if matches else None


def check_list(data):
    items = data.get("data")
    if not isinstance(items, list) or not items:
        return ["data 應為非空陣列（步驟 1 之後至少要有 1 個提醒）"]
    if "remind_id" not in items[0]:
        return ["data[0] 缺少 remind_id 欄位"]
    target = find_target(items)
    if target is None:
        return [f"找不到剛設定的提醒（藥物 {PRESCRIPTION_DRUG_ID}、標籤 {MORNING_TAG!r}）"]
    if not target.get("is_active"):
        return [f"步驟 1 送出 is_active=True，但提醒 {target['remind_id']} 實際是關閉的"]
    return []


data2, step2_ok = run_step(
    2, "查詢藥單提醒列表", "GET", "/medications/api/reminders/list/",
    check=check_list, params={"prescription_id": PRESCRIPTION_ID, "user_id": USER_ID},
)
target_remind_id = find_target(data2["data"])["remind_id"] if step2_ok else None
print(f"   👉 本次測試鎖定的鬧鐘 ID: {target_remind_id}")

# ==========================================
# 3. 取得今日服藥日程
# ==========================================
data3, _ = run_step(3, "今日服藥清單", "GET", "/medications/api/reminders/today/", params={"user_id": USER_ID})
if data3 and isinstance(data3.get("data"), list):
    print(f"   👉 今日共 {len(data3['data'])} 筆")
    if not data3["data"]:
        print("   ⚠️  今日清單為空：請確認該處方箋的日期區間（start_date ~ end_date）是否包含今天")

# ==========================================
# 4 ~ 7 需要 remind_id
# ==========================================
if target_remind_id is not None:
    # 4. 切換鬧鐘開關
    def check_toggle(data):
        items = fetch_reminders() or []
        t = next((i for i in items if i.get("remind_id") == target_remind_id), None)
        if t is None:
            return ["切換後在列表中找不到該提醒"]
        if t.get("is_active") is not False:
            return [f"啟用中的提醒切換後 is_active 應為 false，實際為 {t.get('is_active')!r}"]
        return []

    run_step(4, "切換鬧鐘開關（啟用 → 關閉）", "POST",
             f"/medications/api/reminders/{target_remind_id}/toggle/", check=check_toggle,
             json={"user_id": USER_ID})

    # 5. 服藥打卡回報
    run_step(5, "服藥打卡回報", "POST", "/medications/api/history/record/",
             json={"user_id": USER_ID, "remind_id": target_remind_id, "status": "已吃", "force": True})

    # 6. 查詢遵從率與歷史報表
    def check_stats(data):
        summary = data.get("summary")
        if not isinstance(summary, dict):
            return ["缺少 summary 物件"]
        return [f"summary 缺少 {k}" for k in ("adherence_rate", "rating") if k not in summary]

    data6, ok6 = run_step(6, "查詢週遵從率", "GET", "/medications/api/history/stats/",
                          check=check_stats, params={"user_id": USER_ID, "days": 7})
    if ok6:
        print(f"   👉 遵從率: {data6['summary']['adherence_rate']}% | 評級: {data6['summary']['rating']}")

    # 7. 單筆鬧鐘軟刪除（身分用 header 傳遞，與其他端點不同，API 文件要特別標示）
    run_step(7, "刪除單筆鬧鐘", "DELETE",
             f"/medications/api/reminders/{target_remind_id}/delete/", headers={"X-User-Id": str(USER_ID)})
    after = next((i for i in (fetch_reminders() or []) if i.get("remind_id") == target_remind_id), None)
    if after is not None:
        print(f"   ℹ️  刪除後該提醒仍出現在列表中（is_active={after.get('is_active')!r}），"
              "前端無法分辨『已刪除』與『已關閉』，請確認這是否符合設計並寫進 API 文件")
else:
    reason = "步驟 2 沒有取得 remind_id"
    for n, t in [(4, "切換鬧鐘開關"), (5, "服藥打卡回報"), (6, "查詢週遵從率"), (7, "刪除單筆鬧鐘")]:
        skip_step(n, t, reason)

# ==========================================
# 總結
# ==========================================
print("\n" + "=" * 50)
print("測試總結")
print("=" * 50)
for step, title, ok, note in sorted(results):
    print(f"{'✅' if ok else '❌'} [{step}/{TOTAL}] {title}" + (f"  ← {note}" if note else ""))

passed = sum(1 for r in results if r[2])
print("-" * 50)
if passed == TOTAL:
    print(f"🎉 {passed}/{TOTAL} 全部通過：後端 API 行為與文件一致，可以交給前端串接。")
    sys.exit(0)
print(f"🚫 只通過 {passed}/{TOTAL}，請依上方 ⚠️ 訊息修正後再重跑。")
sys.exit(1)