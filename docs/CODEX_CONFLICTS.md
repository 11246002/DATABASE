# Confirmed conflicts after team-main integration

Incremental comparison: `1032f3e..ed3fadc`, audited 2026-10-06. Findings are classified against the original `CODEX_CONFLICTS.md`. No production code or data was changed.

## Resolved or materially improved

1. **Unmatched-drug warning failure:** confirm/save now creates `DrugWarning` only when a matched `Drug` exists, removing the prior `drug=None` failure path.
2. **Drug lookup coverage:** multi-word OCR search keys are tried individually against Chinese name, English name, and ingredient.
3. **GroupMember ID model-state drift:** `accounts.0003` restores `AutoField`, matching current model/default behavior.
4. **Media configuration absent:** development `MEDIA_ROOT`, `MEDIA_URL`, and URL serving now exist. Existing files are not relocated, so a replacement conflict is listed below.
5. **Reminder concept decision in source:** `Remind` is the active model and the migration graph now intends to delete legacy `MedicationReminder`.
6. **Reminder duplicate creation in source logic:** set now uses update-or-create and a model/migration uniqueness rule instead of always appending. This is not operationally complete because current data blocks the migration.
7. **Reminder/history ownership filtering:** these new handlers filter objects by the asserted user. This reduces accidental IDOR but is not secure authentication because identity remains forgeable.

## Old conflicts still present

### Authentication and ownership

- Login token remains deterministic and unvalidated; Flutter stores it but sends it nowhere.
- Most endpoints trust caller-controlled user/resource IDs and lack ownership checks.
- Logout does not clear SharedPreferences.
- APIs remain CSRF-exempt with open development hosts/CORS/debug settings.
- Reminder/history “authentication” merely parses a claimed ID from token/header/body/query.

### Frontend/backend contract

- Prescription detail still omits `is_severe_danger` used by Flutter.
- Fractional amounts are still truncated by `extract_int` before integer storage.
- Registration real-name UI still has no request/model field.
- Several legacy handlers can still fall through on unsupported methods.
- Group and taking-history features still have no Flutter consumers; the new backend additions widen this gap.

### Workflow and configuration

- Confirm/save remains non-atomic.
- Deleting a prescription still leaves its image file and cascades reminder/history database rows.
- Safety/allergy/interaction matching remains substring/generative and clinically unvalidated.
- OCR response-shape stability remains unverified.
- `GEMINI_API_KEY` still does not match the present environment-variable name.
- API URL remains hardcoded to a LAN HTTP address.
- Tracked Django secret expression, Django-version drift, iOS permission gaps, Android release ID/signing, displayed version mismatch, unused appearance dataset, placeholder settings, and absent real notifications remain.
- There is still no isolated automated backend or Flutter test suite.

## New conflicts introduced by the merged code

### Critical runtime/schema conflicts

1. **Source is ahead of the actual database.** New code immediately queries `MedicationHistory`, `PatientAllergy`, `Remind.is_active`, and `TakingRecord.record_date`, but only old migrations are applied. Safety and new reminder/history/Health Bank flows cannot run against current SQLite.
2. **Reminder uniqueness migration is blocked by data.** Current SQLite has 14 duplicate `(prescription_drug, frequency_tag)` groups (14 excess rows); migration `0005` adds uniqueness without cleanup.
3. **Missing migrations for model constraints.** No migration implements `Drug.license unique=True` or `GroupMember(group,user)` uniqueness. Source, migration state, and actual schema disagree.

### API/frontend conflicts

4. **Existing reminder save is now unauthorized.** Backend requires asserted identity; Flutter sends neither `user_id` nor an identity header, so `/reminders/set/` returns 401.
5. **New APIs are backend-only.** Reminder list/today/toggle/delete, taking record/stats, and Health Bank sync have no Flutter integration.
6. **Reminder replacement semantics are not represented in UI.** Backend disables omitted tags, while Flutter never loads the existing reminder list before sending its generated schedule.
7. **Health Bank spec has an invalid cURL example.** It omits required `user_id` and would receive 400.

### Data and behavior conflicts

8. **Allergy duplication/misclassification risk.** Sync stores plain `PatientAllergy` and appends an annotated copy to `User.allergies`; safety reads both. Substring matching can emit duplicate warnings and classify the annotated copy as manually entered.
9. **Soft-delete guarantee is incomplete.** Reminder soft delete protects direct removal, but parent prescription/drug cascades still delete reminder/taking history.
10. **Adherence history changes after soft deletion.** Statistics count only currently active reminders, so disabling a reminder can remove its past expected doses from historical adherence totals even though recent record rows remain.
11. **Health Bank upserts lack matching DB constraints.** Sequential calls are idempotent, but concurrent calls can duplicate `(user,drug_code)` or `(user,allergen_name)`.
12. **Media path compatibility break.** Existing files are under root `prescriptions/`; new `MEDIA_ROOT` points to root `media/`, which is absent. Existing image URLs can point to missing files.
13. **Admin search uses a nonexistent field.** New admin definitions reference `user__username`; the custom field is `user_name`.
14. **Concurrent taking-record fallback is unsafe.** `IntegrityError` is caught inside the same outer `transaction.atomic()` block and then queries are issued; Django can mark that transaction broken before the fallback executes.

## Status of tests and specifications

- `API_REMINDERS_SPEC.md` is useful contract documentation but its claim of completed backend integration is not independently reproducible here and conflicts with the unmigrated current SQLite state.
- `test_reminders_e2e.py` is state-mutating, uses configured database IDs, and is not an isolated test. It was not run.
- `health_bank_api_spec.md` and `health_bank_schema.md` describe intended source behavior, not the currently applied database.
