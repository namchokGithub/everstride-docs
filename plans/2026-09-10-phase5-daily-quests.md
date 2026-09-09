# Phase 5 — Daily Quests Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** A fixed set of three Daily Quests per local calendar day (two Step-based, one Adventure-completion), tracked automatically from data that already exists (health sync, Adventure resolution), manually claimed once for a fixed EXP/Gold reward, with lazy day rollover and no background timers — exactly the scope `game-design/quests.md` defines.

**Architecture:** Quest *definitions* are static compile-time content (mirrors `Adventure`'s catalog pattern from Phase 4) — only the dated *instance* is persisted (one new Drift table). `EnsureDailyQuestsUseCase` owns rollover (expire yesterday's unclaimed instances, create today's fixed set) and Step-objective progress (recomputed from the existing `HealthSyncRepository`, never a new Step-tracking mechanism). Adventure-objective progress is a separate incremental push (`RecordAdventureCompletionUseCase`), called directly from `AdventureScreen` after a successful resolve — deliberately a manual call rather than a reactive `ref.listen`, unlike Phase 3's steps→Energy composition, because (unlike sync) Phase 5 has no second foreseeable trigger for "an Adventure just resolved" to listen for. Claiming a Quest is the one place in this codebase that uses a real Drift `transaction()` spanning two repositories (Player + Quest) for genuine atomicity, instead of the informal single-repository ordering used everywhere else.

**Tech Stack:** Flutter, Dart 3, Riverpod 3, Drift (schema migration 5 → 6, one new table). No new dependencies.

**Spec:** `everstride-docs/game-design/quests.md` (read this first — it is the authoritative game-design spec for this phase and explicitly defers storage/architecture/UI decisions to this plan, so those decisions are made here). Also relevant: `everstride-docs/game-design/adventure-system.md` and `everstride-docs/specs/2026-09-09-phase3.2-adventure-ui-skeleton-design.md` describe the current `AdventureScreen`/`SpendEnergyForAdventureUseCase`, which Task 5 adds one call to (does not otherwise change).

## Global Constraints

- Quest *definitions* (`QuestDefinition`) are plain immutable value classes in a static `const` catalog — not Drift-backed, matching how `Adventure`/`AdventureDifficulty` were done in Phase 4. Only the dated *instance* (`QuestInstance`) is persisted.
- An instance's `target`/`expReward`/`goldReward` are snapshotted from the catalog at creation time and never re-read from the catalog afterward — the design doc's invariant that "existing Quest target and reward snapshots stay stable" even if the catalog changes later.
- `features/quest` may depend on `features/player` (`PlayerRepository`, `PlayerState`) and `features/health` (`HealthSyncRepository`) — this mirrors how `SpendEnergyForAdventureUseCase` already depends on `PlayerRepository`. The reverse must never happen: `features/player` and `features/health` must never import anything from `features/quest`.
- `ClaimDailyQuestUseCase` is a deliberate, narrow exception to "always go through a repository's own abstraction": it takes the raw `AppDatabase` as a constructor dependency (like every repository already does) so it can wrap both the Player write and the Quest-instance write in one `db.transaction()`. This is the one place in the codebase that does this — contrast with Phase 3's design doc, which explicitly *parked* the equivalent cross-repository atomicity problem between `SyncHealthDataUseCase` and `CreditEnergyFromStepsUseCase` as an unresolved gap. Do not generalize this pattern elsewhere without a similar deliberate reason.
- `PlayerController` gains one new public method, `reload()` (Task 5) — a thin wrapper around its existing private `_loadPlayer()`. This is necessary because `ClaimDailyQuestUseCase` writes to the `Player` row through `PlayerRepository` directly, bypassing `PlayerController` entirely, so nothing would otherwise tell `PlayerController`'s cached state to refresh after a Quest claim (Home/Character screens would show stale EXP/Gold until some unrelated event happened to reload it).
- Duplicate-claim and duplicate-adventure-completion protection follows the same pattern established in Phase 4 for duplicate Adventure starts: a controller-level mutex (`_runExclusive`, copied verbatim from `PlayerController`'s existing implementation) serializes concurrent calls. Defense in depth: inside its Drift transaction, `ClaimDailyQuestUseCase` must re-read the stored instance by ID and require its stored status to still be `claimable` before it reads/writes Player state. It must use that stored instance's snapshotted rewards, not the caller-supplied object, so a stale second claim is rejected after the first claim changes the stored status to `claimed`.
- Every repository/use-case method still returns `Future<Result<T>>` — no exceptions cross a boundary, except internally within `ClaimDailyQuestUseCase`'s transaction callback, where a private exception type is used only to trigger Drift's automatic rollback-on-throw and is caught before ever leaving the use case.
- No new Drift table beyond `DailyQuestInstance`, no new dependency.
- Reward-adjacent logic gets real tests, matching every earlier phase's testing priority: the catalog, the repository, both use cases, and `ClaimDailyQuestUseCase`'s atomicity all get unit/integration tests. `JournalScreen` (now real Quest UI, not a placeholder) gets one widget-test file, matching the step-up in UI-test rigor Phase 4 established for screens with real interaction logic (not just layout).
- All commands below assume the working directory is `everstride-mobile/`.
- **Commit policy: not yet confirmed for this run.** `everstride-docs/AGENTS.md` absolutely prohibits `git commit` and running `flutter test` unless explicitly authorized per run — this plan itself was requested as planning-only ("ทำแค่ plan พอ ไม่ต้อง commit"), so no commit authorization exists yet for actually *executing* these tasks. Whoever runs this plan must get that confirmation first (matching how the Phase 3/3.1/4 runs were each separately authorized — the last confirmed convention was: authorized, but with no `Co-Authored-By` trailer on any commit). `git push` is never allowed, under any circumstance, for any run of this plan.

---

### Task 1: Quest entities and the fixed Daily Quest catalog

**Files:**

- Create: `everstride-mobile/lib/features/quest/domain/entities/quest_definition.dart`
- Create: `everstride-mobile/lib/features/quest/domain/entities/quest_instance.dart`
- Create: `everstride-mobile/lib/features/quest/domain/quest_catalog.dart`
- Test: `everstride-mobile/test/features/quest/domain/quest_catalog_test.dart`

**Interfaces:**

- Consumes: nothing (pure data).
- Produces: `QuestObjectiveType` (`dailySteps`, `adventureCompletions`); `QuestDefinition` (`id`, `title`, `description`, `objectiveType`, `target`, `expReward`, `goldReward`, `sortOrder`); `QuestStatus` (`inProgress`, `claimable`, `claimed`, `expired`); `QuestInstance` (`id`, `questId`, `date`, `objectiveType`, `target`, `progress`, `status`, `expReward`, `goldReward`, `claimedAt`, plus `copyWith`); the top-level `const dailyQuestCatalog` (3 entries). Tasks 2–5 consume all of this.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/quest/domain/quest_catalog_test.dart
import 'package:everstride/features/quest/domain/entities/quest_definition.dart';
import 'package:everstride/features/quest/domain/quest_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the fixed Daily Quest set matches the documented values exactly', () {
    expect(dailyQuestCatalog.length, 3);

    final firstSteps = dailyQuestCatalog.firstWhere((q) => q.id == 'daily_steps_1000');
    expect(firstSteps.objectiveType, QuestObjectiveType.dailySteps);
    expect(firstSteps.target, 1000);
    expect(firstSteps.expReward, 10);
    expect(firstSteps.goldReward, 5);

    final wanderersPath = dailyQuestCatalog.firstWhere((q) => q.id == 'daily_steps_3000');
    expect(wanderersPath.objectiveType, QuestObjectiveType.dailySteps);
    expect(wanderersPath.target, 3000);
    expect(wanderersPath.expReward, 20);
    expect(wanderersPath.goldReward, 10);

    final trailbound = dailyQuestCatalog.firstWhere((q) => q.id == 'daily_adventure_1');
    expect(trailbound.objectiveType, QuestObjectiveType.adventureCompletions);
    expect(trailbound.target, 1);
    expect(trailbound.expReward, 15);
    expect(trailbound.goldReward, 10);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/quest/domain/quest_catalog_test.dart`
Expected: FAIL — `quest_catalog.dart` doesn't exist yet.

- [ ] **Step 3: Write the Quest definition entity**

```dart
// lib/features/quest/domain/entities/quest_definition.dart

enum QuestObjectiveType { dailySteps, adventureCompletions }

/// Static game content — the fixed shape of a Daily Quest template. See
/// everstride-docs/game-design/quests.md.
class QuestDefinition {
  const QuestDefinition({
    required this.id,
    required this.title,
    required this.description,
    required this.objectiveType,
    required this.target,
    required this.expReward,
    required this.goldReward,
    required this.sortOrder,
  });

  final String id;
  final String title;
  final String description;
  final QuestObjectiveType objectiveType;
  final int target;
  final int expReward;
  final int goldReward;
  final int sortOrder;
}
```

- [ ] **Step 4: Write the Quest instance entity**

```dart
// lib/features/quest/domain/entities/quest_instance.dart
import 'quest_definition.dart';

enum QuestStatus { inProgress, claimable, claimed, expired }

/// A Quest definition's state for one local calendar date. Target and
/// reward values are snapshotted at creation time so a later catalog
/// change never silently alters a Quest a player has already begun. See
/// everstride-docs/game-design/quests.md.
class QuestInstance {
  const QuestInstance({
    required this.id,
    required this.questId,
    required this.date,
    required this.objectiveType,
    required this.target,
    required this.progress,
    required this.status,
    required this.expReward,
    required this.goldReward,
    this.claimedAt,
  });

  final String id;
  final String questId;
  final DateTime date;
  final QuestObjectiveType objectiveType;
  final int target;
  final int progress;
  final QuestStatus status;
  final int expReward;
  final int goldReward;
  final DateTime? claimedAt;

  QuestInstance copyWith({
    int? progress,
    QuestStatus? status,
    DateTime? claimedAt,
  }) {
    return QuestInstance(
      id: id,
      questId: questId,
      date: date,
      objectiveType: objectiveType,
      target: target,
      progress: progress ?? this.progress,
      status: status ?? this.status,
      expReward: expReward,
      goldReward: goldReward,
      claimedAt: claimedAt ?? this.claimedAt,
    );
  }
}
```

- [ ] **Step 5: Write the catalog**

```dart
// lib/features/quest/domain/quest_catalog.dart
import 'entities/quest_definition.dart';

/// The fixed set of three Daily Quests for the Phase 5 MVP. Values match
/// everstride-docs/game-design/quests.md exactly — change them there
/// first if they ever need to change.
const dailyQuestCatalog = [
  QuestDefinition(
    id: 'daily_steps_1000',
    title: 'First Steps',
    description: 'Walk 1,000 Steps today.',
    objectiveType: QuestObjectiveType.dailySteps,
    target: 1000,
    expReward: 10,
    goldReward: 5,
    sortOrder: 0,
  ),
  QuestDefinition(
    id: 'daily_steps_3000',
    title: "Wanderer's Path",
    description: 'Walk 3,000 Steps today.',
    objectiveType: QuestObjectiveType.dailySteps,
    target: 3000,
    expReward: 20,
    goldReward: 10,
    sortOrder: 1,
  ),
  QuestDefinition(
    id: 'daily_adventure_1',
    title: 'Trailbound',
    description: 'Complete 1 Adventure today.',
    objectiveType: QuestObjectiveType.adventureCompletions,
    target: 1,
    expReward: 15,
    goldReward: 10,
    sortOrder: 2,
  ),
];
```

- [ ] **Step 6: Run test to verify it passes**

Run: `flutter test test/features/quest/domain/quest_catalog_test.dart`
Expected: PASS (1 test)

- [ ] **Step 7: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Stage (do not commit without confirmed authorization — see Global Constraints)**

```bash
git add lib/features/quest/domain/entities/quest_definition.dart lib/features/quest/domain/entities/quest_instance.dart lib/features/quest/domain/quest_catalog.dart test/features/quest/domain/quest_catalog_test.dart
```

---

### Task 2: `DailyQuestInstance` table and `QuestRepository`

**Files:**

- Modify: `everstride-mobile/lib/core/database/app_database.dart`
- Create: `everstride-mobile/lib/features/quest/domain/repositories/quest_repository.dart` (replaces the existing empty marker interface)
- Create: `everstride-mobile/lib/features/quest/data/repositories/quest_repository_impl.dart`
- Test: `everstride-mobile/test/features/quest/data/repositories/quest_repository_impl_test.dart`

**Interfaces:**

- Consumes: `QuestInstance`, `QuestObjectiveType`, `QuestStatus` (Task 1); `AppDatabase`, `appDatabaseProvider` (existing).
- Produces: abstract `QuestRepository` with `getInstancesForDate(DateTime)`, `getInstanceById(String)`, `getActiveInstancesBeforeDate(DateTime)`, `saveInstance(QuestInstance)`; `QuestRepositoryImpl`; `questRepositoryProvider`. Tasks 3–5 consume all of this.

- [ ] **Step 1: Write the failing test**

```dart
// test/features/quest/data/repositories/quest_repository_impl_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/database/app_database.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/quest/data/repositories/quest_repository_impl.dart';
import 'package:everstride/features/quest/domain/entities/quest_definition.dart';
import 'package:everstride/features/quest/domain/entities/quest_instance.dart';

void main() {
  late AppDatabase database;
  late QuestRepositoryImpl repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = QuestRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('getInstancesForDate returns an empty list when none exist', () async {
    final result = await repository.getInstancesForDate(DateTime(2026, 9, 10));
    expect((result as Ok<List<QuestInstance>>).value, isEmpty);
  });

  test('saveInstance then getInstancesForDate round-trips the same values', () async {
    final instance = QuestInstance(
      id: '2026-09-10_daily_steps_1000',
      questId: 'daily_steps_1000',
      date: DateTime(2026, 9, 10),
      objectiveType: QuestObjectiveType.dailySteps,
      target: 1000,
      progress: 250,
      status: QuestStatus.inProgress,
      expReward: 10,
      goldReward: 5,
    );
    final saveResult = await repository.saveInstance(instance);
    expect(saveResult, isA<Ok<bool>>());

    final getResult = await repository.getInstancesForDate(DateTime(2026, 9, 10));
    final instances = (getResult as Ok<List<QuestInstance>>).value;
    expect(instances, hasLength(1));
    expect(instances.first.progress, 250);
    expect(instances.first.status, QuestStatus.inProgress);
  });

  test('saveInstance overwrites the same id instead of duplicating', () async {
    final first = QuestInstance(
      id: '2026-09-10_daily_steps_1000',
      questId: 'daily_steps_1000',
      date: DateTime(2026, 9, 10),
      objectiveType: QuestObjectiveType.dailySteps,
      target: 1000,
      progress: 250,
      status: QuestStatus.inProgress,
      expReward: 10,
      goldReward: 5,
    );
    await repository.saveInstance(first);
    await repository.saveInstance(first.copyWith(progress: 1000, status: QuestStatus.claimable));

    final getResult = await repository.getInstancesForDate(DateTime(2026, 9, 10));
    final instances = (getResult as Ok<List<QuestInstance>>).value;
    expect(instances, hasLength(1));
    expect(instances.first.progress, 1000);
    expect(instances.first.status, QuestStatus.claimable);
  });

  test('getInstanceById returns the current stored instance', () async {
    final instance = QuestInstance(
      id: '2026-09-10_daily_steps_1000',
      questId: 'daily_steps_1000',
      date: DateTime(2026, 9, 10),
      objectiveType: QuestObjectiveType.dailySteps,
      target: 1000,
      progress: 1000,
      status: QuestStatus.claimable,
      expReward: 10,
      goldReward: 5,
    );
    await repository.saveInstance(instance);

    final result = await repository.getInstanceById(instance.id);
    final stored = (result as Ok<QuestInstance?>).value;
    expect(stored?.status, QuestStatus.claimable);
  });

  test('getActiveInstancesBeforeDate returns only in-progress/claimable rows dated earlier', () async {
    final yesterdayInProgress = QuestInstance(
      id: '2026-09-09_daily_steps_1000',
      questId: 'daily_steps_1000',
      date: DateTime(2026, 9, 9),
      objectiveType: QuestObjectiveType.dailySteps,
      target: 1000,
      progress: 200,
      status: QuestStatus.inProgress,
      expReward: 10,
      goldReward: 5,
    );
    final yesterdayClaimed = QuestInstance(
      id: '2026-09-09_daily_adventure_1',
      questId: 'daily_adventure_1',
      date: DateTime(2026, 9, 9),
      objectiveType: QuestObjectiveType.adventureCompletions,
      target: 1,
      progress: 1,
      status: QuestStatus.claimed,
      expReward: 15,
      goldReward: 10,
      claimedAt: DateTime(2026, 9, 9, 10),
    );
    final todayInProgress = QuestInstance(
      id: '2026-09-10_daily_steps_1000',
      questId: 'daily_steps_1000',
      date: DateTime(2026, 9, 10),
      objectiveType: QuestObjectiveType.dailySteps,
      target: 1000,
      progress: 100,
      status: QuestStatus.inProgress,
      expReward: 10,
      goldReward: 5,
    );
    await repository.saveInstance(yesterdayInProgress);
    await repository.saveInstance(yesterdayClaimed);
    await repository.saveInstance(todayInProgress);

    final result = await repository.getActiveInstancesBeforeDate(DateTime(2026, 9, 10));
    final instances = (result as Ok<List<QuestInstance>>).value;

    expect(instances, hasLength(1));
    expect(instances.first.id, '2026-09-09_daily_steps_1000');
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/features/quest/data/repositories/quest_repository_impl_test.dart`
Expected: FAIL — `DailyQuestInstance`/`QuestRepositoryImpl` don't exist yet.

- [ ] **Step 3: Add the `DailyQuestInstance` table and migration**

Open `lib/core/database/app_database.dart`. Read it fresh first — it currently has `HealthDaily`, `Player`, `AppSettings`, `DebugStepSeedCursors` at `schemaVersion = 5`. Add this table:

```dart
class DailyQuestInstance extends Table {
  TextColumn get id => text()();
  TextColumn get questId => text()();
  TextColumn get date => text()();
  TextColumn get objectiveType => text()();
  IntColumn get target => integer()();
  IntColumn get progress => integer()();
  TextColumn get status => text()();
  IntColumn get expReward => integer()();
  IntColumn get goldReward => integer()();
  DateTimeColumn get claimedAt => dateTime().nullable()();

  @override
  Set<Column> get primaryKey => {id};
}
```

Change `@DriftDatabase(tables: [HealthDaily, Player, AppSettings, DebugStepSeedCursors])` to `@DriftDatabase(tables: [HealthDaily, Player, AppSettings, DebugStepSeedCursors, DailyQuestInstance])`.

Change `int get schemaVersion => 5;` to `int get schemaVersion => 6;` and extend the existing `migration` override (do not remove the earlier `from < 2`/`from < 3`/`from < 4`/`from < 5` branches):

```dart
      if (from < 6) {
        await m.createTable(dailyQuestInstance);
      }
```

- [ ] **Step 4: Regenerate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: `lib/core/database/app_database.g.dart` is regenerated with no errors.

- [ ] **Step 5: Write the repository interface**

```dart
// lib/features/quest/domain/repositories/quest_repository.dart
import '../../../../core/errors/result.dart';
import '../entities/quest_instance.dart';

/// Reads/writes Daily Quest instances. Dumb CRUD only — rollover,
/// progress calculation, and claim validation all live in use cases.
abstract class QuestRepository {
  Future<Result<List<QuestInstance>>> getInstancesForDate(DateTime date);
  Future<Result<QuestInstance?>> getInstanceById(String id);
  Future<Result<List<QuestInstance>>> getActiveInstancesBeforeDate(DateTime date);
  Future<Result<bool>> saveInstance(QuestInstance instance);
}
```

- [ ] **Step 6: Write the Drift-backed implementation**

The row→entity mapping is written inline (not as a separate private helper with an explicit parameter type) because `drift_dev`'s generated row-class name for the `DailyQuestInstance` table isn't spelled out anywhere in this plan — inline lambdas let the compiler infer it instead of this plan guessing wrong. Once this compiles, feel free to extract a helper using whatever the real generated type turns out to be.

```dart
// lib/features/quest/data/repositories/quest_repository_impl.dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/entities/quest_definition.dart';
import '../../domain/entities/quest_instance.dart';
import '../../domain/repositories/quest_repository.dart';

class QuestRepositoryImpl implements QuestRepository {
  QuestRepositoryImpl(this._db);

  final AppDatabase _db;

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  @override
  Future<Result<List<QuestInstance>>> getInstancesForDate(DateTime date) async {
    try {
      final rows = await (_db.select(_db.dailyQuestInstance)
            ..where((t) => t.date.equals(_dateKey(date))))
          .get();
      return Ok(rows
          .map(
            (row) => QuestInstance(
              id: row.id,
              questId: row.questId,
              date: DateTime.parse(row.date),
              objectiveType: QuestObjectiveType.values.byName(row.objectiveType),
              target: row.target,
              progress: row.progress,
              status: QuestStatus.values.byName(row.status),
              expReward: row.expReward,
              goldReward: row.goldReward,
              claimedAt: row.claimedAt,
            ),
          )
          .toList());
    } catch (e) {
      AppLogger.error('quest.state', 'Failed to read quest instances for $date', e);
      return Err(Failure('Failed to read quest instances', cause: e));
    }
  }

  @override
  Future<Result<QuestInstance?>> getInstanceById(String id) async {
    try {
      final row = await (_db.select(_db.dailyQuestInstance)
            ..where((t) => t.id.equals(id)))
          .getSingleOrNull();
      if (row == null) return const Ok(null);
      return Ok(
        QuestInstance(
          id: row.id,
          questId: row.questId,
          date: DateTime.parse(row.date),
          objectiveType: QuestObjectiveType.values.byName(row.objectiveType),
          target: row.target,
          progress: row.progress,
          status: QuestStatus.values.byName(row.status),
          expReward: row.expReward,
          goldReward: row.goldReward,
          claimedAt: row.claimedAt,
        ),
      );
    } catch (e) {
      AppLogger.error('quest.state', 'Failed to read quest instance $id', e);
      return Err(Failure('Failed to read quest instance', cause: e));
    }
  }

  @override
  Future<Result<List<QuestInstance>>> getActiveInstancesBeforeDate(DateTime date) async {
    try {
      final key = _dateKey(date);
      final rows = await (_db.select(_db.dailyQuestInstance)
            ..where(
              (t) =>
                  t.date.isSmallerThanValue(key) &
                  (t.status.equals(QuestStatus.inProgress.name) |
                      t.status.equals(QuestStatus.claimable.name)),
            ))
          .get();
      return Ok(rows
          .map(
            (row) => QuestInstance(
              id: row.id,
              questId: row.questId,
              date: DateTime.parse(row.date),
              objectiveType: QuestObjectiveType.values.byName(row.objectiveType),
              target: row.target,
              progress: row.progress,
              status: QuestStatus.values.byName(row.status),
              expReward: row.expReward,
              goldReward: row.goldReward,
              claimedAt: row.claimedAt,
            ),
          )
          .toList());
    } catch (e) {
      AppLogger.error('quest.state', 'Failed to read active quest instances before $date', e);
      return Err(Failure('Failed to read active quest instances', cause: e));
    }
  }

  @override
  Future<Result<bool>> saveInstance(QuestInstance instance) async {
    try {
      await _db.into(_db.dailyQuestInstance).insertOnConflictUpdate(
            DailyQuestInstanceCompanion.insert(
              id: instance.id,
              questId: instance.questId,
              date: _dateKey(instance.date),
              objectiveType: instance.objectiveType.name,
              target: instance.target,
              progress: instance.progress,
              status: instance.status.name,
              expReward: instance.expReward,
              goldReward: instance.goldReward,
              claimedAt: Value(instance.claimedAt),
            ),
          );
      return const Ok(true);
    } catch (e) {
      AppLogger.error('quest.state', 'Failed to save quest instance ${instance.id}', e);
      return Err(Failure('Failed to save quest instance', cause: e));
    }
  }
}

final questRepositoryProvider = Provider<QuestRepository>((ref) {
  return QuestRepositoryImpl(ref.watch(appDatabaseProvider));
});
```

- [ ] **Step 7: Run test to verify it passes**

Run: `flutter test test/features/quest/data/repositories/quest_repository_impl_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 8: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 9: Stage (do not commit without confirmed authorization)**

```bash
git add lib/core/database/app_database.dart lib/core/database/app_database.g.dart lib/features/quest/domain/repositories/quest_repository.dart lib/features/quest/data/repositories/quest_repository_impl.dart test/features/quest/data/repositories/quest_repository_impl_test.dart
```

---

### Task 3: `EnsureDailyQuestsUseCase` — rollover and Step-progress refresh

**Files:**

- Create: `everstride-mobile/lib/features/quest/domain/usecases/ensure_daily_quests_usecase.dart`
- Test: `everstride-mobile/test/features/quest/domain/usecases/ensure_daily_quests_usecase_test.dart`

**Interfaces:**

- Consumes: `QuestRepository` (Task 2); `HealthSyncRepository`, `HealthDailyRecord` (existing, unchanged); `dailyQuestCatalog`, `QuestInstance`, `QuestObjectiveType`, `QuestStatus` (Task 1).
- Produces: `EnsureDailyQuestsUseCase(QuestRepository, HealthSyncRepository)` with `Future<Result<List<QuestInstance>>> call({DateTime? now})` — returns today's instances after rollover + refresh. Tasks 4 and 5 consume this.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/quest/domain/usecases/ensure_daily_quests_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/health/domain/repositories/health_sync_repository.dart';
import 'package:everstride/features/quest/domain/entities/quest_instance.dart';
import 'package:everstride/features/quest/domain/repositories/quest_repository.dart';
import 'package:everstride/features/quest/domain/usecases/ensure_daily_quests_usecase.dart';

class _FakeQuestRepository implements QuestRepository {
  final Map<String, QuestInstance> store = {};

  @override
  Future<Result<List<QuestInstance>>> getInstancesForDate(DateTime date) async {
    final key = _key(date);
    return Ok(store.values.where((i) => _key(i.date) == key).toList());
  }

  @override
  Future<Result<QuestInstance?>> getInstanceById(String id) async => Ok(store[id]);

  @override
  Future<Result<List<QuestInstance>>> getActiveInstancesBeforeDate(DateTime date) async {
    final key = _key(date);
    return Ok(
      store.values
          .where(
            (i) =>
                _key(i.date).compareTo(key) < 0 &&
                (i.status == QuestStatus.inProgress || i.status == QuestStatus.claimable),
          )
          .toList(),
    );
  }

  @override
  Future<Result<bool>> saveInstance(QuestInstance instance) async {
    store[instance.id] = instance;
    return const Ok(true);
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _FakeHealthSyncRepository implements HealthSyncRepository {
  _FakeHealthSyncRepository(this.totalSteps);

  final int totalSteps;

  @override
  Future<Result<HealthDailyRecord?>> getRecord(DateTime date) async {
    return Ok(HealthDailyRecord(date: date, totalSteps: totalSteps, rewardedSteps: 0, lastSyncedAt: date));
  }

  @override
  Future<Result<int>> getTotalRewardedSteps() async => const Ok(0);

  @override
  Future<Result<DateTime?>> getMostRecentSyncedDate() async => const Ok(null);

  @override
  Future<Result<bool>> upsertRecord(HealthDailyRecord record) async => const Ok(true);
}

void main() {
  final today = DateTime(2026, 9, 10);

  test('first-ever call creates all 3 quests in progress with zero progress', () async {
    final questRepo = _FakeQuestRepository();
    final useCase = EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository(0));

    final result = await useCase.call(now: today);
    final instances = (result as Ok<List<QuestInstance>>).value;

    expect(instances, hasLength(3));
    expect(instances.every((i) => i.status == QuestStatus.inProgress), isTrue);
    expect(instances.firstWhere((i) => i.questId == 'daily_steps_1000').progress, 0);
  });

  test('sufficient Steps makes a Step quest claimable but leaves Trailbound untouched', () async {
    final questRepo = _FakeQuestRepository();
    final useCase = EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository(1500));

    final result = await useCase.call(now: today);
    final instances = (result as Ok<List<QuestInstance>>).value;

    final firstSteps = instances.firstWhere((i) => i.questId == 'daily_steps_1000');
    expect(firstSteps.status, QuestStatus.claimable);
    expect(firstSteps.progress, 1500);

    final wanderersPath = instances.firstWhere((i) => i.questId == 'daily_steps_3000');
    expect(wanderersPath.status, QuestStatus.inProgress);

    final trailbound = instances.firstWhere((i) => i.questId == 'daily_adventure_1');
    expect(trailbound.status, QuestStatus.inProgress);
    expect(trailbound.progress, 0);
  });

  test('a downward Step correction reverts a not-yet-claimed quest from claimable to in progress', () async {
    final questRepo = _FakeQuestRepository();
    await EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository(1500)).call(now: today);

    final result = await EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository(500)).call(now: today);
    final instances = (result as Ok<List<QuestInstance>>).value;

    final firstSteps = instances.firstWhere((i) => i.questId == 'daily_steps_1000');
    expect(firstSteps.status, QuestStatus.inProgress);
    expect(firstSteps.progress, 500);
  });

  test('a claimed quest is never reverted by a later Step correction', () async {
    final questRepo = _FakeQuestRepository();
    await EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository(1500)).call(now: today);
    final claimed = questRepo.store['2026-09-10_daily_steps_1000']!;
    await questRepo.saveInstance(claimed.copyWith(status: QuestStatus.claimed, claimedAt: today));

    final result = await EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository(0)).call(now: today);
    final instances = (result as Ok<List<QuestInstance>>).value;

    final firstSteps = instances.firstWhere((i) => i.questId == 'daily_steps_1000');
    expect(firstSteps.status, QuestStatus.claimed);
  });

  test('rollover expires yesterdays unclaimed instances and creates fresh ones for today', () async {
    final questRepo = _FakeQuestRepository();
    final yesterday = DateTime(2026, 9, 9);
    await EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository(200)).call(now: yesterday);

    final result = await EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository(0)).call(now: today);
    final todayInstances = (result as Ok<List<QuestInstance>>).value;

    expect(todayInstances, hasLength(3));
    expect(todayInstances.every((i) => i.progress == 0 && i.status == QuestStatus.inProgress), isTrue);

    final yesterdayAfter = await questRepo.getInstancesForDate(yesterday);
    final yesterdayInstances = (yesterdayAfter as Ok<List<QuestInstance>>).value;
    expect(yesterdayInstances.every((i) => i.status == QuestStatus.expired), isTrue);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/quest/domain/usecases/ensure_daily_quests_usecase_test.dart`
Expected: FAIL — `ensure_daily_quests_usecase.dart` doesn't exist yet.

- [ ] **Step 3: Write the use case**

```dart
// lib/features/quest/domain/usecases/ensure_daily_quests_usecase.dart
import '../../../../core/errors/result.dart';
import '../../../health/domain/repositories/health_sync_repository.dart';
import '../entities/quest_definition.dart';
import '../entities/quest_instance.dart';
import '../quest_catalog.dart';
import '../repositories/quest_repository.dart';

/// Ensures today's fixed Daily Quest set exists, expires yesterday's
/// unclaimed instances (lazy rollover — no background timer), and
/// refreshes Daily-Steps-objective progress from the local health-sync
/// record. Adventure-objective progress is NOT touched here — see
/// RecordAdventureCompletionUseCase. See
/// everstride-docs/game-design/quests.md.
class EnsureDailyQuestsUseCase {
  EnsureDailyQuestsUseCase(this._questRepository, this._healthSyncRepository);

  final QuestRepository _questRepository;
  final HealthSyncRepository _healthSyncRepository;

  Future<Result<List<QuestInstance>>> call({DateTime? now}) async {
    final today = _atMidnight(now ?? DateTime.now());

    final expireResult = await _expireStaleInstances(today);
    if (expireResult case Err(:final failure)) return Err(failure);

    final ensureResult = await _ensureTodayInstancesExist(today);
    if (ensureResult case Err(:final failure)) return Err(failure);

    return _refreshStepProgress(today);
  }

  Future<Result<void>> _expireStaleInstances(DateTime today) async {
    final staleResult = await _questRepository.getActiveInstancesBeforeDate(today);
    final List<QuestInstance> stale;
    switch (staleResult) {
      case Ok(value: final v):
        stale = v;
      case Err(:final failure):
        return Err(failure);
    }
    for (final instance in stale) {
      final saveResult = await _questRepository.saveInstance(
        instance.copyWith(status: QuestStatus.expired),
      );
      if (saveResult case Err(:final failure)) return Err(failure);
    }
    return const Ok(null);
  }

  Future<Result<void>> _ensureTodayInstancesExist(DateTime today) async {
    final existingResult = await _questRepository.getInstancesForDate(today);
    final List<QuestInstance> existing;
    switch (existingResult) {
      case Ok(value: final v):
        existing = v;
      case Err(:final failure):
        return Err(failure);
    }
    final existingQuestIds = existing.map((i) => i.questId).toSet();

    for (final definition in dailyQuestCatalog) {
      if (existingQuestIds.contains(definition.id)) continue;
      final saveResult = await _questRepository.saveInstance(
        QuestInstance(
          id: '${_dateKey(today)}_${definition.id}',
          questId: definition.id,
          date: today,
          objectiveType: definition.objectiveType,
          target: definition.target,
          progress: 0,
          status: QuestStatus.inProgress,
          expReward: definition.expReward,
          goldReward: definition.goldReward,
        ),
      );
      if (saveResult case Err(:final failure)) return Err(failure);
    }
    return const Ok(null);
  }

  Future<Result<List<QuestInstance>>> _refreshStepProgress(DateTime today) async {
    final recordResult = await _healthSyncRepository.getRecord(today);
    final int totalStepsToday;
    switch (recordResult) {
      case Ok(value: final record):
        totalStepsToday = record?.totalSteps ?? 0;
      case Err(:final failure):
        return Err(failure);
    }

    final instancesResult = await _questRepository.getInstancesForDate(today);
    final List<QuestInstance> instances;
    switch (instancesResult) {
      case Ok(value: final v):
        instances = v;
      case Err(:final failure):
        return Err(failure);
    }

    final refreshed = <QuestInstance>[];
    for (final instance in instances) {
      if (instance.status == QuestStatus.claimed || instance.status == QuestStatus.expired) {
        refreshed.add(instance);
        continue;
      }
      final newProgress = instance.objectiveType == QuestObjectiveType.dailySteps
          ? totalStepsToday
          : instance.progress;
      final newStatus = newProgress >= instance.target ? QuestStatus.claimable : QuestStatus.inProgress;
      final updated = instance.copyWith(progress: newProgress, status: newStatus);
      final saveResult = await _questRepository.saveInstance(updated);
      if (saveResult case Err(:final failure)) return Err(failure);
      refreshed.add(updated);
    }
    return Ok(refreshed);
  }

  DateTime _atMidnight(DateTime date) => DateTime(date.year, date.month, date.day);

  String _dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/quest/domain/usecases/ensure_daily_quests_usecase_test.dart`
Expected: PASS (5 tests)

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Stage (do not commit without confirmed authorization)**

```bash
git add lib/features/quest/domain/usecases/ensure_daily_quests_usecase.dart test/features/quest/domain/usecases/ensure_daily_quests_usecase_test.dart
```

---

### Task 4: `RecordAdventureCompletionUseCase` and `ClaimDailyQuestUseCase`

**Files:**

- Create: `everstride-mobile/lib/features/quest/domain/usecases/record_adventure_completion_usecase.dart`
- Create: `everstride-mobile/lib/features/quest/domain/usecases/claim_daily_quest_usecase.dart`
- Test: `everstride-mobile/test/features/quest/domain/usecases/record_adventure_completion_usecase_test.dart`
- Test: `everstride-mobile/test/features/quest/domain/usecases/claim_daily_quest_usecase_test.dart`

**Interfaces:**

- Consumes: `QuestRepository` (Task 2); `EnsureDailyQuestsUseCase` (Task 3); `PlayerRepository`, `PlayerState` (existing, unchanged); `AppDatabase` (existing).
- Produces: `RecordAdventureCompletionUseCase(QuestRepository, EnsureDailyQuestsUseCase)` with `Future<Result<void>> call({DateTime? now})`; `ClaimDailyQuestUseCase(QuestRepository, PlayerRepository, AppDatabase)` with `Future<Result<PlayerState>> call(QuestInstance instance)`. Task 5 consumes both.

- [ ] **Step 1: Write the failing tests for `RecordAdventureCompletionUseCase`**

```dart
// test/features/quest/domain/usecases/record_adventure_completion_usecase_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/health/domain/repositories/health_sync_repository.dart';
import 'package:everstride/features/quest/domain/entities/quest_instance.dart';
import 'package:everstride/features/quest/domain/repositories/quest_repository.dart';
import 'package:everstride/features/quest/domain/usecases/ensure_daily_quests_usecase.dart';
import 'package:everstride/features/quest/domain/usecases/record_adventure_completion_usecase.dart';

class _FakeQuestRepository implements QuestRepository {
  final Map<String, QuestInstance> store = {};

  @override
  Future<Result<List<QuestInstance>>> getInstancesForDate(DateTime date) async {
    final key = _key(date);
    return Ok(store.values.where((i) => _key(i.date) == key).toList());
  }

  @override
  Future<Result<QuestInstance?>> getInstanceById(String id) async => Ok(store[id]);

  @override
  Future<Result<List<QuestInstance>>> getActiveInstancesBeforeDate(DateTime date) async {
    final key = _key(date);
    return Ok(
      store.values
          .where(
            (i) =>
                _key(i.date).compareTo(key) < 0 &&
                (i.status == QuestStatus.inProgress || i.status == QuestStatus.claimable),
          )
          .toList(),
    );
  }

  @override
  Future<Result<bool>> saveInstance(QuestInstance instance) async {
    store[instance.id] = instance;
    return const Ok(true);
  }

  String _key(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

class _FakeHealthSyncRepository implements HealthSyncRepository {
  @override
  Future<Result<HealthDailyRecord?>> getRecord(DateTime date) async => const Ok(null);
  @override
  Future<Result<int>> getTotalRewardedSteps() async => const Ok(0);
  @override
  Future<Result<DateTime?>> getMostRecentSyncedDate() async => const Ok(null);
  @override
  Future<Result<bool>> upsertRecord(HealthDailyRecord record) async => const Ok(true);
}

void main() {
  final today = DateTime(2026, 9, 10);

  test('a first completion advances Trailbound from 0 to 1 and makes it claimable', () async {
    final questRepo = _FakeQuestRepository();
    final ensureUseCase = EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository());
    final useCase = RecordAdventureCompletionUseCase(questRepo, ensureUseCase);

    await useCase.call(now: today);

    final result = await questRepo.getInstancesForDate(today);
    final trailbound =
        (result as Ok<List<QuestInstance>>).value.firstWhere((i) => i.questId == 'daily_adventure_1');
    expect(trailbound.progress, 1);
    expect(trailbound.status, QuestStatus.claimable);
  });

  test('a completion after Trailbound is already claimed does not change it', () async {
    final questRepo = _FakeQuestRepository();
    final ensureUseCase = EnsureDailyQuestsUseCase(questRepo, _FakeHealthSyncRepository());
    final useCase = RecordAdventureCompletionUseCase(questRepo, ensureUseCase);

    await useCase.call(now: today);
    final claimable = questRepo.store['2026-09-10_daily_adventure_1']!;
    await questRepo.saveInstance(claimable.copyWith(status: QuestStatus.claimed, claimedAt: today));

    await useCase.call(now: today);

    final result = await questRepo.getInstancesForDate(today);
    final trailbound =
        (result as Ok<List<QuestInstance>>).value.firstWhere((i) => i.questId == 'daily_adventure_1');
    expect(trailbound.progress, 1);
    expect(trailbound.status, QuestStatus.claimed);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/quest/domain/usecases/record_adventure_completion_usecase_test.dart`
Expected: FAIL — `record_adventure_completion_usecase.dart` doesn't exist yet.

- [ ] **Step 3: Write `RecordAdventureCompletionUseCase`**

```dart
// lib/features/quest/domain/usecases/record_adventure_completion_usecase.dart
import '../../../../core/errors/result.dart';
import '../entities/quest_definition.dart';
import '../entities/quest_instance.dart';
import '../repositories/quest_repository.dart';
import 'ensure_daily_quests_usecase.dart';

/// Advances today's Adventure-completion Quest(s) (Trailbound in the MVP
/// catalog) by one. Called only after a successful, once-resolved
/// Adventure — see everstride-docs/game-design/quests.md's "Adventure
/// objectives" section. Generic over however many
/// `adventureCompletions`-objective quests the catalog defines, rather
/// than hardcoding `daily_adventure_1`.
class RecordAdventureCompletionUseCase {
  RecordAdventureCompletionUseCase(this._questRepository, this._ensureDailyQuestsUseCase);

  final QuestRepository _questRepository;
  final EnsureDailyQuestsUseCase _ensureDailyQuestsUseCase;

  Future<Result<void>> call({DateTime? now}) async {
    final ensureResult = await _ensureDailyQuestsUseCase.call(now: now);
    final List<QuestInstance> todayInstances;
    switch (ensureResult) {
      case Ok(value: final v):
        todayInstances = v;
      case Err(:final failure):
        return Err(failure);
    }

    final adventureInstances =
        todayInstances.where((i) => i.objectiveType == QuestObjectiveType.adventureCompletions);
    for (final instance in adventureInstances) {
      if (instance.status == QuestStatus.claimed || instance.status == QuestStatus.expired) continue;
      final newProgress = instance.progress + 1;
      final newStatus = newProgress >= instance.target ? QuestStatus.claimable : QuestStatus.inProgress;
      final saveResult = await _questRepository.saveInstance(
        instance.copyWith(progress: newProgress, status: newStatus),
      );
      if (saveResult case Err(:final failure)) return Err(failure);
    }
    return const Ok(null);
  }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/quest/domain/usecases/record_adventure_completion_usecase_test.dart`
Expected: PASS (2 tests)

- [ ] **Step 5: Write the failing tests for `ClaimDailyQuestUseCase`**

```dart
// test/features/quest/domain/usecases/claim_daily_quest_usecase_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/database/app_database.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/player/data/repositories/player_repository_impl.dart';
import 'package:everstride/features/player/domain/repositories/player_repository.dart';
import 'package:everstride/features/quest/data/repositories/quest_repository_impl.dart';
import 'package:everstride/features/quest/domain/entities/quest_definition.dart';
import 'package:everstride/features/quest/domain/entities/quest_instance.dart';
import 'package:everstride/features/quest/domain/usecases/claim_daily_quest_usecase.dart';

void main() {
  late AppDatabase database;
  late PlayerRepositoryImpl playerRepository;
  late QuestRepositoryImpl questRepository;
  late ClaimDailyQuestUseCase useCase;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    playerRepository = PlayerRepositoryImpl(database);
    questRepository = QuestRepositoryImpl(database);
    useCase = ClaimDailyQuestUseCase(questRepository, playerRepository, database);
  });

  tearDown(() async {
    await database.close();
  });

  final claimableInstance = QuestInstance(
    id: '2026-09-10_daily_steps_1000',
    questId: 'daily_steps_1000',
    date: DateTime(2026, 9, 10),
    objectiveType: QuestObjectiveType.dailySteps,
    target: 1000,
    progress: 1000,
    status: QuestStatus.claimable,
    expReward: 10,
    goldReward: 5,
  );

  test('claiming a claimable instance grants its snapshotted EXP/Gold and marks it claimed', () async {
    await questRepository.saveInstance(claimableInstance);

    final result = await useCase.call(claimableInstance);
    final player = (result as Ok<PlayerState>).value;

    expect(player.exp, 10);
    expect(player.gold, 5);

    final storedResult = await questRepository.getInstancesForDate(DateTime(2026, 9, 10));
    final stored = (storedResult as Ok<List<QuestInstance>>).value.first;
    expect(stored.status, QuestStatus.claimed);
    expect(stored.claimedAt, isNotNull);
  });

  test('a stale second claim is rejected after the stored instance is claimed', () async {
    await questRepository.saveInstance(claimableInstance);

    final firstResult = await useCase.call(claimableInstance);
    expect(firstResult, isA<Ok<PlayerState>>());

    // This deliberately reuses the old claimable object, as a double tap or
    // delayed UI callback could. The use case must trust neither its status
    // nor its reward fields; it must re-read the stored row in the transaction.
    final duplicateResult = await useCase.call(claimableInstance);
    expect(duplicateResult, isA<Err<PlayerState>>());

    final playerResult = await playerRepository.getPlayer();
    final player = (playerResult as Ok<PlayerState>).value;
    expect(player.exp, 10);
    expect(player.gold, 5);
  });

  test('claiming with a reward that exactly fills the level threshold applies the level-up', () async {
    await playerRepository.savePlayer(
      const PlayerState(level: 1, exp: 90, energy: 0, gold: 0, pendingSteps: 0),
    );
    await questRepository.saveInstance(claimableInstance);

    final result = await useCase.call(claimableInstance);
    final player = (result as Ok<PlayerState>).value;

    expect(player.level, 2);
    expect(player.exp, 0);
  });
}
```

- [ ] **Step 6: Run tests to verify they fail**

Run: `flutter test test/features/quest/domain/usecases/claim_daily_quest_usecase_test.dart`
Expected: FAIL — `claim_daily_quest_usecase.dart` doesn't exist yet.

- [ ] **Step 7: Write `ClaimDailyQuestUseCase`**

```dart
// lib/features/quest/domain/usecases/claim_daily_quest_usecase.dart
import '../../../../core/database/app_database.dart';
import '../../../../core/errors/result.dart';
import '../../../player/domain/repositories/player_repository.dart';
import '../entities/quest_instance.dart';
import '../repositories/quest_repository.dart';

class _ClaimFailure implements Exception {
  _ClaimFailure(this.failure);
  final Failure failure;
}

/// Claims one Daily Quest instance: grants its snapshotted EXP/Gold to the
/// player and marks it claimed, both in one Drift transaction so a
/// failure partway through can never leave a player rewarded-but-unmarked
/// or marked-but-unrewarded. This is the one place in the codebase using
/// a real cross-repository Drift transaction — see this plan's Global
/// Constraints for why. See everstride-docs/game-design/quests.md's
/// "Rewards and claim behavior" and "Invariants" sections.
class ClaimDailyQuestUseCase {
  ClaimDailyQuestUseCase(this._questRepository, this._playerRepository, this._db);

  final QuestRepository _questRepository;
  final PlayerRepository _playerRepository;
  final AppDatabase _db;

  /// The caller provides an ID-bearing UI snapshot only. Status and rewards
  /// are always read from the stored row inside the transaction, so a stale
  /// second claim cannot grant its snapshot's rewards again.
  Future<Result<PlayerState>> call(QuestInstance instance) async {
    try {
      return await _db.transaction(() async {
        final instanceResult = await _questRepository.getInstanceById(instance.id);
        final QuestInstance? storedInstance;
        switch (instanceResult) {
          case Ok(value: final value):
            storedInstance = value;
          case Err(:final failure):
            throw _ClaimFailure(failure);
        }
        if (storedInstance == null || storedInstance.status != QuestStatus.claimable) {
          throw _ClaimFailure(const Failure('This quest cannot be claimed right now'));
        }

        final playerResult = await _playerRepository.getPlayer();
        final PlayerState player;
        switch (playerResult) {
          case Ok(value: final value):
            player = value;
          case Err(:final failure):
            throw _ClaimFailure(failure);
        }

        var newExp = player.exp + storedInstance.expReward;
        var newLevel = player.level;
        var expToNext = PlayerState.expToNextLevel(newLevel);
        while (newExp >= expToNext) {
          newExp -= expToNext;
          newLevel++;
          expToNext = PlayerState.expToNextLevel(newLevel);
        }
        final updatedPlayer = player.copyWith(
          exp: newExp,
          level: newLevel,
          gold: player.gold + storedInstance.goldReward,
        );
        final claimedInstance = storedInstance.copyWith(
          status: QuestStatus.claimed,
          claimedAt: DateTime.now(),
        );

        final playerSave = await _playerRepository.savePlayer(updatedPlayer);
        if (playerSave case Err(:final failure)) throw _ClaimFailure(failure);
        final questSave = await _questRepository.saveInstance(claimedInstance);
        if (questSave case Err(:final failure)) throw _ClaimFailure(failure);
        return Ok(updatedPlayer);
      });
    } on _ClaimFailure catch (e) {
      return Err(e.failure);
    } catch (e) {
      return Err(Failure('Failed to claim quest', cause: e));
    }
  }
}
```

- [ ] **Step 8: Run tests to verify they pass**

Run: `flutter test test/features/quest/domain/usecases/claim_daily_quest_usecase_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 9: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 10: Stage (do not commit without confirmed authorization)**

```bash
git add lib/features/quest/domain/usecases/record_adventure_completion_usecase.dart lib/features/quest/domain/usecases/claim_daily_quest_usecase.dart test/features/quest/domain/usecases/record_adventure_completion_usecase_test.dart test/features/quest/domain/usecases/claim_daily_quest_usecase_test.dart
```

---

### Task 5: `QuestController`, real Journal screen, and Adventure wiring

**Files:**

- Create: `everstride-mobile/lib/features/quest/presentation/controllers/quest_controller.dart`
- Modify: `everstride-mobile/lib/features/player/presentation/controllers/player_controller.dart` (add `reload()`)
- Modify: `everstride-mobile/lib/features/adventure/presentation/screens/adventure_screen.dart` (add one call)
- Modify: `everstride-mobile/lib/features/journal/presentation/screens/journal_screen.dart` (replaces the placeholder in full)
- Test: `everstride-mobile/test/features/journal/presentation/journal_screen_test.dart`

**Interfaces:**

- Consumes: `EnsureDailyQuestsUseCase`, `RecordAdventureCompletionUseCase`, `ClaimDailyQuestUseCase` (Tasks 3–4); `questRepositoryProvider` (Task 2); `healthSyncControllerProvider`, `healthSyncRepositoryProvider` (existing); `playerRepositoryProvider`, `playerControllerProvider`, `appDatabaseProvider` (existing).
- Produces: `QuestController` (`Notifier<AsyncValue<Result<List<QuestInstance>>>?>`) with `recordAdventureCompletion()` and `claim(QuestInstance)`; `questControllerProvider`. Nothing later in this plan consumes these further.

- [ ] **Step 1: Add `reload()` to `PlayerController`**

Open `lib/features/player/presentation/controllers/player_controller.dart`. Add this public method (anywhere among the other methods — e.g. right after `_loadPlayer`):

```dart
  /// Re-reads Player state from the repository. Needed because
  /// ClaimDailyQuestUseCase writes to the Player row through
  /// PlayerRepository directly (for its cross-repository transaction),
  /// bypassing this controller's own mutation methods — so nothing else
  /// would tell this controller's cached state to refresh after a Quest
  /// claim.
  Future<void> reload() => _loadPlayer();
```

Nothing else in this file changes.

- [ ] **Step 2: Write `QuestController`**

```dart
// lib/features/quest/presentation/controllers/quest_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../health/data/repositories/health_sync_repository_impl.dart';
import '../../../health/presentation/controllers/health_sync_controller.dart';
import '../../../player/data/repositories/player_repository_impl.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import '../../data/repositories/quest_repository_impl.dart';
import '../../domain/entities/quest_instance.dart';
import '../../domain/usecases/claim_daily_quest_usecase.dart';
import '../../domain/usecases/ensure_daily_quests_usecase.dart';
import '../../domain/usecases/record_adventure_completion_usecase.dart';

final ensureDailyQuestsUseCaseProvider = Provider<EnsureDailyQuestsUseCase>((ref) {
  return EnsureDailyQuestsUseCase(
    ref.watch(questRepositoryProvider),
    ref.watch(healthSyncRepositoryProvider),
  );
});

final recordAdventureCompletionUseCaseProvider = Provider<RecordAdventureCompletionUseCase>((ref) {
  return RecordAdventureCompletionUseCase(
    ref.watch(questRepositoryProvider),
    ref.watch(ensureDailyQuestsUseCaseProvider),
  );
});

final claimDailyQuestUseCaseProvider = Provider<ClaimDailyQuestUseCase>((ref) {
  return ClaimDailyQuestUseCase(
    ref.watch(questRepositoryProvider),
    ref.watch(playerRepositoryProvider),
    ref.watch(appDatabaseProvider),
  );
});

class QuestController extends Notifier<AsyncValue<Result<List<QuestInstance>>>?> {
  Future<void> _mutationQueue = Future.value();
  int _pendingMutations = 0;

  bool get isMutating => _pendingMutations > 0;

  @override
  AsyncValue<Result<List<QuestInstance>>>? build() {
    // Reactive composition, same pattern as PlayerController: refresh
    // Step-objective progress whenever a health sync completes, from any
    // trigger — no changes to HealthSyncController.
    ref.listen(healthSyncControllerProvider, (previous, next) {
      if (next is AsyncData) {
        _runExclusive(_refresh);
      }
    });
    _refresh();
    return null;
  }

  Future<void> _refresh() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(ensureDailyQuestsUseCaseProvider).call());
  }

  Future<T> _runExclusive<T>(Future<T> Function() action) {
    _pendingMutations++;
    final previous = _mutationQueue;
    final completer = Completer<T>();
    _mutationQueue = previous.then((_) async {
      try {
        completer.complete(await action());
      } catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      } finally {
        _pendingMutations--;
      }
    });
    return completer.future;
  }

  Future<void> recordAdventureCompletion() {
    return _runExclusive(() async {
      final result = await ref.read(recordAdventureCompletionUseCaseProvider).call();
      if (result case Err(:final failure)) {
        AppLogger.error('quest.state', 'Failed to record Adventure completion', failure);
      }
      await _refresh();
    });
  }

  Future<Result<bool>> claim(QuestInstance instance) {
    return _runExclusive(() async {
      final result = await ref.read(claimDailyQuestUseCaseProvider).call(instance);
      if (result case Err(:final failure)) {
        return Err(failure);
      }
      await ref.read(playerControllerProvider.notifier).reload();
      await _refresh();
      return const Ok(true);
    });
  }
}

final questControllerProvider =
    NotifierProvider<QuestController, AsyncValue<Result<List<QuestInstance>>>?>(QuestController.new);
```

- [ ] **Step 3: Wire `AdventureScreen`'s success path**

Open `lib/features/adventure/presentation/screens/adventure_screen.dart`. Add the import:

```dart
import 'dart:async';
```

```dart
import '../../../quest/presentation/controllers/quest_controller.dart';
```

In `_startAdventure`, in the `case Ok(:final value):` branch, add one line before `context.push(...)`:

```dart
      case Ok(:final value):
        unawaited(ref.read(questControllerProvider.notifier).recordAdventureCompletion());
        context.push(
```

(everything else in that branch — the `AdventureResult(...)` construction and the rest of the file — is unchanged). This is a direct call, not a reactive listener — see this plan's Architecture note for why that's the right call for Adventure completions specifically (unlike steps→Energy in Phase 3).

- [ ] **Step 4: Replace the Journal placeholder with real Quest UI**

```dart
// lib/features/journal/presentation/screens/journal_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../quest/domain/entities/quest_instance.dart';
import '../../../quest/domain/quest_catalog.dart';
import '../../../quest/presentation/controllers/quest_controller.dart';

class JournalScreen extends ConsumerWidget {
  const JournalScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final quests = ref.watch(questControllerProvider);
    final instances = switch (quests?.value) {
      Ok(:final value) => value,
      _ => null,
    };

    if (instances == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Journal')),
        body: const Center(child: Text('Loading...')),
      );
    }

    final sortedInstances = [...instances]
      ..sort((a, b) {
        final aOrder = dailyQuestCatalog.firstWhere((d) => d.id == a.questId).sortOrder;
        final bOrder = dailyQuestCatalog.firstWhere((d) => d.id == b.questId).sortOrder;
        return aOrder.compareTo(bOrder);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Journal')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text("Today's Quests", style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 12),
          for (final instance in sortedInstances) _QuestCard(instance: instance),
        ],
      ),
    );
  }
}

class _QuestCard extends ConsumerWidget {
  const _QuestCard({required this.instance});

  final QuestInstance instance;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final definition = dailyQuestCatalog.firstWhere((d) => d.id == instance.questId);
    final progressRatio =
        instance.target == 0 ? 1.0 : (instance.progress / instance.target).clamp(0, 1).toDouble();

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(definition.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                _StatusBadge(status: instance.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(definition.description, style: Theme.of(context).textTheme.bodySmall),
            const SizedBox(height: 8),
            LinearProgressIndicator(value: progressRatio),
            const SizedBox(height: 4),
            Text('${instance.progress.clamp(0, instance.target)} / ${instance.target}'),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('+${instance.expReward} EXP, +${instance.goldReward} Gold'),
                if (instance.status == QuestStatus.claimable)
                  ElevatedButton(
                    onPressed: () async {
                      final result = await ref.read(questControllerProvider.notifier).claim(instance);
                      if (result case Err(:final failure)) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context)
                              .showSnackBar(SnackBar(content: Text(failure.message)));
                        }
                      }
                    },
                    child: const Text('Claim'),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  const _StatusBadge({required this.status});

  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      QuestStatus.inProgress => ('In Progress', Colors.grey),
      QuestStatus.claimable => ('Claimable', Colors.green),
      QuestStatus.claimed => ('Claimed', Colors.blueGrey),
      QuestStatus.expired => ('Expired', Colors.grey),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 12)),
    );
  }
}
```

Titles/descriptions are looked up from `dailyQuestCatalog` by `questId` rather than duplicated here — the catalog (Task 1) is the single source of truth for that text.

- [ ] **Step 5: Write the Journal widget test**

```dart
// test/features/journal/presentation/journal_screen_test.dart
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/journal/presentation/screens/journal_screen.dart';
import 'package:everstride/features/quest/domain/entities/quest_definition.dart';
import 'package:everstride/features/quest/domain/entities/quest_instance.dart';
import 'package:everstride/features/quest/presentation/controllers/quest_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final _today = DateTime(2026, 9, 10);

List<QuestInstance> _threeInstances({QuestStatus firstStepsStatus = QuestStatus.inProgress}) {
  return [
    QuestInstance(
      id: 'today_daily_steps_1000',
      questId: 'daily_steps_1000',
      date: _today,
      objectiveType: QuestObjectiveType.dailySteps,
      target: 1000,
      progress: firstStepsStatus == QuestStatus.claimable ? 1000 : 200,
      status: firstStepsStatus,
      expReward: 10,
      goldReward: 5,
    ),
    QuestInstance(
      id: 'today_daily_steps_3000',
      questId: 'daily_steps_3000',
      date: _today,
      objectiveType: QuestObjectiveType.dailySteps,
      target: 3000,
      progress: 200,
      status: QuestStatus.inProgress,
      expReward: 20,
      goldReward: 10,
    ),
    QuestInstance(
      id: 'today_daily_adventure_1',
      questId: 'daily_adventure_1',
      date: _today,
      objectiveType: QuestObjectiveType.adventureCompletions,
      target: 1,
      progress: 0,
      status: QuestStatus.inProgress,
      expReward: 15,
      goldReward: 10,
    ),
  ];
}

class _FakeQuestController extends QuestController {
  _FakeQuestController(this._instances);

  final List<QuestInstance> _instances;
  QuestInstance? claimedInstance;

  @override
  AsyncValue<Result<List<QuestInstance>>>? build() => AsyncData(Ok(_instances));

  @override
  Future<Result<bool>> claim(QuestInstance instance) async {
    claimedInstance = instance;
    return const Ok(true);
  }
}

void main() {
  testWidgets('renders all three quests with titles and progress', (tester) async {
    final container = ProviderContainer(
      overrides: [questControllerProvider.overrideWith(() => _FakeQuestController(_threeInstances()))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: JournalScreen())),
    );

    expect(find.text('First Steps'), findsOneWidget);
    expect(find.text("Wanderer's Path"), findsOneWidget);
    expect(find.text('Trailbound'), findsOneWidget);
    expect(find.text('200 / 1000'), findsOneWidget);
  });

  testWidgets('a claimable quest shows a Claim button that calls the controller', (tester) async {
    final controller = _FakeQuestController(_threeInstances(firstStepsStatus: QuestStatus.claimable));
    final container = ProviderContainer(
      overrides: [questControllerProvider.overrideWith(() => controller)],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: JournalScreen())),
    );

    expect(find.widgetWithText(ElevatedButton, 'Claim'), findsOneWidget);
    await tester.tap(find.widgetWithText(ElevatedButton, 'Claim'));
    await tester.pump();

    expect(controller.claimedInstance?.questId, 'daily_steps_1000');
  });

  testWidgets('a not-yet-claimable quest shows no Claim button', (tester) async {
    final container = ProviderContainer(
      overrides: [questControllerProvider.overrideWith(() => _FakeQuestController(_threeInstances()))],
    );
    addTearDown(container.dispose);

    await tester.pumpWidget(
      UncontrolledProviderScope(container: container, child: const MaterialApp(home: JournalScreen())),
    );

    expect(find.widgetWithText(ElevatedButton, 'Claim'), findsNothing);
  });
}
```

- [ ] **Step 6: Run the tests**

Run: `flutter test test/features/journal/presentation/journal_screen_test.dart`
Expected: PASS (3 tests)

- [ ] **Step 7: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 8: Stage (do not commit without confirmed authorization)**

```bash
git add lib/features/quest/presentation/controllers/quest_controller.dart lib/features/player/presentation/controllers/player_controller.dart lib/features/adventure/presentation/screens/adventure_screen.dart lib/features/journal/presentation/screens/journal_screen.dart test/features/journal/presentation/journal_screen_test.dart
```

---

### Task 6: Update manual recheck doc and progress tracker

**Files:**

- Modify: `everstride-docs/development/testing.md`
- Modify: `everstride-docs/PROGRESS.md`

**Interfaces:** none — pure documentation, no code.

- [ ] **Step 1: Add a Phase 5 section to the manual recheck doc**

Open `everstride-docs/development/testing.md`. Add this section after the existing "Phase 4" section:

```markdown
## Phase 5 — Daily Quests

1. Open the Journal tab on a fresh day → three Quests appear: First Steps
   (0/1,000), Wanderer's Path (0/3,000), Trailbound (0/1), all "In Progress",
   no Claim button on any of them.
2. Use the debug seeder (Menu → Debug Tools) to reach ≥1,000 Steps for
   today, then Sync Now on Home → returning to Journal shows First Steps as
   "Claimable" with a Claim button; Wanderer's Path stays "In Progress" if
   under 3,000.
3. Tap Claim on First Steps → EXP/Gold on the Character tab increase by
   exactly 10/5, the card now shows "Claimed" with no Claim button, and
   tapping nothing happens if you somehow tap again (button is gone).
4. Complete a Greenwood Trail Adventure → Trailbound advances to 1/1 and
   becomes "Claimable" without needing to revisit Journal manually first.
5. Force a downward Step correction (re-seed a smaller total for today,
   Sync Now) before claiming First Steps → its progress bar/number drops to
   match, and it reverts to "In Progress" if now under target. After
   claiming a quest, do the same correction again → the claimed quest's
   card is unaffected (stays "Claimed").
6. Force-close and reopen the app after claiming one of the three Quests →
   Journal shows the same claimed/in-progress/claimable states as before
   closing, and the EXP/Gold already granted is still reflected on the
   Character tab.
7. Change the device's date forward by one day (or wait for a real day
   rollover) and reopen the app → yesterday's unclaimed Quests are gone
   from Journal, replaced by three fresh "In Progress" Quests for the new
   day; a Quest claimed yesterday keeps its reward (already applied to
   Player state) but is no longer shown as an active Quest.
8. With Health Connect permission denied/unavailable, open Journal → the
   two Step Quests stay at their last valid progress (or 0/target if never
   synced) without erroring, while Trailbound remains claimable/claimable
   normally once an Adventure completes (Adventure doesn't need Health
   Connect).
```

- [ ] **Step 2: Update `everstride-docs/PROGRESS.md`**

Add a "Phase 5 — Daily Quests" section (mirroring the existing phase sections' style: mixed Thai/English prose, `- [x]` lines per the design doc's real deliverables — Quest entities/catalog, `DailyQuestInstance` table + repository, `EnsureDailyQuestsUseCase` rollover/refresh, `RecordAdventureCompletionUseCase`, `ClaimDailyQuestUseCase`'s atomic transaction, `QuestController`, real Journal Quest UI — each with a short build note in the same voice as the existing sections), mark it done, and move its `- [ ] Phase 5 — Daily Quests` line out of the "Phase ถัดไป" list at the bottom into this new completed section. Reference `everstride-docs/game-design/quests.md` for the full design rationale instead of repeating it, same as every earlier phase section already does for its own spec/design doc.

- [ ] **Step 3: Stage (do not commit without confirmed authorization)**

```bash
cd ../everstride-docs
git add development/testing.md PROGRESS.md
```
