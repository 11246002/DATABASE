# drug_app project map

Audit basis: repository state inspected on 2026-10-06. Statements below come from the checked-in code, migrations, configuration, and a read-only inspection of `db.sqlite3`. Uncertainty is called out explicitly.

## Purpose

The repository implements a personal medication-management application. The implemented path lets a user register and log in, scan or manually create prescriptions, match recognized drug names against a local drug catalog, obtain OpenFDA warnings translated/summarized by Gemini, store prescriptions, inspect cross-prescription allergy/interaction warnings, and save reminder times. Group APIs and taking-history APIs exist only on the backend.

## Technology stack

- Frontend: Flutter/Dart (`app/`), Dart SDK constraint `^3.10.8`, Flutter project version `1.0.0+1`.
- Frontend packages: `http`, `camera`, `image_picker`, `image_cropper`, `shared_preferences`, Material/Cupertino UI.
- Backend: Django project `med_project` with `accounts` and `medications` apps.
- Dependency pin: Django `5.2.13`; some settings/migrations say they were generated with Django `6.0.4`.
- Database: SQLite at repository-root `db.sqlite3`.
- Data/AI: two CSV datasets, Gemini `gemini-2.5-flash`, and OpenFDA drug-label API.

## Repository structure

- `app/lib/main.dart`: all handwritten Flutter screens, state, navigation, and HTTP integration in one file.
- `app/pubspec.yaml`, `analysis_options.yaml`: Flutter package and lint configuration.
- `accounts/`: custom user, group models, account/group JSON APIs, migrations, admin registration.
- `medications/`: prescription/drug/reminder models, APIs, AI/FDA helpers, history/reminder handlers, import script, migrations, datasets.
- `med_project/`: Django settings and root URL routing.
- `prescriptions/`: files saved by `Prescription.image`; contains sample/test and apparent user-uploaded images.
- `test_api1.py`, `test_api2.py`: manual live-server scripts, not isolated automated tests.
- `db.sqlite3`: current local database; intentionally ignored by Git.

## Frontend architecture

There is no service, repository, model, or state-management layer. `main.dart` uses `StatefulWidget` local state and calls `package:http` directly. `MaterialPageRoute`/`PageRouteBuilder` provide navigation. `SharedPreferences` stores `user_id` and a returned token. See `CODEX_FRONTEND_MAP.md`.

## Backend architecture

Function-based, CSRF-exempt Django views parse JSON or multipart input directly, call ORM/helpers, and return `JsonResponse`. There are no serializers, forms, service classes, OpenAPI definitions, or REST framework dependency. See `CODEX_BACKEND_MAP.md`.

## Database

Models/migrations define users, groups, group membership, drug catalog/warnings, prescriptions and their drugs, reminder rows, and taking records. Actual SQLite also contains the migrated but model-less `MedicationReminder` table. At audit time the project tables contained 37 users, 66,169 drugs, 45 prescriptions, 204 prescription-drug rows, 47 warning rows, 145 reminder rows, and no taking-record or `MedicationReminder` rows. See `CODEX_DATA_MODEL.md`.

## Authentication and authorization

- Login verifies the Django password hash and returns `session_token_<user_id>`.
- This token is a placeholder, is stored by Flutter, is never sent again, and is never validated by Django.
- All application API views are `csrf_exempt`; there is no session login, JWT, API-key authentication, or permission decorator.
- Most resource APIs accept a caller-supplied user/resource ID and do not perform ownership checks. Group-member listing is the only explicit membership authorization check.
- Flutter logout only navigates to `LoginPage`; it does not clear saved `user_id`/token.

## External services and files

- Gemini vision extracts drug rows from uploaded prescription images.
- Gemini text generation converts OpenFDA interaction text to short Traditional-Chinese warning objects.
- OpenFDA label search uses the matched drug ingredient.
- Code requests environment variable `GEMINI_API_KEY`; the existing `.env` defines a differently named key. Values were not read or recorded.
- `Prescription.image` uses `upload_to='prescriptions/'`. No explicit `MEDIA_ROOT`, `MEDIA_URL`, or development media URL route is configured; current files appear under the repository-root `prescriptions/` directory.

## Main workflows

1. Register/login: Flutter posts JSON to account APIs, then stores `user_id` and placeholder token.
2. Scan: camera/gallery -> native crop (web skips crop) -> multipart scan API -> Gemini OCR -> confirmation dialog.
3. Confirm/save: Flutter resends image plus JSON -> DB name match -> optional OpenFDA query -> Gemini warning translation -> `Prescription`, `PrescriptionDrug`, and warning writes -> full-user safety check -> result dialog.
4. Medication bag: list/search/sort prescriptions, open detail, manually add drugs, edit/delete prescription, delete individual drug, run safety check.
5. Reminders: choose a prescription -> group drugs by frequency -> select times -> batch-create `Remind` rows.
6. Profile: retrieve/update profile by saved `user_id`.

## How to run

Backend, based on repository layout (not executed during this audit):

```powershell
py -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
py manage.py migrate
py manage.py runserver 0.0.0.0:8000
```

The audit machine had no installed Python interpreter, so these commands could not be verified. Before AI calls can work, configuration must expose the environment-variable name actually requested by code; do not copy secrets into documentation.

Frontend, based on Flutter metadata (not executed during this audit):

```powershell
cd app
flutter pub get
flutter run
```

The backend base URL is currently a hardcoded LAN address in `main.dart`; it must be reachable from the selected device. Android allows Internet, camera, and cleartext HTTP. iOS lacks the camera/photo usage-description keys normally required by these plugins.

## How to test

- `accounts/tests.py` and `medications/tests.py` contain no tests.
- `test_api1.py` calls live OCR and requires an obsolete absolute image path.
- `test_api2.py` calls the live save endpoint and writes production-like database/file data; it also uses an obsolete absolute image path.
- Flutter has the default `flutter_test` dependency but no `app/test/` files.
- No executable tests or analyzer were run: Python is unavailable, the manual scripts mutate live data/external services, and Flutter analysis may update generated caches outside this audit's allowed write set.

