# Current Django backend map

Incremental audit basis: `1032f3e..ed3fadc`, inspected 2026-10-06. No backend source, migration, or database was changed by the audit.

## Project configuration

- Root routes: `/admin/`, `/accounts/`, `/medications/`.
- Apps: `accounts`, `medications`, Django admin/auth/session stack, and `corsheaders`.
- Custom user: `AUTH_USER_MODEL = 'accounts.User'`.
- SQLite: `BASE_DIR / 'db.sqlite3'`.
- `TIME_ZONE` changed from `UTC` to `Asia/Taipei`; `USE_TZ=True` remains.
- `MEDIA_URL='/media/'` and `MEDIA_ROOT=BASE_DIR/'media'` were added, with development serving under `DEBUG`.
- `DEBUG=True`, wildcard hosts, allow-all CORS, CSRF-exempt application views, and tracked non-environment secret configuration remain.

The new media configuration resolves the absence of a media URL/root for future uploads, but the existing 127 files are under root `prescriptions/`, while `media/` is absent. Existing `prescriptions/...` database paths will resolve under `media/prescriptions/...` and are not backed by the current files.

## Accounts app

- Models remain `User`, `Group`, and `GroupMember`.
- `GroupMember.Meta` now declares uniqueness on `(group, user)`.
- New migration `accounts.0003` changes the implicit ID back to `AutoField`, resolving the earlier model-state type drift.
- No migration adds the new group/user unique constraint; actual SQLite has only non-unique FK indexes.
- Group create/join/member-list APIs remain backend-only and still trust caller-supplied identity. Join performs a check-before-create, which is not concurrency-safe without the database constraint.

## Medications app

Current models:

- Existing: `Drug`, `Prescription`, `DrugWarning`, `PrescriptionDrug`, `Remind`, `TakingRecord`.
- New: `MedicationHistory` for Health Bank medication history and `PatientAllergy` for structured synced allergies.
- `Remind` gains `is_active`, date-range properties, a soft-delete override, and intended uniqueness by `(prescription_drug, frequency_tag)`.
- `TakingRecord` gains `record_date`, defaults `taken_at`, and intended uniqueness by `(remind, record_date)`.
- `Drug.license` is now declared unique in the model, but no migration changes that field.

Modules and flows:

- `views.py`: existing scan/save/prescription CRUD/safety routes. Confirm/save now reuses the improved matched object and avoids creating `DrugWarning` with a null drug.
- `utils.py`: multi-keyword Chinese/English/ingredient search; safety now combines manual allergies, `PatientAllergy`, current prescriptions, and `MedicationHistory`.
- `reminders.py`: identity extraction, owner-filtered set/list/today/toggle/soft-delete flows, time validation, and update-or-create behavior.
- `history.py`: owner-filtered taking status, inventory adjustment, duplicate-day handling, and adherence statistics.
- `health_bank.py`: fixed mock payload, per-user upserts, and allergy text backfill; no real Health Bank SDK/OAuth call.
- `admin.py`: table-oriented admin classes for all current models.

## Authentication and ownership

Reminder/history handlers now filter prescription/reminder objects by the asserted user ID. This is a real object-filtering improvement over the baseline, but the identity parser accepts a deterministic token, numeric bearer value, header, body, or query ID without validating credentials. It prevents accidental cross-user IDs only when the caller is honest; it does not prevent impersonation.

Legacy account/prescription/safety/group endpoints remain unchanged: no verified session/token and broad missing object ownership checks.

## Data-integrity behavior

- Reminder writes are atomic and use update-or-create; omitted tags for submitted drugs are disabled.
- Taking status writes are atomic and intended to enforce one row per reminder/day.
- Direct reminder deletion is implemented as inactive state, but deleting a parent `Prescription` or `PrescriptionDrug` still follows `on_delete=CASCADE`; the model's `delete()` override does not prevent collector/queryset cascades.
- Health Bank upserts are idempotent in ordinary sequential requests by lookup keys, but models define no database uniqueness for `(user, drug_code)` or `(user, allergen_name)`.
- Confirm/save remains non-atomic.

## Admin issues

`PrescriptionAdmin`, `MedicationHistoryAdmin`, and `PatientAllergyAdmin` include `user__username` in `search_fields`, but the custom user field is `user_name`. Admin searches using those entries can raise a field-resolution error; the latter two have no valid alternative entry for user-name search.

## Migration state

The source graph adds two parallel medication `0003` branches, reminder/history migrations through `0005`, and merge migration `0006`. It intends to create Health Bank tables, remove legacy `MedicationReminder`, add reminder/history fields, and add uniqueness.

Actual SQLite has only `accounts` 0001/0002 and `medications` 0001/0002 recorded. It therefore lacks all new tables/columns/constraints. Fourteen `(prescription_drug, frequency_tag)` duplicate groups (14 excess rows) exist, so medication migration `0005` cannot safely add its unique constraint without a data reconciliation step. No such data migration is present.

## Tests and runtime verification

`test_reminders_e2e.py` exercises seven live HTTP flows, but it is a mutable live-server script: it creates/updates reminders, writes taking records, changes active state, and uses the configured database. It is not isolated and was not run. Django checks, migration planning, and tests could not run because the machine has no installed Python interpreter.
