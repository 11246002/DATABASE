# Incremental repository audit

Audit date: 2026-10-06 (Asia/Taipei).

## Scope and baseline

The original baseline documentation was committed in `1032f3e` (`wip: preserve local state before team sync`). Current integration `HEAD` is `ed3fadc`. The audited range is therefore exactly:

```text
1032f3e356c232309bb19b2ae0ab4ea90b2dbf92..ed3fadc430bef2a05a18ce6a89644eb6a28446fe
```

The range contains 22 changed production/spec/test/migration files and 16 commits including upstream/final merge commits. This was an incremental audit; unchanged repository areas were not re-audited from scratch.

## Changed since baseline

- Expanded reminder APIs: list, today schedule, toggle, soft delete, owner filtering, active state, update semantics, and date range.
- Expanded taking tracking: one record per reminder/day, status validation, inventory adjustment, and adherence statistics.
- Added Health Bank mock sync, `MedicationHistory`, `PatientAllergy`, allergy backfill, and safety integration.
- Improved drug search across multiple tokens and ingredient; guarded unmatched warning persistence.
- Added media settings/development serving and changed server timezone to Asia/Taipei.
- Added richer medication admin definitions and live reminder E2E script/specifications.
- Added model-level uniqueness for drug license and group membership, although migrations are missing.
- `main.dart` received formatting-only team changes; the local API base URL was retained.

## API coverage

- Backend URL patterns: 27.
- Flutter call sites: 18 across 15 unique endpoint patterns.
- Path coverage: 15/15 Flutter endpoints resolve.
- Contract-ready coverage: 14/15; reminder save lacks required identity.
- Backend-only patterns: 12.

The added backend features are not end-to-end product features yet because no Flutter caller exists for reminder retrieval/taking history/Health Bank/group flows.

## Database and migration status

Read-only SQLite inspection confirms only accounts 0001/0002 and medications 0001/0002 are applied. New source requires schema that is not present. The intended reminder unique constraint is additionally blocked by 14 duplicate key groups. Model-only constraints for drug license and group membership have no migration.

No migration was run and no database row/file was modified.

## Resolved old issues

- Null-drug warning persistence failure is guarded.
- GroupMember ID migration state is brought back to AutoField in the new migration graph.
- Reminder canonical source model is now `Remind`; legacy `MedicationReminder` is scheduled for deletion.
- Reminder update/duplicate prevention and reminder/history owner filtering are materially improved in source.
- Media configuration now exists for new uploads.

Each of the last three has deployment/data/security caveats documented in `CODEX_CONFLICTS.md`.

## Highest-risk new issues

1. Current database cannot support newly imported/querying code.
2. Reminder migration 0005 conflicts with existing duplicate rows.
3. Existing Flutter reminder save now receives 401.
4. Safety endpoint now depends on missing Health Bank tables.
5. Media root change strands existing root-level prescription images.
6. Health Bank allergy is represented in two sources and can produce duplicate/misclassified warnings.

## Verification performed

- Read required audit maps, source diffs, commit history, current routes/models/handlers, migrations, API specs, and E2E script.
- Compared `1032f3e` to `ed3fadc` by commit and file diff.
- Mapped every current Flutter HTTP call to Django URL patterns.
- Opened SQLite with the native read-only flag to inspect applied migrations, columns, indexes, row counts, and duplicate-key counts.
- Verified no merge markers in the incrementally changed source/spec files.

Not performed:

- Django checks, migration plan/dry-run, or tests: no Python interpreter is installed.
- E2E script: it mutates configured database state.
- Migrations or database repair: explicitly out of scope.
- Live Gemini/OpenFDA/Health Bank behavior.

## Development readiness

**Not safe for normal runtime/feature development against the current database.** Safe work can continue on documentation, planning, and isolated branches/tests. Before backend/frontend feature work is treated as runnable, the team needs an explicit duplicate-reminder data decision, corrected migrations, a disposable migration rehearsal, and the reminder-save identity contract aligned with Flutter.
