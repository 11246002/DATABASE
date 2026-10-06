# Current API map

Incremental audit date: 2026-10-06 (Asia/Taipei). Git comparison: `1032f3e` (pre-sync baseline) to `ed3fadc` (current integration `HEAD`). This map is based on current Flutter call sites, Django URL patterns, and handler source. Runtime execution was unavailable because no Python interpreter is installed.

## Coverage summary

- Backend application URL patterns: **27** (7 accounts + 20 medications; Django admin excluded).
- Flutter HTTP call sites: **18**.
- Flutter unique endpoint patterns: **15**.
- Frontend paths resolving to backend routes: **15/15**.
- Frontend contracts currently usable as written: **14/15**. The existing reminder-save caller does not provide the newly required identity value.
- Backend-only URL patterns: **12**: three group routes, reminder list, two reminder-today variants, reminder delete, reminder toggle, history record, two history-stats variants, and Health Bank sync.
- No Flutter-only route was found.

`API_BASE_URL` remains `http://172.20.10.4:8000`. The merge retained the local value; the team-side `127.0.0.1` value was not adopted.

## Authentication and ownership convention

Most legacy endpoints remain unauthenticated and trust a body/path `user_id` or resource ID. The new reminder/history handlers call `get_authenticated_user_id`, which accepts any of:

- `Authorization: Bearer session_token_<user_id>`;
- `Authorization: Bearer <numeric-user-id>`;
- `X-User-Id`;
- body/query/form `user_id`.

This improves owner filtering inside those handlers, but it is not authentication: the token is deterministic and no credential/session/token record is verified. Health Bank sync accepts body/query `user_id` only. Existing account, prescription, safety, and group handlers did not adopt this helper.

## Accounts endpoints

| Method and path | Flutter caller | Current contract and ownership |
|---|---|---|
| `POST /accounts/api/register/` | `RegisterPage._register` | JSON account/profile fields; 201 with `user_id`. The required UI “real name” still has no API/model field. |
| `POST /accounts/api/login/` | `LoginPage._login` | JSON credentials; returns user data and deterministic `session_token_<id>`. |
| `POST /accounts/api/user/profile/` | `UserProfilePage._fetchUserProfile` | Body `user_id`; returns profile. Caller-controlled identity. |
| `POST /accounts/api/user/update/` | `UserProfilePage._updateProfile` | Body `user_id` plus patch fields. Caller-controlled identity. |
| `POST /accounts/api/group/create/` | None | Body `user_id`, `group_name`; creates group and owner row. No real authentication; writes are not atomic. |
| `POST /accounts/api/group/join/` | None | Body `user_id`, `invite_code`; application-level duplicate check, then creates membership. |
| `POST /accounts/api/group/members/` | None | Body `user_id`, `group_id`; checks submitted user is a member, but does not authenticate that identity. |

The three group routes are unchanged at the API layer. `GroupMember` now declares a model constraint, but no migration creates it, so the join route still relies on its race-prone pre-check in the current database.

## Existing medication/prescription endpoints

| Method and path | Flutter caller | Incremental status |
|---|---|---|
| `POST /medications/api/scan/` | Scan sheet | Same multipart field `prescription_img`. OCR prompt now asks for multiple space-separated search names. |
| `POST /medications/api/confirm_and_save/` | Scan sheet | Same multipart contract. Search now tries each keyword against Chinese name, English name, and ingredient. An unmatched drug no longer attempts to create a warning with `drug=NULL`. |
| `GET /medications/api/prescriptions/{user_id}/` | Bag and reminder pages | Same list response and no authentication. `image_url` now uses configured `/media/`, but existing root-level files were not moved. |
| `GET /medications/api/prescription_details/{prescription_id}/` | Detail and reminder pages | Same list response, no ownership check, and still omits `is_severe_danger` even though Flutter reads it. |
| `POST /medications/api/prescriptions/create/` | Bag | Same JSON contract and no ownership authentication. |
| `POST|PUT /medications/api/prescriptions/{id}/update/` | Bag uses POST | Same contract; no ownership check. |
| `POST /medications/api/prescriptions/{id}/add_drug/` | Detail | Same contract. Integer extraction still truncates fractional text. |
| `POST|DELETE /medications/api/prescriptions/{id}/delete/` | Bag uses POST | Same contract; no ownership check. ORM cascade still removes reminders/taking records, and the image file is not removed. |
| `POST|DELETE /medications/api/prescriptions/drug/{id}/delete/` | Detail uses POST | Same contract; no ownership check and cascades reminder/history rows. |
| `POST /medications/api/check_all_safety/` | Scan follow-up and bag | Body `user_id`. Response still returns every current drug with `is_severe_danger` and warnings. It now also queries Health Bank allergy/history tables and may add `source` plus history IDs. Against the current unmigrated SQLite database this endpoint will fail because those tables do not exist. |

## Reminder and taking-history endpoints

### `POST /medications/api/reminders/set/`

Required JSON: `user_id`, `prescription_id`, and `drugs[]`; each drug has `prescription_drug_id` and `reminders[]` containing `frequency_tag`, `remind_time`, and optional `is_active`.

- Verifies that the prescription belongs to the asserted user.
- Uses `update_or_create(prescription_drug, frequency_tag)` and disables omitted tags for each submitted drug.
- Returns 201 when rows are created, otherwise 200 for updates, with created/updated counts.
- Current Flutter caller omits `user_id` and sends no identity header, so the implemented app receives **401** before saving.
- Current SQLite also lacks `Remind.is_active`; even a corrected request cannot run until migrations are reconciled/applied.

### `GET /medications/api/reminders/list/`

Required query: `prescription_id` and asserted identity; optional `active_only`. Returns reminder ID, drug ID/name, tag/time, active/expired state, and start/end dates. No Flutter caller.

### `GET|POST /medications/api/reminders/today/`

Also routed as `/today/{user_id}/`. Accepts asserted identity, optional `date` and `active_only` (default true). Returns the selected day's schedule, taking status, drug quantities including `remaining_amount`, and prescription/date metadata. No Flutter caller.

### `DELETE|POST /medications/api/reminders/{remind_id}/delete/`

Owner-filters using the asserted identity and sets `is_active=false`; it does not delete the row. No Flutter caller.

### `POST|PATCH|PUT /medications/api/reminders/{remind_id}/toggle/`

Owner-filters using the asserted identity. Optional `is_active`; otherwise toggles. No Flutter caller.

### `POST /medications/api/history/record/`

Required: asserted identity, `remind_id`, and status exactly `已吃` or `略過`. Optional: `force`, `record_date`/`date`, and `actual_taken_at`.

- One `TakingRecord` per reminder/date is intended.
- `已吃` decrements `PrescriptionDrug.remaining_amount`; changing from/to `已吃` adjusts it back or forward.
- Same-status duplicate is rejected unless `force=true`.
- No Flutter caller. Current SQLite lacks `record_date`, so this handler cannot run against it.

### `GET /medications/api/history/stats/`

Also routed as `/stats/{user_id}/`. Accepts asserted identity plus optional `days`, `start_date`, `end_date`. Returns summary counts/rate/rating, daily statistics, and up to 30 recent records. No Flutter caller.

## Health Bank endpoint

### `POST /medications/api/v1/health-bank/sync/`

Accepts body or query `user_id`; returns `synced_medications` and `synced_allergies`. It currently writes one fixed mock medication and one fixed allergy through `update_or_create`, then appends an annotated allergy entry to `User.allergies` after removing negative placeholders such as `無`.

- No real SDK/OAuth/token integration exists.
- No Flutter caller exists.
- The API specification's cURL example omits the required `user_id` and would receive 400.
- The handler requires new tables that are absent from the current SQLite database.

## Confirmed contract conflicts

1. Reminder save route exists but the current Flutter request lacks the newly required identity field/header (401).
2. Prescription detail still omits `is_severe_danger` read by Flutter.
3. New backend-only flows have no Flutter screens/callers: group, reminder retrieval/toggle/delete/today, taking record/statistics, and Health Bank sync.
4. The reminder API spec describes the deterministic token parser as authentication; it only extracts a user ID and can be forged.
5. Current source contracts depend on unapplied schema changes, so route coverage does not imply runtime availability.
