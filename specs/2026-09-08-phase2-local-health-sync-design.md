# Phase 2 — Local Health Sync — Design

Status: approved, ready for implementation plan
Relates to: `everstride-docs/plan/EVERSTRIDE_PLAN.md` section "Phase 2 — Local Health Sync"

## Goal

Avoid rewarding the same steps twice, while also catching up any days the
player didn't open the app. Wire this into the existing "Sync Now" button
(`lib/app/home_page.dart`) so tapping it both refreshes the raw step count
(already built) and computes/stores the safely-rewardable delta.

Out of scope for this phase: converting rewardable steps into Energy/EXP
(that's Phase 3), any new screen or route.

## Architecture

Three new pieces, following the existing layering
(`UI → Controller → UseCase → Repository → DataSource`):

- `lib/core/database/app_database.dart` — first `AppDatabase` (Drift) in the
  project, with one table, `HealthDaily`. The `drift`, `sqlite3_flutter_libs`,
  `path_provider`, `path`, `drift_dev`, `build_runner` dependencies were
  already added in Phase 0 and are unused until now.
- `lib/features/health/domain/repositories/health_sync_repository.dart` +
  `lib/features/health/data/repositories/health_sync_repository_impl.dart` —
  reads/writes `health_daily` rows via the Drift `AppDatabase`. Separate from
  `HealthRepository` (which only talks to Health Connect) to keep "talks to
  Health Connect" and "talks to the local DB" as distinct seams.
- `lib/features/health/domain/usecases/sync_health_data_usecase.dart` —
  `SyncHealthDataUseCase`, the only place the sync algorithm lives. Depends
  on `HealthRepository` (to read steps) and `HealthSyncRepository` (to
  read/write local rows). No Flutter/Riverpod imports — plain Dart, so it is
  unit-testable without a device or widget tree.

A new Riverpod controller (`lib/features/health/presentation/controllers/health_sync_controller.dart`)
wraps the use case for the "Sync Now" button, following the same
`Notifier<AsyncValue<Result<T>>>` pattern already used by
`HealthPermissionController`.

## Schema

```
health_daily
------------
date            DateTime (local calendar date, time truncated to midnight) — primary key
total_steps     int  — last known total for that date from Health Connect
rewarded_steps  int  — cumulative amount already credited for that date
last_synced_at  DateTime — when this row was last updated
```

One row per local calendar date. No `user_id`/`player_id` column yet — the
app is single-profile/local-only until Phase 6 (Supabase Integration) adds
accounts; that migration is out of scope here.

## Sync algorithm

All dates the use case works with (`sinceDate`, `today`, and every date in
between) are normalized to local midnight (`DateTime(y, m, d)`) before being
used as a lookup key or written to `health_daily` — otherwise two
`DateTime` values for the same calendar day but different times of day
would be treated as different rows.

`SyncHealthDataUseCase.call()`:

1. Find `sinceDate` = the most recent date that already has a `health_daily`
   row. If no rows exist yet (first-ever sync), cap `sinceDate` to
   `today - 6 days` (a 7-day catch-up window, so a brand-new player with a
   long pre-existing Health Connect history doesn't get flooded with
   historical rewards on their very first sync).
2. Walk forward one calendar date at a time from `sinceDate` through `today`
   inclusive (re-including `sinceDate` itself is intentional and safe — see
   "Why re-walk the last synced date" below):
   - `total = await healthRepository.getStepsForDate(date)`
   - `rewarded = existing row's rewarded_steps, or 0 if no row yet`
   - `delta = max(0, total - rewarded)`
   - upsert the row: `total_steps = total`, `rewarded_steps = rewarded + delta`,
     `last_synced_at = now`
   - accumulate `delta` into a running total and record `(date, delta)` for
     the return value
3. Return `Result<SyncResult>`, where
   `SyncResult { int totalNewRewardableSteps; List<DailySyncResult> days; }`
   (`DailySyncResult { DateTime date; int rewardableSteps; }`) — the caller
   (controller/UI) only needs `totalNewRewardableSteps` today, but the
   per-day list costs nothing extra to return and is useful for future
   debugging/UI (e.g. a "here's what you missed" breakdown later).

### Why this single mechanism covers all four Phase 2 plan tasks

- **Day rollover**: "today" is always included in the walk and always
  recomputed against its existing `rewarded_steps` baseline — there is no
  separate "did the day change?" check needed, because every sync just asks
  "what's new since what I already credited?" for whatever `today` currently
  resolves to.
- **Duplicate rewards**: the `max(0, total - rewarded)` formula is the
  literal rule from the plan (section 6, "Important Rule"). Running it twice
  in a row for the same date with the same `total` yields `delta = 0` the
  second time — safe to re-run any time.
- **Step count corrections**: if Health Connect reports a *lower* total than
  before (a correction), `delta` clamps to `0` (never negative) and
  `total_steps` still updates to the corrected value; `rewarded_steps` is
  left untouched, so no reward is clawed back and none is duplicated.
- **Catch-up for missed days**: walking from `sinceDate` (not just "today")
  means days the app was never opened get synced — and rewarded — the next
  time it is.

### Why re-walk the last synced date

Including `sinceDate` itself (not `sinceDate + 1`) means the boundary day
gets recomputed every sync. This is deliberate: if `sinceDate` is today, this
is exactly how "sync again later today" produces the correct incremental
delta. If `sinceDate` is a past day from a previous session, recomputing it
is a harmless no-op (its `delta` will be `0`, since it was already fully
credited) — the cost is one extra `getStepsForDate` call per sync, which is
negligible.

## Error handling

Each date's read/write happens independently. If one date's
`getStepsForDate` call throws (e.g. Health Connect glitch), the walk stops
at that point and the use case returns `Result` describing what succeeded so
far (the dates already upserted keep their state — no rollback of earlier
successful days in the same pass) plus a `Failure` naming the date that
failed. The user can just tap "Sync Now" again later to retry the remainder;
already-synced days are unaffected (idempotent, per above).

`HealthSyncRepository` follows the existing `Result<T>`/`Failure` pattern
used throughout `HealthRepository` — no exceptions cross the
repository/use-case boundary.

## UI change

"Sync Now" (`lib/app/home_page.dart`) currently only invalidates the raw
steps `FutureProvider`. It will additionally invoke
`HealthSyncController.sync()`, and the screen will show the result
alongside the existing step count — e.g. a line like
`"+250 rewardable steps synced"` (or "No new rewardable steps" when the
delta is 0, or the existing error-rendering pattern on failure). Exact
copy/placement is an implementation-time detail, not a design decision.

## Testing

Per plan section 12 (Testing Priorities), this is the highest-priority area
for tests in the whole codebase. `SyncHealthDataUseCase` must ship with unit
tests (this is new logic, not covered by the "don't run flutter test unless
asked" rule in `everstride-docs/AGENTS.md` — writing test files and running
them as part of implementing this feature is expected and different from
running the full suite unprompted) using:

- A fake/mock `HealthRepository` returning canned step totals per date
  (no real Health Connect or device needed).
- An in-memory Drift database (`NativeDatabase.memory()`) for
  `HealthSyncRepository` — real Drift behavior, no device needed.

Cases to cover (from plan section 12's examples):
- First sync of the day: `rewarded_steps` starts at 0, delta equals total.
- Second sync same day, same total: delta is 0 (no duplicate reward).
- Total increased between syncs: delta equals only the increase.
- Total decreased (correction): delta is 0, `total_steps` still updates.
- First-ever sync with no prior rows: catch-up window is capped to 7 days,
  not further back.
- Multi-day catch-up: app not opened for 2 days syncs and rewards both
  missed days plus today.
