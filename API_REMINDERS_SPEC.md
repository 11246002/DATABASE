# 用藥提醒與服藥追蹤功能 API 規格文件（給前端）

> **適用對象**：Flutter / 前端工程團隊  
> **涵蓋端點**：共 7 個端點（批次設定、查詢列表、今日日程清單、單筆切換開關、服藥打卡回報、單筆刪除鬧鐘、服藥遵從率與歷史報表）。  
> **版本狀態**：已通過後端整合測試，資料庫 Schema 與業務邏輯已對齊。

---

## 一、 通用規則 (General Guidelines)

### 1. Base URL 環境設定

| 環境 | 網址 | 說明 |
|---|---|---|
| **本機開發 / iOS 模擬器** | `http://127.0.0.1:8000` | 電腦本機除錯、Chrome Web 除錯 |
| **Android 模擬器** | `http://10.0.2.2:8000` | 模擬器裡的 `127.0.0.1` 指向手機本機，需用 `10.0.2.2` 連接電腦主機 |
| **實體手機 (Wi-Fi 區網)** | `http://<電腦區域IP>:8000` | 例如 `http://192.168.1.105:8000`（手機與電腦需在同一 Wi-Fi） |

### 2. Request 標頭
- 所有 `POST` / `PUT` / `PATCH` 請求必須附帶 Header：
  ```http
  Content-Type: application/json
  ```

### 3. 身分驗證與 `user_id` 傳遞彈性
後端已實作通用驗證解析器，前端可使用以下**任一種方式**驗證身分（推薦方式 A，最不易出錯）：
- **方式 A（標準推薦）**：在 Request Header 帶入登入時儲存的 Token：
  ```http
  Authorization: Bearer session_token_<user_id>
  ```
- **方式 B（自訂 Header）**：所有端點皆通用支援：
  ```http
  X-User-Id: <user_id>
  ```
- **方式 C（參數帶入）**：若不帶 Header，請依照各端點規格在 `Query String` (`?user_id=1`) 或 `Request Body` (`"user_id": 1`) 中傳入。

### 4. Response 格式規範
- **判斷成功標準**：HTTP 狀態碼 **`200 ~ 299`**（包含 `200 OK` 與 `201 Created`）。
  > ⚠️ **重要**：請使用 `response.statusCode >= 200 && response.statusCode < 300` 判斷成功，切勿只判斷 `200`（例如首次新增鬧鐘會回傳 `201`）。
- **失敗標準**：回傳格式皆固定為：
  ```json
  {
    "status": "error",
    "message": "具體的錯誤原因提示"
  }
  ```
  前端可直接將 `message` 彈出 SnackBar 或 Toast 給長輩/使用者看。

| HTTP 狀態碼 | 情境說明 |
|---|---|
| **200 OK** | 請求成功、資料更新成功、查詢成功 |
| **201 Created** | 首次新增資料成功（如新建提醒、首次打卡） |
| **400 Bad Request** | 必填欄位缺少、時間或日期格式錯誤、非法打卡狀態、重複打卡防呆觸發 |
| **401 Unauthorized** | 缺少身分憑證（未帶 `user_id` 或 Token） |
| **403 Forbidden** | 該藥單/鬧鐘存在，但屬於其他使用者（防越權保護） |
| **404 Not Found** | 該藥單或鬧鐘 ID 在系統中不存在 |

### 5. 格式標準與時段標籤 (`frequency_tag`)
- **時間格式**：`HH:MM:SS`（24 小時制），例如 `08:30:00`、`18:30:00`。
- **日期格式**：`YYYY-MM-DD`，例如 `2026-09-19`。
- **服藥時段標籤 (`frequency_tag`)**：
  - 後端以「同一藥物 + 同一標籤」判斷要更新既有時間還是新增時段。
  - 前端請統一使用以下標準標籤：
    - 三餐後：`早餐後`、`午餐後`、`晚餐後`（或 `早飯後`、`午飯後`、`晚飯後`）
    - 三餐前：`早餐前`、`午餐前`、`晚餐前`
    - 睡前：`睡前`
    - 特殊：`空腹`、`需要時 (PRN)`

---

## 二、 核心 API 端點清單

### 1. 批次設定整張藥單的吃藥鬧鐘
- **URL**：`/medications/api/reminders/set/`
- **Method**：`POST`
- **前端場景**：在「提醒設定」頁面，長輩設定好各餐時間後點擊「一鍵儲存設定」。
- **Request (JSON)**：
  ```json
  {
    "user_id": 1,
    "prescription_id": 1,
    "drugs": [
      {
        "prescription_drug_id": 1,
        "reminders": [
          {"frequency_tag": "早餐後", "remind_time": "08:30:00", "is_active": true},
          {"frequency_tag": "午餐後", "remind_time": "12:30:00", "is_active": true},
          {"frequency_tag": "晚餐後", "remind_time": "18:30:00", "is_active": true}
        ]
      },
      {
        "prescription_drug_id": 2,
        "reminders": [
          {"frequency_tag": "睡前", "remind_time": "21:30:00", "is_active": true}
        ]
      }
    ]
  }
  ```
- **欄位說明**：
  | 欄位 | 型別 | 必填 | 說明 |
  |---|---|:---:|---|
  | `user_id` | int | 是 | 使用者 ID，必須為該處方箋擁有者 |
  | `prescription_id` | int | 是 | 處方箋 ID |
  | `drugs` | array | 是 | 整張藥單的所有藥物陣列 |
  | `drugs[].prescription_drug_id` | int | 是 | 該處方箋下的處方藥物明細 ID |
  | `drugs[].reminders[].frequency_tag` | string | 是 | 時段標籤（如 `早餐後`、`睡前`） |
  | `drugs[].reminders[].remind_time` | string | 是 | 提醒時間 `HH:MM:SS` |
  | `drugs[].reminders[].is_active` | bool | 否 | 預設 `true`，是否啟用鬧鐘 |

- **Response (201 Created / 200 OK)**：
  ```json
  {
    "status": "success",
    "message": "已成功批次設定完成，新增 4 筆、更新 0 筆提醒紀錄",
    "data": {
      "created_count": 4,
      "updated_count": 0
    }
  }
  ```
- **前端串接注意事項**：
  - **整張藥單同步機制**：同顆藥底下，本次 Request **未包含**的既有時段，會被後端自動標記為關閉（`is_active = false`）。
  - 因此前端送出時，請務必送出**該藥單所有藥物的完整時段設定**，避免未修改的鬧鐘被關閉。

---

### 2. 查詢單張藥單已設定的提醒列表
- **URL**：`/medications/api/reminders/list/`
- **Method**：`GET`
- **前端場景**：進入特定藥單的「提醒設定」頁面時，載入目前已設定的時間與開關狀態。
- **Request (Query Parameters)**：
  ```http
  GET /medications/api/reminders/list/?prescription_id=1&user_id=1&active_only=false
  ```
  | 參數 | 型別 | 必填 | 說明 |
  |---|---|:---:|---|
  | `prescription_id` | int | 是 | 處方箋 ID |
  | `user_id` | int | 是 | 使用者 ID |
  | `active_only` | bool | 否 | 預設 `false`。若傳 `true` 則只抓取啟用中且未過期的鬧鐘 |

- **Response (200 OK)**：
  ```json
  {
    "status": "success",
    "data": [
      {
        "remind_id": 14,
        "prescription_drug_id": 1,
        "raw_name": "阿斯匹靈",
        "frequency_tag": "早餐後",
        "remind_time": "08:30:00",
        "is_active": true,
        "is_expired": false,
        "start_date": "2026-09-18",
        "end_date": "2026-09-23"
      }
    ]
  }
  ```
- **欄位說明**：
  - `is_expired`：是否已超過處方服用天數（`visit_date + days - 1`）。
  - 若前端只想顯示啟用中的鬧鐘，可直接帶 `&active_only=true`，已刪除或關閉的鬧鐘將自動隱藏。

---

### 3. 取得今日（或指定日期）服藥日程清單
- **URL**：`/medications/api/reminders/today/`
- **Method**：`GET`（亦支援 `POST`）
- **前端場景**：**App 首頁 / 今日服藥儀表板**。跨藥單匯總今日所有該服用的藥品與提醒時間，並標註今天是否已打卡。
- **Request (Query Parameters)**：
  ```http
  GET /medications/api/reminders/today/?user_id=1&date=2026-09-19&active_only=true
  ```
  | 參數 | 型別 | 必填 | 說明 |
  |---|---|:---:|---|
  | `user_id` | int | 是 | 使用者 ID |
  | `date` | string | 否 | 查詢日期 `YYYY-MM-DD`，**預設為伺服器今天** |
  | `active_only` | bool | 否 | **預設 `true`**。只抓「啟用中且落在服藥天數內」的鬧鐘 |

- **Response (200 OK)**：
  ```json
  {
    "status": "success",
    "date": "2026-09-19",
    "user_id": 1,
    "total_count": 1,
    "data": [
      {
        "remind_id": 14,
        "remind_time": "18:30:00",
        "frequency_tag": "晚餐後",
        "status": "未吃",
        "taken_at": null,
        "takingrecord_id": null,
        "is_active": true,
        "is_expired": false,
        "is_in_range": true,
        "prescription_drug_id": 1,
        "raw_name": "阿斯匹靈",
        "med_ch": "阿斯匹靈腸溶膜衣錠",
        "med_en": "Bokey Enteric-Coated",
        "remaining_amount": 10,
        "prescription_id": 1,
        "hospital_name": "台大醫院",
        "visit_date": "2026-09-18",
        "start_date": "2026-09-18",
        "end_date": "2026-09-23"
      }
    ]
  }
  ```
- **重要欄位說明**：
  - `status`：今日打卡狀態，嚴格只有 3 種：
    1. `"未吃"`：今日尚未針對該時段打卡
    2. `"已吃"`：今日已完成服藥打卡
    3. `"略過"`：今日已點擊略過
  - 清單預設依 `remind_time`（鬧鐘時間）由早到晚嚴格排序。

---

### 4. 單獨切換鬧鐘開關（啟用 / 暫停）
- **URL**：`/medications/api/reminders/{remind_id}/toggle/`
- **Method**：`POST`
- **前端場景**：長輩在鬧鐘列表點擊 Switch 開關（例如中午時段不想響鈴）。
- **Request (JSON)**：
  ```json
  {
    "user_id": 1,
    "is_active": false
  }
  ```
  *(備註：`is_active` 為選填；若未傳入，後端會自動將現有狀態反轉反向切換)*
- **Response (200 OK)**：
  ```json
  {
    "status": "success",
    "message": "鬧鐘已成功關閉",
    "data": {
      "remind_id": 14,
      "is_active": false,
      "frequency_tag": "晚餐後",
      "remind_time": "18:30:00"
    }
  }
  ```

---

### 5. 單獨刪除鬧鐘（軟刪除保護歷史紀錄）
- **URL**：`/medications/api/reminders/{remind_id}/delete/`
- **Method**：`DELETE`（亦相容 `POST`）
- **前端場景**：在鬧鐘列表上長輩向左滑動點擊「刪除」。
- **Request**：
  - URL Path 帶入 `remind_id`。
  - 身分傳遞（任選一）：
    - Header: `X-User-Id: 1`
    - 或 Header: `Authorization: Bearer session_token_1`
    - 或 Query: `?user_id=1`
- **Response (200 OK)**：
  ```json
  {
    "status": "success",
    "message": "已成功刪除鬧鐘：阿斯匹靈 (晚餐後 18:30:00)",
    "data": {
      "remind_id": 14,
      "is_active": false
    }
  }
  ```
- **技術特性**：後端執行安全軟刪除（`is_active = false`），**絕對不會**連帶清空長輩過去累積的服藥歷史打卡紀錄。刪除後該鬧鐘立即自「今日服藥日程」移除。

---

### 6. 服藥打卡回報（已吃 / 略過）
- **URL**：`/medications/api/history/record/`
- **Method**：`POST`
- **前端場景**：手機推播鬧鐘響起，彈出視窗讓長輩點選「已吃」或「略過」。標記「已吃」時後端會**自動扣減該藥物的剩餘顆數 (`remaining_amount`)**。
- **Request (JSON)**：
  ```json
  {
    "user_id": 1,
    "remind_id": 14,
    "status": "已吃",
    "force": false,
    "record_date": "2026-09-19"
  }
  ```
- **欄位說明**：
  | 欄位 | 型別 | 必填 | 說明 |
  |---|---|:---:|---|
  | `user_id` | int | 是 | 使用者 ID |
  | `remind_id` | int | 是 | 鬧鐘 ID（取自今日清單或推播 payload） |
  | `status` | string | 是 | 嚴格限制只能為 **`"已吃"`** 或 **`"略過"`** |
  | `force` | bool | 否 | **預設 `false`**。防連點防呆開關 |
  | `record_date` | string | 否 | 格式 `YYYY-MM-DD`，**預設為今天**。用於離線補打卡或跨日補登 |

- **`force` 防呆防連點機制說明**：
  | 當日既有紀錄狀態 | `force: false`（一般打卡） | `force: true`（強制重刷） |
  |---|---|---|
  | **今日尚無紀錄** | 新增打卡，回傳 **201 Created** | 新增打卡，回傳 **201 Created** |
  | **已有相同狀態**（如已吃又按已吃） | **400 阻擋**（回傳「請勿重複打卡」） | 覆蓋更新時間戳記，回傳 **200 OK** |
  | **已有不同狀態**（如略過改吃） | 視為誤按更正，更新狀態並**自動回補/扣減庫存**，回傳 **200 OK** | 覆蓋更新，回傳 **200 OK** |

- **Response 成功 (201 Created / 200 OK)**：
  ```json
  {
    "status": "success",
    "message": "吃藥紀錄已成功寫入資料庫",
    "data": {
      "takingrecord_id": 45,
      "status": "已吃",
      "taken_at": "2026-09-19 18:32:10",
      "remaining_amount": 9
    }
  }
  ```
- **Response 重複打卡阻擋 (400 Bad Request)**：
  ```json
  {
    "status": "error",
    "message": "請勿重複打卡！此鬧鐘時段已於 18:32:10 記錄為「已吃」",
    "data": {
      "takingrecord_id": 45,
      "status": "已吃",
      "record_date": "2026-09-19",
      "taken_at": "2026-09-19 18:32:10",
      "remaining_amount": 9
    }
  }
  ```
  *(前端若收到重複打卡的 400，可直接拿 `data` 內的資料更新 UI，不需跳出報錯警告)*

---

### 7. 服藥遵從率統計與歷史趨勢報表
- **URL**：`/medications/api/history/stats/`
- **Method**：`GET`
- **前端場景**：**個人健康報表 / 家屬遠端照護介面**。繪製每週服藥折線圖、遵從率儀表盤、歷史服藥日誌。
- **Request (Query Parameters)**：
  ```http
  GET /medications/api/history/stats/?user_id=1&days=7
  ```
  | 參數 | 型別 | 必填 | 說明 |
  |---|---|:---:|---|
  | `user_id` | int | 是 | 使用者 ID |
  | `days` | int | 否 | 統計最近天數，**預設 `7` 天** |
  | `start_date` / `end_date` | string | 否 | 自訂日期區間 `YYYY-MM-DD` |

- **Response (200 OK)**：
  ```json
  {
    "status": "success",
    "user_id": 1,
    "start_date": "2026-09-13",
    "end_date": "2026-09-19",
    "days_analyzed": 7,
    "summary": {
      "total_expected": 21,
      "total_taken": 18,
      "total_skipped": 2,
      "total_missed": 1,
      "adherence_rate": 85.7,
      "rating": "良好 (偶有遺漏)"
    },
    "daily_stats": [
      {
        "date": "2026-09-19",
        "expected_count": 3,
        "taken_count": 3,
        "skipped_count": 0,
        "missed_count": 0,
        "adherence_rate": 100.0
      }
    ],
    "recent_history": [
      {
        "takingrecord_id": 45,
        "remind_id": 14,
        "drug_name": "阿斯匹靈",
        "frequency_tag": "晚餐後",
        "status": "已吃",
        "taken_at": "2026-09-19 18:32:10"
      }
    ]
  }
  ```
- **評級分級標準 (`rating`)**：
  - `≥ 90%`：極佳 (規律服藥)
  - `75% ~ 89%`：良好 (偶有遺漏)
  - `50% ~ 74%`：尚可 (需多加提醒)
  - `< 50%`：不佳 (高度遺漏風險)

---

## 三、 前端典型互動流程建議

```mermaid
graph TD
    A[使用者打開首頁] --> B[呼叫 GET /today/ 取得今日日程]
    B --> C[鬧鐘響起 / 點擊服藥卡片]
    C --> D[呼叫 POST /history/record/ 打卡 (force: false)]
    D -->|成功 200/201| E[重新呼叫 GET /today/ 或就地更新打卡狀態與剩餘顆數]
    D -->|400 重複打卡| E

    F[進入提醒設定頁] --> G[呼叫 GET /list/ 取得整張藥單現存鬧鐘]
    G --> H[長輩調整各餐時間]
    H --> I[點擊儲存: 呼叫 POST /set/ 送出整張藥單完整陣列]
    I --> J[後端就地更新, 保證歷史打卡紀錄永不遺失]

    K[個人健康報表頁] --> L[呼叫 GET /history/stats/?days=7 繪製每週遵從率圖表]
```
