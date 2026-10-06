# Verified Project Baseline

Verification date: 2026-10-06 (Asia/Taipei). This baseline was produced from repository evidence and read-only environment/database checks. No production code, dependency, migration, database row, image, or existing working-tree change was modified.

## Repository

- Root: `C:\Users\88692\drug_app`.
- Independent `drug_app` repository; no assumptions from other projects apply.
- Frontend: Flutter under `app/`; backend: Django under `accounts/`, `medications/`, and `med_project/`; current database: root `db.sqlite3`.
- Before the first takeover audit, Git already reported three tracked modifications: `app/.metadata`, one `app/build/...cache.dill.track.dill` binary, and `app/lib/main.dart` (299 changed lines in current diff stat: 247 insertions, 67 deletions).
- Before the first audit, `app/.gitignore` and 107 files under `prescriptions/` were already untracked. The image directory currently has 127 files total: 20 tracked and 107 untracked.
- Audit-created files are root `AGENTS.md` and `docs/*.md`. This verification only updates/adds documentation.

## Frontend

- All authored behavior remains in `app/lib/main.dart`.
- `API_BASE_URL` is a compile-time constant with one hardcoded private-LAN HTTP URL; it is not read from environment, build flavor, preferences, or platform configuration.
- HTTP inventory: `package:http` direct calls only. No Dio, shared HTTP client, wrapper service, background network worker, or additional Dart source file exists.
- There are 18 HTTP call sites representing 15 unique backend endpoints: 16 ordinary `http.get/post` calls plus two multipart request sites, with safety/list/detail endpoints called from more than one flow as documented in `CODEX_API_MAP.md`.
- State uses `StatefulWidget`/`setState`; persisted login values are `user_id` and `token` in SharedPreferences.
- `app/.dart_tool/package_config.json` and `pubspec.lock` exist; package config reports 72 packages. No `app/test/` tests exist.

## Backend

- Root routing includes `/accounts/` and `/medications/`; static inspection finds 7 account routes and 12 medication routes.
- All application handlers are function views; all are CSRF-exempt. No DRF, serializer, authentication middleware integration, or API schema was found.
- Runtime medication work uses ORM-backed `Drug`, `Prescription`, `PrescriptionDrug`, `DrugWarning`, `Remind`, and `TakingRecord` models.
- Django URL resolver could not be executed because no Python interpreter is installed; coverage was revalidated directly from root/app `urls.py` and every Flutter call site.

## API counts

- Backend application endpoints: **19** (Django admin excluded).
- Frontend HTTP call sites: **18**.
- Frontend unique endpoints: **15**.
- Matched unique frontend endpoints: **15**.
- Frontend-only endpoints: **0**.
- Backend-only endpoints: **4** — group create, group join, group members, and history record.
- These counts match the first takeover audit; no route correction was required.

## Database

- SQLite opened with the native read-only flag. Its SHA-256 hash was identical before and after verification.
- Both `medications.0001_initial` and `0002_medicationreminder` are recorded as applied.
- `Remind`: current model yes; migration yes; table `medications_remind` yes (145 rows); backend and Flutter actively depend on it.
- `MedicationReminder`: current model no; migration yes; table `medications_medicationreminder` yes (0 rows); no current backend or Flutter usage found.
- Removing `Remind` would break current reminder/history flows. Removing `MedicationReminder` has no evidenced current runtime consumer, but remains a product/schema decision rather than an audit action.
- The rest of the previously documented model/migration/SQLite comparison remains verified.

## Authentication

```text
register -> hashed User password
login -> password check -> placeholder token + user_id
Flutter -> stores token + user_id
later calls -> send user_id/resource IDs, not token
backend token verification -> absent
general resource ownership verification -> absent
logout persistence clearing -> absent
```

The only explicit authorization-like check is group membership lookup, and its requester identity is still a caller-supplied `user_id`.

## External services

| Service | Caller | Environment variable name | Endpoint/model | Purpose | Failure behavior |
|---|---|---|---|---|---|
| Google Gemini | `extract_drugs_from_image`, `batch_translate_fda_warnings` in `medications/utils.py` | `GEMINI_API_KEY` | SDK-managed Google Generative AI endpoint; model `gemini-2.5-flash` | Prescription image extraction; OpenFDA warning translation/structuring | OCR/image/model error is printed and returns empty list, producing scan 400. Translation error is printed and returns `{}`, so save can continue without new warnings. |
| OpenFDA drug label API | `query_openfda_interactions` in `medications/utils.py` | None | `https://api.fda.gov/drug/label.json`, generic-name search, limit 1 | Obtain `drug_interactions` text for a matched ingredient | Non-200, no result, or exception returns `NO_DATA`; exception is printed and no warning is added. Timeout is 10 seconds. |

No other runtime outbound HTTP service was found. Root `test_api*.py` scripts call the local Django server and are test clients, not production integrations. Existing `.env` values were not displayed or copied.

## Known broken/incomplete behavior

- Placeholder token is not authentication; IDs are spoofable and ownership is generally unchecked.
- Gemini environment-variable name does not match the name present in the current `.env`.
- Prescription detail omits `is_severe_danger`; its detail-page red header/card state therefore remains false. Safety endpoint flows do return and use the field.
- Fractional total amounts first lose precision in `extract_int`: `0.5 -> 0`, `1.5 -> 1`; later detail display shows the stored integer.
- `MedicationReminder` is migrated/table-backed but model-less and unused; `Remind` is the active implementation.
- Confirm/save is not atomic; reminder saves append duplicates; deleting a prescription does not delete its image file.
- Group/history UI, actual device notification scheduling, cloud sync, PDF export, appearance-dataset import, and meaningful settings behavior are incomplete/absent.
- Platform/deployment configuration issues listed in `CODEX_CONFLICTS.md` remain present.

## Existing uncommitted changes

### Present before Repository Takeover Audit

- Modified: `app/.metadata`.
- Modified binary: `app/build/f537d389bd7fe17e116f8b847863fcdd.cache.dill.track.dill`.
- Modified production source: `app/lib/main.dart`.
- Untracked: `app/.gitignore`.
- Untracked: 107 files under `prescriptions/`.

### Added by takeover documentation work

- `AGENTS.md`.
- `docs/CODEX_PROJECT_MAP.md`.
- `docs/CODEX_FRONTEND_MAP.md`.
- `docs/CODEX_BACKEND_MAP.md`.
- `docs/CODEX_API_MAP.md`.
- `docs/CODEX_DATA_MODEL.md`.
- `docs/CODEX_CONFLICTS.md`.
- `docs/CODEX_AUDIT.md`.
- `docs/CODEX_BASELINE.md`.

No reset, checkout, restore, staging, or commit was performed.

## Environment availability

- Python: unavailable. `python` and `python3` are not found. `C:\Windows\py.exe` exists, but reports that no default Python is installed. No repository `venv` or `.venv` exists.
- Django runtime: unavailable because Python is unavailable. Repository requirement is Django 5.2.13; some generated files identify Django 6.0.4.
- Dart: direct CLI works; Dart SDK 3.10.8 stable on Windows x64.
- Flutter: installation metadata identifies Flutter 3.38.9 stable, framework revision `67323de...`, with Dart 3.10.8.
- Flutter CLI verification: `flutter --version` and `flutter doctor` were attempted but did not get past the existing Flutter startup lock. They were interrupted without terminating existing Dart/IDE processes or changing toolchain configuration.
- SQLite: available for verified read-only inspection through Windows native SQLite; database writes were not attempted.

## Things not yet runtime-tested

- Django startup, system checks, URL resolver, pending migration check, and isolated tests.
- Flutter analyzer, compilation, widget tests, and device launch.
- Camera/gallery/crop behavior on Android, iOS, and web.
- Live Gemini OCR/translation and OpenFDA behavior.
- End-to-end API behavior against a disposable database and storage directory.
- Authentication/ownership abuse cases, error-method fallthrough, fractional amounts, detail severity display, duplicate reminders, and image deletion.
