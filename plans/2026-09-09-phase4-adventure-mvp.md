# Phase 4 — Adventure MVP Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Phase 3.2's temporary Adventure action (fixed 10 Energy → +25 EXP/+10 Gold, difficulty selection that only changes styling) with the real Greenwood Trail MVP: three difficulty tiers with genuinely different Energy costs and rewards, atomic resolution, a dedicated result screen, and a clear insufficient-Energy explanation — exactly the scope `game-design/adventure-system.md` defines, no more.

**Architecture:** Adventure content (`Greenwood Trail` + its 3 difficulties) is static, compile-time data — no Drift table, no `AdventureRun`/history entity (the design doc explicitly excludes these from Phase 4). `SpendEnergyForAdventureUseCase` is generalized to accept the cost/reward values as parameters instead of reading its own hardcoded constants — its caller (the adventure feature) supplies whichever values the player selected, so `features/player` never imports anything from `features/adventure` (mirrors how `CreditEnergyFromStepsUseCase` takes a plain `int`, never a `health`-feature type). A new top-level `GoRoute` (outside the 5-tab shell, matching the mockup's full-screen Result — no bottom nav visible there) shows the result via `context.push(..., extra: AdventureResult(...))`.

**Tech Stack:** Flutter, Dart 3, Riverpod 3, GoRouter 18. No new dependencies, no schema migration.

**Spec:** `everstride-docs/game-design/adventure-system.md` (read this first — it is the authoritative game-design spec for this phase; it explicitly defers all architecture/storage/UI decisions to this plan, so those decisions are made here, not in a separate technical spec doc). Also relevant: `everstride-docs/specs/2026-09-09-phase3.2-adventure-ui-skeleton-design.md` describes the current (pre-Phase-4) `AdventureScreen`, which this plan replaces piece by piece.

## Global Constraints

- Adventure definitions (`Adventure`, `AdventureDifficulty`) are plain immutable value classes with a static `const` catalog — not Drift-backed, not behind a repository. This is a deliberate scope call: the design doc says static content needs no `AdventureRun`/history entity, and there is no real external data source yet to abstract behind `AdventureRepository` (that stub stays untouched — Phase 6 is the earliest point a real data source, e.g. Supabase-hosted adventures, would justify giving it real shape).
- `features/player` code must never import from `features/adventure` — pass primitive values (`int energyCost`, etc.), never `Adventure`/`AdventureDifficulty` objects, across that boundary. This matches the existing `CreditEnergyFromStepsUseCase(int newRewardableSteps)` precedent exactly.
- Every repository/use-case method still returns `Future<Result<T>>` — no exceptions cross a boundary. No change to this project-wide rule.
- The invariants in `game-design/adventure-system.md`'s "Rules that must remain invariant" section are correctness rules, not style preferences — in particular: a failed validation must spend no Energy and grant no reward (already true of the existing use case's structure — preserve it exactly through the parameterization); a repeated/duplicate Start tap must resolve at most once (Task 3 adds a UI-level in-flight guard for this — `PlayerController`'s existing `_runExclusive` mutex only serializes concurrent calls, it does not deduplicate two separate user-initiated taps, so the UI must not allow a second tap while one is in flight).
- No new Drift table, no schema migration, no new dependency (`go_router`'s `extra` parameter is enough to carry the result data across the pushed route for this MVP — no need for a serializable/URL-encodable result shape).
- Riverpod 3 has no `StateProvider` — use `Notifier`/`NotifierProvider` (no change needed this phase, just restating the project-wide rule since `PlayerController` is touched).
- Reward-math changes get real unit tests (project testing priority, unchanged from every earlier phase) — Task 1's catalog and Task 2's generalized use case both get tests. UI screens (`AdventureScreen`, `AdventureResultScreen`) get one comprehensive widget-test file (Task 3), reflecting that this phase's UI is no longer purely decorative (it now drives real per-difficulty values and real navigation) — this is a deliberate step up from the "no automated UI test" precedent set in Phase 3.1/3.2, justified by the new push-navigation and dialog behavior being real logic worth protecting, not just layout.
- All commands below assume the working directory is `everstride-mobile/`.
- **Commit policy for this execution run only:** the user has explicitly authorized `git commit` and running `flutter test` for this specific subagent-driven run of this plan (overriding `everstride-docs/AGENTS.md`'s normal absolute "never commit"/"never test unasked" rules, which still apply everywhere else) — **conditional on no commit carrying a `Co-Authored-By` trailer** (explicit user instruction for this run, overriding the general attribution instruction that would otherwise add one). Each task's implementer commits its own work normally at the end of the task, with a plain commit message and no trailer. **`git push` is never allowed, under any circumstance, for this run or any other.**

---

### Task 1: Adventure entities and the Greenwood Trail catalog

**Files:**

- Create: `everstride-mobile/lib/features/adventure/domain/entities/adventure.dart`
- Create: `everstride-mobile/lib/features/adventure/domain/adventure_catalog.dart`
- Test: `everstride-mobile/test/features/adventure/domain/adventure_catalog_test.dart`

**Interfaces:**

- Consumes: nothing (pure data).
- Produces: `AdventureDifficulty` (`id`, `label`, `energyCost`, `expReward`, `goldReward`, all required); `Adventure` (`id`, `name`, `description`, `difficultyOptions` (`List<AdventureDifficulty>`), `defaultDifficultyId`, plus `defaultDifficulty` and `difficultyById(String id)` getters/methods); the top-level `const greenwoodTrail` catalog entry. Tasks 2 and 3 consume all of this.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/adventure/domain/adventure_catalog_test.dart
import 'package:everstride/features/adventure/domain/adventure_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Greenwood Trail matches the documented difficulty matrix exactly', () {
    expect(greenwoodTrail.id, 'greenwood_trail');
    expect(greenwoodTrail.defaultDifficulty.id, 'easy');

    final easy = greenwoodTrail.difficultyById('easy');
    expect(easy.energyCost, 10);
    expect(easy.expReward, 25);
    expect(easy.goldReward, 10);

    final normal = greenwoodTrail.difficultyById('normal');
    expect(normal.energyCost, 20);
    expect(normal.expReward, 55);
    expect(normal.goldReward, 22);

    final hard = greenwoodTrail.difficultyById('hard');
    expect(hard.energyCost, 30);
    expect(hard.expReward, 90);
    expect(hard.goldReward, 36);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/adventure/domain/adventure_catalog_test.dart`
Expected: FAIL — `adventure_catalog.dart` doesn't exist yet.

- [ ] **Step 3: Write the entities**

```dart
// lib/features/adventure/domain/entities/adventure.dart

/// Static game content — not a record of a player currently traveling.
/// See everstride-docs/game-design/adventure-system.md.
class AdventureDifficulty {
  const AdventureDifficulty({
    required this.id,
    required this.label,
    required this.energyCost,
    required this.expReward,
    required this.goldReward,
  });

  final String id;
  final String label;
  final int energyCost;
  final int expReward;
  final int goldReward;
}

class Adventure {
  const Adventure({
    required this.id,
    required this.name,
    required this.description,
    required this.difficultyOptions,
    required this.defaultDifficultyId,
  });

  final String id;
  final String name;
  final String description;
  final List<AdventureDifficulty> difficultyOptions;
  final String defaultDifficultyId;

  AdventureDifficulty get defaultDifficulty => difficultyById(defaultDifficultyId);

  AdventureDifficulty difficultyById(String id) =>
      difficultyOptions.firstWhere((d) => d.id == id);
}
```

- [ ] **Step 4: Write the catalog**

```dart
// lib/features/adventure/domain/adventure_catalog.dart
import 'entities/adventure.dart';

/// The one playable Adventure for the Phase 4 MVP. Values match the
/// difficulty matrix in everstride-docs/game-design/adventure-system.md
/// exactly — change them there first if they ever need to change.
const greenwoodTrail = Adventure(
  id: 'greenwood_trail',
  name: 'Greenwood Trail',
  description: 'A peaceful path through the forest.',
  defaultDifficultyId: 'easy',
  difficultyOptions: [
    AdventureDifficulty(id: 'easy', label: 'Easy', energyCost: 10, expReward: 25, goldReward: 10),
    AdventureDifficulty(id: 'normal', label: 'Normal', energyCost: 20, expReward: 55, goldReward: 22),
    AdventureDifficulty(id: 'hard', label: 'Hard', energyCost: 30, expReward: 90, goldReward: 36),
  ],
);
```

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/features/adventure/domain/adventure_catalog_test.dart`
Expected: PASS (1 test)

- [ ] **Step 6: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Stage and commit (no push)**

```bash
git add lib/features/adventure/domain/entities/adventure.dart lib/features/adventure/domain/adventure_catalog.dart test/features/adventure/domain/adventure_catalog_test.dart
git commit -m "feat(adventure): add Adventure entities and Greenwood Trail catalog"
```

Do not `git push`.

---

### Task 2: Generalize `SpendEnergyForAdventureUseCase` for per-difficulty values

**Files:**

- Modify: `everstride-mobile/lib/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart`
- Modify: `everstride-mobile/lib/features/player/presentation/controllers/player_controller.dart`
- Modify: `everstride-mobile/lib/features/adventure/presentation/screens/adventure_screen.dart` (one-line bridge fix only — see Step 6; Task 3 does the real UI rewrite)
- Modify: `everstride-mobile/test/features/adventure/presentation/adventure_screen_test.dart` (signature-only fix — see Step 7; Task 3 replaces this file's content for real)
- Test: `everstride-mobile/test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart` (full rewrite)

**Interfaces:**

- Consumes: `PlayerRepository`, `PlayerState` (existing, unchanged).
- Produces: `SpendEnergyForAdventureUseCase.call({required int energyCost, required int expReward, required int goldReward})` (replaces the old no-arg `call()`); `PlayerController.spendOnAdventure({required int energyCost, required int expReward, required int goldReward})` (replaces the old no-arg method — same name, new required parameters). Task 3 consumes the new `spendOnAdventure` signature to pass real catalog-driven values.

This task's scope is deliberately narrow: prove the reward math now accepts caller-supplied values instead of its own hardcoded constants (10/25/10), without changing what `AdventureScreen` looks like or does. Step 6's edit to `adventure_screen.dart` exists only to keep the project compiling after the method signature changes (it passes the same literal 10/25/10 values the old constants held) — Task 3 replaces this with real catalog-driven values.

- [ ] **Step 1: Rewrite the failing tests**

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

    final result = await useCase.call(energyCost: 10, expReward: 25, goldReward: 10);
    final player = (result as Ok<PlayerState>).value;

    expect(player.energy, 10);
    expect(player.exp, 25);
    expect(player.gold, 10);
    expect(player.level, 1);
  });

  test('sufficient energy, exactly enough exp to level up once', () async {
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 75, energy: 10, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call(energyCost: 10, expReward: 25, goldReward: 10);
    final player = (result as Ok<PlayerState>).value;

    expect(player.level, 2);
    expect(player.exp, 0);
  });

  test('a large reward crosses two level thresholds in one grant', () async {
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 280, energy: 10, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call(energyCost: 10, expReward: 25, goldReward: 10);
    final player = (result as Ok<PlayerState>).value;

    expect(player.level, 3);
    expect(player.exp, 5);
  });

  test('insufficient energy returns Err and leaves player state unchanged', () async {
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 0, energy: 5, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call(energyCost: 10, expReward: 25, goldReward: 10);

    expect(result, isA<Err<PlayerState>>());
    expect(repo.state.energy, 5);
    expect(repo.state.exp, 0);
    expect(repo.state.gold, 0);
  });

  test('Normal-tier values (20/55/22) apply exactly as given, not the old fixed 10/25/10', () async {
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 0, energy: 20, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call(energyCost: 20, expReward: 55, goldReward: 22);
    final player = (result as Ok<PlayerState>).value;

    expect(player.energy, 0);
    expect(player.exp, 55);
    expect(player.gold, 22);
  });

  test('Hard-tier cost (30) is rejected when energy only covers Normal tier (20)', () async {
    final repo = _FakePlayerRepository(
      const PlayerState(level: 1, exp: 0, energy: 20, gold: 0, pendingSteps: 0),
    );
    final useCase = SpendEnergyForAdventureUseCase(repo);

    final result = await useCase.call(energyCost: 30, expReward: 90, goldReward: 36);

    expect(result, isA<Err<PlayerState>>());
    expect(repo.state.energy, 20);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart`
Expected: FAIL — `call()` doesn't accept named parameters yet.

- [ ] **Step 3: Generalize the use case**

```dart
// lib/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart
import '../../../../core/errors/result.dart';
import '../repositories/player_repository.dart';

/// Resolves an Adventure attempt: spends the given Energy cost and grants
/// the given EXP/Gold, applying the level-up curve. The caller (the
/// adventure feature) supplies the exact values for whichever Adventure and
/// difficulty the player selected — this use case has no opinion on what an
/// "Adventure" is, only how spending Energy for one affects Player state.
/// See everstride-docs/game-design/adventure-system.md.
class SpendEnergyForAdventureUseCase {
  SpendEnergyForAdventureUseCase(this._playerRepository);

  final PlayerRepository _playerRepository;

  Future<Result<PlayerState>> call({
    required int energyCost,
    required int expReward,
    required int goldReward,
  }) async {
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
Expected: PASS (6 tests)

- [ ] **Step 5: Update `PlayerController.spendOnAdventure`**

Open `lib/features/player/presentation/controllers/player_controller.dart`. Replace the `spendOnAdventure` method:

```dart
  Future<Result<PlayerState>> spendOnAdventure({
    required int energyCost,
    required int expReward,
    required int goldReward,
  }) {
    return _runExclusive(() async {
      final result = await ref.read(spendEnergyForAdventureUseCaseProvider).call(
            energyCost: energyCost,
            expReward: expReward,
            goldReward: goldReward,
          );
      if (result case Ok()) {
        await _loadPlayer();
      }
      return result;
    });
  }
```

Nothing else in this file changes (the doc comment above it, `_runExclusive`, `_loadPlayer`, and the reactive `ref.listen` in `build()` are all untouched).

- [ ] **Step 6: Bridge-fix `adventure_screen.dart`'s call site**

Open `lib/features/adventure/presentation/screens/adventure_screen.dart`. Find `_startAdventure` and change only the `spendOnAdventure()` call:

```dart
    final result = await ref
        .read(playerControllerProvider.notifier)
        .spendOnAdventure(energyCost: 10, expReward: 25, goldReward: 10);
```

(Everything else in this file — the difficulty chips, the SnackBar messages, the reward cards — is unchanged in this task. Task 3 replaces all of it with the real catalog-driven version.)

- [ ] **Step 7: Bridge-fix the existing widget test's fake controllers**

Open `test/features/adventure/presentation/adventure_screen_test.dart`. Change both fake subclasses' overridden method signature from `spendOnAdventure()` to match the new required parameters (the bodies and both tests' assertions stay exactly as they are — Easy-tier values are still 10/25/10, so nothing observable changes):

```dart
  @override
  Future<Result<PlayerState>> spendOnAdventure({
    required int energyCost,
    required int expReward,
    required int goldReward,
  }) async {
    spendCallCount++;
    return const Ok(_player);
  }
```

(apply the equivalent signature change to `_FailingPlayerController`'s override too, keeping its body — `return const Err(Failure('Not enough energy'));` — unchanged).

- [ ] **Step 8: Run the full affected test suite**

Run: `flutter test test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart test/features/adventure/presentation/adventure_screen_test.dart`
Expected: PASS (6 + 2 tests)

- [ ] **Step 9: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 10: Stage and commit (no push)**

```bash
git add lib/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart lib/features/player/presentation/controllers/player_controller.dart lib/features/adventure/presentation/screens/adventure_screen.dart test/features/player/domain/usecases/spend_energy_for_adventure_usecase_test.dart test/features/adventure/presentation/adventure_screen_test.dart
git commit -m "feat(player): generalize SpendEnergyForAdventureUseCase for per-difficulty values"
```

Do not `git push`.

---

### Task 3: Real Adventure screen, result screen, and router wiring

**Files:**

- Create: `everstride-mobile/lib/features/adventure/presentation/models/adventure_result.dart`
- Create: `everstride-mobile/lib/features/adventure/presentation/screens/adventure_result_screen.dart`
- Modify: `everstride-mobile/lib/features/adventure/presentation/screens/adventure_screen.dart` (full rewrite)
- Modify: `everstride-mobile/lib/app/router.dart` (add one route)
- Modify: `everstride-mobile/test/features/adventure/presentation/adventure_screen_test.dart` (full rewrite)

**Interfaces:**

- Consumes: `greenwoodTrail`, `Adventure`, `AdventureDifficulty` (Task 1); `PlayerController.spendOnAdventure({energyCost, expReward, goldReward})` (Task 2); `PlayerState` (existing).
- Produces: `AdventureResult` (presentation-layer DTO — not a domain entity, since Phase 4 keeps no result-history record); `AdventureResultScreen`; the `/adventure-result` route. Nothing later in this plan consumes these further (this is the last task before docs).

- [ ] **Step 1: Write the `AdventureResult` DTO**

```dart
// lib/features/adventure/presentation/models/adventure_result.dart
import '../../../player/domain/repositories/player_repository.dart';

/// UI-transport data for the Adventure result screen — not a persisted
/// domain entity (Phase 4 keeps no AdventureRun/result-history record).
class AdventureResult {
  const AdventureResult({
    required this.adventureName,
    required this.difficultyLabel,
    required this.energySpent,
    required this.expGained,
    required this.goldGained,
    required this.levelBefore,
    required this.playerAfter,
  });

  final String adventureName;
  final String difficultyLabel;
  final int energySpent;
  final int expGained;
  final int goldGained;
  final int levelBefore;
  final PlayerState playerAfter;

  bool get leveledUp => playerAfter.level > levelBefore;
}
```

- [ ] **Step 2: Write the result screen**

```dart
// lib/features/adventure/presentation/screens/adventure_result_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../player/domain/repositories/player_repository.dart';
import '../models/adventure_result.dart';

class AdventureResultScreen extends StatelessWidget {
  const AdventureResultScreen({super.key, required this.result});

  final AdventureResult result;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.check_circle, size: 64),
              const SizedBox(height: 16),
              const Text(
                'Adventure Complete!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('${result.adventureName} — ${result.difficultyLabel}'),
              const SizedBox(height: 24),
              if (result.leveledUp) ...[
                Text(
                  'Level Up! ${result.levelBefore} → ${result.playerAfter.level}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 16),
              ],
              _ResultRow(label: 'Energy spent', value: '-${result.energySpent}'),
              _ResultRow(label: 'EXP gained', value: '+${result.expGained}'),
              _ResultRow(label: 'Gold gained', value: '+${result.goldGained}'),
              const SizedBox(height: 8),
              Text(
                'Lv. ${result.playerAfter.level} — EXP ${result.playerAfter.exp}/${PlayerState.expToNextLevel(result.playerAfter.level)}',
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => context.pop(),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  const _ResultRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [Text(label), Text(value, style: const TextStyle(fontWeight: FontWeight.bold))],
      ),
    );
  }
}
```

`Continue` uses `context.pop()`, not `context.go(...)` — the result screen is reached via `context.push`, so popping it returns cleanly to exactly the Adventure tab state that was showing before, without disturbing the shell's other tabs.

- [ ] **Step 3: Add the router route**

Open `lib/app/router.dart`. Add the import and the new top-level route (a sibling of `/splash`/`/onboarding`/`/permission` — deliberately *outside* the `StatefulShellRoute`, so it renders full-screen with no bottom nav, matching the mockup's Result screen):

```dart
import '../features/adventure/presentation/models/adventure_result.dart';
import '../features/adventure/presentation/screens/adventure_result_screen.dart';
```

```dart
    GoRoute(
      path: '/adventure-result',
      builder: (context, state) => AdventureResultScreen(result: state.extra as AdventureResult),
    ),
```

Add it alongside the other top-level routes (before the `StatefulShellRoute.indexedStack(...)` entry).

- [ ] **Step 4: Rewrite the Adventure screen**

```dart
// lib/features/adventure/presentation/screens/adventure_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../../../player/domain/repositories/player_repository.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import '../../domain/adventure_catalog.dart';
import '../../domain/entities/adventure.dart';
import '../models/adventure_result.dart';

class AdventureScreen extends ConsumerStatefulWidget {
  const AdventureScreen({super.key});

  @override
  ConsumerState<AdventureScreen> createState() => _AdventureScreenState();
}

class _AdventureScreenState extends ConsumerState<AdventureScreen> {
  static const _adventure = greenwoodTrail;
  String _selectedDifficultyId = greenwoodTrail.defaultDifficultyId;
  var _isStarting = false;

  AdventureDifficulty get _selectedDifficulty => _adventure.difficultyById(_selectedDifficultyId);

  Future<void> _startAdventure() async {
    final difficulty = _selectedDifficulty;
    final playerBefore = switch (ref.read(playerControllerProvider)?.value) {
      Ok(:final value) => value,
      _ => null,
    };
    if (playerBefore == null) return;

    if (playerBefore.energy < difficulty.energyCost) {
      await _showInsufficientEnergyDialog(difficulty, playerBefore.energy);
      return;
    }

    setState(() => _isStarting = true);
    final result = await ref.read(playerControllerProvider.notifier).spendOnAdventure(
          energyCost: difficulty.energyCost,
          expReward: difficulty.expReward,
          goldReward: difficulty.goldReward,
        );
    if (!mounted) return;
    setState(() => _isStarting = false);

    switch (result) {
      case Ok(:final value):
        context.push(
          '/adventure-result',
          extra: AdventureResult(
            adventureName: _adventure.name,
            difficultyLabel: difficulty.label,
            energySpent: difficulty.energyCost,
            expGained: difficulty.expReward,
            goldGained: difficulty.goldReward,
            levelBefore: playerBefore.level,
            playerAfter: value,
          ),
        );
      case Err(:final failure):
        if (failure.message == 'Not enough energy') {
          await _showInsufficientEnergyDialog(difficulty, playerBefore.energy);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(failure.message)));
        }
    }
  }

  Future<void> _showInsufficientEnergyDialog(AdventureDifficulty difficulty, int currentEnergy) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Not enough Energy'),
        content: Text(
          '${_adventure.name} (${difficulty.label}) costs ${difficulty.energyCost} Energy. '
          'You have $currentEnergy. Walk more to earn Energy, or pick an easier difficulty.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final difficulty = _selectedDifficulty;
    return Scaffold(
      appBar: AppBar(title: const Text('Adventure')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_adventure.name, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text(_adventure.description, style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 16),
            ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: Image.asset('lib/assets/bg.png', height: 180, fit: BoxFit.cover),
            ),
            const SizedBox(height: 24),
            const Text('Difficulty', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              children: _adventure.difficultyOptions
                  .map(
                    (d) => ChoiceChip(
                      label: Text(d.label),
                      selected: _selectedDifficultyId == d.id,
                      onSelected: (_) => setState(() => _selectedDifficultyId = d.id),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 24),
            const Text('Possible Rewards', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(child: _RewardCard(icon: Icons.auto_graph, label: '+${difficulty.expReward} EXP')),
                const SizedBox(width: 12),
                Expanded(child: _RewardCard(icon: Icons.monetization_on, label: '+${difficulty.goldReward} Gold')),
              ],
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: _isStarting ? null : _startAdventure,
              icon: _isStarting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.bolt),
              label: Text('Start Adventure · ${difficulty.energyCost} Energy'),
            ),
          ],
        ),
      ),
    );
  }
}

class _RewardCard extends StatelessWidget {
  const _RewardCard({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(label),
          ],
        ),
      ),
    );
  }
}
```

Note `static const _adventure = greenwoodTrail;` and `String _selectedDifficultyId = greenwoodTrail.defaultDifficultyId;` both reference the top-level `greenwoodTrail` constant directly rather than the instance field `_adventure` — an instance field initializer in Dart cannot reference another instance field (that would require `this`, which isn't available yet at that point), so both must independently read the top-level constant.

The pre-check (`playerBefore.energy < difficulty.energyCost`) handles the common case without ever entering the loading state; the `Err`-with-message fallback after actually calling `spendOnAdventure` handles the rarer race where Energy changed between the read and the mutation — both paths show the same dialog, satisfying the design doc's "cannot start without sufficient Energy" invariant either way.

- [ ] **Step 5: Rewrite the widget test**

```dart
// test/features/adventure/presentation/adventure_screen_test.dart
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/adventure/presentation/models/adventure_result.dart';
import 'package:everstride/features/adventure/presentation/screens/adventure_result_screen.dart';
import 'package:everstride/features/adventure/presentation/screens/adventure_screen.dart';
import 'package:everstride/features/player/domain/repositories/player_repository.dart';
import 'package:everstride/features/player/presentation/controllers/player_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

const _player = PlayerState(level: 1, exp: 0, energy: 20, gold: 0, pendingSteps: 0);

class _SuccessfulPlayerController extends PlayerController {
  var lastEnergyCost = 0;
  var lastExpReward = 0;
  var lastGoldReward = 0;

  @override
  AsyncValue<Result<PlayerState>>? build() => const AsyncData(Ok(_player));

  @override
  Future<Result<PlayerState>> spendOnAdventure({
    required int energyCost,
    required int expReward,
    required int goldReward,
  }) async {
    lastEnergyCost = energyCost;
    lastExpReward = expReward;
    lastGoldReward = goldReward;
    return Ok(
      _player.copyWith(energy: _player.energy - energyCost, exp: expReward, gold: goldReward),
    );
  }
}

class _FailingPlayerController extends PlayerController {
  @override
  AsyncValue<Result<PlayerState>>? build() => const AsyncData(Ok(_player));

  @override
  Future<Result<PlayerState>> spendOnAdventure({
    required int energyCost,
    required int expReward,
    required int goldReward,
  }) async {
    return const Err(Failure('Not enough energy'));
  }
}

Widget _harness(ProviderContainer container) {
  final router = GoRouter(
    initialLocation: '/adventure',
    routes: [
      GoRoute(path: '/adventure', builder: (_, __) => const AdventureScreen()),
      GoRoute(
        path: '/adventure-result',
        builder: (context, state) => AdventureResultScreen(result: state.extra as AdventureResult),
      ),
    ],
  );
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp.router(routerConfig: router),
  );
}

void main() {
  testWidgets('selecting a harder difficulty updates displayed cost and rewards', (tester) async {
    final container = ProviderContainer(
      overrides: [playerControllerProvider.overrideWith(_SuccessfulPlayerController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));

    expect(find.text('Start Adventure · 10 Energy'), findsOneWidget);
    await tester.tap(find.text('Normal'));
    await tester.pump();
    expect(find.text('Start Adventure · 20 Energy'), findsOneWidget);
    expect(find.text('+55 EXP'), findsOneWidget);
    expect(find.text('+22 Gold'), findsOneWidget);
  });

  testWidgets('starting a valid Adventure pushes the result screen with the real values', (tester) async {
    final container = ProviderContainer(
      overrides: [playerControllerProvider.overrideWith(_SuccessfulPlayerController.new)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(_harness(container));

    await tester.tap(find.text('Normal'));
    await tester.pump();

    final startButton = find.text('Start Adventure · 20 Energy');
    await tester.ensureVisible(startButton);
    await tester.tap(startButton);
    await tester.pumpAndSettle();

    final controller = container.read(playerControllerProvider.notifier) as _SuccessfulPlayerController;
    expect(controller.lastEnergyCost, 20);
    expect(controller.lastExpReward, 55);
    expect(controller.lastGoldReward, 22);
    expect(find.byType(AdventureResultScreen), findsOneWidget);
    expect(find.text('Adventure Complete!'), findsOneWidget);
  });

  testWidgets(
    'insufficient Energy shows a dialog explaining cost and current Energy, no navigation',
    (tester) async {
      final container = ProviderContainer(
        overrides: [playerControllerProvider.overrideWith(_FailingPlayerController.new)],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(_harness(container));

      final startButton = find.text('Start Adventure · 10 Energy');
      await tester.ensureVisible(startButton);
      await tester.tap(startButton);
      await tester.pumpAndSettle();

      expect(find.text('Not enough Energy'), findsOneWidget);
      expect(find.textContaining('costs 10 Energy'), findsOneWidget);
      expect(find.byType(AdventureResultScreen), findsNothing);
    },
  );
}
```

The third test exercises the `Err`-fallback path (not the pre-check path): `_player`'s Energy is 20, Easy costs 10, so the pre-check passes and the fake controller's `Err('Not enough energy')` is what actually triggers the dialog — proving that path independently of the pre-check.

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/adventure/presentation/adventure_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Stage and commit (no push)**

```bash
git add lib/features/adventure/presentation/models/adventure_result.dart lib/features/adventure/presentation/screens/adventure_result_screen.dart lib/features/adventure/presentation/screens/adventure_screen.dart lib/app/router.dart test/features/adventure/presentation/adventure_screen_test.dart
git commit -m "feat(adventure): add real Greenwood Trail resolution and result screen"
```

Do not `git push`.

---

### Task 4: Update manual recheck doc and progress tracker

**Files:**

- Modify: `everstride-docs/development/testing.md`
- Modify: `everstride-docs/PROGRESS.md`

**Interfaces:** none — pure documentation, no code.

`everstride-docs/` is a sibling directory outside the `everstride-mobile` git repo — these edits are a separate commit in that repo (unlike prior phases' plans, where the doc edits had no commit step at all — this repo's own commits so far, e.g. `317250a`, show doc changes are in fact committed here, so this task does commit, in `everstride-docs/`, not `everstride-mobile/`).

- [ ] **Step 1: Add a Phase 4 section to the manual recheck doc**

Open `everstride-docs/development/testing.md`. Add this section after the existing "Phase 3.2" section:

```markdown
## Phase 4 — Adventure MVP

1. Open the Adventure tab → Greenwood Trail shows Easy selected by default,
   "Start Adventure · 10 Energy" and "+25 EXP"/"+10 Gold" reward cards.
2. Tap Normal → button and reward cards update to "20 Energy"/"+55 EXP"/
   "+22 Gold"; tap Hard → "30 Energy"/"+90 EXP"/"+36 Gold". Tap back to Easy
   → values return to 10/25/10.
3. With ≥10 Energy, start on Easy → a dedicated result screen appears
   (not a SnackBar) showing Greenwood Trail, Easy, "-10" Energy, "+25" EXP,
   "+10" Gold, and current Lv/EXP; "Continue" returns to the Adventure tab
   with the bottom nav visible again.
4. Repeat with enough Energy for Normal or Hard → the result screen shows
   the correct 20/55/22 or 30/90/36 values, matching what was displayed
   before starting.
5. Attempt an Adventure whose cost exceeds current Energy → a dialog names
   the exact cost and current Energy (not a generic message), offers "Got
   it", and does not navigate to a result screen; Energy/EXP/Gold on the
   Character tab are unchanged afterward.
6. Grant enough EXP in one Adventure to cross one or more level thresholds
   (e.g. repeat Hard near a level boundary) → the result screen shows a
   "Level Up!" callout with the correct before/after levels, and leftover
   EXP after the level-up is not negative.
7. Rapidly double-tap "Start Adventure" → only one resolution happens (the
   button visibly disables while resolving); Energy is deducted exactly
   once, not twice.
8. Force-close the app after a successful Adventure and reopen it → the
   updated Level/EXP/Energy/Gold on the Character tab persist exactly as
   shown on the result screen (no partial or duplicated state).
```

- [ ] **Step 2: Update `everstride-docs/PROGRESS.md`**

Add a "Phase 4 — Adventure MVP" section (mirroring the existing phase sections' style: mixed Thai/English prose, `- [x]` lines per the design doc's real deliverables — Adventure entities/catalog, generalized `SpendEnergyForAdventureUseCase`, real per-difficulty Adventure screen, dedicated result screen with level-up callout, insufficient-Energy dialog, duplicate-tap protection — each with a short build note in the same voice as the existing sections), mark it done, and move its `- [ ] Phase 4 — Adventure MVP` line out of the "Phase ถัดไป" list at the bottom into this new completed section. Reference `everstride-docs/game-design/adventure-system.md` for the full design rationale instead of repeating it, same as every earlier phase section already does for its own spec/design doc.

- [ ] **Step 3: Stage and commit (no push)**

```bash
cd ../everstride-docs
git add development/testing.md PROGRESS.md
git commit -m "docs: record Phase 4 Adventure MVP completion"
```

Do not `git push`.
