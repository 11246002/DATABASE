# Verified incremental baseline

Verification date: 2026-10-06 (Asia/Taipei).

## Git boundary

- Original takeover baseline commit: `1032f3e356c232309bb19b2ae0ab4ea90b2dbf92` (`wip: preserve local state before team sync`).
- Current integration commit: `ed3fadc430bef2a05a18ce6a89644eb6a28446fe` (`merge: sync team main into local integration`).
- Branch: `integrate/team-main-20261006`.
- Incremental range: `1032f3e..ed3fadc`.
- Future source audits should use `ed3fadc` as the new code baseline unless a later baseline supersedes it.

## Repository state at audit start

Tracked source was clean after the merge. Existing untracked state consisted of `app/.gitignore` and prescription image files; these were preserved. This audit changes only the seven requested `docs/CODEX_*.md` files. It does not stage or commit them.

## Current frontend baseline

- Flutter remains a single authored `app/lib/main.dart` file with 18 HTTP call sites and 15 unique endpoint patterns.
- API base URL: `http://172.20.10.4:8000`.
- Existing UI supports account, prescription/OCR, safety, reminder setting, and profile flows.
- New group, reminder retrieval/taking history, and Health Bank backend features have no Flutter integration.
- Reminder save is currently contract-incompatible because it omits required identity.

## Current backend baseline

- 27 application URL patterns: 7 accounts and 20 medications.
- New reminder/history handlers implement active state, list/today/toggle/delete, daily status, inventory changes, and statistics.
- Health Bank mock sync adds structured medication/allergy storage and safety inputs.
- Search now handles multiple terms/ingredients and unmatched warnings safely.
- Identity remains unverified; new owner filtering is based on forgeable asserted IDs.

## Current model/migration baseline

Source intends:

- canonical `Remind` with `is_active` and unique drug/tag;
- `TakingRecord.record_date` and unique reminder/day;
- new `MedicationHistory` and `PatientAllergy`;
- removal of legacy `MedicationReminder`;
- `GroupMember(group,user)` and `Drug.license` uniqueness in models.

Actual SQLite remains at accounts 0002 and medications 0002. It has the legacy reminder table and lacks all new tables/columns/constraints. It contains 14 duplicate reminder-tag groups, blocking the intended unique constraint. The last modified timestamp predates this audit; SQLite was opened read-only.

## Current API coverage baseline

- Frontend path resolution: 15/15.
- Frontend contract-ready: 14/15.
- Backend-only URL patterns: 12.
- `check_all_safety`, reminder/history, and Health Bank source paths depend on unapplied schema.

## Resolved since original baseline

- Unmatched-drug warning null-FK path guarded.
- Multi-keyword/ingredient drug search added.
- GroupMember ID migration corrected to AutoField.
- Source-level reminder canonicalization, update behavior, and partial ownership checks added.
- Media settings and Asia/Taipei timezone added.

## Blocking or unresolved baseline facts

- Migration/data reconciliation is required before current backend can run safely with current SQLite.
- Flutter reminder save and backend identity requirement disagree.
- Real authentication and broad ownership enforcement remain absent.
- Detail danger flag, fractional amount, registration real-name, non-atomic save, cascade/file deletion, deployment configuration, and test gaps remain.
- Existing prescription images are not under the new `MEDIA_ROOT`.

## Environment and test limits

- No installed Python interpreter; Django runtime/checks/tests/migration dry-run unavailable.
- Reminder E2E script is state-mutating and was not run.
- Database inspection used read-only SQLite access; no migration or row change occurred.
- No production code, API, migration, database, or image was modified by this audit.
