# Phase 2 — Local Health Sync Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Store a per-day snapshot of Health Connect step totals locally (Drift/SQLite), safely compute how many steps are newly rewardable each sync (never double-rewarding, never going negative), and catch up any days the app wasn't opened — wired into the existing "Sync Now" button.

**Architecture:** `UI (home_page.dart) → HealthSyncController (Notifier) → SyncHealthDataUseCase → HealthRepository (existing, reads Health Connect) + HealthSyncRepository (new, reads/writes Drift)`. `SyncHealthDataUseCase` is plain Dart (no Flutter/Riverpod imports) so it is unit-testable without a device.

**Tech Stack:** Flutter, Dart 3.13, Riverpod 3 (`flutter_riverpod`), Drift (`drift`, `sqlite3_flutter_libs`, `path_provider`, `path`, dev: `drift_dev`, `build_runner`) — all already in `everstride-mobile/pubspec.yaml` since Phase 0, unused until this plan.

**Spec:** `everstride-docs/specs/2026-09-08-phase2-local-health-sync-design.md` (read this first — it explains *why* the algorithm below covers all four Phase 2 plan tasks in one mechanism).

## Global Constraints

- Never use `reward = currentSteps`. Always `rewardable = max(0, currentSteps - alreadyRewardedSteps)` (`everstride-docs/plan/EVERSTRIDE_PLAN.md` section 6).
- Every repository method returns `Future<Result<T>>` (`Ok<T>`/`Err<T>`, see `lib/core/errors/result.dart`) — no raw exceptions cross a repository or use-case boundary; catch and wrap instead.
- Never call Drift or Health Connect directly from a UI widget — only through a repository (`everstride-docs/AGENTS.md`).
- Riverpod 3 has no `StateProvider` — use `Notifier`/`NotifierProvider` for mutable state (already the pattern in `lib/features/health/presentation/controllers/health_permission_controller.dart`).
- All dates used as `health_daily` keys or compared for "which day is this" must be normalized to local midnight (`DateTime(y, m, d)`) first.
- Log health-related actions/errors through `lib/core/utils/app_logger.dart` (`AppLogger.debug`/`AppLogger.error`), area tag `'health.sync'` for anything in this plan — never raw `print`.
- **Do not run `git commit`** (`everstride-docs/AGENTS.md` — absolutely no exceptions). Every task's last step is "stage the changes and stop" — the user commits.
- `everstride-docs/AGENTS.md` says not to run `flutter test` unless asked. This plan is an exception by design: writing and running the unit tests below is the whole point of Tasks 1–3 (TDD), and was explicitly requested when the spec was approved. Do not run the *entire* project test suite beyond the files this plan touches without being asked.
- All commands below assume the working directory is `everstride-mobile/`.

---

### Task 1: Drift database + `health_daily` table

**Files:**
- Create: `everstride-mobile/lib/core/database/app_database.dart`
- Test: `everstride-mobile/test/core/database/app_database_test.dart`

**Interfaces:**
- Consumes: nothing new (uses `drift`, `drift/native.dart`, `path_provider`, `path` — already in `pubspec.yaml`).
- Produces: `AppDatabase` class with constructor `AppDatabase([QueryExecutor? executor])`; table `HealthDaily` with columns `date` (`DateTimeColumn`, primary key), `totalSteps` (`IntColumn`), `rewardedSteps` (`IntColumn`), `lastSyncedAt` (`DateTimeColumn`); generated row class `HealthDailyData` (fields: `date`, `totalSteps`, `rewardedSteps`, `lastSyncedAt`); generated `HealthDailyCompanion` with `.insert({required date, required totalSteps, required rewardedSteps, required lastSyncedAt})`; Riverpod provider `appDatabaseProvider` (`Provider<AppDatabase>`). Later tasks access the table via `db.healthDaily`, `db.select(db.healthDaily)`, `db.into(db.healthDaily)`.

- [ ] **Step 1: Write the failing test**

```dart
// test/core/database/app_database_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/database/app_database.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('inserts and reads back a health_daily row', () async {
    final date = DateTime(2026, 9, 8);
    await database.into(database.healthDaily).insertOnConflictUpdate(
          HealthDailyCompanion.insert(
            date: date,
            totalSteps: 1000,
            rewardedSteps: 400,
            lastSyncedAt: date,
          ),
        );

    final row = await (database.select(database.healthDaily)
          ..where((t) => t.date.equals(date)))
        .getSingle();

    expect(row.totalSteps, 1000);
    expect(row.rewardedSteps, 400);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `flutter test test/core/database/app_database_test.dart`
Expected: FAIL — `package:everstride/core/database/app_database.dart` doesn't exist yet.

- [ ] **Step 3: Write the table and database**

```dart
// lib/core/database/app_database.dart
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

part 'app_database.g.dart';

class HealthDaily extends Table {
  DateTimeColumn get date => dateTime()();
  IntColumn get totalSteps => integer()();
  IntColumn get rewardedSteps => integer()();
  DateTimeColumn get lastSyncedAt => dateTime()();

  @override
  Set<Column> get primaryKey => {date};
}

@DriftDatabase(tables: [HealthDaily])
class AppDatabase extends _$AppDatabase {
  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => 1;

  static QueryExecutor _openConnection() {
    return LazyDatabase(() async {
      final dbFolder = await getApplicationDocumentsDirectory();
      final file = File(p.join(dbFolder.path, 'everstride.sqlite'));
      return NativeDatabase.createInBackground(file);
    });
  }
}

final appDatabaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});
```

- [ ] **Step 4: Generate Drift code**

Run: `dart run build_runner build --delete-conflicting-outputs`
Expected: creates `lib/core/database/app_database.g.dart`, exits 0.

- [ ] **Step 5: Run test to verify it passes**

Run: `flutter test test/core/database/app_database_test.dart`
Expected: PASS

- [ ] **Step 6: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Stage the changes (do not commit)**

```bash
git add lib/core/database/app_database.dart lib/core/database/app_database.g.dart test/core/database/app_database_test.dart pubspec.lock
```

Stop here — the user reviews and commits.

---

### Task 2: `HealthSyncRepository` (interface + Drift-backed implementation)

**Files:**
- Create: `everstride-mobile/lib/features/health/domain/repositories/health_sync_repository.dart`
- Create: `everstride-mobile/lib/features/health/data/repositories/health_sync_repository_impl.dart`
- Test: `everstride-mobile/test/features/health/data/repositories/health_sync_repository_impl_test.dart`

**Interfaces:**
- Consumes: `AppDatabase`, `HealthDaily`, `HealthDailyCompanion` (Task 1); `Result`/`Ok`/`Err`/`Failure` (`lib/core/errors/result.dart`); `AppLogger` (`lib/core/utils/app_logger.dart`).
- Produces: `HealthDailyRecord` value class (fields: `date`, `totalSteps`, `rewardedSteps`, `lastSyncedAt`, all required, no default `==`/`hashCode` needed — not compared directly in tests); abstract `HealthSyncRepository` with `Future<Result<DateTime?>> getMostRecentSyncedDate()`, `Future<Result<HealthDailyRecord?>> getRecord(DateTime date)`, `Future<Result<bool>> upsertRecord(HealthDailyRecord record)`; `HealthSyncRepositoryImpl implements HealthSyncRepository` with constructor `HealthSyncRepositoryImpl(AppDatabase db)`; Riverpod provider `healthSyncRepositoryProvider` (`Provider<HealthSyncRepository>`). Task 3 consumes all of the above.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/health/data/repositories/health_sync_repository_impl_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/database/app_database.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/health/data/repositories/health_sync_repository_impl.dart';
import 'package:everstride/features/health/domain/repositories/health_sync_repository.dart';

void main() {
  late AppDatabase database;
  late HealthSyncRepositoryImpl repository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    repository = HealthSyncRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('getMostRecentSyncedDate returns null when no rows exist', () async {
    final result = await repository.getMostRecentSyncedDate();
    expect((result as Ok<DateTime?>).value, isNull);
  });

  test('upsertRecord then getRecord round-trips the same values', () async {
    final date = DateTime(2026, 9, 8);
    final upsertResult = await repository.upsertRecord(HealthDailyRecord(
      date: date,
      totalSteps: 1000,
      rewardedSteps: 400,
      lastSyncedAt: date,
    ));
    expect(upsertResult, isA<Ok<bool>>());

    final getResult = await repository.getRecord(date);
    final record = (getResult as Ok<HealthDailyRecord?>).value;
    expect(record, isNotNull);
    expect(record!.totalSteps, 1000);
    expect(record.rewardedSteps, 400);
  });

  test('upsertRecord overwrites the existing row for the same date', () async {
    final date = DateTime(2026, 9, 8);
    await repository.upsertRecord(HealthDailyRecord(
      date: date,
      totalSteps: 1000,
      rewardedSteps: 400,
      lastSyncedAt: date,
    ));
    await repository.upsertRecord(HealthDailyRecord(
      date: date,
      totalSteps: 1500,
      rewardedSteps: 900,
      lastSyncedAt: date,
    ));

    final getResult = await repository.getRecord(date);
    final record = (getResult as Ok<HealthDailyRecord?>).value!;
    expect(record.totalSteps, 1500);
    expect(record.rewardedSteps, 900);
  });

  test('getMostRecentSyncedDate returns the latest date across multiple rows', () async {
    await repository.upsertRecord(HealthDailyRecord(
      date: DateTime(2026, 9, 5),
      totalSteps: 100,
      rewardedSteps: 100,
      lastSyncedAt: DateTime(2026, 9, 5),
    ));
    await repository.upsertRecord(HealthDailyRecord(
      date: DateTime(2026, 9, 7),
      totalSteps: 200,
      rewardedSteps: 200,
      lastSyncedAt: DateTime(2026, 9, 7),
    ));

    final result = await repository.getMostRecentSyncedDate();
    expect((result as Ok<DateTime?>).value, DateTime(2026, 9, 7));
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/health/data/repositories/health_sync_repository_impl_test.dart`
Expected: FAIL — the interface/impl files don't exist yet.

- [ ] **Step 3: Write the repository interface**

```dart
// lib/features/health/domain/repositories/health_sync_repository.dart
import '../../../../core/errors/result.dart';

class HealthDailyRecord {
  const HealthDailyRecord({
    required this.date,
    required this.totalSteps,
    required this.rewardedSteps,
    required this.lastSyncedAt,
  });

  final DateTime date;
  final int totalSteps;
  final int rewardedSteps;
  final DateTime lastSyncedAt;
}

/// Reads/writes the local `health_daily` table. Only called from
/// SyncHealthDataUseCase — never directly from UI.
abstract class HealthSyncRepository {
  Future<Result<DateTime?>> getMostRecentSyncedDate();
  Future<Result<HealthDailyRecord?>> getRecord(DateTime date);
  Future<Result<bool>> upsertRecord(HealthDailyRecord record);
}
```

- [ ] **Step 4: Write the Drift-backed implementation**

```dart
// lib/features/health/data/repositories/health_sync_repository_impl.dart
import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/database/app_database.dart';
import '../../../../core/errors/result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/repositories/health_sync_repository.dart';

class HealthSyncRepositoryImpl implements HealthSyncRepository {
  HealthSyncRepositoryImpl(this._db);

  final AppDatabase _db;

  @override
  Future<Result<DateTime?>> getMostRecentSyncedDate() async {
    try {
      final query = _db.select(_db.healthDaily)
        ..orderBy([(t) => OrderingTerm.desc(t.date)])
        ..limit(1);
      final row = await query.getSingleOrNull();
      return Ok(row?.date);
    } catch (e) {
      AppLogger.error('health.sync', 'Failed to read most recent synced date', e);
      return Err(Failure('Failed to read most recent synced date', cause: e));
    }
  }

  @override
  Future<Result<HealthDailyRecord?>> getRecord(DateTime date) async {
    try {
      final row =
          await (_db.select(_db.healthDaily)..where((t) => t.date.equals(date))).getSingleOrNull();
      if (row == null) return const Ok(null);
      return Ok(HealthDailyRecord(
        date: row.date,
        totalSteps: row.totalSteps,
        rewardedSteps: row.rewardedSteps,
        lastSyncedAt: row.lastSyncedAt,
      ));
    } catch (e) {
      AppLogger.error('health.sync', 'Failed to read health_daily record for $date', e);
      return Err(Failure('Failed to read health_daily record', cause: e));
    }
  }

  @override
  Future<Result<bool>> upsertRecord(HealthDailyRecord record) async {
    try {
      await _db.into(_db.healthDaily).insertOnConflictUpdate(
            HealthDailyCompanion.insert(
              date: record.date,
              totalSteps: record.totalSteps,
              rewardedSteps: record.rewardedSteps,
              lastSyncedAt: record.lastSyncedAt,
            ),
          );
      AppLogger.debug('health.sync', 'Upserted health_daily row for ${record.date}');
      return const Ok(true);
    } catch (e) {
      AppLogger.error('health.sync', 'Failed to write health_daily record for ${record.date}', e);
      return Err(Failure('Failed to write health_daily record', cause: e));
    }
  }
}

final healthSyncRepositoryProvider = Provider<HealthSyncRepository>((ref) {
  return HealthSyncRepositoryImpl(ref.watch(appDatabaseProvider));
});
```

- [ ] **Step 5: Run tests to verify they pass**

Run: `flutter test test/features/health/data/repositories/health_sync_repository_impl_test.dart`
Expected: PASS (4 tests)

- [ ] **Step 6: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 7: Stage the changes (do not commit)**

```bash
git add lib/features/health/domain/repositories/health_sync_repository.dart lib/features/health/data/repositories/health_sync_repository_impl.dart test/features/health/data/repositories/health_sync_repository_impl_test.dart
```

Stop here — the user reviews and commits.

---

### Task 3: `SyncHealthDataUseCase`

**Files:**
- Create: `everstride-mobile/lib/features/health/domain/usecases/sync_health_data_usecase.dart`
- Test: `everstride-mobile/test/features/health/domain/usecases/sync_health_data_usecase_test.dart`

**Interfaces:**
- Consumes: `HealthRepository` (existing, `lib/features/health/domain/repositories/health_repository.dart`, method used: `Future<Result<int>> getStepsForDate(DateTime date)`); `HealthSyncRepository`/`HealthDailyRecord` (Task 2); `Result`/`Ok`/`Err`/`Failure`.
- Produces: `DailySyncResult` (fields: `date`, `rewardableSteps`; has value `==`/`hashCode`); `SyncResult` (fields: `totalNewRewardableSteps` (int), `days` (`List<DailySyncResult>`)); `SyncHealthDataUseCase` with constructor `SyncHealthDataUseCase(HealthRepository, HealthSyncRepository)` and method `Future<Result<SyncResult>> call({DateTime? now})`. Task 4 consumes `SyncHealthDataUseCase`, `SyncResult`.

- [ ] **Step 1: Write the failing tests**

```dart
// test/features/health/domain/usecases/sync_health_data_usecase_test.dart
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:everstride/core/database/app_database.dart';
import 'package:everstride/core/errors/result.dart';
import 'package:everstride/features/health/data/repositories/health_sync_repository_impl.dart';
import 'package:everstride/features/health/domain/repositories/health_repository.dart';
import 'package:everstride/features/health/domain/repositories/health_sync_repository.dart';
import 'package:everstride/features/health/domain/usecases/sync_health_data_usecase.dart';

class _FakeHealthRepository implements HealthRepository {
  _FakeHealthRepository(this.stepsByDate, {this.failOnDate});

  final Map<DateTime, int> stepsByDate;
  final DateTime? failOnDate;

  @override
  Future<Result<int>> getStepsForDate(DateTime date) async {
    if (failOnDate != null && date == failOnDate) {
      return Err(Failure('Simulated failure for $date'));
    }
    return Ok(stepsByDate[date] ?? 0);
  }

  @override
  Future<Result<int>> getTodaySteps() => getStepsForDate(DateTime.now());

  @override
  Future<Result<bool>> isAvailable() => throw UnimplementedError();

  @override
  Future<Result<bool>> promptInstallOrUpdate() => throw UnimplementedError();

  @override
  Future<Result<bool>> hasPermission() => throw UnimplementedError();

  @override
  Future<Result<bool>> requestPermissions() => throw UnimplementedError();
}

void main() {
  late AppDatabase database;
  late HealthSyncRepositoryImpl syncRepository;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
    syncRepository = HealthSyncRepositoryImpl(database);
  });

  tearDown(() async {
    await database.close();
  });

  test('first sync of the day rewards the full total', () async {
    final today = DateTime(2026, 9, 8);
    final useCase = SyncHealthDataUseCase(_FakeHealthRepository({today: 2500}), syncRepository);

    final result = await useCase.call(now: today);
    final syncResult = (result as Ok<SyncResult>).value;

    expect(syncResult.totalNewRewardableSteps, 2500);
    expect(syncResult.days, [DailySyncResult(date: today, rewardableSteps: 2500)]);
  });

  test('second sync same day with the same total rewards nothing new', () async {
    final today = DateTime(2026, 9, 8);
    final useCase = SyncHealthDataUseCase(_FakeHealthRepository({today: 2500}), syncRepository);

    await useCase.call(now: today);
    final result = await useCase.call(now: today);
    final syncResult = (result as Ok<SyncResult>).value;

    expect(syncResult.totalNewRewardableSteps, 0);
  });

  test('an increased total rewards only the increase', () async {
    final today = DateTime(2026, 9, 8);
    await SyncHealthDataUseCase(_FakeHealthRepository({today: 2500}), syncRepository).call(now: today);

    final result =
        await SyncHealthDataUseCase(_FakeHealthRepository({today: 4000}), syncRepository).call(now: today);
    final syncResult = (result as Ok<SyncResult>).value;

    expect(syncResult.totalNewRewardableSteps, 1500);
  });

  test('a decreased total (correction) rewards nothing and does not go negative', () async {
    final today = DateTime(2026, 9, 8);
    await SyncHealthDataUseCase(_FakeHealthRepository({today: 2500}), syncRepository).call(now: today);

    final result =
        await SyncHealthDataUseCase(_FakeHealthRepository({today: 1000}), syncRepository).call(now: today);
    final syncResult = (result as Ok<SyncResult>).value;

    expect(syncResult.totalNewRewardableSteps, 0);

    final recordResult = await syncRepository.getRecord(today);
    final record = (recordResult as Ok<HealthDailyRecord?>).value!;
    expect(record.totalSteps, 1000);
    expect(record.rewardedSteps, 2500);
  });

  test('first-ever sync caps the catch-up window to 7 days', () async {
    final today = DateTime(2026, 9, 8);
    final stepsByDate = {for (var i = 0; i < 30; i++) today.subtract(Duration(days: i)): 100};
    final useCase = SyncHealthDataUseCase(_FakeHealthRepository(stepsByDate), syncRepository);

    final result = await useCase.call(now: today);
    final syncResult = (result as Ok<SyncResult>).value;

    expect(syncResult.days.length, 7);
    expect(syncResult.totalNewRewardableSteps, 700);
  });

  test('catches up missed days plus today', () async {
    final lastSynced = DateTime(2026, 9, 5);
    final today = DateTime(2026, 9, 8);
    await syncRepository.upsertRecord(HealthDailyRecord(
      date: lastSynced,
      totalSteps: 1000,
      rewardedSteps: 1000,
      lastSyncedAt: lastSynced,
    ));

    final useCase = SyncHealthDataUseCase(
      _FakeHealthRepository({
        lastSynced: 1000,
        DateTime(2026, 9, 6): 2000,
        DateTime(2026, 9, 7): 3000,
        today: 500,
      }),
      syncRepository,
    );

    final result = await useCase.call(now: today);
    final syncResult = (result as Ok<SyncResult>).value;

    expect(syncResult.totalNewRewardableSteps, 2000 + 3000 + 500);
    expect(syncResult.days.length, 4);
  });

  test('a failure on the only date walked returns Err', () async {
    final today = DateTime(2026, 9, 8);
    await syncRepository.upsertRecord(HealthDailyRecord(
      date: today,
      totalSteps: 100,
      rewardedSteps: 100,
      lastSyncedAt: today,
    ));
    final useCase = SyncHealthDataUseCase(_FakeHealthRepository({}, failOnDate: today), syncRepository);

    final result = await useCase.call(now: today);
    expect(result, isA<Err<SyncResult>>());
  });

  test('a failed date after a successful one returns the partial result', () async {
    final dayBefore = DateTime(2026, 9, 7);
    final today = DateTime(2026, 9, 8);
    await syncRepository.upsertRecord(HealthDailyRecord(
      date: dayBefore,
      totalSteps: 0,
      rewardedSteps: 0,
      lastSyncedAt: dayBefore,
    ));

    final useCase = SyncHealthDataUseCase(
      _FakeHealthRepository({dayBefore: 1000}, failOnDate: today),
      syncRepository,
    );

    final result = await useCase.call(now: today);
    final syncResult = (result as Ok<SyncResult>).value;

    expect(syncResult.totalNewRewardableSteps, 1000);
    expect(syncResult.days, [DailySyncResult(date: dayBefore, rewardableSteps: 1000)]);
  });
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `flutter test test/features/health/domain/usecases/sync_health_data_usecase_test.dart`
Expected: FAIL — `sync_health_data_usecase.dart` doesn't exist yet.

- [ ] **Step 3: Write the use case**

```dart
// lib/features/health/domain/usecases/sync_health_data_usecase.dart
import 'dart:math';

import '../../../../core/errors/result.dart';
import '../repositories/health_repository.dart';
import '../repositories/health_sync_repository.dart';

class DailySyncResult {
  const DailySyncResult({required this.date, required this.rewardableSteps});

  final DateTime date;
  final int rewardableSteps;

  @override
  bool operator ==(Object other) =>
      other is DailySyncResult && other.date == date && other.rewardableSteps == rewardableSteps;

  @override
  int get hashCode => Object.hash(date, rewardableSteps);

  @override
  String toString() => 'DailySyncResult(date: $date, rewardableSteps: $rewardableSteps)';
}

class SyncResult {
  const SyncResult({required this.totalNewRewardableSteps, required this.days});

  final int totalNewRewardableSteps;
  final List<DailySyncResult> days;
}

/// Walks forward from the last-synced date (or a capped catch-up window on
/// the very first sync) through today, safely computing
/// `rewardable = max(0, total - alreadyRewarded)` per date and storing it.
/// See everstride-docs/specs/2026-09-08-phase2-local-health-sync-design.md.
class SyncHealthDataUseCase {
  SyncHealthDataUseCase(this._healthRepository, this._syncRepository);

  final HealthRepository _healthRepository;
  final HealthSyncRepository _syncRepository;

  static const _firstSyncCatchUpDays = 7;

  Future<Result<SyncResult>> call({DateTime? now}) async {
    final resolvedNow = now ?? DateTime.now();
    final today = _atMidnight(resolvedNow);

    final sinceResult = await _syncRepository.getMostRecentSyncedDate();
    final DateTime sinceDate;
    switch (sinceResult) {
      case Ok(value: final mostRecent):
        sinceDate = mostRecent != null
            ? _atMidnight(mostRecent)
            : today.subtract(const Duration(days: _firstSyncCatchUpDays - 1));
      case Err(:final failure):
        return Err(failure);
    }

    final days = <DailySyncResult>[];
    var totalNewRewardableSteps = 0;

    for (var date = sinceDate; !date.isAfter(today); date = date.add(const Duration(days: 1))) {
      final stepsResult = await _healthRepository.getStepsForDate(date);
      final int totalSteps;
      switch (stepsResult) {
        case Ok(value: final v):
          totalSteps = v;
        case Err(:final failure):
          return days.isEmpty
              ? Err(failure)
              : Ok(SyncResult(totalNewRewardableSteps: totalNewRewardableSteps, days: days));
      }

      final existingResult = await _syncRepository.getRecord(date);
      final HealthDailyRecord? existing;
      switch (existingResult) {
        case Ok(value: final v):
          existing = v;
        case Err(:final failure):
          return days.isEmpty
              ? Err(failure)
              : Ok(SyncResult(totalNewRewardableSteps: totalNewRewardableSteps, days: days));
      }

      final rewardedSoFar = existing?.rewardedSteps ?? 0;
      final delta = max(0, totalSteps - rewardedSoFar);

      final upsertResult = await _syncRepository.upsertRecord(HealthDailyRecord(
        date: date,
        totalSteps: totalSteps,
        rewardedSteps: rewardedSoFar + delta,
        lastSyncedAt: resolvedNow,
      ));
      if (upsertResult case Err(:final failure)) {
        return days.isEmpty
            ? Err(failure)
            : Ok(SyncResult(totalNewRewardableSteps: totalNewRewardableSteps, days: days));
      }

      days.add(DailySyncResult(date: date, rewardableSteps: delta));
      totalNewRewardableSteps += delta;
    }

    return Ok(SyncResult(totalNewRewardableSteps: totalNewRewardableSteps, days: days));
  }

  DateTime _atMidnight(DateTime date) => DateTime(date.year, date.month, date.day);
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `flutter test test/features/health/domain/usecases/sync_health_data_usecase_test.dart`
Expected: PASS (8 tests)

- [ ] **Step 5: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 6: Stage the changes (do not commit)**

```bash
git add lib/features/health/domain/usecases/sync_health_data_usecase.dart test/features/health/domain/usecases/sync_health_data_usecase_test.dart
```

Stop here — the user reviews and commits.

---

### Task 4: Wire "Sync Now" to the use case + update docs

**Files:**
- Create: `everstride-mobile/lib/features/health/presentation/controllers/health_sync_controller.dart`
- Modify: `everstride-mobile/lib/app/home_page.dart`
- Modify: `everstride-docs/development/testing.md`
- Modify: `everstride-docs/PROGRESS.md`

**Interfaces:**
- Consumes: `SyncHealthDataUseCase`, `SyncResult` (Task 3); `healthRepositoryProvider` (`lib/features/health/data/repositories/health_repository_impl.dart`); `healthSyncRepositoryProvider` (Task 2); `stepsForSelectedDateProvider` (`lib/features/health/presentation/controllers/steps_controller.dart`); `Result`/`Ok`/`Err` (`lib/core/errors/result.dart`).
- Produces: `syncHealthDataUseCaseProvider` (`Provider<SyncHealthDataUseCase>`); `HealthSyncController` (`Notifier<AsyncValue<Result<SyncResult>>?>`) with method `Future<void> sync()`; `healthSyncControllerProvider` (`NotifierProvider<HealthSyncController, AsyncValue<Result<SyncResult>>?>`).

This task has no automated test (Riverpod controller wiring + widget tree) — verify with `flutter analyze` and the manual recheck steps added to `everstride-docs/development/testing.md` below.

- [ ] **Step 1: Write the controller**

```dart
// lib/features/health/presentation/controllers/health_sync_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/health_repository_impl.dart';
import '../../data/repositories/health_sync_repository_impl.dart';
import '../../domain/usecases/sync_health_data_usecase.dart';

final syncHealthDataUseCaseProvider = Provider<SyncHealthDataUseCase>((ref) {
  return SyncHealthDataUseCase(
    ref.watch(healthRepositoryProvider),
    ref.watch(healthSyncRepositoryProvider),
  );
});

class HealthSyncController extends Notifier<AsyncValue<Result<SyncResult>>?> {
  @override
  AsyncValue<Result<SyncResult>>? build() => null;

  Future<void> sync() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() => ref.read(syncHealthDataUseCaseProvider).call());
  }
}

final healthSyncControllerProvider =
    NotifierProvider<HealthSyncController, AsyncValue<Result<SyncResult>>?>(HealthSyncController.new);
```

- [ ] **Step 2: Run the analyzer on the new file**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Wire the controller into the Home screen**

Open `lib/app/home_page.dart`. Add this import alongside the other `features/health/presentation/controllers/...` imports:

```dart
import '../features/health/presentation/controllers/health_sync_controller.dart';
```

Find the existing `ElevatedButton` whose `child` is `const Text('Sync Now')` (inside the steps `Consumer`'s `Column`). Replace it, and add a result line right after it, with:

```dart
ElevatedButton(
  onPressed: steps.isLoading
      ? null
      : () {
          ref.invalidate(stepsForSelectedDateProvider);
          ref.read(healthSyncControllerProvider.notifier).sync();
        },
  child: const Text('Sync Now'),
),
Consumer(
  builder: (context, ref, _) {
    final sync = ref.watch(healthSyncControllerProvider);
    final text = switch (sync) {
      null => null,
      AsyncData(:final value) => switch (value) {
          Ok(:final value) => value.totalNewRewardableSteps > 0
              ? '+${value.totalNewRewardableSteps} rewardable steps synced'
              : 'No new rewardable steps',
          Err(:final failure) => 'Sync error (${failure.message})',
        },
      AsyncError() => 'Sync error',
      _ => 'Syncing...',
    };
    if (text == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Text(text, style: const TextStyle(fontSize: 12)),
    );
  },
),
```

(The existing `onPressed: steps.isLoading ? null : () => ref.invalidate(stepsForSelectedDateProvider),` single-line body is being replaced by the two-statement block above — same guard condition, now doing two things.)

- [ ] **Step 4: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Add a Phase 2 section to the manual recheck doc**

Open `everstride-docs/development/testing.md`. Add this section after the existing "Phase 1" section:

```markdown
## Phase 2 — Local Health Sync

The local database file persists across app restarts (it's a real sqlite
file, not in-memory) — to test "first-ever sync" behavior again, uninstall
the app first (`flutter clean` does not remove app-local storage; a real
uninstall/reinstall does).

1. Tap "Sync Now" for the first time ever on a device/emulator → shows
   "+N rewardable steps synced" (N should roughly match the visible step
   count, since nothing has been rewarded yet).
2. Tap "Sync Now" again immediately, without walking anywhere → shows
   "No new rewardable steps" (0 delta — not a duplicate reward).
3. Use the debug step seeder (Phase 1) to add steps, then tap "Sync Now" →
   the new amount, not the full total, shows as rewarded.
4. Force-close the app, wait a bit (or change the device's date forward one
   day in developer settings), reopen, tap "Sync Now" → both the skipped
   day and the new day get credited (visible as a single combined number).
```

- [ ] **Step 6: Update `everstride-docs/PROGRESS.md`**

Add a "Phase 2 — Local Health Sync" section (mirroring the existing Phase 1
section's style: a `### Phase 2` heading with `- [x]` lines per plan task,
each with a short note on what was built and where), and mark this phase's
plan tasks done: "Create Drift health tables", "Store daily Health Connect
snapshot", "Store already-converted steps", "Calculate delta safely",
"Handle day rollover", "Handle step count corrections", "Prevent duplicate
rewards". Reference `everstride-docs/specs/2026-09-08-phase2-local-health-sync-design.md`
for the full design rationale instead of repeating it.

- [ ] **Step 7: Stage the changes (do not commit)**

```bash
git add lib/features/health/presentation/controllers/health_sync_controller.dart lib/app/home_page.dart everstride-docs/development/testing.md everstride-docs/PROGRESS.md
```

Stop here — the user reviews and commits.
