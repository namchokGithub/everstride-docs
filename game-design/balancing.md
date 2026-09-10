# Balancing

## Status

**Pre-playtest balancing baseline — after Phase 5.**

This document records Everstride’s current numeric economy and progression
relationships, the questions they must answer in playtests, and the rules for
changing them safely. It does not declare the present values final or authorize
an implementation change by itself.

Balancing follows working gameplay. It must not invent new systems such as
items, combat, Energy purchases, timers, or shops to solve a number problem.

## Current playable baseline

The implemented loop is:

```text
Newly rewardable Steps
→ Energy
→ Greenwood Trail
→ EXP + Gold

Total daily Steps + completed Adventure
→ Daily Quest progress
→ optional claimed EXP + Gold
```

Current game content is intentionally small:

- One Adventure: Greenwood Trail.
- Three deterministic difficulties: Easy, Normal, Hard.
- Three fixed Daily Quests.
- No Energy cap, decay, passive regeneration, or purchases.
- No Gold sink, item, equipment, shop, or premium currency.
- No random outcome, failure chance, combat, loot, or timed Adventure.
- Local and offline-first player state.

## Balancing goals

The baseline should make the player feel all of the following:

1. A normal amount of real-world movement creates visible progress.
2. The next Energy point and next Adventure are understandable goals.
3. Easy is welcoming; Normal and Hard are meaningful choices, not cosmetic
   tabs or mandatory optimizations.
4. Quests acknowledge normal play without becoming a mandatory fitness
   checklist.
5. EXP and Gold rewards feel satisfying without racing through the early level
   curve or flooding the future economy.
6. A rest day is safe: no resource loss, debt, streak penalty, or shame.
7. Every reward and cost is explainable from the player’s point of view.

## Current values

### Steps and Energy

| Value                       |           Current baseline | Classification  |
| --------------------------- | -------------------------: | --------------- |
| Steps per Energy            | 100 newly rewardable Steps | Tunable         |
| Energy cap                  |                       None | Tunable         |
| Energy decay                |                       None | Current rule    |
| Passive Energy regeneration |                       None | Current rule    |
| Energy purchase             |              Not available | Design boundary |
| Pending-Step behavior       |        Remainder preserved | Invariant       |

### Adventure rewards

| Difficulty | Energy cost | EXP | Gold | EXP per Energy | Gold per Energy |
| ---------- | ----------: | --: | ---: | -------------: | --------------: |
| Easy       |          10 |  25 |   10 |           2.50 |            1.00 |
| Normal     |          20 |  55 |   22 |           2.75 |            1.10 |
| Hard       |          30 |  90 |   36 |           3.00 |            1.20 |

The higher difficulties intentionally offer a modest efficiency increase. They
must remain optional: an Easy player should still feel that their choice is
valid, not wasteful.

### Progression

| Value                            | Current baseline          | Classification   |
| -------------------------------- | ------------------------- | ---------------- |
| EXP required for next Level      | current Level × 100       | Tunable          |
| EXP overflow                     | carries to the next Level | Invariant        |
| Multiple level-ups in one reward | supported                 | Invariant        |
| Starting Level                   | 1                         | Current baseline |

Examples:

| Transition    | EXP needed |
| ------------- | ---------: |
| Level 1 → 2   |        100 |
| Level 2 → 3   |        200 |
| Level 3 → 4   |        300 |
| Level 10 → 11 |      1,000 |

### Daily Quest rewards

| Quest            |                       Target | EXP | Gold |
| ---------------- | ---------------------------: | --: | ---: |
| First Steps      |            1,000 total Steps |  10 |    5 |
| Wanderer’s Path  |            3,000 total Steps |  20 |   10 |
| Trailbound       |        1 completed Adventure |  15 |   10 |
| All three Quests | 3,000 Steps plus 1 Adventure |  45 |   25 |

Quest rewards are manually claimed, may be earned once per local day, and do
not consume Steps, Energy, or Adventure completions.

## Derived reference scenarios

These scenarios are arithmetic checks, not promises about how players should
move.

### Low-activity session: 1,000 Steps

```text
1,000 newly rewardable Steps
→ 10 Energy
→ one Easy Adventure
→ 25 EXP + 10 Gold

First Steps Quest
→ 10 EXP + 5 Gold

Trailbound Quest
→ 15 EXP + 10 Gold

Total, if all are claimed:
→ 50 EXP + 25 Gold
```

This should feel like meaningful early progress without requiring a long walk.

### Moderate-activity session: 3,000 Steps

```text
3,000 newly rewardable Steps
→ 30 Energy
→ one Hard Adventure
→ 90 EXP + 36 Gold

First Steps + Wanderer’s Path + Trailbound
→ 45 EXP + 25 Gold

Total, if all are claimed:
→ 135 EXP + 61 Gold
```

A new Level 1 player who starts at zero EXP would level to 2 and retain 35 EXP
toward Level 3. This is a deliberate test case: determine whether one moderate
day feels exciting or too fast.

### Same Energy, different difficulty

With 30 Energy:

| Choice            | EXP | Gold | Player trade-off                            |
| ----------------- | --: | ---: | ------------------------------------------- |
| 3 Easy attempts   |  75 |   30 | More separate completions, lower efficiency |
| 1 Normal + 1 Easy |  80 |   32 | Mixed cadence and modest efficiency         |
| 1 Hard attempt    |  90 |   36 | Largest commitment and best efficiency      |

The current model gives Hard a 20% efficiency advantage over Easy. Test whether
that is a compelling optional reward for saving Energy or an excessive pressure
to avoid Easy.

## What is balanced together

Do not tune any one of these values in isolation:

```text
Steps per Energy
+ Adventure Energy cost
+ Adventure EXP and Gold
+ Quest targets and rewards
+ Level curve
+ future Gold sink prices
```

For example, reducing Steps per Energy makes every Adventure and Gold source
more frequent. Increasing Quest rewards changes both level pacing and the
future Gold economy. A Gold price cannot be chosen before knowing typical Gold
earned per active day.

## Invariants

The following must remain true while values change:

- One real-world Step is not rewarded twice.
- Pending Step remainder is preserved.
- Energy never becomes negative.
- An insufficient-Energy Adventure changes no player state.
- A successful Adventure applies its displayed cost and rewards exactly once.
- Quest rewards are claimed at most once per dated Quest instance.
- Failed or repeated Quest claims create no partial result.
- EXP overflow is preserved.
- Gold never becomes negative or disappears through rest, rollover, or app
  restart.
- A player is never required to spend Gold, finish a Quest, or walk a target
  number of Steps to retain earned progress.
- The preview, result, and stored outcome use the same selected reward values.

## Healthy-engagement guardrails

Balance must not optimize raw step count at the expense of player wellbeing.

- Do not treat 10,000 Steps as a mandatory daily baseline.
- Keep the first meaningful Adventure reachable after ordinary movement.
- Do not add a penalty for missing a day, an expired Quest, or unspent Energy.
- Do not use decay, debt, forced spending, or streak loss to solve retention.
- Do not make the highest difficulty the only economically rational choice.
- Do not add energy purchases, direct EXP purchases, or Quest completion
  shortcuts as a response to low engagement.
- Give players with lower mobility a valid way to enjoy the core loop at their
  own pace.

## Core hypotheses to test

| Hypothesis                             | Evidence that supports it                                 | Evidence that challenges it                              |
| -------------------------------------- | --------------------------------------------------------- | -------------------------------------------------------- |
| 100 Steps per Energy is understandable | Players can predict Energy from Steps without explanation | Frequent confusion about what Steps produced             |
| Easy is accessible                     | Most new players can attempt it after ordinary activity   | Many players repeatedly lack 10 Energy                   |
| Difficulty feels like a choice         | Meaningful use across Easy, Normal, and Hard              | Almost all attempts use one tier                         |
| Hard bonus is fair                     | Players save Energy voluntarily and still use Easy        | Players say Easy is a trap or Hard is irrelevant         |
| Daily Quests are optional              | Claims are healthy but missing a Quest feels neutral      | Players feel punished or forced to hit targets           |
| Early level pace is satisfying         | Level-ups feel noticeable but not constant                | Players level too fast or see no progress                |
| Gold reward scale is safe              | Gold has perceived value without anxiety                  | Gold feels pointless or future prices become unreachable |

## Metrics to record

Collect values by player and by local day. Do not collect more personal health
data than the product actually needs.

### Activity and Energy

- Total Steps seen by the app.
- Newly rewardable Steps.
- Energy earned, spent, and ending balance.
- Pending Step remainder.
- Days with no activity or no sync.

### Adventure

- Attempts and successful completions by difficulty.
- Insufficient-Energy start attempts.
- Time between earning Energy and spending it.
- Energy balance before and after attempts.
- Repeated use of one tier versus mixed tier use.

### Quests

- Progress, completion, claim, and expiry rates by Quest.
- Claim delay after completion.
- Percentage of players completing zero, one, two, or three Quests.
- Relationship between Quest completion and normal Adventure use.

### Progression and economy

- Level distribution and EXP earned per active day.
- Number of level-ups per active day.
- Gold earned per active day and current Gold balance distribution.
- Share of daily EXP/Gold from Quests versus Adventures.
- Future: Gold spent, purchase selection, and purchase failure rate.

### Player feedback

Ask simple qualitative questions:

- Was it clear why you got Energy, EXP, and Gold?
- Did you feel encouraged or pressured by today’s Quests?
- Did Easy, Normal, and Hard all look worthwhile?
- Did your level change at a satisfying pace?
- What would you want Gold to do first?

## Measurement windows

Use the following sequence before changing values:

1. **Smoke test:** Verify arithmetic, duplicate protection, persistence, and
   result feedback with internal/manual testers.
2. **Short observation:** Watch first sessions and first three active days.
   Prioritize comprehension and broken expectations over aggregate averages.
3. **Baseline sample:** Gather at least one to two weeks of normal use across
   a range of activity levels before large tuning changes.
4. **Single-variable experiment:** Change one connected value or one clearly
   stated reward relationship at a time.
5. **Review:** Compare behavior, feedback, and healthy-engagement guardrails
   before keeping, reverting, or iterating.

Do not use an activity total alone as proof that balance is good. A player can
walk a lot and still feel confused, pressured, or unrewarded.

## Change policy

Every balance change must record:

- Date and version.
- Exact value before and after.
- Hypothesis being tested.
- Intended player outcome.
- Metrics and feedback reviewed.
- Expected effect on Steps, Energy, Adventures, Quests, EXP, and Gold.
- Rollback condition.

Prefer small, reversible changes. Examples:

| Goal                    | Safer first change                                  | Avoid                        |
| ----------------------- | --------------------------------------------------- | ---------------------------- |
| Easy feels inaccessible | Reduce Easy cost slightly or increase early clarity | Add Energy purchases         |
| Hard is never chosen    | Adjust its reward relationship modestly             | Make Easy objectively bad    |
| Quest feels mandatory   | Lower target or reduce emphasis                     | Add harsh expiry penalties   |
| Leveling feels too fast | Tune one reward source after measurement            | Flatten all rewards blindly  |
| Gold has no meaning     | Design one optional sink first                      | Add many shops/items at once |

## Balance levers

| Lever                  | Primary effect           | Secondary effects                 | Change only after          |
| ---------------------- | ------------------------ | --------------------------------- | -------------------------- |
| Steps per Energy       | Adventure frequency      | EXP/Gold income and Quest cadence | Real activity data         |
| Easy cost/reward       | New-player accessibility | Tier selection                    | First-session feedback     |
| Normal/Hard efficiency | Saving and tier choice   | Daily progression speed           | Tier-use data              |
| Quest targets          | Daily goal reachability  | Completion and pressure           | Completion/expiry feedback |
| Quest rewards          | Claim motivation         | EXP/Gold income                   | Quest contribution data    |
| EXP curve              | Level pacing             | Player motivation and UI feedback | Level distribution         |
| Gold sink price        | Long-term choice         | Inflation and hoarding            | Gold income data           |

## Explicit non-goals

This document does not define:

- A final level cap or long-term endgame curve.
- Combat stats, enemy difficulty, damage, health, or failure chance.
- Items, loot rarity, equipment, crafting, shops, or Gold sink prices.
- Premium currency, real-money purchases, ads-for-rewards, trading, or
  marketplace behavior.
- Energy caps, passive regeneration, expiration, or paid recovery.
- Streaks, battle passes, leaderboards, seasonal systems, or social goals.
- Server authority, anti-cheat, cross-device merging, or clock-change policy.

## Phase handoff

### Phase 6 — Supabase integration

Cloud synchronization should preserve the correctness of balances and rewards.
Before a cloud balance is treated as authoritative, define conflict handling,
transaction identity, offline replay behavior, and recovery from duplicated or
missing outcomes. Balancing values should not be changed merely to compensate
for an unresolved synchronization problem.

### Economy

Gold sinks must be priced from observed Gold income and player goals. The first
sink should be optional and understandable; it must not replace Energy as the
core activity-to-gameplay bridge.

### Adventure and content expansion

When a new Adventure, objective type, or item is designed, add it to the same
reference scenarios before implementation. Its rewards should be compared with
existing Easy, Normal, Hard, and Quest income rather than balanced alone.

### Full UI and UX polish

Polish should make cost, reward, Quest progress, and level feedback clearer.
It must not conceal unfavorable trade-offs or turn optional play into pressure.

## Balancing success criteria

Balancing is ready for its first live iteration when:

- All current sources and values are documented in one place.
- The 1,000-Step and 3,000-Step reference scenarios are reproducible.
- Invariants and healthy-engagement boundaries are explicit.
- The team can name the hypothesis behind every numeric change.
- The app can capture or manually observe enough evidence to answer the core
  hypotheses.
- No new system is introduced solely to hide an unmeasured balance problem.

## Version log

| Version | Date       | Change                        | Reason                                                   |
| ------- | ---------- | ----------------------------- | -------------------------------------------------------- |
| 0.1     | 2026-09-10 | Initial pre-playtest baseline | Phase 5 complete; values recorded before balance changes |

## Design summary

```text
Measure normal play
→ understand activity, Energy, Adventure, Quest, EXP, and Gold together
→ change one tested relationship at a time
→ protect clarity, player trust, and healthy engagement
```
