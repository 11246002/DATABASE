# Repository takeover audit

Audit date: 2026-10-06 (Asia/Taipei). Scope: Flutter -> HTTP API -> Django -> SQLite, with source/migration/dataset/static consistency review. Production code and database contents were not modified.

## Current state

- The main end-to-end prescription flow is implemented: account creation/login, camera/gallery upload, Gemini OCR, confirmation/save, local catalog match, OpenFDA/Gemini warning enrichment, prescription browsing/editing, safety display, reminder persistence, and profile editing.
- Backend exposes 19 application endpoints. Flutter has 18 call sites across 15 unique endpoints; every frontend endpoint resolves to a backend route.
- Actual SQLite schema was opened read-only and agrees with applied migrations, apart from current-source model drift documented separately.
- The database is populated and is not a blank development shell.

## What appears complete

- Core user, prescription, prescription-drug, catalog, warning, reminder, and history schemas.
- Basic account registration/password hashing/login response.
- OCR upload and confirmation path for web/mobile variants.
- Prescription and individual-drug CRUD used by Flutter.
- Medication catalog import path and runtime ORM search.
- Cross-prescription safety response structure and UI rendering.
- Batch reminder row creation and profile read/update.

“Complete” here means code paths exist, not that they are secure, tested, or production-ready.

## What appears incomplete

- Real authentication/session lifecycle and ownership authorization.
- Environment/base-URL/media deployment configuration.
- Device notification scheduling and reminder update/list/delete flows.
- Taking-history frontend, group frontend, cloud sync, PDF export, large-font behavior.
- Appearance dataset integration.
- Automated tests and API schema/documentation.
- iOS camera/photo permission configuration.
- Production Android application ID/signing and consistent displayed package version.

## Major technical risks

1. Any caller can spoof IDs and read/change another user's resources.
2. AI integration is currently misbound to the available environment-variable name.
3. Non-atomic multi-step saves can leave partial data.
4. Hardcoded LAN HTTP endpoint and open development settings block safe deployment.
5. Clinically sensitive interaction/allergy output depends on fuzzy substring matching and generative summaries without validation controls.
6. Model/migration drift can cause an accidental destructive migration.
7. There is effectively no regression test safety net.

## Technical debt

- One very large Flutter file mixes UI, state, persistence, and networking.
- Function views repeat JSON/error handling and often leak exception text.
- N+1 ORM patterns exist in prescription listing/detail and warning loops.
- No request schema/type validation; optional/default behavior is implicit.
- Duplicate reminder concepts and duplicate saved image files.
- Debug prints include full backend response/payload details.
- Generic generated README and outdated comments conflict with actual configuration.

## Verification performed

- Read: all handwritten Dart and Python sources; Flutter/Django configuration; migrations; root manual scripts; dataset headers/counts; Android/iOS integration manifests; Git inventory/status.
- Read-only SQLite inspection: project tables, row counts, columns, indexes, foreign keys, applied project migrations.
- Static searches: HTTP callers/routes, token use, environment-variable names, TODO/FIXME/mock/sample/localhost/hardcoded URLs, API-spec artifacts.
- Not run: live API scripts (external calls and data writes), Django checks/tests (no Python interpreter installed), Flutter analysis/tests (no test suite and it can update generated caches outside the allowed write set).

## Recommended next investigation

1. Decide the intended authentication scheme and object-ownership rules before any feature change.
2. Decide whether `MedicationReminder` should be restored or removed, then inspect pending migrations in the exact supported Django version.
3. Run a disposable-database integration suite with Gemini/OpenFDA mocked.
4. Validate OCR JSON shape and safety behavior with representative, de-identified prescriptions.
5. Define environment-specific API/media configuration and supported client platforms.

## Items requiring owner confirmation

- Is the app intended for single-user/local demonstration or multi-user deployment?
- Should group members ever see one another's prescriptions/medications, and under what consent rules?
- Which reminder model is canonical: `Remind` or migrated `MedicationReminder`?
- Are fractional tablet quantities required?
- Is the appearance CSV expected to populate `Drug.color`/`shape`?
- Should existing `prescriptions/` images and `db.sqlite3` be treated as production, test, or disposable demo data?
- Which Python/Django version is authoritative for the project?
