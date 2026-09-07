# Everstride — MVP Development Plan

> **Project:** Everstride  
> **Platform:** Android first  
> **Goal:** Turn real-world activity from Health Connect into RPG progression.  
> **Primary Stack:** Flutter + Health Connect + Drift/SQLite + Supabase

---

## 1. Project Goal

Build an Android-first mobile RPG where real-world walking becomes in-game progression.

Core loop:

```text
Real-world Steps
      ↓
Health Connect
      ↓
Step Sync
      ↓
Energy
      ↓
Adventure / Quest
      ↓
EXP + Gold + Items
      ↓
Character Progression
```

The first milestone is not to build a full RPG.

The first milestone is:

> Read today's steps from Health Connect reliably and convert them into a simple in-game resource.

---

## 2. Tech Stack

### Mobile

- Flutter
- Dart
- Riverpod
- GoRouter
- Dio
- Freezed / json_serializable

### Health

- Android Health Connect
- Samsung Health as the initial health data source
- Health data must be accessed through a `HealthRepository`

### Local Storage

- Drift
- SQLite

Use local storage for:

- Cached health summaries
- Player state
- Game settings
- Quest progress
- Inventory cache
- Health sync checkpoints

### Cloud

- Supabase Auth
- Supabase PostgreSQL
- Supabase Storage
- Supabase Realtime only when actually needed

### Later / Optional

- Firebase Cloud Messaging
- Firebase Crashlytics
- Firebase Analytics
- Flame for battle scenes or sprite-heavy gameplay
- Go API for authoritative game logic

---

## 3. Architecture Principles

Do not call Supabase, Health Connect, or SQLite directly from UI widgets.

Use this flow:

```text
UI
 ↓
Controller / Notifier
 ↓
Use Case / Service
 ↓
Repository
 ↓
Data Source
```

Example:

```text
HomeScreen
   ↓
HomeController
   ↓
SyncHealthUseCase
   ↓
HealthRepository
   ↓
Health Connect
```

Repositories to prepare from the beginning:

```text
HealthRepository
PlayerRepository
QuestRepository
InventoryRepository
AuthRepository
AdventureRepository
```

This allows future migration from direct Supabase access to a Go API without rewriting the UI.

---

## 4. Suggested Project Structure

```text
lib/
├── app/
│   ├── app.dart
│   ├── router.dart
│   └── theme/
│
├── core/
│   ├── constants/
│   ├── database/
│   ├── errors/
│   ├── network/
│   ├── utils/
│   └── widgets/
│
├── features/
│   ├── auth/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── health/
│   │   ├── data/
│   │   ├── domain/
│   │   └── presentation/
│   │
│   ├── player/
│   ├── adventure/
│   ├── quest/
│   ├── inventory/
│   └── settings/
│
├── shared/
│   ├── models/
│   └── widgets/
│
└── main.dart
```

Each feature should preferably follow:

```text
feature/
├── data/
│   ├── datasources/
│   ├── models/
│   └── repositories/
├── domain/
│   ├── entities/
│   ├── repositories/
│   └── usecases/
└── presentation/
    ├── controllers/
    ├── screens/
    └── widgets/
```

Keep the architecture practical. Do not create empty layers/files just to satisfy a pattern.

---

# 5. Development Phases

## Phase 0 — Project Foundation

### Tasks

- [ ] Verify Flutter project builds on Android
- [ ] Set minimum Android version required by Health Connect
- [ ] Add Riverpod
- [ ] Add GoRouter
- [ ] Add Drift + SQLite
- [ ] Add Supabase Flutter SDK
- [ ] Add environment configuration
- [ ] Create base app theme
- [ ] Create error/result handling pattern
- [ ] Create initial repository interfaces

### Expected Result

The app launches with a basic Home screen and has a clean project structure ready for features.

---

## Phase 1 — Health Connect Prototype

### Goal

Successfully read today's walking steps.

### Tasks

- [ ] Detect Health Connect availability
- [ ] Request required permissions
- [ ] Handle permission denied state
- [ ] Read today's steps
- [ ] Display current step count
- [ ] Add manual refresh
- [ ] Handle Health Connect unavailable state
- [ ] Log readable errors during development

### Screen Example

```text
Everstride

Today's Steps

8,432

Health Connect
Connected

[ Sync Now ]
```

### Definition of Done

- Physical Android device can connect to Health Connect
- App can read today's steps
- Permission flow works correctly
- App does not crash when permission is denied
- Step data survives UI refresh/navigation

Do not build RPG mechanics before this milestone is stable.

---

## Phase 2 — Local Health Sync

### Goal

Avoid repeatedly rewarding the same steps.

### Suggested Local Model

```text
health_daily
------------
date
total_steps
rewarded_steps
last_synced_at
```

Example:

```text
Health Connect: 8,500 steps
Already rewarded: 6,000

New eligible steps:
2,500
```

### Tasks

- [ ] Create Drift health tables
- [ ] Store daily Health Connect snapshot
- [ ] Store already-converted steps
- [ ] Calculate delta safely
- [ ] Handle day rollover
- [ ] Handle step count corrections
- [ ] Prevent duplicate rewards

### Important Rule

Never use:

```text
reward = currentSteps
```

Use:

```text
rewardableSteps = max(0, currentSteps - alreadyRewardedSteps)
```

---

## Phase 3 — Player Progression MVP

### Goal

Turn steps into a simple RPG resource.

Initial conversion:

```text
100 steps = 1 Energy
```

Keep this configurable.

### Player Model

```text
Player
------
level
exp
energy
gold
```

### Tasks

- [ ] Create Player entity
- [ ] Create Player local persistence
- [ ] Implement step-to-energy conversion
- [ ] Display Energy
- [ ] Create EXP system
- [ ] Create basic level-up curve
- [ ] Add simple player status screen

### First Game Loop

```text
Walk
 ↓
Steps
 ↓
Energy
 ↓
Spend Energy
 ↓
Gain EXP
```

Do not over-design balancing yet.

---

## Phase 4 — Adventure MVP

### Goal

Give Energy something useful to do.

Start with a simple non-realtime adventure system.

Example:

```text
Forest Path

Energy Cost: 10

Reward:
+25 EXP
+10 Gold

[ Adventure ]
```

### Tasks

- [ ] Create Adventure model
- [ ] Define energy cost
- [ ] Define static rewards
- [ ] Validate sufficient energy
- [ ] Deduct energy
- [ ] Add EXP
- [ ] Add Gold
- [ ] Show reward result
- [ ] Save transaction atomically locally

### Avoid Initially

- Real-time combat
- Complex stats
- Skills
- Element system
- Equipment modifiers
- PvP
- Multiplayer

---

## Phase 5 — Daily Quests

Example:

```text
Daily Quest

Walk 1,000 steps
Completed

Walk 5,000 steps
3,842 / 5,000

Walk 10,000 steps
3,842 / 10,000
```

### Tasks

- [ ] Define daily quest structure
- [ ] Track progress from health data
- [ ] Claim reward flow
- [ ] Prevent duplicate claims
- [ ] Reset quests by local calendar date
- [ ] Add reward chest / EXP / Gold

Keep rewards server-independent for the MVP.

---

## Phase 6 — Supabase Integration

Do this after the local gameplay loop works.

### Supabase Responsibility

Initially use Supabase for:

- Authentication
- Player cloud backup
- User profile
- Basic cloud save
- Optional game configuration

### Suggested Initial Tables

```text
profiles
--------
id
display_name
created_at
updated_at

player_saves
------------
user_id
level
exp
energy
gold
updated_at

health_daily
------------
user_id
date
steps
rewarded_steps
updated_at
```

Later:

```text
inventory
quests
quest_progress
achievements
```

### Tasks

- [ ] Configure Supabase project
- [ ] Add Auth
- [ ] Configure RLS
- [ ] Create profile table
- [ ] Create player save table
- [ ] Sync local player state
- [ ] Define local-first conflict strategy
- [ ] Add logout/login restoration

---

# 6. Offline-First Strategy

The game should continue working without internet.

Preferred flow:

```text
Health Connect
      ↓
Local Drift
      ↓
Game Logic
      ↓
Flutter UI

When online:
      ↓
Sync with Supabase
```

Supabase should not be required every time the player spends Energy or opens Inventory during the MVP.

---

# 7. Health Data Privacy Rules

Only request data that the game actually uses.

Initial permission:

```text
Steps
```

Possible later additions:

```text
Exercise
Active Calories
Floors Climbed
Sleep
```

Do not collect raw health information simply because it is available.

Avoid uploading detailed/raw health data to Supabase unless a feature clearly requires it.

Prefer storing daily summaries.

Example:

```json
{
  "date": "2026-09-07",
  "steps": 8432
}
```

Not:

```text
raw sensor history
heart rate every few seconds
full Samsung Health history
```

---

# 8. Game Balance Rules

Keep conversion rates configurable.

Do not hardcode numbers throughout widgets.

Example:

```dart
class GameBalance {
  static const int stepsPerEnergy = 100;
  static const int maxRewardableStepsPerDay = 30000;
}
```

Potential future reward curve:

```text
0–5,000 steps       100% reward
5,001–10,000         80%
10,001–15,000        50%
15,001+               20%
```

Do not implement this until basic gameplay is stable.

---

# 9. When to Add a Go API

Do **not** add Go API in the first implementation unless needed.

Add it when server authority becomes important.

Typical triggers:

- Anti-cheat
- Leaderboards
- Trading
- Guilds
- Marketplace
- Competitive systems
- Server-controlled events
- Reward validation
- Economy validation
- Premium currency
- Cross-player interactions

Future architecture:

```text
Health Connect
      ↓
Flutter
      ↓
Go API
      ↓
Supabase PostgreSQL
```

When Go API is introduced, migrate repository implementations instead of rewriting UI.

Example:

```text
SupabasePlayerRepository
         ↓
ApiPlayerRepository
```

---

# 10. Initial Screens

Keep the first version small.

## Splash

- App loading
- Local DB initialization
- Health Connect availability check

## Home

Show:

```text
Character Level
EXP
Today's Steps
Energy
Daily Quest Progress
Adventure Button
```

## Adventure

- Adventure list
- Energy cost
- Reward preview
- Start adventure

## Quest

- Daily step quests
- Progress
- Claim reward

## Settings

- Health Connect status
- Permission status
- Sync status
- Supabase login/logout
- Debug information during development

---

# 11. First UI Scope

Target a simple working UI before creating final game art.

Use placeholders for:

- Character
- Monster
- Item
- Background
- World map

Do not block engineering progress on art assets.

---

# 12. Testing Priorities

Write tests first for logic where duplicated rewards would be problematic.

Priority tests:

- [ ] Step delta calculation
- [ ] Duplicate health sync
- [ ] Day rollover
- [ ] Step-to-energy calculation
- [ ] Energy spending
- [ ] EXP / level-up calculation
- [ ] Quest completion
- [ ] Duplicate quest claim

Example:

```text
Initial rewarded steps = 5,000
Health Connect reports = 7,500

Expected new steps = 2,500
```

Sync again:

```text
Health Connect reports = 7,500

Expected new steps = 0
```

---

# 13. Logging

Use structured logging during development.

Important areas:

```text
Health permission
Health query
Health sync
Reward calculation
Database write
Supabase sync
Authentication
```

Do not log sensitive health data unnecessarily.

---

# 14. Codex / Claude Working Rules

When implementing tasks in this repository:

1. Inspect the existing project before making architectural changes.
2. Do not replace established dependencies without a clear reason.
3. Prefer small, reviewable changes.
4. Keep business/game logic outside Flutter widgets.
5. Use repository interfaces for Health Connect, local DB, and Supabase.
6. Do not directly call Supabase from presentation widgets.
7. Do not directly access Health Connect from presentation widgets.
8. Do not introduce Go API yet unless explicitly requested.
9. Do not introduce Flame until a feature clearly benefits from it.
10. Add tests for reward/progression calculations.
11. Handle Android permission denial gracefully.
12. Preserve offline-first behavior.
13. Never store secrets in the repository.
14. Never expose a Supabase service-role key in the Flutter app.
15. Run formatter/analyzer/tests after meaningful changes.

---

# 15. Suggested Implementation Order

Follow this order unless the existing repository requires otherwise:

```text
01. Flutter project foundation
02. Riverpod + GoRouter
03. Drift setup
04. Health Connect availability
05. Health permission
06. Read today's steps
07. Health sync persistence
08. Duplicate reward protection
09. Player state
10. Steps → Energy
11. Basic Home screen
12. Adventure action
13. EXP / Gold
14. Daily quests
15. Supabase setup
16. Auth
17. Cloud save
18. Polish / tests
```

---

# 16. MVP Definition

The MVP is complete when a player can:

1. Install the Android app.
2. Grant Health Connect permission.
3. See today's step count.
4. Convert newly detected steps into Energy.
5. Spend Energy on an Adventure.
6. Receive EXP and Gold.
7. Level up.
8. Complete daily walking quests.
9. Close and reopen the app without losing progress.
10. Optionally sign in and back up progress to Supabase.

Anything beyond this is post-MVP.

---

# 17. Post-MVP Ideas

Only consider these after the core loop feels good:

```text
Character classes
Equipment
Item rarity
Skills
Dungeon
Boss battles
World map
Achievements
Streak system
Season pass
Guild
Friends
Leaderboard
Cosmetics
Pets
Crafting
Flame battle scene
Push notifications
Sleep-based buffs
Exercise-based training
Floors-climbed tower mode
```

---

# Current Priority

The next implementation target should be:

> **Get today's step count from Health Connect on a physical Android device and display it reliably in Flutter.**

Everything else can build on top of that.
