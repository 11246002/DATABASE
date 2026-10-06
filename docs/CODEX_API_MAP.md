# Reverse-engineered API map

Base URL is supplied by Flutter's `API_BASE_URL`. Root Django prefixes are `/accounts/` and `/medications/`. No query parameters are implemented by any application endpoint. JSON calls use `Content-Type: application/json`; multipart calls let `http.MultipartRequest` set the boundary. No endpoint requires or validates an authentication header.

Coverage definition used by the audit:

- Backend application endpoints: **19** (admin excluded).
- Flutter HTTP call sites: **18**.
- Unique frontend endpoints: **15**.
- Unique frontend endpoints matched to backend: **15**.
- Backend-only/unmatched endpoints: **4** (three group APIs and taking-history record).
- Frontend-only/unmatched endpoints: **0**.

## Accounts endpoints

### POST `/accounts/api/register/`

- Frontend caller: `RegisterPage._register`; backend: `accounts.views.register_api`.
- Request JSON: required `user_name: string`, `password: string`; optional `nickname: string|null`, `gender: string|null`, `height: number|null`, `weight: number|null`, `allergies: string|null`, `emergency_contact_phone: string|null`. Flutter additionally requires a local “real name” but sends no such key.
- Success: 201 `{status, message, user_id}`. Errors: 400 missing credentials or duplicate name; 500 exception. Unsupported methods fall through without a response.
- DB: reads/creates `User`; password is hashed through `UserManager.create_user`.
- Auth/status/conflict: public by design, no CSRF. Frontend accepts 200 or 201 and does not verify response `status`; real-name field has no backend/model equivalent.

### POST `/accounts/api/login/`

- Frontend caller: `LoginPage._login`; backend: `accounts.views.login_api`.
- Request JSON: `user_name: string`, `password: string`; neither is explicitly validated before lookup/check.
- Success: 200 `{status:'success', message, data:{user_id,user_name,role,nickname,token}}`. Errors: 404 unknown user, 401 wrong password, 500 exception. Unsupported methods fall through.
- DB: reads `User`; no session/token row is created.
- Auth/status/conflict: public. `token` is deterministic placeholder text; Flutter stores it but never sends it.

### POST `/accounts/api/user/profile/`

- Frontend caller: `UserProfilePage._fetchUserProfile`; backend: `get_user_profile_api`.
- Request JSON: required `user_id: integer`.
- Success: 200 data with `user_id`, `user_name`, `nickname`, `gender`, `height`, `weight`, `allergies`, `emergency_contact_phone`. Errors: 400 missing/invalid JSON, 404 user missing, 500; 405 other methods.
- DB: reads `User`.
- Auth/conflict: none; caller-provided user ID controls whose profile is returned.

### POST `/accounts/api/user/update/`

- Frontend caller: `UserProfilePage._updateProfile`; backend: `update_user_profile_api`.
- Request JSON: required `user_id: integer`; optional patch keys `nickname`, `gender`, `height`, `weight`, `allergies`, `emergency_contact_phone`.
- Success: 200 data only includes `user_id`, `user_name`, `nickname`. Errors: 400 missing ID/invalid JSON, 404, 500; 405 other methods.
- DB: updates `User`.
- Auth/conflict: none; caller can update any known user ID. Types/ranges are not validated beyond ORM conversion.

### POST `/accounts/api/group/create/`

- Frontend caller: none; backend: `create_group_api`.
- Request JSON: required `user_id: integer`, `group_name: string`.
- Success: 201 data with `group_id`, `group_name`, six-character `invite_code`. Errors: 400 missing fields, 404 user, 500; unsupported methods fall through.
- DB: reads `User`; creates `Group` and owner `GroupMember` in separate, non-atomic writes.
- Auth/conflict: no authentication; no Flutter consumer.

### POST `/accounts/api/group/join/`

- Frontend caller: none; backend: `join_group_api`.
- Request JSON: required `user_id: integer`, `invite_code: string`.
- Success: 201 data with group ID/name. Errors: 400 missing/already joined, 404 user or invite code, 500; unsupported methods fall through.
- DB: reads `User`/`Group`/`GroupMember`, creates member row.
- Auth/conflict: no authentication; no Flutter consumer; duplicate protection is application-only.

### POST `/accounts/api/group/members/`

- Frontend caller: none; backend: `get_group_members_api`.
- Request JSON: required `user_id: integer`, `group_id: integer`.
- Success: 200 data with group ID/name and member objects (`user_id`, `user_name`, display `nickname`, `group_role`, formatted `joined_at`). Errors: 400 missing/invalid JSON, 404 group, 403 requester not a member, 500; 405 other methods.
- DB: reads `Group`, `GroupMember`, related `User`.
- Auth/conflict: membership is checked, but requester identity is still an unverified body value; no Flutter consumer.

## Medication endpoints

### POST `/medications/api/scan/`

- Frontend caller: `ScanPrescriptionSheet._uploadAndAnalyze`; backend: `analyze_prescription_api`.
- Multipart request: required file `prescription_img`; no JSON/body fields.
- Success: 200 `{status:'success', data:[{raw_name,search_keyword,frequency,days,total_amount}, ...]}` as expected by Flutter. Errors: 400 missing file or empty/failed parsed list; 405 other methods. Uncaught AI exceptions are converted to an empty list by helper.
- External/DB: Pillow + Gemini vision; no DB write.
- Auth/conflict: none. File size/type is not validated; actual Gemini JSON list shape needs live verification.

### POST `/medications/api/confirm_and_save/`

- Frontend caller: `ScanPrescriptionSheet._checkInteractionsAndSave`; backend: `confirm_and_save_prescription_api`.
- Multipart request: required text field `data` containing JSON; optional file `prescription_img` in backend (always sent by Flutter). JSON requires a usable `user_id`; optional/defaulted `hospital_name`, `visit_date`, `confirmed_drugs`. Each drug may contain `raw_name`, `search_keyword`, `frequency`, `days`, `total_amount`.
- Success: 200 `{status,message,data:[report...]}`. Each report includes submitted fields, catalog fields (`license`, `med_ch`, `element`, `indications`, `dosage_form`, appearance flags), `fda_result`, and saved `id`. Errors: 400 missing/invalid `data`; 404 user; 500 main/detail/warning/general failures; 405 other methods.
- DB/external: reads `User`/`Drug`/`DrugWarning`; creates `Prescription`, `PrescriptionDrug`, possibly `DrugWarning`; saves image; may call OpenFDA and Gemini.
- Auth/conflict: none. Not atomic; integer extraction loses decimals; warning creation can fail for null matched drug; Flutter checks only HTTP status and ignores returned report.

### GET `/medications/api/prescriptions/{user_id}/`

- Frontend callers: medication bag and reminder page; backend: `get_user_prescriptions_api`.
- Path: `user_id: integer`; no body/query.
- Success: 200 list of `{prescription_id,hospital_name,visit_date:'YYYY-MM-DD',drug_count,image_url}`; 500 exception. Unsupported methods fall through.
- DB: reads `Prescription`, counts `PrescriptionDrug` per row.
- Auth/conflict: none; arbitrary user ID can be enumerated. `image_url` depends on incomplete media configuration.

### GET `/medications/api/prescription_details/{prescription_id}/`

- Frontend callers: prescription detail and reminder page; backend: `get_prescription_detail_api`.
- Path: `prescription_id: integer`; no body/query.
- Success: 200 list of `{id,raw_name,med_ch,med_en,frequency,total_amount,days,indications,warnings:[{conflict_target,warning_desc}]}`. Unknown prescription returns an empty success list. Errors: 500; unsupported methods fall through.
- DB: reads `PrescriptionDrug`, related `Drug`, `DrugWarning`.
- Auth/conflict: no existence/ownership check. Backend omits `is_severe_danger`, which Flutter attempts to read.

### POST `/medications/api/prescriptions/create/`

- Frontend caller: `MyMedicationBagPage._createManualPrescription`; backend: `create_manual_prescription_api`.
- Request JSON: `user_id: integer`; optional `hospital_name` (default `手動新增藥單`), `visit_date` (default now).
- Success: 200 `{status:'success',prescription_id}`. Any error, including missing user/bad date, is 500. Unsupported methods fall through.
- DB: reads `User`, creates `Prescription`.
- Auth/conflict: none; no explicit validation or 404 distinction.

### POST `/medications/api/prescriptions/{prescription_id}/add_drug/`

- Frontend caller: `PrescriptionDetailPage._addSingleDrug`; backend: `add_single_drug_api`.
- Request JSON: required nonblank `raw_name`; optional/defaulted `frequency`, `days`, `total_amount`.
- Success: 200 with one report item in `data`. Errors: 400 blank name, 500, 405 other methods.
- DB/external: reads matched `Drug`/warnings; may call OpenFDA/Gemini; creates `PrescriptionDrug` and warnings.
- Auth/conflict: no prescription existence/ownership check before create; numeric text is coerced with first-integer extraction.

### POST or PUT `/medications/api/prescriptions/{prescription_id}/update/`

- Frontend caller: bag uses POST; backend: `update_prescription_api`.
- Request JSON: optional `hospital_name`, optional `visit_date` string. An invalid date is silently ignored.
- Success: 200 with updated hospital/date. Errors: 404 prescription, 400 invalid JSON, 500; 405 other methods.
- DB: updates `Prescription`.
- Auth/conflict: no ownership check.

### POST or DELETE `/medications/api/prescriptions/{prescription_id}/delete/`

- Frontend caller: bag uses POST; backend: `delete_prescription_api`.
- Request: path ID only.
- Success: 200 status/message. Errors: 404, 500. Unsupported methods fall through.
- DB: deletes `Prescription`; ORM cascades child drugs/reminders/history.
- Auth/conflict: no ownership check; stored image file is not deleted; Flutter optimistically removes list row before result.

### POST or DELETE `/medications/api/prescriptions/drug/{pd_id}/delete/`

- Frontend caller: detail uses POST; backend: `delete_single_drug_api`.
- Request: path `pd_id` only.
- Success: 200 status/message. Errors: 404, 500. Unsupported methods fall through.
- DB: deletes `PrescriptionDrug`; ORM cascades reminders/history.
- Auth/conflict: no ownership check.

### POST `/medications/api/check_all_safety/`

- Frontend callers: scan-save follow-up and bag safety button; backend: `check_all_medications_safety_api`.
- Request JSON: required `user_id: integer`.
- Success: 200 list of every user drug with prescription/drug IDs, names, hospital, `is_severe_danger`, and warning objects including allergy/drug-conflict flags and conflicting names/IDs. Errors: 400 missing ID, 404 user, 500; 405 other methods.
- DB: reads `User`, all related `PrescriptionDrug`/`Drug`/`Prescription`, and `DrugWarning`.
- Auth/conflict: no authentication. Clinical result is based on unvalidated substring matching.

### POST `/medications/api/reminders/set/`

- Frontend caller: `ReminderSettingsPage._saveReminders`; backend: `reminders.set_medication_reminder`.
- Request JSON: `prescription_id: integer`, optional `drugs: list`; each item contains `prescription_drug_id` and optional `reminders`, each with `frequency_tag` and `remind_time` (`HH:MM:SS` from Flutter).
- Success: 201 status/message containing created count. Errors: 404 prescription, 400 other exceptions; 405 other methods.
- DB: reads `Prescription`/`PrescriptionDrug`; creates `Remind` rows.
- Auth/conflict: no ownership check; invalid drug IDs are silently skipped; empty list succeeds; repeated submissions duplicate reminders.

### POST `/medications/api/history/record/`

- Frontend caller: none; backend: `history.record_taking_status`.
- Request JSON: required `remind_id: integer`, `status: string` (comment examples: `已吃`, `略過`).
- Success: 201 data with `takingrecord_id`, echoed status, and formatted server time. Errors: 400 missing/parse/other, 404 reminder; 405 other methods.
- DB: reads `Remind`, creates `TakingRecord` with `timezone.now()`.
- Auth/conflict: no authentication/ownership or status enum validation; no Flutter consumer.

