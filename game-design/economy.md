# Economy System

## Status

**Economy v0.1 game-design specification — post-Phase 5 baseline.**

This document defines the purpose, boundaries, and first design rules for
Everstride’s economy. It turns the currently earned Gold into a deliberate
future resource without pretending that a shop, inventory, items, equipment,
or purchases already exist.

It is game design, not an implementation plan. Persistence, interfaces,
screens, transactions, backend choices, and tests belong in the relevant future
implementation plan.

## Current baseline

The following facts are implemented and constrain this specification:

- Player state persists locally with Level, EXP, Energy, Gold, and pending
  Steps.
- Steps produce Energy. Energy is earned from activity and is not Gold.
- Greenwood Trail is the one playable Adventure with fixed rewards:
  Easy grants 10 Gold, Normal grants 22 Gold, and Hard grants 36 Gold.
- Daily Quests exist as three fixed local Quests:
  First Steps grants 5 Gold, Wanderer’s Path grants 10 Gold, and Trailbound
  grants 10 Gold.
- Adventure and Quest reward operations protect against duplicate grants.
- Gold is visible and earnable, but there is currently no Gold spending
  system, shop, item, inventory, equipment, crafting, trade, or premium
  currency.
- Gameplay is local and offline-first. Supabase integration is not implemented.

Nothing in this document means that Gold has a live use yet.

## Economy purpose

Gold is Everstride’s long-term **soft currency**. It should create choices
around how a player prepares for, personalizes, or improves their RPG journey
without becoming a second source of pressure to walk.

The intended relationship is:

```text
Real-world activity
→ Energy
→ Adventures and Quests
→ EXP + Gold
→ future optional Gold choices
→ more meaningful Adventure decisions
```

Gold must not replace Energy as the bridge from real-world activity to gameplay.
Energy answers “what can I attempt now?” Gold will eventually answer “how do I
want to prepare or customize over time?”

## Economy principles

- **One clear role per resource.** Steps become Energy; EXP advances Level;
  Gold supports future discretionary choices. Avoid letting Gold bypass every
  progression gate.
- **Earned, not required.** Gold should feel like a welcome result of play, not
  a resource that forces unhealthy activity, daily completion, or spending.
- **Meaningful choices over chores.** The first sinks should create understandable
  trade-offs, not repetitive maintenance taxes.
- **No punishment for rest.** No Gold decay, debt, missed-day penalty, or
  mandatory daily purchase.
- **Trustworthy accounting.** A Gold balance must never change silently,
  become negative, or receive/spend the same transaction twice.
- **Simple before broad.** A small number of sources and one well-tested sink
  is better than adding shops, loot, crafting, and premium systems together.
- **Offline-first now.** Local persistence is enough until cross-device and
  anti-cheat requirements are designed.

## Resource map

| Resource         | Role                                      | Current source              | Current sink                        | Transferability     |
| ---------------- | ----------------------------------------- | --------------------------- | ----------------------------------- | ------------------- |
| Steps            | Real-world activity input                 | Health Connect              | None; not a spendable game currency | Not transferable    |
| Energy           | Adventure-attempt resource                | Newly rewardable Steps      | Adventure cost                      | Not transferable    |
| EXP              | Character progression                     | Adventures and Quest claims | Level progression                   | Not transferable    |
| Gold             | Soft currency for future optional choices | Adventures and Quest claims | None yet                            | Not transferable    |
| Items            | Future gameplay or cosmetic objects       | Not implemented             | Not implemented                     | Not designed        |
| Premium currency | Not part of this design                   | Not implemented             | Not implemented                     | Explicitly deferred |

Gold is not purchasable, tradable, convertible into Energy, or convertible into
EXP in the MVP. Those boundaries prevent the economy from undermining the
health-powered core loop.

## Gold sources

Gold is currently granted only by completed normal gameplay:

| Source                   | Gold | Frequency constraint       |
| ------------------------ | ---: | -------------------------- |
| Greenwood Trail — Easy   |   10 | Each successful resolution |
| Greenwood Trail — Normal |   22 | Each successful resolution |
| Greenwood Trail — Hard   |   36 | Each successful resolution |
| First Steps Quest        |    5 | At most once per local day |
| Wanderer’s Path Quest    |   10 | At most once per local day |
| Trailbound Quest         |   10 | At most once per local day |

The fixed Quest set can contribute at most 25 Gold per completed local day.
Adventure Gold is limited indirectly by Energy earned from normal activity.

These values are current rewards, not final economic balance. Economy tuning
must assess the combined income from Adventures and Quests, not either system
in isolation.

## Current state: accumulation without a sink

At present, Gold is intentionally an accumulating balance. This is acceptable
while the core loop is being proven, but it is not a completed economy.

Until a Gold sink is separately designed and implemented:

- Do not display Gold as required for current gameplay.
- Do not gate Greenwood Trail, Quest claims, Energy, or Level progression behind
  Gold.
- Do not add placeholder spend buttons or a shop that cannot fulfill a purchase.
- Do not reduce an existing balance in the name of “balance.”
- Keep earning Gold visible so players learn that it is a future RPG resource.

## First sink direction

The first Gold sink should arrive only alongside the minimum supporting system
it genuinely needs. The preferred direction is **optional Adventure
preparation**: a player spends Gold before an Adventure for a small,
understandable, non-essential benefit.

Possible future examples, not Phase 5 or 6 features:

| Candidate                 | Player choice                                                 | Why it fits                                              | Design dependency                     |
| ------------------------- | ------------------------------------------------------------- | -------------------------------------------------------- | ------------------------------------- |
| Trail supplies            | Spend Gold for a small one-run Adventure convenience or bonus | Connects Gold back to Adventure without replacing Energy | Item/effect model and Adventure rules |
| Cosmetic travel kit       | Spend Gold to change a visual element                         | Adds expression without balance pressure                 | Cosmetic content model                |
| Character utility upgrade | Spend Gold on a permanent, capped quality-of-life option      | Gives long-term goal                                     | Character progression design and caps |

The first implementation should choose **one** direction. It must not introduce
all three, and it must not let a Gold purchase grant raw Steps, Energy, or
unlimited direct EXP.

## Sink requirements

Before a Gold sink is approved, its design must define:

1. What decision the player is making.
2. Its exact Gold price and the expected time needed to earn that amount.
3. What benefit it grants and its duration.
4. Whether the benefit stacks, expires, or has a cap.
5. Whether it can affect Quest progress or Adventure rewards.
6. Whether it is optional for normal advancement.
7. The behavior when purchase/storage resolution fails.
8. How the player can see their balance before and after the purchase.

A sink is invalid if it only removes Gold without adding a clear player benefit,
or if it turns routine play into compulsory upkeep.

## Purchase model for a later phase

When a sink exists, every purchase should follow this conceptual flow:

```text
Player views price and benefit
→ confirms a specific choice
→ validate sufficient Gold and eligibility
→ atomically deduct Gold and grant the benefit
→ record a result the player can understand
```

A purchase must be rejected without side effects when the balance is
insufficient, the product is unavailable, or storage cannot complete safely.

## Economic invariants

These are correctness and trust rules:

- Gold balance is always zero or greater.
- A successful Adventure or Quest grants its displayed Gold exactly once.
- A failed Adventure start or Quest claim grants no Gold.
- A Gold purchase, when introduced, deducts its price and grants its benefit as
  one outcome; no partial state may remain after an error.
- Repeated input must not duplicate an earn, claim, purchase, or benefit.
- The source, amount, and reason for every visible Gold change must be
  explainable to the player.
- Gold never alters total Steps, rewarded Steps, pending Steps, or Energy
  conversion.
- Gold cannot currently buy Energy, Steps, direct EXP, Quest completion, or
  Adventure success.
- Gold is never lost because of a missed day, expiry, rest day, or app restart.
- A balance change must persist before the player is told it succeeded.

## Tunable values

The following are balance values, not permanent laws:

| Value                     | Current or proposed position                                   |
| ------------------------- | -------------------------------------------------------------- |
| Adventure Gold rewards    | Easy 10, Normal 22, Hard 36                                    |
| Daily Quest Gold maximum  | 25 Gold from all three fixed Quests                            |
| Gold balance cap          | No cap currently designed                                      |
| Gold decay                | None                                                           |
| First sink timing         | After its supporting system is designed                        |
| First sink category       | Optional Adventure preparation is preferred, not yet committed |
| Price range               | Undecided; set only from observed earnings                     |
| Premium currency          | None                                                           |
| Trading                   | None                                                           |
| Gold-to-Energy conversion | Not allowed                                                    |

Do not select a price in isolation. A price needs an intended earning horizon,
such as a few ordinary play sessions for a small optional choice versus a
longer goal for a permanent cosmetic or upgrade.

## Inflation and pacing guardrails

Gold has no sink today, so its balance will grow. That is expected while
testing the core loop. When the first sink is proposed, inspect:

- Gold earned per active day from each Adventure difficulty and completed Quests.
- Typical Gold accumulated by low-, moderate-, and high-activity players.
- Whether Quest Gold becomes a dominant reason to play rather than a bonus.
- Whether a price makes players feel encouraged, neutral, or pressured.
- Whether players hoard because no option feels worthwhile.
- Whether the first sink creates a one-time goal or a recurring maintenance
  burden.

Do not solve inflation by adding punitive decay, daily taxes, or random loss.
Adjust sources, prices, optionality, and content cadence only after playtest
evidence.

## Failure and player-facing states

| State                     | Player-facing behavior                                                 | Required result                                      |
| ------------------------- | ---------------------------------------------------------------------- | ---------------------------------------------------- |
| No Gold sink available    | Gold remains visible as future currency without fake controls.         | No deduction.                                        |
| Insufficient Gold         | Explain price and current balance when a future purchase is attempted. | No deduction or benefit.                             |
| Unavailable product       | Explain it cannot be chosen yet.                                       | No deduction or benefit.                             |
| Purchase/storage error    | Say the purchase did not complete and allow a safe retry.              | No partial deduction or benefit.                     |
| Repeated purchase input   | Resolve at most once.                                                  | At most one deduction and benefit.                   |
| Rest day or date rollover | Retain existing Gold.                                                  | No decay or debt.                                    |
| Local data unavailable    | Do not fabricate a balance or successful purchase.                     | Keep last confirmed state or show recoverable error. |

## Deferred systems

The following require separate design and are not authorized by this document:

- Shops, product catalogs, item inventory, consumables, equipment, crafting,
  upgrades, cosmetic ownership, and Gold purchase UI.
- Loot tables, item rarity, random chests, gacha, gambling-like mechanics, or
  duplicate conversion.
- Premium currency, real-money purchases, ads-for-currency, subscriptions,
  battle passes, marketplace, trading, gifting, or player-to-player exchange.
- Gold sinks that bypass Energy, directly buy EXP, auto-complete Quests, or
  guarantee Adventure success.
- Daily tax, upkeep, decay, debt, forced spending, or streak-related penalties.
- Cloud balance authority, cross-device reconciliation, fraud detection, and
  currency recovery policy.

## Playtest questions

1. Do players understand that Gold is different from Energy and EXP?
2. Does earning Gold from Adventures and Quests feel rewarding even before a
   sink exists?
3. How much Gold do low-, typical-, and high-activity players earn each day?
4. Do players perceive Quest rewards as a bonus rather than a mandate?
5. At what balance do players expect Gold to become usable?
6. Which first-sink direction sounds most valuable: preparation, cosmetics, or
   a long-term utility upgrade?
7. Would a small optional Gold spend make Adventure choices more interesting
   without feeling required?
8. Do any proposed prices pressure players toward unhealthy activity?
9. Can players understand every balance change from its result feedback?
10. Does the absence of decay and debt make rest days feel safe?

## Economy success criteria

This document’s immediate success is a clear, shared baseline:

- Gold’s role is distinct from Steps, Energy, and EXP.
- Current Gold sources are documented with no invented sinks.
- The first sink has explicit principles and entry criteria instead of a
  placeholder shop.
- Every future earn/spend operation has atomicity and duplicate-protection
  requirements.
- No economy proposal undermines the health-powered loop or penalizes rest.
- Gold reward values remain clearly marked as tunable before balancing.

A future Gold-sink implementation is successful only when the player can
understand what it costs, why it is useful, and what happened to their balance,
while still progressing normally without purchasing it.

## Handoff to later phases

### Supabase integration

Phase 6 should determine whether Gold balances and transactions synchronize
across devices, how conflicts are resolved, and when a server becomes
authoritative. Local gameplay remains valid until that policy exists; this
document does not grant permission to trust a cloud balance blindly.

### Balancing

Balancing must consolidate Step-to-Energy rate, Adventure rewards, Daily Quest
rewards, player level pacing, and any first sink price. It should use real
playtest data rather than optimize one reward table in isolation.

### Adventure and content expansion

Additional Adventures, difficulty tiers, items, and Adventure preparation may
add new Gold sources or uses only after they define their rewards, costs, and
effect on existing players. More content is not an automatic reason to increase
Gold income.

### Full UI and UX polish

Phase 7 can improve Gold feedback, balance-change presentation, empty states,
and accessibility. It must not create fake shop affordances or new economy
mechanics without a corresponding design decision.

## Design summary

```text
Activity
→ Energy
→ Adventures and Daily Quests
→ EXP + Gold

Gold
→ future optional, understandable player choices
→ never a shortcut that replaces activity or Energy
```

Gold is currently an earned future resource. Its first job is to accumulate
trust; its first sink must earn the player’s interest rather than demand it.

### Trail Supplies earning horizon

- Price: 30 Gold
- Intended cadence: ผู้เล่นควรซื้อได้ประมาณวันละ 1 ครั้ง
  จากการเล่นปกติ ไม่ใช่ทุก Adventure
- Baseline: Daily Quests ครบให้ 25 Gold; การจบ Easy อีก 1 ครั้ง
  ทำให้มี Gold พอซื้อ Supplies ได้
- Trade-off: Easy ที่ใช้ Supplies ได้ +37 EXP / +15 Gold แต่ Gold สุทธิ
  ลด 15; ผู้เล่นเลือกเร่งรางวัลวันนี้ แลกกับการเก็บ Gold เพื่อ run ต่อไป
- Review trigger: ทบทวนราคาเมื่อมีข้อมูลว่าผู้เล่นใช้ Easy/Normal/Hard
  ต่อวันเฉลี่ยเท่าไร
