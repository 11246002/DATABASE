# Current Flutter frontend map

Incremental audit basis: `1032f3e..ed3fadc`, inspected 2026-10-06.

## Incremental result

`app/lib/main.dart` remains the only authored Dart source and is 2,442 lines. The team merge changed formatting around the registration success dialog and the final newline; it did not add team reminder/history/group/Health Bank screens or calls. The resolved merge retained:

```dart
const String API_BASE_URL = 'http://172.20.10.4:8000';
```

No conflict markers remain.

## Architecture and persistence

- Widget-local `StatefulWidget`/`setState`; no service, repository, domain model, or external state-management layer.
- Direct `package:http` calls from widgets.
- SharedPreferences stores `user_id` and `token` after login.
- The token is not sent by any current API caller and logout still does not clear it or `user_id`.
- There are 18 HTTP call sites covering 15 unique endpoint patterns.

## Existing screens

Login, registration, main four-tab shell, scanner/confirmation, medication bag, prescription detail, reminder settings, profile, and settings remain. Existing prescription, safety, and profile flows are otherwise unchanged from the original audit.

## Reminder screen mismatch

`ReminderSettingsPage` still:

1. loads the user's prescriptions;
2. loads selected prescription details;
3. derives tags/times from each drug's frequency;
4. posts `prescription_id` and `drugs` to `/medications/api/reminders/set/`.

It does **not** include `user_id`, `Authorization`, or `X-User-Id` in the save request. The updated backend requires one of these and returns 401. It also does not call `/reminders/list/`, so it cannot load current active/toggled reminder state before submitting the full replacement-style payload.

## Backend features with no frontend integration

- Group creation, join, and member list.
- Reminder list, today schedule, per-reminder toggle, and per-reminder soft delete.
- Taking status and adherence/history statistics.
- Health Bank mock sync and display of `MedicationHistory`/`PatientAllergy`.
- Real device notification scheduling remains absent.

## Persisting frontend/backend conflicts

- Prescription detail UI reads `is_severe_danger`, but detail API still omits it.
- Registration requires a “real name” locally but sends no such field.
- Fractional amounts are preserved as text in Flutter but truncated by backend integer extraction.
- Prescription deletion remains optimistic in UI and lacks rollback on backend failure.
- Hardcoded LAN HTTP URL remains environment-specific.
- Settings toggles, cloud sync, PDF export, large-font behavior, and logout lifecycle remain placeholders/incomplete.

## API coverage view

All 15 frontend paths resolve to Django URL patterns. Only 14 are contract-compatible with current handlers because reminder save lacks identity. The 12 backend-only URL patterns are documented in `CODEX_API_MAP.md`.
