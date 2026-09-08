# Everstride — Player Progression Design

> **Document type:** Game Design Specification
> **Status:** MVP / Experimental
> **Current implementation phase:** Phase 3 — Player Progression MVP
> **Last updated:** 2026-09-08
> **Scope:** Steps → Energy → Adventure → EXP / Gold → Level progression

---

## 1. Purpose

This document defines the current player progression rules for Everstride.

It describes **what the progression system should do**, not how it is implemented in Flutter, Riverpod, Drift, Supabase, or any other technical layer.

The implementation plan and source code should follow the rules in this document.

The values defined here are intentionally simple for the MVP and should be treated as **tunable game-balance values unless explicitly marked as invariants**.

---

## 2. Progression Philosophy

Everstride should turn ordinary real-world activity into meaningful game progress without requiring extreme activity.

The system should:

- Reward consistent movement.
- Never discard valid player progress.
- Avoid punishing players for syncing frequently.
- Avoid rewarding the same real-world steps more than once.
- Make progression understandable without requiring the player to understand Health Connect.
- Keep the first progression loop simple enough to test and balance.
- Allow future systems such as equipment, quests, classes, adventures, and events to build on top of the same progression foundation.

The MVP intentionally prioritizes correctness and clarity over complex balance.

---

## 3. Core Progression Loop

The current MVP loop is:

```text
Walk in the real world
        ↓
Health Connect records Steps
        ↓
Everstride detects newly rewardable Steps
        ↓
Steps convert into Energy
        ↓
Player spends Energy on an Adventure
        ↓
Adventure grants EXP and Gold
        ↓
EXP increases Player Level
        ↓
Higher progression unlocks future content
```

In Phase 3, the Adventure action is temporary.

Phase 4 will replace the placeholder action with the real Adventure system.

---

## 4. Progression Resources

Phase 3 defines four primary progression values:

| Resource   | Purpose                                          |
| ---------- | ------------------------------------------------ |
| **Steps**  | Real-world activity input                        |
| **Energy** | Play resource generated from Steps               |
| **EXP**    | Character level progression                      |
| **Gold**   | General-purpose progression currency placeholder |

The player also stores `pendingSteps`, which is an internal progression value used to preserve incomplete Step-to-Energy conversion progress.

---

## 5. Player State

The MVP player state contains:

```text
level
exp
energy
gold
pendingSteps
```

Default player state:

```text
Level:        1
EXP:          0
Energy:       0
Gold:         0
PendingSteps: 0
```

### Invariants

- Level must never be lower than `1`.
- EXP must never be negative.
- Energy must never be negative.
- Gold must never be negative.
- Pending Steps must never be negative.
- Player progression must persist across app restarts.

---

## 6. Steps

Steps are the primary real-world input for the MVP.

Everstride does not reward the player's total step count directly.

Instead, it rewards only **newly rewardable steps** that have not previously generated game progress.

Example:

```text
Health Connect total today: 8,500
Already rewarded:           6,000

New rewardable steps:       2,500
```

Only the `2,500` new steps may enter the Step-to-Energy conversion system.

### Invariant — No Duplicate Rewards

The same real-world steps must never generate progression more than once.

Repeated Health Connect syncs with no new rewardable steps must generate:

```text
0 Steps credited
0 Energy gained
```

---

## 7. Step → Energy Conversion

### MVP Conversion Rate

```text
100 rewardable Steps = 1 Energy
```

This value is **tunable** and is not considered final game balance.

### 7.1 Pending Steps

Partial progress toward the next Energy point must never be discarded.

Example:

```text
250 new rewardable Steps
```

Result:

```text
+2 Energy
50 Pending Steps
```

Later:

```text
+50 new rewardable Steps
```

The player now has:

```text
50 previous Pending Steps
+50 new Steps
=100 Steps

→ +1 Energy
→ 0 Pending Steps
```

### 7.2 Repeated Small Syncs

Frequent Health Connect syncs must produce the same result as one combined sync.

Example A:

```text
30 + 30 + 30 + 20 Steps
```

Example B:

```text
110 Steps
```

Both must result in:

```text
+1 Energy
10 Pending Steps
```

This is a **progression invariant**.

### 7.3 Conversion Formula

Conceptually:

```text
totalPendingSteps =
    existingPendingSteps
    + newRewardableSteps

energyGained =
    floor(totalPendingSteps / stepsPerEnergy)

newPendingSteps =
    totalPendingSteps % stepsPerEnergy
```

For the MVP:

```text
stepsPerEnergy = 100
```

---

## 8. Energy

Energy represents activity converted into usable game progression.

The current loop is:

```text
Steps
→ Energy
→ Adventure
```

### MVP Rules

- Energy is earned from newly rewardable Steps.
- Energy is not regenerated passively.
- Energy is not purchased.
- Energy persists across app restarts.
- Energy cannot become negative.
- There is currently **no maximum Energy cap**.

The lack of an Energy cap is an MVP decision, not necessarily final design.

### 8.1 Why No Energy Cap Yet

A cap introduces additional game-design decisions such as:

```text
What happens to Energy earned above the cap?
Is excess Energy lost?
Is it stored elsewhere?
Does walking while capped feel punishing?
Can the cap be upgraded?
```

These questions are intentionally postponed until the core progression loop has been validated.

---

## 9. Adventure — Phase 3 Placeholder

Phase 3 includes a temporary Adventure action so that the progression loop can be tested end-to-end.

This is **not the final Adventure system**.

### Current Cost

```text
10 Energy
```

### Current Reward

```text
+25 EXP
+10 Gold
```

Therefore:

```text
10 Energy
    ↓
Temporary Adventure
    ↓
25 EXP + 10 Gold
```

All three numbers are **tunable MVP values**.

### 9.1 Insufficient Energy

If:

```text
Player Energy < 10
```

the Adventure must fail without modifying progression state.

Example:

```text
Before

Energy: 5
EXP:    25
Gold:   10
```

Player attempts Adventure:

```text
Result:
Not enough Energy
```

After:

```text
Energy: 5
EXP:    25
Gold:   10
```

No partial reward or partial deduction is allowed.

This is a **progression invariant**.

---

## 10. Experience Points

EXP represents long-term character progression.

Completing the temporary Adventure grants:

```text
25 EXP
```

EXP persists across app restarts.

---

## 11. Level Progression

The Phase 3 MVP uses a simple linear level threshold.

### Formula

```text
EXP required for next level = currentLevel × 100
```

Examples:

| Current Level | EXP Required |
| ------------: | -----------: |
|             1 |          100 |
|             2 |          200 |
|             3 |          300 |
|             4 |          400 |
|             5 |          500 |
|            10 |        1,000 |

This curve is **tunable**.

It exists primarily because it is:

- Simple to understand.
- Easy to test.
- Deterministic.
- Easy to replace later.

---

## 12. Level-Up Behavior

When current EXP reaches or exceeds the required threshold:

```text
Level increases by 1
```

and the threshold amount is removed from the current EXP.

Example:

```text
Level 1
EXP 75

Adventure reward:
+25 EXP
```

Result:

```text
75 + 25 = 100

Level 2
EXP 0
```

### 12.1 EXP Overflow

Excess EXP must never be discarded.

Example:

```text
Level 1
EXP 90

Reward:
+25
```

Calculation:

```text
90 + 25 = 115

Level 1 → 2 requires 100
115 - 100 = 15
```

Result:

```text
Level 2
EXP 15
```

This is a **progression invariant**.

### 12.2 Multiple Level-Ups

The progression system must support crossing multiple level thresholds in a single reward operation.

Although the current Phase 3 Adventure reward is small, future systems may grant larger EXP rewards.

Example synthetic state:

```text
Level 1
EXP 280

Reward:
+25 EXP
```

Calculation:

```text
305 total EXP

Level 1 → 2:
305 - 100 = 205

Level 2 → 3:
205 - 200 = 5
```

Result:

```text
Level 3
EXP 5
```

The system must continue processing level-ups until:

```text
current EXP < EXP required for next level
```

---

## 13. Gold

Gold is introduced in Phase 3 as a general-purpose game currency.

Temporary Adventure reward:

```text
+10 Gold
```

### Current MVP Rules

- Gold persists across app restarts.
- Gold cannot become negative.
- Gold currently has no spending system.
- Gold has no maximum cap.

Gold exists now so future progression systems can build on an already-established currency.

Possible future uses include:

```text
Equipment upgrades
Item purchases
Crafting
Adventure preparation
Character development
Cosmetic unlocks
```

These are not part of Phase 3.

---

## 14. Progression Example

A new player starts with:

```text
Level:        1
EXP:          0
Energy:       0
Gold:         0
PendingSteps: 0
```

The player walks:

```text
1,250 newly rewardable Steps
```

Conversion:

```text
1,250 / 100

→ +12 Energy
→ 50 Pending Steps
```

Player state:

```text
Level:        1
EXP:          0
Energy:       12
Gold:         0
PendingSteps: 50
```

The player completes one Adventure:

```text
Cost:
-10 Energy

Reward:
+25 EXP
+10 Gold
```

Result:

```text
Level:        1
EXP:          25
Energy:       2
Gold:         10
PendingSteps: 50
```

Later, the player walks another:

```text
950 newly rewardable Steps
```

Calculation:

```text
50 Pending
+950 Steps
=1,000

→ +10 Energy
→ 0 Pending
```

Player now has:

```text
Energy: 12
```

The player can continue the progression loop.

---

## 15. Progression Invariants

The following rules should remain true even if balance values change.

### Health / Steps

- A real-world Step must never be rewarded twice.
- Repeated syncs without new Steps must not generate additional Energy.
- Partial Step conversion progress must never be lost.
- Frequent small syncs and one combined sync must yield equivalent progression.

### Player Resources

- Energy must never become negative.
- EXP must never become negative.
- Gold must never become negative.
- Pending Steps must never become negative.
- Player Level must always be at least 1.

### Adventure

- Insufficient Energy must not mutate player state.
- Energy deduction and Adventure rewards should behave as one logical progression operation.

### Leveling

- EXP overflow must be preserved.
- Multiple level-ups from a single reward must be supported.
- Level-up calculations must be deterministic.

### Persistence

- Player progression must survive app restart.
- Existing local player data must remain valid across database migrations.

---

## 16. Tunable MVP Values

The following values should be easy to change later.

| Value                 |       Phase 3 |
| --------------------- | ------------: |
| Steps per Energy      |           100 |
| Adventure Energy Cost |            10 |
| Adventure EXP Reward  |            25 |
| Adventure Gold Reward |            10 |
| EXP Threshold Formula | `level × 100` |
| Energy Cap            |          None |
| Gold Cap              |          None |

These values should not be treated as final balance.

---

## 17. Balance Configuration

As the game grows, progression numbers should move toward a centralized game-balance configuration rather than being scattered throughout UI or feature code.

Conceptually:

```text
ProgressionBalance
├── stepsPerEnergy
├── adventureEnergyCost
├── adventureExpReward
├── adventureGoldReward
└── expCurve
```

The implementation mechanism may evolve later.

The important design requirement is that **balance values remain adjustable without redesigning the progression architecture**.

---

## 18. Daily Limits

Phase 3 does not define:

```text
Daily Step Reward Cap
Daily Energy Cap
Energy Decay
Energy Expiration
Daily EXP Cap
```

These systems should not be added until player behavior can be observed and the core loop is validated.

A future design may introduce diminishing rewards rather than a hard activity cutoff.

Example concept only:

```text
0–5,000 Steps       Full reward
5,001–10,000        Reduced reward
10,001–15,000       Further reduced reward
15,001+             Small bonus reward
```

This is **not currently part of the progression rules**.

---

## 19. Relationship to Daily Quests

Phase 3 progression and future Daily Quests should remain conceptually separate.

Walking may simultaneously contribute toward:

```text
Steps → Energy

and

Steps → Quest Progress
```

Completing a quest must not consume the Steps used to generate Energy unless a future game design explicitly introduces such a mechanic.

Example:

```text
Player walks 5,000 Steps

Progression:
→ 50 Energy

Daily Quest:
→ Walk 5,000 Steps completed
```

The same activity may support multiple progression systems because they serve different purposes.

---

## 20. Relationship to Health Data

Everstride's progression system should depend on a normalized concept of:

```text
newly rewardable Steps
```

It should not depend directly on Samsung Health or any specific device vendor.

Conceptually:

```text
Samsung Health
      ↓
Health Connect
      ↓
Health Sync
      ↓
New Rewardable Steps
      ↓
Progression System
```

This allows the progression system to remain independent from the health-data source.

---

## 21. Offline Behavior

Core progression should work offline whenever the required Health Connect data is available locally.

The intended model is:

```text
Health Connect
      ↓
Local Health Sync
      ↓
Local Player Progression
      ↓
Drift / SQLite
```

Cloud synchronization is secondary to the local gameplay experience.

Losing internet connectivity should not prevent the player from:

```text
Viewing progression
Using existing Energy
Completing local Adventures
Receiving local EXP / Gold
```

unless a future server-authoritative feature explicitly requires connectivity.

---

## 22. Cloud Progression

Supabase integration is outside the core Phase 3 loop.

When cloud save is added, local progression should remain the immediate source for gameplay, with Supabase used for account-level persistence and synchronization.

Future multiplayer or competitive features may require server authority.

That decision is intentionally deferred.

---

## 23. Anti-Cheat Considerations

Phase 3 is a local MVP and is not designed to provide strong anti-cheat guarantees.

However, the progression model should avoid making future server validation unnecessarily difficult.

Future server-authoritative progression may validate:

```text
Health sync history
Rewarded Step totals
Daily reward limits
Energy issuance
Adventure rewards
Economy changes
```

The current MVP should not prematurely introduce a Go API solely for anti-cheat.

---

## 24. Player-Facing Presentation

Players should not need to understand internal concepts such as:

```text
rewardedSteps
pendingSteps
health sync delta
database state
```

The UI should primarily present:

```text
Today's Steps
Energy
Level
EXP
Gold
Adventure cost
Adventure rewards
```

`pendingSteps` is an internal progression mechanic.

It may eventually be represented visually as progress toward the next Energy point, but that is not required for Phase 3.

Example future presentation:

```text
Energy Progress
50 / 100 Steps
```

---

## 25. MVP Success Criteria

Player Progression MVP is successful when the player can:

1. Walk in the real world.
2. Sync newly rewardable Steps.
3. Receive Energy without losing Step remainder.
4. Sync repeatedly without duplicate rewards.
5. Spend Energy on the temporary Adventure.
6. Receive EXP and Gold.
7. Level up correctly.
8. Preserve EXP overflow.
9. Receive a clear failure when Energy is insufficient.
10. Close and reopen the app without losing progression.

---

## 26. Explicit Non-Goals for Phase 3

The following are intentionally outside this design:

```text
Character classes
Character stats
Equipment
Weapons
Armor
Item rarity
Inventory economy
Skills
Skill trees
Combat calculations
Real-time battles
Enemy stats
Bosses
World map progression
Crafting
Shops
Guilds
Friends
PvP
Leaderboards
Trading
Marketplace
Premium currency
Season pass
Energy regeneration timer
Energy purchases
Final economy balance
```

These should not block completion of the Player Progression MVP.

---

## 27. Phase 4 Handoff

Phase 4 should take ownership of the Adventure system.

The Phase 3 placeholder:

```text
10 Energy
→ Adventure
→ 25 EXP + 10 Gold
```

should evolve into something closer to:

```text
Adventure Definition
├── ID
├── Name
├── Area
├── Energy Cost
├── Difficulty
├── Duration / Resolution Type
├── EXP Reward
├── Gold Reward
└── Future Loot Table
```

Phase 4 should preserve the core resource flow:

```text
Energy
→ Adventure
→ Progression Rewards
```

while replacing the fixed placeholder values with data-driven Adventure definitions.

---

## 28. Open Design Questions

These questions are deliberately unresolved and should be revisited after the MVP loop is playable.

### Energy

- Should Energy have a maximum cap?
- Should excess Energy ever be lost?
- Should Energy regenerate independently of Steps?
- Should Energy be spendable on systems other than Adventures?

### Steps

- Should Step rewards use diminishing returns?
- Should there be a maximum rewardable Step count per day?
- Should exercise-specific activity provide additional bonuses?

### Leveling

- Is `level × 100` too linear for long-term progression?
- Should character Level have a maximum?
- Should Level unlock content or only represent progression?

### Gold

- What should Gold be spent on first?
- Should Gold be the main soft currency?
- Should Gold rewards scale with Adventure difficulty?

### Adventure

- Should Adventures resolve instantly?
- Should they take real-world time?
- Should combat be automatic?
- Should Energy cost scale with difficulty?

These questions should be answered through later Game Design documents rather than by embedding assumptions directly into implementation code.

---

## 29. Design Classification Summary

### Invariants

These should not change without an explicit progression-design decision:

```text
No duplicate Step rewards
No lost Step remainder
No negative progression resources
Insufficient Energy does not mutate state
EXP overflow is preserved
Multiple level-ups are supported
Player progression persists
```

### Tunable Values

These are expected to change during balancing:

```text
100 Steps = 1 Energy
10 Energy per placeholder Adventure
25 EXP per placeholder Adventure
10 Gold per placeholder Adventure
EXP threshold = level × 100
```

### Deferred Systems

These are intentionally postponed:

```text
Energy cap
Daily reward limits
Equipment
Combat
Skills
Economy sinks
Server authority
Anti-cheat enforcement
Multiplayer progression
```

---

## 30. Current Design Baseline

Until a newer progression design explicitly replaces it, Phase 3 uses:

```text
100 newly rewardable Steps
        ↓
1 Energy

10 Energy
        ↓
Temporary Adventure
        ↓
25 EXP
10 Gold

EXP required for next Level
        ↓
current Level × 100
```

This is the **Everstride Player Progression MVP v0.1 baseline**.
