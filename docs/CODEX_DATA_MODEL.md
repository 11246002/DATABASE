# Data model

Primary source: current models and migrations. Verification source: read-only SQLite schema inspection on 2026-10-06. All four project migrations are recorded as applied.

## Entities

### `accounts.User` / `accounts_user` (37 rows)

| Field | Type | Null/default/constraint |
|---|---|---|
| `user_id` | AutoField / INTEGER | Primary key. |
| `user_name` | varchar(50) | Required, unique (auto unique index). Login identifier. |
| `password` | varchar(128) | Required hashed password from `AbstractBaseUser`. |
| `last_login` | datetime | Nullable. |
| `role` | varchar(20) | Model default `user`; `sys_admin` drives staff/superuser properties. |
| `nickname` | varchar(50) | Nullable/blank. |
| `gender` | varchar(2) | Nullable/blank. |
| `height`, `weight` | REAL | Nullable/blank. |
| `allergies` | TEXT | Nullable/blank. |
| `emergency_contact_phone` | varchar(20) | Nullable/blank. |
| `created_at` | datetime | Required, `auto_now_add`. |

### `accounts.Group` / `accounts_group` (2 rows)

`group_id` AutoField PK; required `group_name` varchar(100); required auto-created `created_at`; required unique `invite_code` varchar(10).

### `accounts.GroupMember` / `accounts_groupmember` (4 rows)

Implicit `id` PK; required FKs `group -> Group` and `user -> User`, both model-level CASCADE; `joined_at` auto-created; `group_role` varchar(20), model default `member`. FK indexes exist. There is no unique constraint preventing duplicate `(group, user)` rows; the join API enforces it procedurally.

### `medications.Drug` / `medications_drug` (66,169 rows)

Implicit BigAutoField PK; required `license` varchar(100) and `med_ch` varchar(100); nullable `med_en`, `color`, `shape`, `indications`, `element`, and `dosage_form`. No uniqueness or explicit search index exists on license/name fields.

### `medications.Prescription` / `medications_prescription` (45 rows)

`prescription_id` AutoField PK; required FK `user -> User` with model-level CASCADE and index; required `hospital_name` varchar(50); required `visit_date` DateTimeField; nullable `image` varchar(100) path using `prescriptions/` upload prefix.

### `medications.PrescriptionDrug` / `medications_prescriptiondrug` (204 rows)

Implicit BigAutoField PK; required FK `prescription -> Prescription` with CASCADE/index; nullable FK `drug -> Drug` with SET_NULL/index; required `raw_name` varchar(255), `total_amount` integer, `frequency` varchar(20), `days` integer; nullable `remaining_amount` integer. No uniqueness constraint exists.

### `medications.DrugWarning` / `medications_drugwarning` (47 rows)

`warning_id` AutoField PK; required indexed FK `drug -> Drug` with CASCADE; required `conflict_target` varchar(255) and `warning_desc` text. `get_or_create` is used in code, but the database has no unique constraint on `(drug, conflict_target)`.

### `medications.Remind` / `medications_remind` (145 rows)

`remind_id` AutoField PK; required indexed FK `prescription_drug -> PrescriptionDrug` with CASCADE; required `frequency_tag` varchar(50) and `remind_time` time. There is no uniqueness constraint, active flag, or update timestamp.

### `medications.TakingRecord` / `medications_takingrecord` (0 rows)

`takingrecord_id` AutoField PK; required indexed FK `remind -> Remind` with CASCADE; required `status` varchar(20) and `taken_at` datetime. Status has no enum/check constraint.

### Orphaned migrated entity: `medications_medicationreminder` (0 rows)

Migration `0002_medicationreminder` and SQLite define: implicit BigAutoField `id`, required `medication_name` varchar(100), `reminder_time` time, `is_active` bool (migration default true), `created_at`, and indexed FK `user -> User`. The class is absent from current `models.py`, so ORM/runtime code cannot use it.

## Verified reminder implementation matrix

| Evidence | `Remind` | `MedicationReminder` |
|---|---|---|
| Current Django model | Yes: `medications.models.Remind`. | No current model class. |
| Migration | Created by `medications/0001_initial.py`. | Created by `medications/0002_medicationreminder.py`. |
| Actual SQLite table | `medications_remind`, 145 rows. | `medications_medicationreminder`, 0 rows. |
| Backend writes | `set_medication_reminder` creates rows. | None found. |
| Backend reads | `record_taking_status` resolves `Remind`; admin registers it; ORM cascades through `TakingRecord`. | None found; not registered in admin. |
| Flutter dependency | Direct: reminder screen POSTs `/medications/api/reminders/set/`, whose implementation writes `Remind`. | None found. |
| Effect if removed now | Breaks reminder saving, reminder-to-taking-history lookup, admin access, and cascaded `TakingRecord` relationship; Flutter reminder flow would fail. | No current runtime caller would fail based on repository evidence, but deleting the table/migration state is a schema decision and could affect unknown external/older clients. |

This matrix does not choose which concept should remain. The SQLite file hash was unchanged across the read-only verification.

## Relationships

```text
User 1--* Prescription 1--* PrescriptionDrug *--0..1 Drug 1--* DrugWarning
                              |
                              1
                              *
                            Remind 1--* TakingRecord

User 1--* GroupMember *--1 Group
User 1--* MedicationReminder   (migration/DB only)
```

## Model / migration / SQLite comparison

- Migrations and actual SQLite agree on all existing table columns, FKs, and indexes inspected.
- `medications.0002_medicationreminder` is applied and its table exists, but the model has been removed from source. A future migration generated from current models would likely propose deleting it.
- `accounts.0002` changes `GroupMember.id` to `BigAutoField`, while the current `AccountConfig`/settings do not declare `default_auto_field` and the model does not declare `id`. This may produce model-state drift depending on the Django version; verify with `makemigrations --check --dry-run` in a configured Python environment.
- Django 6.0.4 generated two migrations, while `requirements.txt` pins Django 5.2.13.
- SQLite reports FK actions as `NO ACTION`; Django's CASCADE/SET_NULL behavior is implemented by ORM deletion collection rather than matching SQL `ON DELETE` clauses in this database.
