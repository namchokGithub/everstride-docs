# Adventure System

## Status

**Phase 4 MVP design specification.**

This document defines the first real Adventure system for Everstride. It
replaces the Phase 3 temporary Adventure action as the game's intended way to
turn Energy into progression rewards.

It is a game-design document, not an implementation plan. Exact architecture,
storage, UI composition, and API choices belong in the Phase 4 implementation
plan.

## Current baseline

The following facts are already true and must remain accurately represented:

- The Adventure tab has a **Greenwood Trail** UI.
- The screen offers **Easy**, **Normal**, and **Hard** local-only selection,
  defaulting to Easy. The selected difficulty is not persisted.
- Difficulty currently changes styling only; it does **not** change Energy
  cost or rewards.
- The temporary Start Adventure action spends **10 Energy** and grants
  **25 EXP** and **10 Gold** through `PlayerController`.
- The app has no Adventure model, Adventure database records, items, loot,
  in-progress adventures, dedicated result screen, or atomic Adventure
  transaction yet.

Phase 4 may replace the temporary action with a real MVP flow. It must not
claim that any of the deferred systems above already exist.

## Design intent

Adventure is the active payoff in Everstride's core loop:

```text
Walk
→ earn Energy
→ choose an Adventure and difficulty
→ resolve it
→ receive progression rewards
→ return motivated to walk again
```

The system should be quick to understand, low-pressure, and rewarding after
ordinary daily activity. An Adventure is a deliberate Energy-spending choice,
not a punishment for missing steps or a reason to encourage unsafe exercise.

For the MVP, resolution is immediate and deterministic. The player chooses a
trail and a difficulty, confirms the spend, then sees a clear outcome. This
keeps the loop testable before time-based expeditions, combat, or loot systems
are designed.

## Phase 4 MVP scope

Phase 4 introduces exactly one playable adventure definition: **Greenwood
Trail**. It establishes the reusable Adventure shape and supports the complete
instant-resolution loop.

### Included

- Greenwood Trail as a real Adventure definition.
- Difficulty-aware Energy costs and fixed EXP/Gold rewards.
- A Start/resolve action that validates Energy before any player progress is
  changed.
- An explicit success result that reports the rewards received and any level
  increase.
- An explicit insufficient-Energy outcome that leaves player state unchanged.
- A clear return path to the Adventure screen or Home after a result.
- Local, offline-first play. The state may be stored locally according to the
  Phase 4 implementation plan.

### Explicitly excluded

- Additional trails, regions, unlock chains, or procedural adventures.
- Timers, real-time travel, background completion, or an in-progress screen.
- Failure chance, combat, damage, health, enemies, skills, or equipment.
- Items, loot tables, chests, rarity, inventory, or consumables.
- Daily quests or quest-linked Adventure objectives.
- Cloud sync, server authority, multiplayer, or anti-cheat enforcement.
- Final balance and final visual polish.

## Adventure entity

An Adventure is static game content: a named activity that offers one or more
difficulty variants. It is not a record of a player currently travelling.

The Phase 4 design needs these fields:

| Field               | Purpose                                       | Greenwood Trail MVP value                           |
| ------------------- | --------------------------------------------- | --------------------------------------------------- |
| `id`                | Stable content identifier                     | `greenwood_trail`                                   |
| `name`              | Player-facing title                           | Greenwood Trail                                     |
| `description`       | Short player-facing fantasy/context text      | A peaceful path through the forest.                 |
| `artKey`            | Reference to display art                      | Greenwood Trail artwork / existing background asset |
| `difficultyOptions` | Available ways to attempt this Adventure      | Easy, Normal, Hard                                  |
| `defaultDifficulty` | Preselected option on entry                   | Easy                                                |
| `status`            | Whether the content can currently be selected | Available                                           |

Each difficulty option has these design fields:

| Field        | Purpose                                                                    |
| ------------ | -------------------------------------------------------------------------- |
| `id`         | Stable difficulty identifier (`easy`, `normal`, `hard`)                    |
| `label`      | Player-facing difficulty name                                              |
| `energyCost` | Energy spent for one resolved attempt                                      |
| `expReward`  | Guaranteed EXP granted on success                                          |
| `goldReward` | Guaranteed Gold granted on success                                         |
| `riskLabel`  | Optional explanatory text; it must not imply a failure mechanic in the MVP |

Phase 4 does not require an `AdventureRun`, timer, progress percentage, item
drops, or result-history entity. Those concepts should be added only when
their later rules have been designed.

## Greenwood Trail

Greenwood Trail is the Phase 4 reference Adventure and the bridge from the
completed UI skeleton to gameplay.

**Theme:** a welcoming first forest route; it should feel approachable rather
than dangerous.

**Availability:** available to every MVP player. There is no level gate or
unlock requirement.

**Outcome:** every valid attempt succeeds. Difficulty represents a larger
resource commitment and a larger fixed payoff—not a success probability.

### Difficulty matrix

The current Phase 3 values are preserved as the Easy baseline. Normal and Hard
are proposed MVP tuning values, not already-implemented behavior.

| Difficulty | Energy cost | EXP | Gold | Design role                                                          |
| ---------- | ----------: | --: | ---: | -------------------------------------------------------------------- |
| Easy       |          10 |  25 |   10 | Current temporary-action baseline; low-commitment repeatable choice. |
| Normal     |          20 |  55 |   22 | Mid-tier choice with a modest efficiency bonus.                      |
| Hard       |          30 |  90 |   36 | Largest immediate commitment and reward; still deterministic.        |

The MVP may use these values as a starting point, but must keep them
centralized and adjustable. The key design relationship is that a higher
difficulty costs more and rewards more; its exact efficiency is tunable.

## Player flow and resolution model

```text
Adventure tab
→ select Greenwood Trail
→ select difficulty (Easy by default)
→ review cost and guaranteed rewards
→ start
→ validate Energy
→ atomically apply cost and rewards
→ show result
→ continue
```

### Before starting

The player can inspect the selected difficulty's actual Energy cost and
guaranteed rewards. The displayed values must always match the values used to
resolve the action.

The selected difficulty applies only to the Adventure being started. It need
not be remembered when the player leaves or reopens the screen in Phase 4.

### Successful resolution

If the player has at least the selected option's Energy cost:

1. Spend that exact amount of Energy.
2. Grant the selected option's fixed EXP and Gold.
3. Apply normal progression rules, including level-up and overflow EXP.
4. Produce one success result containing the Adventure, selected difficulty,
   cost, rewards, and level-change information.

There is no random roll and no partial success in the MVP. The result should
use completion language such as **Adventure Complete**, not battle or loot
language that implies undeveloped systems.

### Result behavior

The result is a moment of acknowledgement, not just an invisible state change.
It must show:

- Greenwood Trail and the completed difficulty.
- Energy spent.
- EXP gained.
- Gold gained.
- Current level/EXP progress after rewards, or a clear level-up callout when
  the attempt raises one or more levels.
- One unambiguous Continue action.

The result UI itself may be visually simple in Phase 4; Phase 3.2 deliberately
did not implement a result screen. A SnackBar alone is insufficient for the
designed MVP result because it does not reliably communicate the complete
outcome.

### Failure and non-success states

| State                    | Player-facing behavior                                                                                | State-change rule                              |
| ------------------------ | ----------------------------------------------------------------------------------------------------- | ---------------------------------------------- |
| Insufficient Energy      | Explain the selected cost and current Energy; offer a way back to walk/sync or choose another option. | Spend and rewards are both zero.               |
| Unavailable Adventure    | Do not allow the start action; explain why if this state is introduced later.                         | No player-state change.                        |
| Resolution/storage error | Clearly say the Adventure could not be completed and let the player safely retry.                     | No partial spend or partial reward may remain. |
| Repeated start input     | Treat duplicate input as one resolution only.                                                         | At most one cost/reward application.           |

There is no gameplay failure, retreat, loss of rewards, or penalty in Phase 4.
Those systems need separate design decisions before they exist.

## Rules that must remain invariant

These are correctness and trust rules, not balance knobs:

- A player cannot start an Adventure without sufficient Energy for its selected
  difficulty.
- A failed validation spends no Energy and grants no reward.
- A successful Adventure spends the selected cost exactly once and grants its
  corresponding rewards exactly once.
- Cost, EXP, Gold, and level progress change together as one outcome; an
  error must not leave a partial result.
- The preview and result must use the same selected difficulty values.
- EXP follows the existing progression rule: required EXP for the next level is
  `level × 100`, and excess EXP carries into later levels.
- Adventure resolution must not alter step totals, rewarded steps, or pending
  step remainder. Those belong to the health-to-Energy loop.
- Existing earned Energy is not removed except by the selected Adventure cost.
- Re-entering the screen, retrying after a result, or a repeated tap must not
  duplicate a resolved Adventure's rewards.

## Tunable values

The following are intentional MVP tuning points and may change after testing:

| Value                     | Initial MVP position                                          |
| ------------------------- | ------------------------------------------------------------- |
| Available Adventure count | One: Greenwood Trail                                          |
| Difficulty count          | Three: Easy, Normal, Hard                                     |
| Easy cost/rewards         | 10 Energy, 25 EXP, 10 Gold (current baseline)                 |
| Normal cost/rewards       | 20 Energy, 55 EXP, 22 Gold (proposed)                         |
| Hard cost/rewards         | 30 Energy, 90 EXP, 36 Gold (proposed)                         |
| Difficulty efficiency     | Slightly better at higher commitment, but subject to playtest |
| Starting availability     | No level gate                                                 |
| Resolution timing         | Immediate                                                     |
| Success rate              | 100% for a valid attempt                                      |

`100 steps = 1 Energy`, the lack of a current Energy cap, and the EXP curve
come from the existing player-progression baseline. They constrain the feel of
Adventure, but they are owned by their respective game-design documents and
remain balance values rather than Adventure invariants.

## Deferred systems and design handoff

### Later Adventure iterations

Do not add these opportunistically during Phase 4. Each changes the game loop
enough to need a follow-up design pass:

- **In-progress adventures:** duration, app-close behavior, concurrency, end
  early, completion notifications, and whether walking affects progress.
- **Risk/failure:** success chance, losses, recovery, player control, and how
  difficulty communicates risk.
- **Items and loot:** drop sources, loot tables, rarity, inventory capacity,
  duplicates, sinks, and economy impact.
- **More content:** region unlocks, level requirements, discovery, encounter
  variety, and content pacing.
- **History/journal:** what event data is worth retaining and how players view
  it.

### Phase 5 — Daily Quests

Phase 5 can refer to completed Adventure events only after Phase 4 has a
reliable resolution outcome. Quest goals may later count completed Adventures,
specific difficulties, Energy spent, or rewards claimed, but Phase 4 must not
invent quest behavior or a quest reward layer.

### Phase 6 — Supabase Integration

Phase 6 should decide which player and Adventure outcomes sync to the cloud,
how conflicts are handled, and which operations require server authority.
Phase 4 remains local and offline-first; it must not assume a database service
or online validation exists.

### Economy and balancing

Gold has no spending system yet. The Phase 4 Gold reward is a progression
placeholder, not evidence of a completed economy. `economy.md` should define
Gold sinks before rewards are finalized; `balancing.md` should revisit
difficulty costs/rewards using playtest evidence.

### Phase 7 — Full UI & UX Polish

Phase 7 can refine the result presentation, animations, content art, loading
states, and accessibility after the functional Phase 4 loop is stable. It is
visual completion, not authorization to introduce new Adventure mechanics.

## Playtest questions

Test the intended player experience, not only whether values change:

1. After seeing the home dashboard, do players understand that walking earns
   Energy and Energy starts Adventures?
2. Before committing, can players accurately state what their chosen
   difficulty costs and guarantees?
3. Does Easy feel accessible after realistic everyday step totals?
4. Do Normal and Hard feel like meaningful choices rather than cosmetic tabs?
5. Is the higher-difficulty efficiency motivating without making Easy feel
   wasteful?
6. Does the immediate result make the Energy spend feel rewarding and clear?
7. When Energy is insufficient, does the message explain the next useful
   action without making the player feel punished?
8. Do level-ups and EXP overflow remain understandable after multiple
   Adventures?
9. Does repeating Greenwood Trail become dull before players have enough
   Energy to make the loop satisfying?
10. Are players asking for timed expeditions or risk, or do they first need
    more trails and clearer progression goals?

Record actual Energy earned, Adventure selections, failed starts, time between
attempts, and player feedback before changing values. Those observations are
inputs to `balancing.md`, not a reason to add systems mid-MVP.

## Phase 4 success criteria

Phase 4 is complete when a player can:

- Earn Energy through the existing steps-to-Energy loop.
- Open Greenwood Trail, select Easy, Normal, or Hard, and see that selection's
  genuine cost and rewards.
- Start a valid Adventure and receive exactly the displayed EXP and Gold.
- See a dedicated, understandable result including any level-up outcome.
- Continue playing with the updated player state visible in the app.
- Attempt an Adventure without enough Energy and receive no accidental reward
  or deduction.
- Repeat the flow without duplicate resolution or reward application.

It is not a Phase 4 requirement to ship multiple Adventures, loot, combat,
timers, cloud synchronization, quests, or final production polish.

## Design summary

```text
Greenwood Trail
→ choose a difficulty with a real cost/reward trade-off
→ spend Energy once
→ resolve immediately and deterministically
→ receive EXP + Gold + clear feedback
```

This is the smallest Adventure system that makes Everstride's existing
walk-to-Energy progression loop feel like a game while preserving room for
quests, economy, cloud sync, and richer Adventure content later.
