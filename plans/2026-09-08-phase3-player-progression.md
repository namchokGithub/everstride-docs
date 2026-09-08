# Phase 3 — Player Progression MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Turn steps into a simple RPG resource. Newly-rewardable steps from Phase 2's sync convert to Energy (100 steps = 1 Energy, no remainder ever lost); Energy spends on a temporary placeholder Adventure action that grants EXP/Gold with a basic level-up curve. Makes the full game loop (`Walk → Steps → Energy → Spend Energy → Gain EXP`) testable end-to-end before the real Adventure system (Phase 4) exists.

**Architecture:** `UI (home_page.dart) → PlayerController (Notifier) → CreditEnergyFromStepsUseCase / SpendEnergyForAdventureUseCase → PlayerRepository (dumb CRUD) → AppDatabase (Drift)`. `PlayerController` reactively listens to `healthSyncControllerProvider` (via `ref.listen`) to credit energy whenever a sync completes — Phase 2's code is not modified.

**Tech Stack:** Flutter, Dart 3.13, Riverpod 3, Drift (existing `AppDatabase` from Phase 2, gains a second table + its first schema migration).

**Spec:** `everstride-docs/specs/2026-09-08-phase3-player-progression-design.md` (read this first — it explains _why_ `pendingSteps` exists and why energy-crediting is wired reactively instead of by the UI calling two controllers in sequence).

## Global Constraints

- Never lose a partial steps-to-energy conversion. Bank the remainder in `pendingSteps`; convert from the running total, never from an isolated delta alone.
- `PlayerRepository` is dumb CRUD only (`getPlayer`/`savePlayer`) — no game logic (energy conversion, spending, leveling) belongs there. That logic lives only in the use cases.
- Every repository/use-case method returns `Future<Result<T>>` (`Ok<T>`/`Err<T>`, `lib/core/errors/result.dart`) — no raw exceptions cross a boundary.
- `SpendEnergyForAdventureUseCase` returning `Err` for insufficient energy is an expected outcome, not a bug path — it must not mutate any persisted state when it happens.
- Never call Drift directly from a UI widget — only through a repository/controller.
- Riverpod 3 has no `StateProvider` — use `Notifier`/`NotifierProvider`.
- Log through `lib/core/utils/app_logger.dart` (`AppLogger.debug`/`AppLogger.error`), area tag `'player.state'`.
- **Commit policy for this execution run only:** the user has explicitly authorized `git commit` for this specific subagent-driven run of this plan (overriding `everstride-docs/AGENTS.md`'s normal absolute "never commit" rule, which still applies everywhere else). Each task's implementer commits its own work normally at the end of the task, per the standard subagent-driven-development workflow. **`git push` is never allowed, under any circumstance, for any reason, for this run or any other** — nothing in this plan authorizes pushing to a remote.
- `everstride-docs/AGENTS.md` says not to run `flutter test` unless asked. This plan is an exception by design: writing and running the unit tests below is the point of Tasks 1–3 (TDD), explicitly requested when the spec was approved. Do not run the _entire_ project test suite beyond the files this plan touches without being asked.
- All commands below assume the working directory is `everstride-mobile/`.
- The `everstride.sqlite` file on a developer's device may already exist from testing Phase 2 (`schemaVersion = 1`, only `health_daily`). Adding `Player` requires a real migration (`schemaVersion` bump + `onUpgrade`), not just adding the table to `onCreate` — otherwise existing installs never get the new table and crash with "no such table: player."

---

### Task 1: `Player` table, schema migration, `PlayerRepository`

**Files:**

- Modify: `everstride-mobile/lib/core/database/app_database.dart`
- Create: `everstride-mobile/lib/features/player/domain/repositories/player_repository.dart` (replaces the existing empty marker interface)
- Create: `everstride-mobile/lib/features/player/data/repositories/player_repository_impl.dart`
- Test: `everstride-mobile/test/features/player/data/repositories/player_repository_impl_test.dart`

**Interfaces:**

- Consumes: `AppDatabase`, `appDatabaseProvider` (existing, this task adds the `Player` table to the same file); `Result`/`Ok`/`Err`/`Failure`; `AppLogger`.
- Produces: `PlayerState` value class (fields: `level`, `exp`, `energy`, `gold`, `pendingSteps`, all `int`; static helper `PlayerState.expToNextLevel(int level) => level * 100`; a `copyWith` method); abstract `PlayerRepository` with `Future<Result<PlayerState>> getPlayer()` and `Future<Result<bool>> savePlayer(PlayerState player)`; `PlayerRepositoryImpl` implementing it; Riverpod provider `playerRepositoryProvider` (`Provider<PlayerRepository>`). Tasks 2–4 consume all of the above.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/player/data/repositories/player_repository_impl_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/database/app_database.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/player/data/repositories/player_repository_impl.dart';
import 'package:everstride/features/player/domain/repositories/player_repository.dart';

void main() {
  late AppDatabase database;
  late PlayerRepositoryImpl repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = PlayerRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('getPlayer returns a default state when no row exists', () async {
    final result = await repository.getPlayer();
    final player = (result as Ok<PlayerState>).value;

    expect(player.level, 1);
    expect(player.exp, 0);
    expect(player.energy, 0);
    expect(player.gold, 0);
    expect(player.pendingSteps, 0);
  });

  test('savePlayer then getPlayer round-trips the same values', () async {
    const player = PlayerState(level: 3, exp: 40, energy: 5, gold: 20, pendingSteps: 60);
    final saveResult = await repository.savePlayer(player);
    expect(saveResult, isA<Ok<bool>>());

    final getResult = await repository.getPlayer();
    final loaded = (getResult as Ok<PlayerState>).value;

    expect(loaded.level, 3);
    expect(loaded.exp, 40);
    expect(loaded.energy, 5);
    expect(loaded.gold, 20);
    expect(loaded.pendingSteps, 60);
  });

  test('savePlayer overwrites the existing row', () async {
    await repository.savePlayer(
      const PlayerState(level: 1, exp: 0, energy: 0, gold: 0, pendingSteps: 0),
    );
    await repository.savePlayer(
      const PlayerState(level: 2, exp: 10, energy: 5, gold: 30, pendingSteps: 15),
    );

    final result = await repository.getPlayer();
    final player = (result as Ok<PlayerState>).value;

    expect(player.level, 2);
    expect(player.exp, 10);
    expect(player.energy, 5);
    expect(player.gold, 30);
    expect(player.pendingSteps, 15);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/player/data/repositories/player_repository_impl_test.dart`
Expected: FAIL — `Player`/`PlayerRepositoryImpl` don't exist yet.

- [ ] **Step 3: Add the `Player` table and migration to `app_database.dart`**

Open `lib/core/database/app_database.dart`. Add this table class (alongside the existing `HealthDaily`):

```dart
class Player extends Table {
  IntColumn get id => integer()();
  IntColumn get level => integer()();
  IntColumn get exp => integer()();
  IntColumn get energy => integer()();
  IntColumn get gold => integer()();
  IntColumn get pendingSteps => integer()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Change `@DriftDatabase(tables: [HealthDaily])` to `@DriftDatabase(tables: [HealthDaily, Player])`.

Change `int get schemaVersion => 1;` to `int get schemaVersion => 2;` and add a `migration` override to the `AppDatabase` class (this is the project's first migration — a developer's existing `everstride.sqlite` from Phase 0 has `schemaVersion = 1` with only `health_daily`; without this, the new `player` table never gets created on that device):

```dart
  @override
  MigrationStrategy get migration => MigrationStrategy(
        onCreate: (m) => m.createAll(),
        onUpgrade: (m, from, to) async {
          if (from < 2) {
            await m.createTable(player);
          }
        },
      );
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/core/database/app_database.g.dart` is regenerated with no errors.

- [ ] **Step 5: Write the repository interface**

```dart
// lib/features/player/domain/repositories/player_repository.dart
import '../../../../core/errors/result.dart';

class PlayerState {
  const PlayerState({
    required this.level,
    required this.exp,
    required this.energy,
    required this.gold,
    required this.pendingSteps,
  });

  final int level;
  final int exp;
  final int energy;
  final int gold;
  final int pendingSteps;

  static int expToNextLevel(int level) => level * 100;

  PlayerState copyWith({
    int? level,
    int? exp,
    int? energy,
    int? gold,
    int? pendingSteps,
  }) {
    return PlayerState(
      level: level ?? this.level,
      exp: exp ?? this.exp,
      energy: energy ?? this.energy,
      gold: gold ?? this.gold,
      pendingSteps: pendingSteps ?? this.pendingSteps,
    );
  }
}

/// Reads/writes the single local player row. Dumb CRUD only — energy
/// conversion, spending, and leveling live in use cases, never here.
abstract class PlayerRepository {
  Future<Result<PlayerState>> getPlayer();
  Future<Result<bool>> savePlayer(PlayerState player);
}
```

- [ ] **Step 6: Write the Drift-backed implementation**

```dart
// lib/features/player/data/repositories/player_repository_impl.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/repositories/player_repository.dart';

class PlayerRepositoryImpl implements PlayerRepository {
  PlayerRepositoryImpl(this._db);

  final AppDatabase _db;

  static const _playerId = 0;

  @override
  Future<Result<PlayerState>> getPlayer() async {
    try {
      final row =
          await (_db.select(_db.player)..where((t) => t.id.equals(_playerId))).getSingleOrNull();
      if (row == null) {
        return const Ok(PlayerState(level: 1, exp: 0, energy: 0, gold: 0, pendingSteps: 0));
      }
      return Ok(PlayerState(
        level: row.level,
        exp: row.exp,
        energy: row.energy,
        gold: row.gold,
        pendingSteps: row.pendingSteps,
      ));
    } catch (e) {
      AppLogger.error('player.state', 'Failed to read player state', e);
      return Err(Failure('Failed to read player state', cause: e));
    }
  }

  @override
  Future<Result<bool>> savePlayer(PlayerState player) async {
    try {
      await _db.into(_db.player).insertOnConflictUpdate(
            PlayerCompanion.insert(
              id: _playerId,
              level: player.level,
              exp: player.exp,
              energy: player.energy,
              gold: player.gold,
              pendingSteps: player.pendingSteps,
            ),
          );
      AppLogger.debug(
        'player.state',
        'Saved player state: level=${player.level}, energy=${player.energy}',
      );
      return const Ok(true);
    } catch (e) {
      AppLogger.error('player.state', 'Failed to save player state', e);
      return Err(Failure('Failed to save player state', cause: e));
    }
  }
}

final playerRepositoryProvider = Provider<PlayerRepository>((ref) {
  return PlayerRepositoryImpl(ref.watch(appDatabaseProvider));
});
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/player/data/repositories/player_repository_impl_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 8: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 9: Stage and commit (no push)**

```bash
git add lib/core/database/app_database.dart lib/core/database/app_database.g.dart lib/features/player/domain/repositories/player_repository.dart lib/features/player/data/repositories/player_repository_impl.dart test/features/player/data/repositories/player_repository_impl_test.dart
git commit -m "feat(player): add Player table, schema migration, PlayerRepository"
```

Do not `git push` — not authorized, for this task or any other.

---

### Task 2: `CreditEnergyFromStepsUseCase`

**Files:**

- Create: `everstride-mobile/lib/features/player/domain/usecases/credit_energy_from_steps_usecase.dart`
- Test: `everstride-mobile/test/features/player/domain/usecases/credit_energy_from_steps_usecase_test.dart`

**Interfaces:**

- Consumes: `PlayerRepository`, `PlayerState` (Task 1); `Result`/`Ok`/`Err`.
- Produces: `CreditEnergyFromStepsUseCase` with constructor `CreditEnergyFromStepsUseCase(PlayerRepository)` and method `Future<Result<int>> call(int newRewardableSteps)` (returns the amount of Energy actually gained). Task 4 consumes this.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/player/domain/usecases/credit_energy_from_steps_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/player/domain/repositories/player_repository.dart';
import 'package:everstride/features/player/domain/usecases/credit_energy_from_steps_usecase.dart';

class _FakePlayerRepository implements PlayerRepository {
  _FakePlayerRepository([PlayerState? initial])
      : state = initial ?? const PlayerState(level: 1, exp: 0, energy: 0, gold: 0, pendingSteps: 0);

  PlayerState state;

  @override
  Future<Result<PlayerState>> getPlayer() async => Ok(state);

  @override
  Future<Result<bool>> savePlayer(PlayerState player) async {
    state = player;
    return const Ok(true);
  }
}

void main() {
  test('250 new steps with 0 pending grants 2 energy, banks 50 pending', () async {
    final repo = _FakePlayerRepository();
    final useCase = CreditEnergyFromStepsUseCase(repo);

    final result = await useCase.call(250);

    expect((result as Ok<int>).value, 2);
    expect(repo.state.energy, 2);
    expect(repo.state.pendingSteps, 50);
  });

  test('50 new steps with 70 pending grants 1 energy, banks 20 pending', () async {
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 0, energy: 0, gold: 0, pendingSteps: 70),
    );
    final useCase = CreditEnergyFromStepsUseCase(repo);

    final result = await useCase.call(50);

    expect((result as Ok<int>).value, 1);
    expect(repo.state.energy, 1);
    expect(repo.state.pendingSteps, 20);
  });

  test('0 new steps is a no-op', () async {
    final repo = _FakePlayerRepository();
    final useCase = CreditEnergyFromStepsUseCase(repo);

    final result = await useCase.call(0);

    expect((result as Ok<int>).value, 0);
    expect(repo.state.energy, 0);
    expect(repo.state.pendingSteps, 0);
  });

  test('repeated small syncs accumulate the same energy as one combined sync', () async {
    final repoRepeated = _FakePlayerRepository();
    final useCaseRepeated = CreditEnergyFromStepsUseCase(repoRepeated);
    await useCaseRepeated.call(30);
    await useCaseRepeated.call(30);
    await useCaseRepeated.call(30);

    final repoCombined = _FakePlayerRepository();
    final useCaseCombined = CreditEnergyFromStepsUseCase(repoCombined);
    await useCaseCombined.call(90);

    expect(repoRepeated.state.energy, repoCombined.state.energy);
    expect(repoRepeated.state.pendingSteps, repoCombined.state.pendingSteps);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/player/domain/usecases/credit_energy_from_steps_usecase_test.dart`
Expected: FAIL — `credit_energy_from_steps_usecase.dart` doesn't exist yet.

- [ ] **Step 3: Write the use case**

```dart
// lib/features/player/domain/usecases/credit_energy_from_steps_usecase.dart
import '../../../../core/errors/result.dart';
import '../repositories/player_repository.dart';

/// Converts newly-rewardable steps (from Phase 2's sync) into Energy,
/// banking any leftover remainder in `pendingSteps` so nothing is lost
/// across repeated small syncs. See
/// everstride-docs/specs/2026-09-08-phase3-player-progression-design.md.
class CreditEnergyFromStepsUseCase {
  CreditEnergyFromStepsUseCase(this._playerRepository);

  final PlayerRepository _playerRepository;

  static const stepsPerEnergy = 100;

  Future<Result<int>> call(int newRewardableSteps) async {
    final playerResult = await _playerRepository.getPlayer();
    final PlayerState player;
    switch (playerResult) {
      case Ok(value: final v):
        player = v;
      case Err(:final failure):
        return Err(failure);
    }

    final totalPending = player.pendingSteps + newRewardableSteps;
    final energyGained = totalPending ~/ stepsPerEnergy;
    final newPendingSteps = totalPending % stepsPerEnergy;

    final updated = player.copyWith(
      energy: player.energy + energyGained,
      pendingSteps: newPendingSteps,
    );

    final saveResult = await _playerRepository.savePlayer(updated);
    if (saveResult case Err(:final failure)) {
      return Err(failure);
    }

    return Ok(energyGained);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/player/domain/usecases/credit_energy_from_steps_usecase_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Stage and commit (no push)**

```bash
git add lib/features/player/domain/usecases/credit_energy_from_steps_usecase.dart test/features/player/domain/usecases/credit_energy_from_steps_usecase_test.dart
git commit -m "feat(player): add CreditEnergyFromStepsUseCase"
```

Do not `git push` — not authorized, for this task or any other.

---

### Task 3: `SpendEnergyForAdventureUseCase`

**Files:**

- Create: `everstride-mobile/lib/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart`
- Test: `everstride-mobile/test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart`

**Interfaces:**

- Consumes: `PlayerRepository`, `PlayerState` (Task 1); `Result`/`Ok`/`Err`/`Failure`.
- Produces: `SpendEnergyForAdventureUseCase` with constructor `SpendEnergyForAdventureUseCase(PlayerRepository)`, constants `energyCost = 10`, `expReward = 25`, `goldReward = 10`, and method `Future<Result<PlayerState>> call()`. Task 4 consumes this.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/player/domain/repositories/player_repository.dart';
import 'package:everstride/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart';

class _FakePlayerRepository implements PlayerRepository {
  _FakePlayerRepository(this.state);

  PlayerState state;

  @override
  Future<Result<PlayerState>> getPlayer() async => Ok(state);

  @override
  Future<Result<bool>> savePlayer(PlayerState player) async {
    state = player;
    return const Ok(true);
  }
}

void main() {
  test('sufficient energy, no level-up: updates energy/exp/gold, level unchanged', () async {
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 0, energy: 20, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call();
    final player = (result as Ok<PlayerState>).value;

    expect(player.energy, 10);
    expect(player.exp, 25);
    expect(player.gold, 10);
    expect(player.level, 1);
  });

  test('sufficient energy, exactly enough exp to level up once', () async {
    // Level 1 needs 100 exp to reach level 2. Starting at 75 + 25 reward = exactly 100.
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 75, energy: 10, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call();
    final player = (result as Ok<PlayerState>).value;

    expect(player.level, 2);
    expect(player.exp, 0);
  });

  test('a large reward crosses two level thresholds in one grant', () async {
    // This starting exp (280) is a deliberately synthetic edge case chosen
    // to exercise the while-loop's multi-level-up path — a fixed +25
    // reward per call can never naturally reach this state through normal
    // play (each call always leaves exp below the next threshold), but the
    // use case must still handle it correctly if it's ever reached.
    // 280 + 25 = 305. Level 1 needs 100: 305-100=205, level -> 2.
    // Level 2 needs 200: 205-200=5, level -> 3. 5 < 300 (level 3's
    // threshold), loop stops.
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 280, energy: 10, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call();
    final player = (result as Ok<PlayerState>).value;

    expect(player.level, 3);
    expect(player.exp, 5);
  });

  test('insufficient energy returns Err and leaves player state unchanged', () async {
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 0, energy: 5, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call();

    expect(result, isA<Err<PlayerState>>());
    expect(repo.state.energy, 5);
    expect(repo.state.exp, 0);
    expect(repo.state.gold, 0);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart`
Expected: FAIL — `spend_energy_for_adventure_usecase.dart` doesn't exist yet.

- [ ] **Step 3: Write the use case**

```dart
// lib/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart
import '../../../../core/errors/result.dart';
import '../repositories/player_repository.dart';

/// Temporary placeholder Adventure (Phase 4 replaces this with a real
/// Adventure system) — fixed cost/reward taken directly from the plan's
/// own Phase 4 example ("Forest Path"). See
/// everstride-docs/specs/2026-09-08-phase3-player-progression-design.md.
class SpendEnergyForAdventureUseCase {
  SpendEnergyForAdventureUseCase(this._playerRepository);

  final PlayerRepository _playerRepository;

  static const energyCost = 10;
  static const expReward = 25;
  static const goldReward = 10;

  Future<Result<PlayerState>> call() async {
    final playerResult = await _playerRepository.getPlayer();
    final PlayerState player;
    switch (playerResult) {
      case Ok(value: final v):
        player = v;
      case Err(:final failure):
        return Err(failure);
    }

    if (player.energy < energyCost) {
      return const Err(Failure('Not enough energy'));
    }

    var newExp = player.exp + expReward;
    var newLevel = player.level;
    var expToNext = PlayerState.expToNextLevel(newLevel);
    while (newExp >= expToNext) {
      newExp -= expToNext;
      newLevel++;
      expToNext = PlayerState.expToNextLevel(newLevel);
    }

    final updated = player.copyWith(
      energy: player.energy - energyCost,
      exp: newExp,
      level: newLevel,
      gold: player.gold + goldReward,
    );

    final saveResult = await _playerRepository.savePlayer(updated);
    if (saveResult case Err(:final failure)) {
      return Err(failure);
    }

    return Ok(updated);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Stage and commit (no push)**

```bash
git add lib/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart
git commit -m "feat(player): add SpendEnergyForAdventureUseCase"
```

Do not `git push` — not authorized, for this task or any other.

---

### Task 4: `PlayerController`, wire into Home screen, update docs

**Files:**

- Create: `everstride-mobile/lib/features/player/presentation/controllers/player_controller.dart`
- Modify: `everstride-mobile/lib/app/home_page.dart`
- Modify: `everstride-docs/development/testing.md`
- Modify: `everstride-docs/PROGRESS.md`

**Interfaces:**

- Consumes: `PlayerState`, `playerRepositoryProvider` (Task 1); `CreditEnergyFromStepsUseCase` (Task 2); `SpendEnergyForAdventureUseCase` (Task 3); `healthSyncControllerProvider` (existing, `lib/features/health/presentation/controllers/health_sync_controller.dart`); `Result`/`Ok`/`Err`/`Failure`; `AppLogger`.
- Produces: `creditEnergyFromStepsUseCaseProvider`, `spendEnergyForAdventureUseCaseProvider` (both `Provider<...>`); `PlayerController` (`Notifier<AsyncValue<Result<PlayerState>>?>`) with method `Future<Result<PlayerState>> spendOnAdventure()`; `playerControllerProvider`.

This task has no automated test (Riverpod controller + widget wiring) — verify with `flutter analyze` and manual testing per the doc update below.

- [ ] **Step 1: Write the controller**

```dart
// lib/features/player/presentation/controllers/player_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../health/presentation/controllers/health_sync_controller.dart';
import '../../data/repositories/player_repository_impl.dart';
import '../../domain/repositories/player_repository.dart';
import '../../domain/usecases/credit_energy_from_steps_usecase.dart';
import '../../domain/usecases/spend_energy_for_adventure_usecase.dart';

final creditEnergyFromStepsUseCaseProvider = Provider<CreditEnergyFromStepsUseCase>((ref) {
  return CreditEnergyFromStepsUseCase(ref.watch(playerRepositoryProvider));
});

final spendEnergyForAdventureUseCaseProvider = Provider<SpendEnergyForAdventureUseCase>((ref) {
  return SpendEnergyForAdventureUseCase(ref.watch(playerRepositoryProvider));
});

class PlayerController extends Notifier<AsyncValue<Result<PlayerState>>?> {
  @override
  AsyncValue<Result<PlayerState>>? build() {
    // Reactive composition with Phase 2: credit energy automatically
    // whenever a sync completes with new rewardable steps, from any
    // trigger — no changes to HealthSyncController/the health feature.
    ref.listen(healthSyncControllerProvider, (previous, next) {
      if (next case AsyncData(value: Ok(:final value)) when value.totalNewRewardableSteps > 0) {
        _creditEnergy(value.totalNewRewardableSteps);
      }
    });
    _loadPlayer();
    return null;
  }

  Future<void> _loadPlayer() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(playerRepositoryProvider).getPlayer());
  }

  Future<void> _creditEnergy(int newRewardableSteps) async {
    final result = await ref.read(creditEnergyFromStepsUseCaseProvider).call(newRewardableSteps);
    if (result case Err(:final failure)) {
      AppLogger.error('player.state', 'Failed to credit energy from steps', failure);
      return;
    }
    await _loadPlayer();
  }

  /// Returns the spend result so the caller can show "not enough energy"
  /// feedback; on success, also refreshes the persisted player state.
  Future<Result<PlayerState>> spendOnAdventure() async {
    final result = await ref.read(spendEnergyForAdventureUseCaseProvider).call();
    if (result case Ok()) {
      await _loadPlayer();
    }
    return result;
  }
}

final playerControllerProvider =
    NotifierProvider<PlayerController, AsyncValue<Result<PlayerState>>?>(PlayerController.new);
```

- [ ] **Step 2: Run the analyzer on the new file**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Wire the controller into the Home screen**

Open `lib/app/home_page.dart`. Read the file fresh (it has evolved since Phase 2 shipped — do not assume its exact current shape from memory). Add this import alongside the other `features/.../presentation/controllers/...` imports:

```dart
import '../features/player/presentation/controllers/player_controller.dart';
import '../features/player/domain/repositories/player_repository.dart';
```

Add a new section to the `Column`'s `children` (after the existing steps/sync section, before the leftover default-counter demo text at the bottom — or replacing that demo text if it makes more sense once you see the current file; the demo counter is not part of any real feature):

```dart
const SizedBox(height: 24),
Consumer(
  builder: (context, ref, _) {
    final player = ref.watch(playerControllerProvider);
    final playerState = switch (player?.value) {
      Ok(:final value) => value,
      _ => null,
    };
    if (playerState == null) return const Text('Player: loading...');
    return Column(
      children: [
        Text(
          'Level ${playerState.level} — EXP ${playerState.exp}/${PlayerState.expToNextLevel(playerState.level)}',
        ),
        Text('Energy: ${playerState.energy}   Gold: ${playerState.gold}'),
        ElevatedButton(
          onPressed: () async {
            final result = await ref.read(playerControllerProvider.notifier).spendOnAdventure();
            if (result case Err(:final failure)) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
              }
            }
          },
          child: const Text('Adventure (temporary) — 10 Energy → +25 EXP, +10 Gold'),
        ),
      ],
    );
  },
),
```

- [ ] **Step 4: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Add a Phase 3 section to the manual recheck doc**

Open `everstride-docs/development/testing.md`. Add this section after the existing "Phase 2" section:

```markdown
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
```

- [ ] **Step 6: Update `everstride-docs/PROGRESS.md`**

Add a "Phase 3 — Player Progression MVP" section (mirroring the existing
Phase 1/Phase 2 sections' style: a `### Phase 3` heading with `- [x]` lines
per plan task — "Create Player entity", "Create Player local persistence",
"Implement step-to-energy conversion", "Display Energy", "Create EXP
system", "Create basic level-up curve", "Add simple player status screen"
— each with a short build note), and mark them done. Reference
`everstride-docs/specs/2026-09-08-phase3-player-progression-design.md` for
the full design rationale instead of repeating it, same as the Phase 2
section already does for its own spec.

- [ ] **Step 7: Stage and commit (no push)**

`everstride-docs/` is a sibling directory outside this git repo — the doc edits from Steps 5–6 are not part of this commit; only the repo files below are.

```bash
git add lib/features/player/presentation/controllers/player_controller.dart lib/app/home_page.dart
git commit -m "feat(player): wire PlayerController into Home screen"
```

Do not `git push` — not authorized, for this task or any other.
