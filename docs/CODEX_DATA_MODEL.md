# Current data model and migration state

Incremental audit date: 2026-10-06. Sources: models, migration graph, and read-only SQLite inspection. No migration or database write was performed.

## Current source models

### Accounts

- `User`: unchanged custom user with profile fields and text `allergies`.
- `Group`: unchanged group/invite-code model.
- `GroupMember`: now declares `UniqueConstraint(fields=['group','user'], name='unique_group_member')`.

### Medication and prescription

- `Drug`: `license` is now declared `unique=True`; other catalog fields are unchanged.
- `Prescription`, `PrescriptionDrug`, `DrugWarning`: structurally unchanged.
- `Remind`: adds `is_active`; derives `start_date`, `end_date`, and `is_expired`; declares uniqueness on `(prescription_drug, frequency_tag)`; direct `delete()` performs a soft delete unless `force=True`.
- `TakingRecord`: adds `record_date`, defaults `taken_at`, and declares uniqueness on `(remind, record_date)`.

### Health Bank

- `MedicationHistory`: `history_id`, nullable `user`, `drug_code`, `drug_name`, `dosage`, `frequency`, `days`, `hosp_name`, `rx_date`, `synced_at`.
- `PatientAllergy`: `allergy_id`, nullable `user`, `allergen_name`, nullable `reaction`, `synced_at`.

`MedicationHistory` is Health Bank medication data; it is not the same concept as `TakingRecord`, which records whether a scheduled reminder was taken or skipped.

## Intended relationships

```text
User 1--* Prescription 1--* PrescriptionDrug *--0..1 Drug 1--* DrugWarning
                              |
                              1
                              *
                            Remind 1--* TakingRecord

User 1--* GroupMember *--1 Group
User 1--* MedicationHistory
User 1--* PatientAllergy
```

## New migration graph

Accounts:

- `0003_alter_groupmember_id`: changes `GroupMember.id` from the prior migration state back to `AutoField`, matching the current accounts app default.
- Missing: no migration adds `unique_group_member`.

Medications has parallel branches after `0002_medicationreminder`:

- `0003_medicationhistory_patientallergy_and_more`: creates `MedicationHistory` and `PatientAllergy`, then deletes `MedicationReminder`.
- `0003_remind_is_active_delete_medicationreminder`: despite its filename, only adds `Remind.is_active`; it contains no delete operation.
- `0004`: adds `TakingRecord.record_date`, changes `taken_at` default, and adds `(remind, record_date)` uniqueness.
- `0005`: adds `(prescription_drug, frequency_tag)` uniqueness to `Remind`.
- `0006_merge_20260920_0033`: merges the two branches.

Missing: no migration changes `Drug.license` to unique.

## Actual SQLite state

Only these project migrations are recorded as applied:

- `accounts.0001_initial`
- `accounts.0002_alter_groupmember_id`
- `medications.0001_initial`
- `medications.0002_medicationreminder`

Consequences:

- `medications_medicationhistory` and `medications_patientallergy` do not exist.
- `medications_remind` has no `is_active` column.
- `medications_takingrecord` has no `record_date` column.
- Reminder/day and reminder-tag unique constraints do not exist.
- `medications_medicationreminder` still exists and has 0 rows.
- `medications_remind` has 145 rows; `medications_takingrecord` has 0 rows.
- `GroupMember(group,user)` and `Drug.license` are not unique in actual schema.

## Data migration blocker

Read-only duplicate checks found:

| Intended unique key | Duplicate groups | Excess rows |
|---|---:|---:|
| `GroupMember(group,user)` | 0 | 0 |
| `Drug.license` | 0 | 0 |
| `Remind(prescription_drug,frequency_tag)` | 14 | 14 |
| `TakingRecord(remind,day)` | 0 | 0 |

Migration `medications.0005` attempts to add reminder-tag uniqueness without a preceding cleanup/data migration. With the present database, applying the chain is expected to fail at that constraint. The audit did not choose which duplicate reminder rows to retain.

## Reminder implementation status

| Evidence | `Remind` | Legacy `MedicationReminder` |
|---|---|---|
| Current model | Active and expanded. | Absent. |
| Migration intent | Adds active state and uniqueness. | Deleted by one `0003` branch. |
| Actual SQLite | Old schema, 145 rows. | Table still present, 0 rows. |
| Current backend | All reminder/history flows depend on it. | No caller. |
| Current Flutter | Save route only. | No caller. |

The canonical source concept is now clearly `Remind`, resolving the earlier source-level ambiguity. The local database has not reached that migration state.

## Cascade and history caveat

Soft deletion preserves history only when the reminder endpoint explicitly sets `is_active=false` or an individual instance calls its override. Parent deletion of `Prescription` or `PrescriptionDrug` still uses ORM cascade collection and can delete `Remind` and `TakingRecord`; the override does not make the full relationship chain soft-delete-safe.
