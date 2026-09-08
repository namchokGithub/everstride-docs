# Manual Recheck

Quick manual steps to confirm a phase still works after changes. Not detailed test cases — a smoke check to run before/after touching related code. See `everstride-docs/PROGRESS.md` for full history of what's been verified and how.

## Phase 1 — Health Connect Prototype

Status: all plan checklist items done, verified on emulator and a real device. Recheck after any change touching `lib/features/health/**`, `lib/app/home_page.dart`, or Health Connect manifest entries.

1. Restart the app (fresh install if manifest/permissions changed) — Home screen loads, no crash.
2. Health Connect status line matches reality: shows "available" only if Health Connect is actually installed and up to date on the device.
3. **Not available**: "Install / Update Health Connect" button shows instead of the permission/steps section; tapping it opens the Play Store.
4. **Available**: permission line briefly shows "Permission: checking..." then auto-settles to the real current status ("granted"/"denied") within about a second — it should never sit on a stale value from a previous run.
5. Tap "Request Health Permission" → Allow → shows "Permission: granted".
6. Deny path (optional — needs a clean permission state first, e.g. `adb shell pm reset-permissions <applicationId>`): deny in the dialog → shows "Permission: denied" + hint text, no crash.
7. Known OS limitation, not a bug: if a permission was denied twice in a row (or once via `adb pm revoke` + once for real), Android marks it `USER_FIXED` and refuses to show the dialog again — the app can't force it back open. Fix by clearing it, not by changing app code: `adb shell pm reset-permissions <applicationId>`, or revoke/re-grant manually from Health Connect's own settings.
8. Steps count shows a number for today (not stuck on "Loading...", no crash even if it's 0).
9. Tap "Pick a date" → choose a past date → steps update for that date.
10. Tap "Sync Now" → the number doesn't disappear during refresh (small spinner shows instead).
11. Emulator only, debug build: tap "[Debug] Insert 500 test steps" a few times → total increases by exactly 500 each press (if it doesn't, the seeder is writing overlapping time windows again — Health Connect de-dupes those instead of summing).
12. Debug console/logcat shows readable `health.availability` / `health.permission` / `health.query` log lines for the actions above (only in debug builds).

## Phase 2 — Local Health Sync

The local database file persists across app restarts (it's a real sqlite
file, not in-memory) — to test "first-ever sync" behavior again, uninstall
the app first (`flutter clean` does not remove app-local storage; a real
uninstall/reinstall does).

1. Tap "Sync Now" for the first time ever on a device/emulator → shows
   "+N rewardable steps synced" (N should roughly match the visible step
   count, since nothing has been rewarded yet).
2. Tap "Sync Now" again immediately, without walking anywhere → shows
   "No new rewardable steps" (0 delta — not a duplicate reward).
3. Use the debug step seeder (Phase 1) to add steps, then tap "Sync Now" →
   the new amount, not the full total, shows as rewarded.
4. Force-close the app, wait a bit (or change the device's date forward one
   day in developer settings), reopen, tap "Sync Now" → both the skipped
   day and the new day get credited (visible as a single combined number).

## Phase 3 — Player Progression MVP

1. On a fresh player (level 1, 0 exp/energy/gold), tap "Sync Now" after
   using the Phase 1 debug seeder to add ≥100 steps → Energy increases by
   the expected amount (steps ÷ 100, rounded down); syncing again with
   under 100 new steps still banks toward the next Energy point instead of
   losing it (check by syncing twice with a small amount each time and
   confirming Energy eventually increments).
2. Tap "Adventure (temporary)" with ≥10 Energy → Energy -10, EXP +25,
   Gold +10 shown immediately.
3. Tap it enough times to cross a level boundary → Level increments, EXP
   wraps correctly (not negative, not still showing ≥ the old threshold).
4. Tap it with <10 Energy → a "Not enough energy" message appears (a
   SnackBar), and Level/EXP/Energy/Gold on screen are unchanged.
5. Force-close and reopen the app → Level/EXP/Energy/Gold persist exactly
   as before closing (this exercises the schema migration on a device
   that already had Phase 2's database file, if you're testing on one that
   ran Phase 2 before this phase existed).
