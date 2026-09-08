# Phase 3 — Player Progression MVP — Design

Status: approved, ready for implementation plan
Relates to: `everstride-docs/plan/EVERSTRIDE_PLAN.md` section "Phase 3 — Player Progression MVP"

## Goal

Turn steps into a simple RPG resource. Steps rewarded by Phase 2's sync
convert to Energy (100 steps = 1 Energy); Energy is spent on a temporary
placeholder Adventure action that grants EXP and Gold, with a basic
level-up curve. This makes the full game loop
(`Walk → Steps → Energy → Spend Energy → Gain EXP`) testable end-to-end,
even though the real Adventure system (Phase 4) doesn't exist yet.

Out of scope for this phase: the real Adventure system/screen (Phase 4),
inventory/items, any UI beyond the existing Home screen, Supabase sync of
player state (Phase 6).

## Schema

Add a `Player` table to the existing `AppDatabase` (`lib/core/database/app_database.dart`,
alongside `HealthDaily`):

```
Player
------
id            int, fixed at 0 — single local player, no multi-profile yet
level         int, default 1
exp           int, default 0
energy        int, default 0
gold          int, default 0
pendingSteps  int, default 0
```

One row, always read/written at `id = 0`.

### Why `pendingSteps` (a deliberate addition beyond the plan's literal model)

The plan's Player model lists only `level`, `exp`, `energy`, `gold`. Converting
each sync's *delta* of newly-rewardable steps to Energy independently
(`delta ~/ 100`) silently discards the remainder every time. A player who
syncs frequently in small increments (e.g. 50 steps per sync) would never
accumulate enough for a single Energy point — this is the same class of bug
Phase 2 exists to prevent (never lose a partial amount across repeated
operations). `pendingSteps` banks the un-converted remainder so it carries
forward to the next sync, mirroring Phase 2's own `rewardedSteps` pattern.

## Architecture

Three new pieces, following the same layering Phase 2 established
(`UI → Controller → UseCase → Repository → DataSource`):

- `lib/features/player/domain/repositories/player_repository.dart` — replaces
  the existing empty marker interface with `PlayerState` (a plain value
  class: `level`, `exp`, `energy`, `gold`, `pendingSteps`) and
  `abstract class PlayerRepository { Future<Result<PlayerState>> getPlayer(); Future<Result<bool>> savePlayer(PlayerState player); }`.
  Deliberately dumb CRUD — no game logic here, matching `HealthSyncRepository`.
- `lib/features/player/data/repositories/player_repository_impl.dart` —
  Drift-backed implementation. `getPlayer()` returns the default
  `PlayerState(level: 1, exp: 0, energy: 0, gold: 0, pendingSteps: 0)` if no
  row exists yet (first-ever launch inserts nothing until the first save);
  `savePlayer()` upserts the `id = 0` row.
- `lib/features/player/domain/usecases/credit_energy_from_steps_usecase.dart` —
  `CreditEnergyFromStepsUseCase`: given a count of newly-rewardable steps,
  adds them to `pendingSteps`, converts whole 100s to Energy, keeps the
  remainder. Returns the amount of Energy actually gained (for UI feedback).
- `lib/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart` —
  `SpendEnergyForAdventureUseCase`: the temporary placeholder Adventure.
  Fixed costs/rewards taken directly from the plan's own Phase 4 example
  ("Forest Path"): `energyCost = 10`, `expReward = 25`, `goldReward = 10`.
  Fails with `Err` if energy is insufficient (does not mutate state).
  Otherwise deducts energy, adds EXP and Gold, and applies the level-up
  curve (looping — a single reward could theoretically cross more than one
  level).
- `lib/features/player/presentation/controllers/player_controller.dart` —
  `PlayerController extends Notifier<AsyncValue<Result<PlayerState>>?>`.
  `build()` loads the player once via a `_loadPlayer()` call and,
  critically, registers `ref.listen(healthSyncControllerProvider, ...)` to
  reactively call `CreditEnergyFromStepsUseCase` whenever a sync completes
  with `totalNewRewardableSteps > 0` — see "Reactive composition" below.
  Also exposes a `spendOnAdventure()` method for the UI button.

### Reactive composition with Phase 2 (why, not just how)

Phase 2's `HealthSyncController`/`SyncHealthDataUseCase` are untouched by
this phase — no import of anything from `features/player` is added to
`features/health`. Instead, `PlayerController.build()` uses
`ref.listen(healthSyncControllerProvider, (previous, next) { ... })` to
react whenever the Sync Now button's controller produces a new successful
result. This was chosen over having the UI manually call both controllers
in sequence: a manual-sequencing approach would work today (there is only
one call site, the button), but silently stops working the moment any other
code path ever triggers a sync without remembering to also credit energy.
The reactive listener removes the "forgot to also call the second
controller" failure mode specifically — but it is not failure-proof in
general, and the final review (see the Phase 3 plan's implementation
ledger) found two real gaps worth flagging for whoever builds on this next:

- The `ref.listen` registration only exists once `playerControllerProvider`
  has been read at least once. Today the only sync trigger (the Sync Now
  button) lives in the same widget tree that already reads both providers,
  so this isn't reachable — but it would become live the moment a
  background sync, an app-resume sync, or any trigger outside that widget
  tree is added.
- If `CreditEnergyFromStepsUseCase`'s `savePlayer` call fails after
  `SyncHealthDataUseCase` has already persisted `rewardedSteps` for those
  steps (a separate repository, a separate write), the Energy for that
  delta is lost with no retry — Phase 2 has no way to know those steps
  still owe Energy.

Neither has a cheap, safe fix bundled into this phase (both need either a
durable retry/outbox or a real cross-repository transaction) — parked
explicitly for before Phase 4 introduces any additional sync trigger.

## Algorithm

### `CreditEnergyFromStepsUseCase.call(int newRewardableSteps)`

```
totalPending = player.pendingSteps + newRewardableSteps
energyGained = totalPending ~/ 100
newPendingSteps = totalPending % 100
if energyGained == 0: still persist the updated pendingSteps (don't lose the partial amount), return Ok(0)
else: persist energy += energyGained, pendingSteps = newPendingSteps, return Ok(energyGained)
```

### `SpendEnergyForAdventureUseCase.call()`

```
if player.energy < energyCost: return Err(Failure('Not enough energy'))
newExp = player.exp + expReward
newLevel = player.level
expToNext = newLevel * 100          // linear level-up curve
while newExp >= expToNext:
  newExp -= expToNext
  newLevel += 1
  expToNext = newLevel * 100
persist: energy -= energyCost, exp = newExp, level = newLevel, gold += goldReward
return Ok(updated PlayerState)
```

The `while` loop (not a single `if`) is deliberate: a large-enough EXP
reward relative to a low level could cross more than one level-up threshold
in a single grant, and the loop handles that correctly without a special
case.

The `expToNext = level * 100` formula is needed in two places (the use
case's level-up loop, and the UI's "EXP: x / expToNext" display) — to avoid
duplicating this constant, expose it as a single static helper (e.g.
`PlayerState.expToNextLevel(int level) => level * 100`, or a top-level
function in the same file as `PlayerState`) that both call.

## Error handling

Both use cases follow the established `Result<T>`/`Failure` pattern — no
exceptions cross the repository or use-case boundary. `SpendEnergyForAdventureUseCase`
returning `Err` for insufficient energy is an expected, non-exceptional
outcome (not a bug path) — the UI shows it as a normal message, not an
error state distinct from "not enough energy."

## UI

Added to the existing Home screen (`lib/app/home_page.dart`) — no new
route. Below the existing sync/steps section:

- Level, EXP (as `exp / expToNext`), Energy, Gold — read from
  `playerControllerProvider`.
- A button, clearly labeled as temporary (e.g. "Adventure (temporary)"),
  calling `spendOnAdventure()`. Shows the plan's fixed cost/reward inline
  ("10 Energy → +25 EXP, +10 Gold") so its purpose is self-evident before
  Phase 4 replaces it with a real Adventure list.
- When `SpendEnergyForAdventureUseCase` returns `Err` (not enough energy),
  show that message inline rather than crashing or silently doing nothing.

## Testing

Per the plan's testing priorities (this phase's reward math is exactly the
kind of logic that must not silently break), unit tests for both use cases
using a fake `PlayerRepository` (no Drift needed — a plain in-memory fake is
sufficient here since there's no per-date bookkeeping like Phase 2 had):

**`CreditEnergyFromStepsUseCase`:**
- 250 new steps with 0 pending → +2 Energy, 50 pendingSteps left over.
- 50 new steps with 70 pendingSteps already banked → 120 total → +1 Energy, 20 pendingSteps left over.
- 0 new steps → no-op, returns `Ok(0)`, player state unchanged.
- Repeated small syncs (e.g. 30 steps three times) accumulate to the same
  total Energy as one sync of the combined amount — proves the remainder
  genuinely carries forward and nothing is lost.

**`SpendEnergyForAdventureUseCase`:**
- Sufficient energy, no level-up: energy/exp/gold update as expected, level unchanged.
- Sufficient energy, exactly enough EXP to level up once: level increments, leftover EXP is `0`, not negative.
- A reward large enough (relative to a low starting level) to cross two level thresholds in one call: `while` loop applies both level-ups correctly in one grant.
- Insufficient energy: returns `Err`, and the player's stored state is unchanged (no partial deduction).
