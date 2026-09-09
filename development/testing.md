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

## Phase 3.1 — UI Foundation

1. Fresh install (or clear app data) → app opens to Splash → Onboarding →
   "Get Started" → Permission screen → "Continue" (or "Not now") → lands on
   Home inside the bottom-nav shell.
2. Force-close and reopen the app → Splash routes straight to Home (skips
   Onboarding/Permission — `onboardingCompleted` persisted in the database).
3. Tap each of the 5 bottom-nav destinations (Home/Adventure/Journal/
   Character/Menu) → each shows its own screen; switching back to a
   previously-visited tab preserves its state (`StatefulShellRoute`).
4. On Home: the steps ring reflects today's steps, the EXP bar reflects
   Player state, tapping the sync icon behaves exactly as the old "Sync
   Now" button did (the rewardable-steps caption below it updates), and
   tapping the calendar icon still lets you view a past date's steps.
5. Tap "Go to Adventure" on Home → lands on the Adventure tab; the
   Adventure (temporary) button there still spends Energy and grants
   EXP/Gold exactly as before (this is the same button, just relocated —
   including still showing "Not enough energy" correctly when Energy < 10).
6. On Menu (debug build only): the "Debug Tools" section shows the seeder
   button; tapping it still inserts steps for whichever date Home's
   calendar icon last selected.
7. Revoke Health Connect permission (or uninstall Health Connect) mid-use
   → Home shows the same denied/unavailable banners as before (unchanged
   behavior), the app does not crash, and does not re-route back to the
   full-screen Permission screen.
8. Force-close and reopen the app on a device whose `everstride.sqlite`
   predates this phase (`schemaVersion` 1 or 2) → app still opens without
   crashing (exercises the `AppSettings` migration on top of an existing
   `health_daily`/`player` database).

## Phase 4 — Adventure MVP

1. Open the Adventure tab → Greenwood Trail shows Easy selected by default,
   "Start Adventure · 10 Energy" and "+25 EXP"/"+10 Gold" reward cards.
2. Tap Normal → button and reward cards update to "20 Energy"/"+55 EXP"/
   "+22 Gold"; tap Hard → "30 Energy"/"+90 EXP"/"+36 Gold". Tap back to Easy
   → values return to 10/25/10.
3. With ≥10 Energy, start on Easy → a dedicated result screen appears
   (not a SnackBar) showing Greenwood Trail, Easy, "-10" Energy, "+25" EXP,
   "+10" Gold, and current Lv/EXP; "Continue" returns to the Adventure tab
   with the bottom nav visible again.
4. Repeat with enough Energy for Normal or Hard → the result screen shows
   the correct 20/55/22 or 30/90/36 values, matching what was displayed
   before starting.
5. Attempt an Adventure whose cost exceeds current Energy → a dialog names
   the exact cost and current Energy (not a generic message), offers "Got
   it", and does not navigate to a result screen; Energy/EXP/Gold on the
   Character tab are unchanged afterward.
6. Grant enough EXP in one Adventure to cross one or more level thresholds
   (e.g. repeat Hard near a level boundary) → the result screen shows a
   "Level Up!" callout with the correct before/after levels, and leftover
   EXP after the level-up is not negative.
7. Rapidly double-tap "Start Adventure" → only one resolution happens (the
   button visibly disables while resolving); Energy is deducted exactly
   once, not twice.
8. Force-close the app after a successful Adventure and reopen it → the
   updated Level/EXP/Energy/Gold on the Character tab persist exactly as
   shown on the result screen (no partial or duplicated state).
