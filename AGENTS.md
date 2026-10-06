# drug_app project

This repository is the drug_app project.

It is completely unrelated to BanAn or any other project.

Never bring architecture, APIs, models, features, requirements, or assumptions from another repository.

Frontend: Flutter

Backend: Django

Database: currently SQLite unless repository evidence shows otherwise.

Before any cross-layer change, trace:

Flutter UI
-> state/function
-> API call
-> Django URL
-> Django View
-> business logic
-> ORM/model
-> database
-> response
-> Flutter response handling

Never invent API behavior.

When frontend/backend disagree, report the discrepancy before changing interfaces.

Never expose `.env` secret values. Environment-variable names may be documented when required, but values must remain private.

Ignore generated Flutter/build artifacts unless needed.

Do not inspect prescription images individually unless a task explicitly requires it and privacy is addressed.

Avoid unrelated refactoring.

Preserve existing working behavior.

Treat `db.sqlite3` and `prescriptions/` as stateful data. Do not write, migrate, flush, delete, or replace them without explicit user authorization and a verified recovery plan.

The current login token is a placeholder and is not backend authentication. Do not assume a request is authorized merely because it includes `user_id` or a resource ID.

Before changing models or migrations, reconcile current models, applied migrations, and actual SQLite schema. In particular, review the model-less migrated `MedicationReminder` table and `GroupMember.id` migration state.

Before changing AI/OCR behavior, trace Gemini configuration, OpenFDA lookup, medication matching, database writes, safety response, and consuming Flutter UI. Never copy secret values into code or documentation.

Before major changes consult:

- `docs/CODEX_PROJECT_MAP.md`
- `docs/CODEX_FRONTEND_MAP.md`
- `docs/CODEX_BACKEND_MAP.md`
- `docs/CODEX_API_MAP.md`
- `docs/CODEX_DATA_MODEL.md`
- `docs/CODEX_CONFLICTS.md`
- `docs/CODEX_AUDIT.md`

