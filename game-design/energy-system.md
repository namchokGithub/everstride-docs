# Everstride — Energy System

> **Document type:** Game Design Specification
> **Status:** MVP / Experimental
> **Current implementation phase:** Phase 3 — Player Progression MVP
> **Last updated:** 2026-09-08
> **Scope:** Step conversion, Energy earning, storage, spending, and future Energy-system decisions

---

## 1. Purpose

This document defines the current Energy system for Everstride.

Energy is the bridge between real-world activity and in-game actions.

The system exists so that walking does not immediately grant all RPG rewards directly. Instead, real-world activity creates a resource that the player can choose how to spend.

This document defines:

- How Energy is earned
- How incomplete Step conversion is preserved
- How Energy is stored
- How Energy is spent
- What happens when Energy is insufficient
- Which Energy rules are fixed invariants
- Which values are temporary MVP balance
- Which Energy features are intentionally deferred

Implementation details belong in technical or implementation documents.

---

## 2. Role of Energy

Energy connects the real-world activity layer to the gameplay layer.

The intended relationship is:

```text
Real-world Steps
      ↓
Energy
      ↓
Adventure / Future Game Actions
      ↓
EXP / Gold / Items / Progression
```

Without Energy:

```text
Steps
→ direct rewards
```

With Energy:

```text
Steps
→ Energy
→ player choice
→ game action
→ rewards
```

This separation is intentional.

Energy allows Everstride to feel more like an RPG and less like a passive step counter.

---

## 3. Current MVP Rule

The Phase 3 conversion rate is:

```text
100 newly rewardable Steps = 1 Energy
```

This is a **tunable balance value**.

It is not considered final.

---

## 4. Newly Rewardable Steps

Energy must only be generated from Steps that have not previously produced progression.

Example:

```text
Health Connect total today: 8,500
Already rewarded:           7,200

Newly rewardable Steps:     1,300
```

Only the `1,300` newly rewardable Steps may enter the Energy conversion system.

### Invariant

```text
The same real-world Steps must never generate Energy more than once.
```

Repeated syncs with no newly rewardable Steps must produce:

```text
0 new Energy
```

---

## 5. Pending Steps

Energy conversion must never discard incomplete progress.

If the player has fewer than the required Steps for another full Energy point, those Steps are stored as `pendingSteps`.

Example:

```text
250 newly rewardable Steps
```

Result:

```text
+2 Energy
50 Pending Steps
```

Later:

```text
+30 Steps
```

Result:

```text
Energy gained: 0
Pending Steps: 80
```

Later:

```text
+20 Steps
```

Result:

```text
80 Pending
+20 New
=100

→ +1 Energy
→ 0 Pending
```

---

## 6. Why Pending Steps Exist

Health synchronization may happen frequently and in small increments.

Without remainder preservation:

```text
30 Steps
30 Steps
30 Steps
30 Steps
```

could incorrectly produce:

```text
0 Energy
```

if each sync were converted independently.

With `pendingSteps`:

```text
30 + 30 + 30 + 30 = 120 Steps
```

Correct result:

```text
+1 Energy
20 Pending Steps
```

### Core Invariant

```text
Multiple small syncs must produce the same Energy result
as one equivalent combined sync.
```

---

## 7. Conversion Formula

Conceptually:

```text
totalPendingSteps =
    existingPendingSteps
    + newlyRewardableSteps

energyGained =
    floor(totalPendingSteps / stepsPerEnergy)

newPendingSteps =
    totalPendingSteps % stepsPerEnergy
```

For Phase 3:

```text
stepsPerEnergy = 100
```

Example:

```text
existingPendingSteps = 70
newlyRewardableSteps = 250

totalPendingSteps = 320

energyGained = 3
newPendingSteps = 20
```

---

## 8. Energy Storage

Energy is persistent player progression.

It must survive:

- App navigation
- App restart
- Device restart
- Temporary lack of network access

The MVP treats Energy as a locally stored resource.

Conceptually:

```text
Health Connect
      ↓
Health Sync
      ↓
Energy Conversion
      ↓
Local Player State
      ↓
Drift / SQLite
```

Cloud synchronization may be added later.

---

## 9. Energy Cap

Phase 3 has:

```text
No maximum Energy cap
```

This is an MVP decision.

It is intentionally temporary.

### Why No Cap Yet

An Energy cap introduces additional design questions:

- What happens to Energy earned above the cap?
- Is overflow lost?
- Is overflow stored separately?
- Does walking while capped feel punishing?
- Can the cap be upgraded?
- Does the player need to open the game frequently to avoid waste?

Those questions are deferred until the core loop is validated through playtesting.

---

## 10. Energy Regeneration

Phase 3 has:

```text
No passive Energy regeneration
```

Energy currently comes only from real-world Steps.

This keeps the relationship simple:

```text
Walk
→ Energy
```

Future versions may consider alternate recovery systems, but they are not part of the MVP.

---

## 11. Energy Expiration

Phase 3 has:

```text
No Energy expiration
```

Earned Energy remains available until spent.

The player should not lose valid progress because:

- They did not open the app that day
- They took a rest day
- They were offline
- They did not spend Energy quickly enough

This supports Everstride's intended healthy-engagement philosophy.

---

## 12. Energy Decay

Phase 3 has:

```text
No Energy decay
```

Energy does not decrease over time.

There is currently no mechanic such as:

```text
-5 Energy per day
```

or:

```text
Energy resets at midnight
```

These mechanics should not be introduced without explicit game-design review.

---

## 13. Energy Purchase

Phase 3 has:

```text
No purchased Energy
```

The current progression identity is based on:

```text
Real-world activity
→ Energy
```

Premium or purchased Energy is outside the MVP scope.

If monetization is considered later, it should not undermine the meaning of real-world movement.

---

## 14. Energy Spending

Energy is currently spent on the temporary Phase 3 Adventure action.

Current placeholder cost:

```text
10 Energy
```

This validates the loop:

```text
Steps
→ Energy
→ Spend Energy
→ Reward
```

The real Adventure system will replace this placeholder in Phase 4.

---

## 15. Spending Invariant

Energy must never become negative.

If:

```text
player.energy < requiredEnergy
```

the action must fail.

Example:

```text
Player Energy: 7
Adventure Cost: 10
```

Result:

```text
Adventure does not start
Energy remains 7
No EXP reward
No Gold reward
```

### Core Rule

```text
Insufficient Energy must not mutate player progression state.
```

---

## 16. Atomic Spending

From a game-design perspective, spending Energy and receiving the resulting reward should behave as one logical action.

A successful action should feel like:

```text
Spend Energy
      +
Receive Reward
```

not:

```text
Spend Energy
      ↓
something fails
      ↓
player loses Energy without reward
```

The implementation should preserve this logical integrity.

---

## 17. Phase 3 Adventure Example

Current placeholder:

```text
Adventure Cost:
10 Energy

Rewards:
25 EXP
10 Gold
```

Example player:

```text
Before

Energy: 23
EXP:    50
Gold:   20
```

After one Adventure:

```text
Energy: 13
EXP:    75
Gold:   30
```

Energy acts as the cost that converts real-world activity into game progression.

---

## 18. Player-Facing Energy Presentation

The player should primarily see:

```text
Energy: 23
```

They should not need to understand internal terms such as:

```text
pendingSteps
rewardedSteps
sync delta
conversion remainder
```

However, `pendingSteps` may later be represented visually.

Example:

```text
Next Energy
████████░░
80 / 100 Steps
```

This can make small amounts of walking feel meaningful even before another full Energy point is earned.

---

## 19. Energy Feedback

When Energy is earned, the relationship should be visible.

Example:

```text
+450 Steps synced
+4 Energy
50 Steps toward next Energy
```

When Energy is spent:

```text
Energy
23 → 13
```

The player should understand why their Energy changed.

---

## 20. Sync Behavior

Energy earning should not depend on how often the player manually syncs.

Example A:

```text
Player walks 500 Steps
Sync once

→ 5 Energy
```

Example B:

```text
Walk 100
Sync
Walk 100
Sync
Walk 100
Sync
Walk 100
Sync
Walk 100
Sync

→ 5 Energy
```

Both must produce equivalent progression.

---

## 21. Day Rollover

The health system may organize Steps by calendar day, but Energy itself is currently persistent and does not reset at midnight.

Example:

```text
Day 1:
Earn 20 Energy
Spend 5

Remaining:
15 Energy
```

Day 2 starts with:

```text
15 Energy
```

New Steps add more Energy normally.

---

## 22. Pending Steps Across Day Boundaries

For the Phase 3 model, `pendingSteps` represent incomplete Step-to-Energy conversion progress and should not be silently discarded.

Example:

```text
End of Day 1:
70 Pending Steps
```

The system should preserve valid progress unless a later design explicitly changes this behavior.

Current baseline:

```text
Pending Steps persist
```

This supports the invariant:

```text
No valid conversion progress is lost.
```

---

## 23. Offline Behavior

Energy earning and spending should work offline where possible.

Expected flow:

```text
Health Connect data available locally
      ↓
Sync
      ↓
Convert Steps
      ↓
Persist Energy locally
      ↓
Spend Energy
```

The player should not require Supabase connectivity simply to:

- View Energy
- Earn Energy from locally available Steps
- Spend existing Energy on local MVP gameplay

---

## 24. Relationship to Supabase

Supabase is not the authority for Phase 3 Energy gameplay.

Later, Supabase may provide:

- Cloud backup
- Multi-device synchronization
- Account restore
- Remote game configuration

But local gameplay should remain responsive.

A future server-authoritative design may change this for competitive systems.

---

## 25. Relationship to Go API

A Go API is intentionally deferred.

It may become useful if Energy becomes part of systems requiring stronger authority, such as:

- Competitive leaderboards
- Trading
- Marketplace
- Premium economy
- Anti-cheat enforcement
- Multiplayer
- Server-controlled events

Phase 3 does not require this.

---

## 26. Relationship to Daily Quests

Energy and Daily Quest progress should be separate outputs from the same activity.

Example:

```text
Walk 5,000 Steps
```

can produce:

```text
50 Energy
```

and also:

```text
Daily Quest:
Walk 5,000 Steps
→ Completed
```

Quest completion should not normally consume the Steps used to create Energy.

---

## 27. Relationship to Future Health Inputs

Steps are the only Energy source in Phase 3.

Future health inputs may or may not grant Energy.

Possible design directions:

```text
Steps
→ Energy

Exercise
→ Bonus Energy

Floors Climbed
→ Special Adventure resource

Sleep
→ Rest Buff
```

These are future possibilities only.

The Energy system should not assume every health metric converts into the same resource.

---

## 28. Relationship to Adventure System

Phase 4 should make Energy costs data-driven.

Instead of:

```text
Every Adventure = 10 Energy
```

future Adventures may have:

```text
Forest Path       5 Energy
Ancient Ruins    10 Energy
Mountain Pass    15 Energy
Boss Expedition  25 Energy
```

The Energy system should support different costs without changing its core rules.

---

## 29. Relationship to Difficulty

Energy cost may eventually communicate commitment or difficulty.

Possible relationship:

```text
Higher Difficulty
→ Higher Energy Cost
→ Higher Potential Reward
```

However, Energy cost should not become the only difficulty mechanic.

Difficulty may later also depend on:

- Character strength
- Equipment
- Enemy stats
- Adventure conditions
- Risk/reward choices

---

## 30. Relationship to Character Progression

Energy is not a character stat.

It is a player resource earned from activity.

Future character systems should not make walking itself irrelevant.

For example, stronger characters may:

```text
Complete harder Adventures
Earn better rewards
Unlock new areas
```

but the real-world activity loop should continue to supply Energy.

---

## 31. Healthy Engagement

Energy design should avoid pressuring the player into unhealthy behavior.

Avoid mechanics that strongly encourage:

- Excessive walking
- Losing all Energy because of inactivity
- Mandatory daily high Step counts
- Opening the app repeatedly to prevent Energy waste
- Punishment for rest days

Everstride should reward movement without turning Energy into a source of anxiety.

---

## 32. Future Daily Limits

Phase 3 has no daily Energy earning cap.

A future version may evaluate:

```text
Daily Step reward limits
Diminishing returns
Soft caps
Bonus milestones
```

If limits are introduced, a soft reduction model may be preferable to an abrupt cutoff.

Concept example only:

```text
0–5,000 Steps
→ Full conversion

5,001–10,000
→ Reduced conversion

10,001+
→ Smaller bonus conversion
```

This is not part of the current system.

---

## 33. Energy Cap Alternatives

If an Energy cap becomes necessary, possible future approaches include:

### Hard Cap

```text
Energy: 100 / 100
```

Simple, but risks wasting movement.

### Overflow Storage

```text
Energy: 100 / 100
Reserve Energy: 25
```

Preserves progress but adds complexity.

### Soft Cap

```text
Energy can exceed the preferred amount
but certain bonuses stop applying.
```

### Expandable Cap

```text
Character / account progression
→ increases Energy capacity
```

No option is currently selected.

---

## 34. Passive Regeneration Alternatives

If passive Energy is introduced later, possible approaches include:

```text
1 Energy every N minutes
```

or:

```text
Small daily baseline Energy
```

or:

```text
Rest-day support Energy
```

Any passive source should complement walking rather than replace the core identity:

```text
Movement powers Adventure.
```

---

## 35. Energy as a Single Resource

Phase 3 uses one Energy type.

This is intentionally simple.

Avoid introducing:

```text
Walking Energy
Battle Energy
Dungeon Energy
Quest Energy
Raid Energy
```

until there is a clear design need.

Multiple stamina currencies can make the game harder to understand and may weaken the connection between real-world activity and gameplay.

---

## 36. Energy Naming

The internal design currently uses:

```text
Energy
```

This is functional but may not be the final player-facing fantasy term.

Future naming possibilities may be explored if they better match Everstride's world.

Examples of naming direction only:

```text
Vitality
Stamina
Journey Energy
Stride
Spirit
Adventure Energy
```

No rename is currently approved.

Technical identifiers should not be changed solely for thematic experimentation.

---

## 37. Failure States

The Energy system should handle the following gracefully.

### No New Steps

```text
Sync
→ 0 newly rewardable Steps
→ 0 Energy gained
```

No error is necessary.

### Below Conversion Threshold

```text
+60 Steps
→ 0 Energy
→ 60 Pending Steps
```

This is successful progress, not failure.

### Insufficient Energy

```text
Adventure cost 10
Player has 6
→ action rejected
→ state unchanged
```

### Health Permission Missing

Energy cannot be newly earned from Steps, but existing Energy remains usable.

### Health Connect Unavailable

Existing progression should remain accessible.

### Persistence Failure

Energy should not be presented as safely credited if the underlying progression state could not be saved reliably.

---

## 38. Energy System Invariants

These rules should remain stable unless explicitly redesigned.

### Earning

- The same Step must never generate Energy twice.
- Pending Step progress must never be lost.
- Sync frequency must not alter total Energy earned for the same underlying activity.
- Newly rewardable Steps are the only Step input to Energy conversion.

### Storage

- Energy must persist across app restarts.
- Energy must never be negative.
- Pending Steps must never be negative.

### Spending

- Energy cannot be spent below zero.
- Insufficient Energy must not mutate progression state.
- A successful spend and its resulting reward should behave as one logical game action.

### Player Experience

- Energy changes should have understandable causes.
- Internal sync mechanics should not dominate player-facing UI.

---

## 39. Tunable MVP Values

| Value                      | Current Phase 3 Rule |
| -------------------------- | -------------------: |
| Steps per Energy           |                  100 |
| Maximum Energy             |                 None |
| Passive Regeneration       |                 None |
| Expiration                 |                 None |
| Decay                      |                 None |
| Purchased Energy           |                 None |
| Placeholder Adventure Cost |            10 Energy |

These are current baseline values, not final balance.

---

## 40. Deferred Decisions

The following are intentionally unresolved:

```text
Maximum Energy
Daily Energy cap
Daily Step conversion cap
Diminishing returns
Passive regeneration
Energy expiration
Energy decay
Energy purchases
Alternate health-data sources
Adventure-specific Energy modifiers
Character-based Energy bonuses
Premium Energy mechanics
Multi-resource stamina systems
```

These should not block the current MVP.

---

## 41. Open Design Questions

### Conversion

- Is `100 Steps = 1 Energy` satisfying during real play?
- Does the player earn Energy too quickly or too slowly?
- Should conversion remain linear?

### Cap

- Does unlimited Energy encourage hoarding?
- Would a cap make activity feel wasted?
- Should a future cap be soft rather than hard?

### Spending

- How many Adventures should a typical day's walking support?
- Should low-cost and high-cost Adventures coexist?
- Should some actions require no Energy?

### Rest Days

- Should the player receive a small non-walking Energy allowance?
- Can the game remain engaging when the player cannot walk?

### Balance

- Should higher daily activity receive diminishing returns?
- Should very high activity provide cosmetic or achievement rewards instead of more Energy?

These questions should be answered through playtesting rather than assumptions.

---

## 42. Playtest Questions

When Phase 3 is playable, observe:

1. How much Energy does a normal day generate?
2. Does `100 Steps = 1 Energy` feel understandable?
3. Does Energy accumulate much faster than it can be spent?
4. Does the player feel motivated to walk a little more for the next Energy point?
5. Is the `pendingSteps` progress worth showing in the UI?
6. Does unlimited Energy create excessive hoarding?
7. Does spending 10 Energy feel meaningful?
8. Does the player understand the relationship between Steps and Energy without explanation?

These observations should inform future balancing.

---

## 43. MVP Success Criteria

The Energy system is successful for Phase 3 when:

1. Newly rewardable Steps convert into Energy.
2. No Step reward is duplicated.
3. Partial conversion progress is preserved.
4. Repeated small syncs and combined syncs produce equivalent results.
5. Energy survives app restart.
6. Energy cannot become negative.
7. The player can spend Energy on the temporary Adventure.
8. Insufficient Energy leaves progression unchanged.
9. Energy changes are visible and understandable.
10. The full `Steps → Energy → Adventure` loop can be tested end-to-end.

---

## 44. Phase 4 Handoff

Phase 4 should keep the Energy earning model stable while expanding how Energy is spent.

Current:

```text
10 Energy
→ Temporary Adventure
```

Phase 4:

```text
Energy
→ Choose Adventure
→ Adventure-specific Cost
→ Resolve
→ Adventure-specific Rewards
```

The Adventure system should consume Energy through a consistent interface rather than implementing its own independent stamina logic.

---

## 45. Current Energy Baseline

Until explicitly replaced by a later game-design decision:

```text
100 newly rewardable Steps
        ↓
1 Energy

Partial Steps
        ↓
Preserved as Pending Steps

Energy
        ↓
Persists until spent

10 Energy
        ↓
Temporary Phase 3 Adventure
```

Current restrictions:

```text
No Energy cap
No passive regeneration
No expiration
No decay
No purchased Energy
```

In short:

> **Move in the real world → Earn Energy → Choose when to use it.**

This is the **Everstride Energy System MVP v0.1 baseline**.
