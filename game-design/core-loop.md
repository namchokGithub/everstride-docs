# Everstride — Core Game Loop

> **Document type:** Game Design Specification
> **Status:** MVP / Experimental
> **Current implementation phase:** Phase 3 — Player Progression MVP
> **Last updated:** 2026-09-08
> **Scope:** Real-world activity → Energy → Adventure → Rewards → Progression

---

## 1. Purpose

This document defines the current **core gameplay loop** of Everstride.

It explains how real-world activity becomes in-game progress and how the main systems should connect from the player's point of view.

This document focuses on **gameplay flow and design intent**.

Implementation details such as Flutter, Riverpod, Drift, Supabase, repositories, controllers, and database migrations belong in technical or implementation documents.

---

## 2. Core Idea

Everstride is a health-powered RPG where everyday real-world activity becomes in-game progress.

The central idea is:

> **Walk in real life, gain the resources needed to continue your adventure.**

The game should feel like an RPG first, with health activity acting as the input that powers progression.

The player should not feel like they are operating a fitness dashboard with RPG decorations.

Instead, walking should naturally support the fantasy progression loop.

---

## 3. Primary Core Loop

The MVP core loop is:

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
Player grows stronger / levels up
        ↓
Player returns to Adventure
```

In compact form:

```text
Walk
→ Energy
→ Adventure
→ Rewards
→ Progression
→ Repeat
```

---

## 4. Loop Goals

The core loop should satisfy the following goals:

- Real-world movement should have a clear in-game purpose.
- Progress should remain meaningful even when the player walks only a moderate amount.
- The player should understand what their steps become.
- Frequent syncing should not reduce rewards.
- The same activity should never be rewarded twice.
- The loop should work without requiring constant internet access.
- The MVP should be simple enough to test before adding combat, equipment, or complex economy systems.

---

## 5. Real-World Activity Layer

The first part of the loop comes from outside the game.

```text
Player walks
    ↓
Health Connect
    ↓
Everstride Health Sync
```

For the MVP, the primary activity input is:

```text
Steps
```

The game should not depend on Samsung Health directly at the gameplay level.

Health Connect acts as the normalized source of activity data.

Conceptually:

```text
Samsung Health / compatible health source
                ↓
          Health Connect
                ↓
            Everstride
```

The core game loop only needs to understand:

```text
newly rewardable Steps
```

---

## 6. Rewardable Steps

Everstride must distinguish between:

```text
Total Steps
```

and:

```text
Newly Rewardable Steps
```

Example:

```text
Health Connect total today: 6,800
Already rewarded:           5,000

New rewardable Steps:       1,800
```

Only those `1,800` steps continue into the progression loop.

### Core Rule

```text
One real-world Step must never produce progression more than once.
```

This is a core-loop invariant.

---

## 7. Steps → Energy

Steps do not directly grant EXP, Gold, Items, or Level.

They first convert into **Energy**.

Current MVP rule:

```text
100 Steps = 1 Energy
```

This creates a useful separation:

```text
Real-world activity
        ↓
     Energy
        ↓
Gameplay choices
```

Instead of:

```text
Steps
→ direct EXP
```

This is intentional.

Energy gives the player agency over how and when their activity is converted into game progress.

---

## 8. Why Energy Exists

Energy serves as the bridge between health activity and RPG gameplay.

It allows Everstride to separate:

```text
How much the player moved
```

from:

```text
What the player chooses to do in the game
```

Without Energy:

```text
Walk
→ automatic rewards
```

With Energy:

```text
Walk
→ gain Energy
→ choose an Adventure
→ gain rewards
```

This gives the player a stronger sense of interaction and ownership.

---

## 9. Step Remainder

Incomplete Step-to-Energy progress must be preserved.

Example:

```text
250 Steps
```

becomes:

```text
2 Energy
50 Pending Steps
```

Later:

```text
+50 Steps
```

becomes:

```text
1 additional Energy
```

The player should never lose progress because they synced at an inconvenient time.

### Core Invariant

```text
Frequent small syncs must produce the same progression
as one equivalent combined sync.
```

---

## 10. Energy → Adventure

The player spends Energy to participate in Adventures.

For Phase 3, the Adventure is intentionally simple and temporary.

Current placeholder:

```text
Adventure Cost:
10 Energy
```

The purpose of this action is to validate the full loop:

```text
Walk
→ gain Energy
→ spend Energy
→ receive progression rewards
```

The real Adventure system is deferred to Phase 4.

---

## 11. Adventure → Rewards

Current Phase 3 placeholder reward:

```text
+25 EXP
+10 Gold
```

So the MVP loop currently resolves as:

```text
1,000 Steps
    ↓
10 Energy
    ↓
1 Temporary Adventure
    ↓
25 EXP
10 Gold
```

This relationship is useful for early testing but is **not final balance**.

---

## 12. Rewards → Progression

Adventure rewards currently feed two systems:

```text
EXP
Gold
```

### EXP

EXP increases Player Level.

Current threshold:

```text
EXP required for next Level = current Level × 100
```

### Gold

Gold is introduced as a general-purpose future currency.

In Phase 3, Gold is earned but not yet spent.

---

## 13. Full MVP Example

A new player begins with:

```text
Level:  1
EXP:    0
Energy: 0
Gold:   0
```

They walk:

```text
2,350 newly rewardable Steps
```

Conversion:

```text
2,350 Steps
→ 23 Energy
→ 50 Pending Steps
```

The player uses Energy for two Adventures:

```text
2 × 10 Energy
→ 20 Energy spent
```

Rewards:

```text
2 × 25 EXP
→ 50 EXP

2 × 10 Gold
→ 20 Gold
```

Result:

```text
Level:        1
EXP:          50 / 100
Energy:       3
Gold:         20
PendingSteps: 50
```

The player then returns to real-world activity.

---

## 14. Session Loop

A typical short session should feel like:

```text
Open Everstride
      ↓
See today's Steps
      ↓
Sync activity
      ↓
Receive new Energy
      ↓
See available Adventure
      ↓
Spend Energy
      ↓
Receive rewards
      ↓
See progression update
      ↓
Close app
```

The loop should be understandable within seconds.

---

## 15. Daily Loop

The broader daily loop is intended to become:

```text
Walk during the day
      ↓
Open Everstride
      ↓
Sync activity
      ↓
Gain Energy
      ↓
Complete Adventures
      ↓
Progress Daily Quests
      ↓
Gain EXP / Gold / Items
      ↓
Advance Character
```

Daily Quests are not part of Phase 3, but they should reinforce the same activity rather than compete with it.

---

## 16. Long-Term Loop

The long-term RPG loop is expected to evolve toward:

```text
Real-world activity
      ↓
Energy
      ↓
Adventure
      ↓
EXP / Gold / Items
      ↓
Character Growth
      ↓
Unlock stronger Adventures
      ↓
Gain better rewards
      ↓
Build stronger Character
      ↓
Repeat
```

This is the intended progression backbone of Everstride.

---

## 17. Core Loop Layers

The Everstride loop can be thought of in four layers.

### Layer 1 — Real-World Activity

```text
Walking
Exercise
Future health signals
```

Phase 3 uses only Steps.

### Layer 2 — Conversion

```text
Steps
→ Energy
```

This layer protects the game from directly coupling every gameplay system to health data.

### Layer 3 — Gameplay

```text
Energy
→ Adventure
```

This is where the player makes game decisions.

### Layer 4 — Progression

```text
Adventure
→ EXP
→ Gold
→ Future Items
→ Character Growth
```

---

## 18. Core Loop Invariants

The following rules should remain true even if balance values change.

### Health Activity

- A Step must never be rewarded twice.
- Partial Step conversion must never be lost.
- Sync frequency must not change total earned progression for the same underlying activity.

### Energy

- Energy must never become negative.
- Energy should represent activity already earned by the player.
- Spending more Energy than the player owns must fail without side effects.

### Rewards

- Successful Adventures grant their complete reward.
- Failed Adventures must not partially consume or reward resources.
- EXP overflow must be preserved.
- Player progression must persist across app restarts.

### Player Experience

- The player should not need to understand Health Connect internals.
- The player should always understand why Energy increased.
- The player should always understand what an Adventure costs and what it can reward.

---

## 19. Tunable MVP Values

The current loop uses:

| Value                      |       Phase 3 |
| -------------------------- | ------------: |
| Steps per Energy           |           100 |
| Placeholder Adventure Cost |     10 Energy |
| Placeholder EXP Reward     |        25 EXP |
| Placeholder Gold Reward    |       10 Gold |
| EXP Threshold              | `Level × 100` |

These are balance values, not architectural rules.

---

## 20. Player Motivation

The loop should create three types of motivation.

### Immediate

```text
I walked
→ I gained Energy
```

The player sees a direct connection between movement and the game.

### Short-Term

```text
I have enough Energy
→ I can do another Adventure
```

Activity creates a gameplay opportunity.

### Long-Term

```text
Adventure
→ EXP / Gold / Items
→ Character Growth
```

Repeated activity creates persistent RPG progression.

---

## 21. Avoiding Fitness-App Behavior

Everstride should not make the main experience feel like:

```text
Step counter
Calories
Health graph
Statistics dashboard
```

Those may exist in supporting screens.

The primary player-facing experience should emphasize:

```text
Character
Adventure
Energy
Quest
Progression
World
Rewards
```

Health information should support the game rather than dominate the visual hierarchy.

---

## 22. Healthy Engagement Principles

Everstride should encourage movement without creating unhealthy pressure.

The core loop should avoid relying on:

- Punishing missed days.
- Harsh streak loss.
- Extremely high mandatory Step targets.
- Rewards that strongly pressure the player to exceed reasonable activity.
- Losing earned progress because the player did not open the app at the right time.

The game should reward activity, not punish rest.

---

## 23. No Forced Daily Completion

A player who walks less on one day should still be able to make some progress.

The game should not assume:

```text
10,000 Steps every day
```

as a mandatory baseline.

Different players have different activity levels.

Future balancing may use:

```text
small milestone
medium milestone
optional stretch milestone
```

instead of one rigid requirement.

---

## 24. Offline-First Loop

The core loop should remain playable without a network connection where possible.

Intended behavior:

```text
Health Connect
      ↓
Local Sync
      ↓
Energy
      ↓
Adventure
      ↓
EXP / Gold
      ↓
Local Persistence
```

Supabase should not be required for every core-loop interaction during the MVP.

Cloud sync should enhance persistence, not become the foundation of basic gameplay.

---

## 25. Sync Should Not Be Gameplay Friction

Syncing is a technical necessity, not the game's fantasy.

The player should not feel forced to repeatedly manage:

```text
Health permission
Data refresh
Sync state
Database status
```

The intended future experience is:

```text
Open app
→ progression is already up to date
```

Manual sync may remain available for troubleshooting or explicit refresh, but the core game should feel seamless.

---

## 26. Relationship to Daily Quests

Daily Quests should extend the loop:

```text
Walk
├──→ Energy
└──→ Quest Progress
```

Example:

```text
Walk 5,000 Steps
```

may simultaneously:

```text
Generate Energy
Complete "Walk 5,000 Steps"
```

Quest progress should not normally consume Steps.

This allows the same real-world action to support multiple game systems.

---

## 27. Relationship to Adventure System

Phase 4 will expand:

```text
Energy
→ Adventure
```

into a data-driven system.

Potential Adventure properties:

```text
Adventure
├── Area
├── Difficulty
├── Energy Cost
├── Rewards
├── Duration
├── Encounter
└── Loot
```

The core loop should remain unchanged:

```text
Activity
→ Energy
→ Adventure
→ Progression
```

Only the richness of the Adventure layer grows.

---

## 28. Relationship to Character Progression

Future Character systems may include:

```text
Stats
Equipment
Skills
Classes
Talents
Cosmetics
```

These systems should consume or amplify rewards from the core loop.

They should not replace the loop itself.

Example:

```text
Adventure
→ Items
→ Equipment
→ Stronger Character
→ Harder Adventure
```

while Steps continue to supply Energy.

---

## 29. Relationship to Economy

Gold is currently a reward without a sink.

Future economy systems may introduce:

```text
Gold
→ Upgrade Equipment
Gold
→ Buy Items
Gold
→ Craft
Gold
→ Prepare for Adventure
```

Economy design should reinforce the core loop rather than create unrelated grinding.

---

## 30. Relationship to Future Health Inputs

Steps are the MVP input.

Future health-related systems may include:

```text
Exercise
Active Calories
Floors Climbed
Sleep
```

These should not necessarily become alternate versions of Steps.

They may provide distinct bonuses.

Example concepts:

```text
Steps
→ Energy

Exercise
→ Training Bonus

Floors Climbed
→ Tower Progress

Sleep
→ Rest Bonus
```

These are future concepts only.

The core MVP remains Step-driven.

---

## 31. Core Loop Feedback

Every stage of the loop should provide clear feedback.

### When Steps Sync

Show something equivalent to:

```text
+450 Steps synced
+4 Energy
50 Steps toward next Energy
```

### When Adventure Starts

Show:

```text
Energy
23 → 13
```

### When Adventure Completes

Show:

```text
+25 EXP
+10 Gold
```

### When Leveling Up

Show:

```text
Level Up!
Lv. 1 → Lv. 2
```

Feedback should make the cause-and-effect relationship obvious.

---

## 32. Core Loop Failure States

The loop should gracefully handle:

### Health Permission Missing

```text
Cannot read Steps
→ Explain why
→ Offer reconnect / permission action
```

### Health Connect Unavailable

```text
Activity sync unavailable
→ Existing game progress remains accessible
```

### No New Steps

```text
Sync succeeds
→ No duplicate reward
→ Player state unchanged
```

### Insufficient Energy

```text
Adventure cannot start
→ Explain required Energy
→ No state mutation
```

### Persistence Failure

```text
Do not present progression as successfully granted
if the state could not be safely saved.
```

---

## 33. Core Loop Success Criteria

The MVP loop is successful when a player can understand and complete this sequence without explanation:

```text
Walk
↓
Open Everstride
↓
See Steps
↓
Gain Energy
↓
Spend Energy
↓
Receive EXP / Gold
↓
See Level progress
```

The implementation should demonstrate that the entire sequence works reliably end-to-end.

---

## 34. Phase 3 Scope

Phase 3 proves:

```text
Steps
→ Energy
→ Temporary Adventure
→ EXP
→ Gold
→ Level
```

It does **not** need to prove:

```text
Combat
Loot
Equipment
Classes
Skills
World progression
Enemy balance
Crafting
Guilds
Multiplayer
```

These systems should not block completion of the core-loop MVP.

---

## 35. Phase 4 Handoff

Phase 4 should replace the temporary Adventure button with the first real Adventure system.

The expected transition is:

```text
Phase 3

10 Energy
→ Temporary Adventure
→ +25 EXP / +10 Gold
```

to:

```text
Phase 4

Choose Adventure
      ↓
View Energy Cost
      ↓
Start Adventure
      ↓
Resolve Adventure
      ↓
Receive defined rewards
```

The Adventure system should be data-driven so that different Adventures can have different:

```text
Energy Cost
EXP Reward
Gold Reward
Future Loot
Difficulty
```

---

## 36. Future Core Loop Extensions

Potential future loop:

```text
Walk
↓
Energy
↓
Explore Region
↓
Encounter Enemy
↓
Battle
↓
EXP / Gold / Loot
↓
Equipment / Skill Growth
↓
Unlock New Region
↓
Walk More
```

The health-powered foundation remains the same even as gameplay grows.

---

## 37. Explicit Non-Goals

The core-loop MVP does not define:

- Final progression balance.
- Final Step conversion rate.
- Energy cap.
- Energy regeneration.
- Energy purchases.
- Combat mechanics.
- Item rarity.
- Equipment stats.
- Character classes.
- Skill trees.
- Crafting.
- Shops.
- Guilds.
- PvP.
- Leaderboards.
- Trading.
- Marketplace.
- Premium currency.
- Season systems.
- Final anti-cheat architecture.
- Final server authority model.

These should be designed only when the core loop is proven enjoyable and reliable.

---

## 38. Open Design Questions

The following remain intentionally unresolved.

### Activity

- Is `100 Steps = 1 Energy` satisfying in real use?
- Should there be diminishing returns after high Step counts?
- Should different health activities create different resources?

### Energy

- Should Energy have a cap?
- Should Energy expire?
- Should Energy regenerate slowly when the player cannot walk?
- Should multiple game systems consume Energy?

### Adventure

- Should Adventures resolve instantly?
- Should Adventures take time?
- Should combat be automatic or interactive?
- Should Energy cost scale with difficulty?
- Should the player be able to queue Adventures?

### Rewards

- How quickly should players level?
- What is Gold's first meaningful use?
- When should Items enter the loop?
- How should rewards scale with difficulty?

### Retention

- How should Daily Quests reinforce the loop?
- Should there be streaks at all?
- How can consistency be rewarded without punishing rest?

---

## 39. Design Classification

### Core Invariants

These should remain stable unless explicitly redesigned:

```text
No duplicate Step rewards
No lost Step remainder
Steps convert through Energy before core Adventure progression
Insufficient Energy does not mutate progression
EXP overflow is preserved
Progress persists across app restarts
```

### Tunable Values

These are expected to change:

```text
100 Steps = 1 Energy
10 Energy per temporary Adventure
25 EXP reward
10 Gold reward
Level × 100 EXP threshold
```

### Replaceable MVP Components

These exist only to test the loop:

```text
Temporary Adventure button
Fixed Adventure cost
Fixed Adventure rewards
Simple linear EXP curve
```

---

## 40. Current Core Loop Baseline

Until a later design explicitly replaces it, the Everstride MVP core loop is:

```text
REAL WORLD

Walk
  ↓
New Rewardable Steps

CONVERSION

100 Steps
  ↓
1 Energy

GAMEPLAY

10 Energy
  ↓
Temporary Adventure

REWARD

+25 EXP
+10 Gold

PROGRESSION

EXP
  ↓
Level Up
  ↓
Continue Adventure
```

In its shortest form:

> **Walk → Earn Energy → Adventure → Grow**

This is the **Everstride Core Game Loop MVP v0.1 baseline**.
