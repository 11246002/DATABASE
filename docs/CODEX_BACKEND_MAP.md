# Django backend map

## Project configuration

- Project: `med_project`; root routes `/admin/`, `/accounts/`, `/medications/`.
- Apps: `accounts`, `medications`, plus Django admin/auth/session stack and `corsheaders`.
- Custom user: `AUTH_USER_MODEL = 'accounts.User'`.
- SQLite: `BASE_DIR / 'db.sqlite3'`.
- Development settings: `DEBUG=True`, `ALLOWED_HOSTS=['*']`, and allow-all CORS.
- `SECRET_KEY` is a non-environment expression in tracked settings; its value is intentionally omitted here.

## Accounts app

- `models.py`: custom `UserManager`, `User`, `Group`, `GroupMember`.
- `views.py`: register, login, profile read/update, group create/join/member-list functions.
- `urls.py`: seven JSON endpoints.
- Passwords are created with `set_password` and checked with `check_password`.
- Login does not create a Django session or real token. The returned token is a deterministic placeholder.
- Group-member listing checks that the requesting `user_id` belongs to the group; other APIs do not establish caller identity.

## Medications app

- `models.py`: `Drug`, `Prescription`, `DrugWarning`, `PrescriptionDrug`, `Remind`, `TakingRecord`.
- `views.py`: OCR, confirm/save, prescription CRUD, drug CRUD, and total safety check.
- `reminders.py`: batch reminder creation.
- `history.py`: taking-status record creation.
- `utils.py`: Gemini OCR/translation, local fuzzy matching, OpenFDA query, number extraction, allergy/interaction matching.
- `import_med.py`: standalone pandas import from `全部藥品許可證資料集.csv` using `Drug.get_or_create(license=...)`.
- `藥品外觀資料集.csv` is not referenced by runtime/import code.

## Backend flow by feature

### Scan

`/medications/api/scan/` -> `analyze_prescription_api` -> uploaded Pillow image -> Gemini vision -> parsed JSON -> response. No database write occurs in this first step.

### Confirm and save

`confirm_and_save_prescription_api` -> parse multipart `data` -> fuzzy `Drug` lookup -> cached warnings or OpenFDA lookup -> Gemini translation -> validate user -> create `Prescription` and `PrescriptionDrug` rows -> cache `DrugWarning` rows -> return report. The imported `transaction` module is unused, so this multi-write flow is not atomic.

### Safety

`check_all_medications_safety_api` -> `check_user_medication_safety` -> all user's prescription drugs -> substring-match declared allergies against raw/Chinese/English drug names -> substring-match stored warning targets against every other drug name -> mark both sides and return all drugs plus warnings.

### Reminder/history

The reminder endpoint creates one `Remind` per submitted drug/time pair; invalid drug IDs are silently skipped and previous rows are not replaced. The history endpoint creates `TakingRecord` for a supplied reminder ID/status. Neither verifies ownership.

## Authentication/authorization

All application handlers are `csrf_exempt`. There are no DRF authentication classes, Django `login()`, session checks, bearer-token checks, or object-level permission helpers. Resource ownership is generally not checked. Treat all current endpoints as unauthenticated regardless of the frontend login screen.

## File storage

`Prescription.image` saves under `prescriptions/`. The repository has many generated/uploaded images, including explicitly named samples and repeated Django-renamed copies. No code deletes image files when a prescription row is deleted. No explicit media serving configuration was found.

## External integrations

- Gemini model `gemini-2.5-flash` for image extraction and warning translation.
- OpenFDA `https://api.fda.gov/drug/label.json` with a ten-second `requests` timeout.
- Code reads `GEMINI_API_KEY`; the current `.env` exposes a different variable name. Secret values were not inspected.

## Dataset path

- `全部藥品許可證資料集.csv`: 80,361 data rows; headers include license, Chinese/English names, indication, dosage form, and ingredient. `import_med.py` writes selected fields to `Drug`.
- `藥品外觀資料集.csv`: 5,851 data rows; license/shape/color; currently unused.
- Runtime search reads `Drug` via ORM. It does not read either CSV at request time.

## API implementation notes

- No OpenAPI/Swagger/Postman or serializer layer exists; `CODEX_API_MAP.md` is the reverse-engineered contract.
- Several views have no explicit response for unsupported methods, causing Django's “view returned None” failure instead of a 405.
- Exceptions are often returned verbatim to clients, potentially leaking implementation details.
- `MedicationReminder` exists in migration/SQLite only, not current models/admin/views.

