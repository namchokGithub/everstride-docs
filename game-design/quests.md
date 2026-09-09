# Daily Quests

## Status

**Phase 5 MVP game-design specification.**

This document defines Everstride’s first Daily Quest system: small, optional
goals that acknowledge normal activity and Adventure play. It is a game-design
specification, not an implementation plan. Storage, providers, UI composition,
database migrations, and tests belong in the Phase 5 implementation plan.

## Current baseline

The Quest design starts from facts already implemented:

- Health Connect Steps sync locally and safely; 100 newly rewardable Steps
  become 1 Energy, with no duplicate rewards or lost remainder.
- Player state persists locally: Level, EXP, Energy, Gold, and pending Steps.
- Greenwood Trail is the one playable Adventure.
- Greenwood Trail resolves immediately and deterministically. Easy, Normal,
  and Hard each use a real Energy cost and fixed EXP/Gold reward.
- Adventure has a dedicated result screen, insufficient-Energy handling, and
  duplicate-start protection.
- A placeholder QuestRepository interface exists, but no Quest entity,
  persistence, assignment, progress, claiming, history, or Quest UI exists.

Nothing in this document means that Daily Quests are already implemented.

## Purpose and principles

Daily Quests answer a gentle player question: **“What can I do today?”**

They extend the core loop without replacing it:

```text
Walk
→ earn Energy
→ Adventure
→ gain progression

Walk and Adventure
→ Daily Quest progress
→ small optional reward
```

The system must follow these principles:

- Reward activity, never punish rest or a missed day.
- Track existing meaningful actions; do not invent artificial chores.
- Make objective, progress, target, reward, and state easy to understand.
- Keep the MVP low-pressure and viable for a broad range of activity levels.
- Grant each Quest reward exactly once.
- Remain local and offline-first in Phase 5.

## Phase 5 MVP scope

### Included

- A fixed set of three Quests for the current local calendar day.
- Step-progress Quests based on the day’s total recorded Steps.
- An Adventure-completion Quest based on successful Adventure resolution.
- Fixed EXP and Gold rewards.
- States for in progress, claimable, claimed, and expired.
- A manual Claim action that applies a reward exactly once.
- Local persistence and app-restart recovery.
- Lazy day rollover: a new day is created on first access, with no background
  timer required.
- A lightweight Quest presentation in the existing Journal or Home experience.

### Excluded

- Streaks, missed-day penalties, catch-up purchases, or paid refreshes.
- Random assignments, rerolls, skips, weighted pools, or difficulty gating.
- Story/chain quests, weekly/seasonal quests, achievements, or social goals.
- Items, loot, crafting materials, equipment, premium currency, or Gold sinks.
- Notifications, countdown timers, background jobs, server time, cloud sync,
  cross-device merge, analytics, or anti-cheat authority.

## Quest model

Separate a static **Quest definition** from a dated **Daily Quest instance**.
Definitions state what a Quest means. Instances retain a player’s state for one
local day.

### Quest definition

| Field          | Meaning                              |
| -------------- | ------------------------------------ |
| ID             | Stable template identifier.          |
| Title          | Player-facing objective name.        |
| Description    | Plain explanation of what counts.    |
| Objective type | The tracked event or measure.        |
| Target         | Amount needed to complete it.        |
| Rewards        | Fixed EXP and Gold granted by claim. |
| Sort order     | Stable display order.                |
| Active         | Future content-control flag.         |

### Daily Quest instance

| Field               | Meaning                                          |
| ------------------- | ------------------------------------------------ |
| Instance ID         | Stable identity for this definition on one date. |
| Quest ID            | The underlying definition.                       |
| Local date          | Local calendar date (YYYY-MM-DD).                |
| Progress            | Current progress, bounded to target for display. |
| Status              | In progress, claimable, claimed, or expired.     |
| Claimed at          | Local timestamp after a successful claim.        |
| Reward snapshot     | Exact rewards promised to this instance.         |
| Definition snapshot | Objective and target retained with the instance. |

An existing dated instance’s target and reward must not silently change after
the player begins it.

## Objective types and progress sources

The MVP supports exactly two objective types:

| Type                  | Source of truth                                 | What counts                             |
| --------------------- | ----------------------------------------------- | --------------------------------------- |
| Daily Steps           | Local health-sync record for the instance date. | The day’s total recorded Steps.         |
| Adventure completions | Successful, once-resolved Adventure result.     | Each completed Greenwood Trail attempt. |

### Step objectives

Step Quest progress uses **total Steps for the day**, not newly rewardable
Steps, Energy, or a separate Step pool. The same real-world Steps may earn
Energy and advance Quest progress; neither system consumes them.

```text
Today’s total Steps: 3,200
Walk 3,000 Steps: 3,000 / 3,000 → claimable
Energy conversion: continues normally from newly rewardable Steps
```

Before claim, a later health correction may lower displayed Quest progress to
the latest valid total. After claim, a later correction never revokes reward or
creates negative player state.

### Adventure objectives

Progress occurs only after a successful Adventure resolution has fully applied
its cost and rewards once. Insufficient Energy, resolution failure, and
duplicate input do not advance a Quest. Easy, Normal, and Hard each count as
one completed Adventure in the MVP.

## Initial Daily Quest set

Every MVP day uses the same three Quests. Fixed content is easier to explain
and validate before introducing variety.

| ID                | Quest           |            Objective |          Reward | Role                                 |
| ----------------- | --------------- | -------------------: | --------------: | ------------------------------------ |
| daily_steps_1000  | First Steps     |     Walk 1,000 Steps |  10 EXP, 5 Gold | Welcoming milestone.                 |
| daily_steps_3000  | Wanderer’s Path |     Walk 3,000 Steps | 20 EXP, 10 Gold | Moderate everyday goal.              |
| daily_adventure_1 | Trailbound      | Complete 1 Adventure | 15 EXP, 10 Gold | Closes the Energy-to-Adventure loop. |

The Quests are independent. The two Step Quests intentionally overlap:
reaching 3,000 Steps completes both. This is a layered reward structure, not a
choice the player must optimize. Targets and rewards are tunable values, not
health prescriptions.

## Daily lifecycle

### Day identity and creation

Phase 5 uses the device’s local calendar day. On the first Quest read or
relevant progress event for a date, ensure that date has the fixed Quest set.
The player need not open the app at midnight, and no background task is needed.

Phase 5 does not claim protection against deliberate device-clock changes. A
server-authoritative day boundary is deferred to Phase 6 or a later trust
design.

### Progress and completion

- A successful health sync refreshes current-day Step Quest progress.
- A successful Adventure resolution refreshes current-day Adventure progress.
- Reaching a target makes a Quest **claimable**; it does not reward
  automatically.
- The player may claim a completed Quest in any order.
- Claiming marks only that instance **claimed** and records the success.

### Rollover

On first access after the local date changes:

- Create the new date’s fixed Quest set.
- Mark unclaimed prior-day Quests **expired** and non-claimable.
- Keep previously claimed rewards permanently retained.
- Do not backfill missed days.
- Do not create debt, streak loss, or a penalty for incomplete Quests.

Use neutral language such as “Today’s Quests are ready,” not language that
shames a player for yesterday’s expired Quests.

## Rewards and claim behavior

Quest rewards are a small bonus. They never cost Energy or consume Steps,
Adventure completions, EXP, Gold, or future items.

```text
Target reached
→ Quest becomes claimable
→ player selects Claim
→ validate current, complete, unclaimed instance
→ atomically grant fixed EXP + Gold and mark claimed
→ show clear acknowledgement
```

Quest EXP follows the existing player progression rules:

- EXP required for the next Level is level × 100.
- EXP overflow carries across level-ups.
- A Quest claim that levels up the player must make that outcome clear.

The reward acknowledgement may be compact, but a claimed Quest must not retain
an active Claim action.

## Failure and edge states

| State                     | Player-facing behavior                                                      | Required state outcome                   |
| ------------------------- | --------------------------------------------------------------------------- | ---------------------------------------- |
| Health access unavailable | Explain that Step Quests cannot update yet; Adventure Quest remains usable. | Do not invent Step progress.             |
| No new health data        | Retain latest valid progress.                                               | No duplicate reward.                     |
| Insufficient Energy       | Adventure cannot start; Trailbound does not progress.                       | No Adventure or Quest change.            |
| Already claimed           | Show claimed/rewarded state.                                                | A second claim grants nothing.           |
| Expired                   | Show unavailable without punitive language.                                 | Cannot be claimed or reactivated.        |
| Storage/claim error       | Explain claim was not completed; allow safe retry.                          | No partial reward or partial claim flag. |
| Repeated Claim input      | Treat as one claim.                                                         | At most one reward application.          |
| Date change               | Load correct daily set and retain prior state.                              | No duplicate dated instance.             |

## Invariants

These are player-trust and correctness rules, not balance knobs:

- A Quest definition has at most one Daily Quest instance per local date.
- A Quest instance grants its reward at most once.
- Reward grant and claimed state change together; no partial outcome remains.
- Claiming a Quest never spends Energy or consumes Steps/Adventure completions.
- Step progress is derived from the instance date’s actual total Steps.
- Adventure progress derives only from a successful, once-resolved completion.
- Existing Quest target and reward snapshots stay stable.
- Claimed or expired instances never become claimable again.
- Quest rewards preserve existing player invariants: Energy never goes negative
  and EXP overflow is retained.
- A Quest failure cannot corrupt health sync, Energy conversion, or Adventure
  resolution.

## Tunable values

| Value                  | Initial MVP value                  |
| ---------------------- | ---------------------------------- |
| Quests per day         | 3 fixed Quests                     |
| Low Step target        | 1,000 Steps                        |
| Medium Step target     | 3,000 Steps                        |
| Adventure target       | 1 completion                       |
| First Steps reward     | 10 EXP, 5 Gold                     |
| Wanderer’s Path reward | 20 EXP, 10 Gold                    |
| Trailbound reward      | 15 EXP, 10 Gold                    |
| Step structure         | Overlapping milestones             |
| Day boundary           | Device local date                  |
| Completion behavior    | Manual claim; no penalty on expiry |

Change these only after observing player behavior. They must not pressure users
toward unhealthy activity or flood the unfinished Gold economy.

## Deferred systems

Do not add these opportunistically in Phase 5:

- Random pools, rerolls, skip tokens, difficulty-specific Quest requirements,
  or premium refreshes.
- Streaks, battle passes, weekly/seasonal layers, achievements, leaderboards,
  social/guild goals, or story chains.
- Items, loot, equipment, crafting materials, cosmetics, or Gold sinks.
- Auto-claim, notifications, timers, and background expiration processing.
- Cloud sync, server time, cross-device conflict rules, and clock-change
  authority.
- Permanent Journal history. Its requirements need a separate design pass.

## Playtest questions

1. Can players explain how Steps, Energy, Adventures, and Quests relate?
2. Do 1,000 and 3,000 Steps feel encouraging rather than mandatory or trivial?
3. Do overlapping Step Quests feel satisfying rather than confusing?
4. Does Trailbound motivate spending Energy without excessive pressure to walk?
5. Are rewards noticeable without eclipsing Adventure rewards or the level curve?
6. Do players understand why a complete Quest must still be claimed?
7. Does a rest day and rollover feel neutral and understandable?
8. When health access is unavailable, is it clear which progress is paused?
9. Is claimed state clear enough to prevent repeated claim attempts?
10. Does the fixed set remain engaging long enough to validate the system?

Record completion/claim/expiry rates, average Step totals, Adventure completion
rates, Quest reward share of daily EXP/Gold, and player feedback. Use that
evidence in balancing.md; do not compensate with unplanned retention mechanics.

## Phase 5 success criteria

Phase 5 is complete when a player can:

- See today’s three Quests with objective, progress, target, reward, and state.
- Sync Steps and update Step Quest progress without changing Energy rules.
- Complete Greenwood Trail and advance Trailbound exactly once.
- Claim a completed Quest once and receive exactly its displayed EXP and Gold,
  including correct level-up behavior.
- Restart the app and retain current progress and claimed state.
- Encounter insufficient Energy, repeated input, health unavailability, or a
  new local day without accidental progress or duplicate rewards.
- Return after a rest day without losing previously earned progression or being
  penalized.

Phase 5 does not require random Quests, items, economy systems, story content,
notifications, cloud sync, or final visual polish.

## Handoff to later phases

- **Economy and balancing:** Define Gold sinks before Quest rewards are final.
  Revisit targets, rewards, overlap, and variety with real playtest data.
- **Supabase:** Decide whether Quest instances, claims, and local-date rules
  sync across devices; define conflict handling and authoritative time first.
- **Journal and content:** Add Quest history, new objective types, narrative,
  weekly, or seasonal layers only after their event sources and player impact
  are designed.
- **Full UI/UX polish:** Improve loading, empty, expired, claimed, reward, and
  accessibility states without using polish to smuggle in new mechanics.

## Design summary

```text
Today’s optional Quests
→ track normal Steps and completed Adventures
→ become claimable at their target
→ grant a small fixed reward exactly once
→ reset cleanly tomorrow, with no punishment for rest
```

Daily Quests should make existing healthy behavior feel acknowledged—not turn
Everstride into a checklist that punishes players for having a life.
