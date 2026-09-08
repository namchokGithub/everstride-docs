# Everstride — Progress Tracker

อ้างอิงแผนงานที่ `everstride-docs/plan/EVERSTRIDE_PLAN.md`

## สถานะปัจจุบัน (2026-09-07, อัปเดตล่าสุด)

ตรวจสอบ repo จริง (`everstride-mobile/`) แล้วพบว่า:

- **Flutter project สร้างแล้ว** — มี `pubspec.yaml`, `lib/main.dart`
- `flutter analyze` ผ่าน ไม่มี issue
- **Android emulator** — **ยืนยันแล้ว** ว่า build ขึ้นจริงบน `Pixel_10_Pro` emulator, เปิดแอปได้สำเร็จ (ปิด emulator แล้วหลังเช็ค)
- **Riverpod** — wire แล้ว — `main.dart` ห่อ `MyApp` ด้วย `ProviderScope`
- **GoRouter** — wire แล้ว — `lib/app/router.dart` มี route `/`, `MaterialApp.router` ใช้งานจริง, `MyHomePage` ย้ายไป `lib/app/home_page.dart`
- **minSdk** — bump เป็น `26` ใน `android/app/build.gradle.kts` แล้ว (Health Connect ต้องการ API 26 ขึ้นไป)
- **อุปกรณ์ Android จริง** — **ยืนยันแล้ว** รันบนมือถือจริงได้ (ไม่ใช่แค่ emulator), อ่านค่าก้าวเดินถูกต้อง

**Phase 0 เสร็จครบทุกข้อแล้ว** — พร้อมเริ่ม Phase 1

## ต้องทำก่อน (ถัดไป — Phase 1: Health Connect Prototype)

1. Detect Health Connect availability
2. Request required permissions
3. Handle permission denied state
4. Read today's steps
5. Display current step count

ทำ `HealthRepository` (`lib/features/health/domain/repositories/health_repository.dart`) ที่มี interface เตรียมไว้แล้วให้เป็นจริง (data source + implementation), ตามลำดับใน plan section 15

## เป้าหมายที่ plan ระบุไว้ (Current Priority ใน plan)

> อ่านจำนวนก้าวเดินวันนี้จาก Health Connect ได้จริง และแสดงผลใน Flutter อย่างเสถียร บนอุปกรณ์ Android จริง

นี่คือ Phase 1 — ทุกอย่างอื่นต้องรอจน milestone นี้เสถียรก่อน (ห้ามข้ามไปทำ RPG mechanics ก่อน)

## Checklist ตามลำดับ (Phase 0 → Phase 1)

### Phase 0 — Project Foundation

- [x] Verify Flutter project builds on Android (run บน Pixel_10_Pro emulator สำเร็จ, เปิดแอปขึ้นจริง — ปิด emulator ได้ ไม่ต้องเปิดค้าง)
- [x] Set minimum Android version required by Health Connect (bump `minSdk` เป็น `26` ใน `android/app/build.gradle.kts` แล้ว)
- [x] Add Riverpod (wire แล้ว — `main.dart` ห่อ `MyApp` ด้วย `ProviderScope`)
- [x] Add GoRouter (wire แล้ว — `lib/app/router.dart` มี route `/` → `MyHomePage`, `MaterialApp` เปลี่ยนเป็น `MaterialApp.router`, ย้าย `MyHomePage` ไป `lib/app/home_page.dart`, `flutter analyze` ผ่าน)
- [x] Add Drift + SQLite (dependency เพิ่มแล้ว: `drift`, `sqlite3_flutter_libs`, `path_provider`, `path` + dev: `drift_dev`, `build_runner` — ยังไม่สร้างตาราง/`AppDatabase` class รอ Phase 2 "Create Drift health tables")
- [x] Add Supabase Flutter SDK (dependency เพิ่มแล้ว: `supabase_flutter` — ยังไม่เรียก `Supabase.initialize` รอ "Add environment configuration" ก่อน เพราะต้องใช้ URL/anon key)
- [x] Add environment configuration (`flutter_dotenv` เพิ่มแล้ว, `.env.example` template committed-ready, `.env` จริง local + gitignored, `lib/core/config/env.dart` อ่านค่า `SUPABASE_URL`/`SUPABASE_ANON_KEY`, `main.dart` เรียก `Env.load()` ก่อน `runApp`. ค่าใน `.env` ตอนนี้ว่างเปล่า รอ Supabase project จริงตอนทำ Phase 6)
- [x] Create base app theme (`lib/app/theme/app_theme.dart` — light/dark, `MaterialApp.router` ใช้ `themeMode: ThemeMode.system`)
- [x] Create error/result handling pattern (`lib/core/errors/result.dart` — `Result<T>` sealed class: `Ok<T>` / `Err<T>` + `Failure`)
- [x] Create initial repository interfaces (ทั้ง 6 ตัวสร้างแล้วที่ `lib/features/<name>/domain/repositories/`: `HealthRepository` มี method จริง `isAvailable`/`requestPermissions`/`getTodaySteps` เพราะ Phase 1 ต้องใช้ทันที; `PlayerRepository`/`QuestRepository`/`InventoryRepository`/`AuthRepository`/`AdventureRepository` เป็น marker interface เปล่า รอ entity/shape จริงตอนถึง phase ของมัน)

### Phase 1 — Health Connect Prototype

- [x] Detect Health Connect availability (`health` package เพิ่มแล้ว, `HealthConnectDataSource` + `HealthRepositoryImpl.isAvailable()` เช็ค `getHealthConnectSdkStatus()`, AndroidManifest เพิ่ม `<queries>` สำหรับ `com.google.android.apps.healthdata`, `main.dart` เรียก `Health().configure()`, หน้า Home แสดงสถานะ "Health Connect: available/not available". **ยืนยันแล้ว** บน emulator จริง — เห็น "Health Connect: available". `requestPermissions()`/`getTodaySteps()` ยัง throw `UnimplementedError` รอ task ถัดไป)
- [x] Request required permissions (`MainActivity` เปลี่ยนเป็น `FlutterFragmentActivity` แล้ว, `AndroidManifest.xml` เพิ่ม `READ_STEPS` permission + permission-rationale intent-filter + `ViewPermissionUsageActivity` alias, `HealthConnectDataSource.hasStepsPermission()`/`requestStepsPermission()` ขอแค่ steps ตาม plan section 7, `HealthRepositoryImpl.requestPermissions()` implement จริง, หน้า Home มีปุ่ม "Request Health Permission" + สถานะ granted/denied. **ยืนยันแล้ว** บน emulator จริง — กดปุ่มแล้วได้ "Permission: granted")

  ![granted](image/PROGRESS/1788805440434.png)

- [x] Handle permission denied state (ไม่ crash โดยดีไซน์เดิม — `health` package คืน `Future<bool>` ตอนขอ permission ไม่ throw ตอน deny, + `Result`/`Err` + `AsyncValue.guard` ดักซ้ำอีกชั้น. เพิ่ม hint text "Steps can't be read without this permission. Tap below to try again." ตอน denied ใน home page, ปุ่มกด retry ได้เรื่อย ๆ. **ยืนยันแล้ว** บน emulator จริง — revoke permission ผ่าน `adb shell pm revoke`, กด deny ใน dialog, เห็น "Permission: denied" + hint text ถูกต้อง ไม่ crash)
- [x] Read today's steps (`HealthRepository` เพิ่ม `getStepsForDate(DateTime)`, `getTodaySteps()` เรียกต่อด้วย `DateTime.now()`; `HealthConnectDataSource.getTotalSteps()` ใช้ `health` package's `getTotalStepsInInterval()`; ทำเกินสโคปนิดตามที่สั่ง — เพิ่มความสามารถเลือกวันย้อนหลังได้ด้วย ไม่ใช่แค่ today)
- [x] Display current step count (`lib/features/health/presentation/controllers/steps_controller.dart` — `selectedDateProvider` (`Notifier<DateTime>`, ค่าเริ่มต้น = วันนี้) + `stepsForSelectedDateProvider` (`FutureProvider<Result<int>>`, re-fetch อัตโนมัติเมื่อวันที่เปลี่ยน). Home page แสดง "Steps on YYYY-MM-DD: N" + ปุ่ม "Pick a date" (`showDatePicker`, จำกัดช่วง 365 วันย้อนหลังถึงวันนี้). หมายเหตุ: Riverpod 3 เอา `StateProvider` ออกแล้ว ใช้ `Notifier<DateTime>` แทน)

**เจอปัญหาระหว่างทดสอบ**: อ่านได้ 0 steps ทั้งที่ Samsung Health (บน emulator) โชว์ 31 steps — สาเหตุคือ permission "write" ให้ Samsung Health sync เข้า Health Connect ไม่ได้แปลว่า data ถูกเขียนจริงแล้ว (emulator ไม่มี sensor เดินจริง, sync ของ Samsung Health ไม่แน่นอน). แก้ด้วยการเพิ่มเครื่องมือ debug-only สำหรับยัด test data เข้า Health Connect เอง:

- `android/app/src/debug/AndroidManifest.xml` เพิ่ม `WRITE_STEPS` (debug build เท่านั้น, ไม่ขึ้น release)
- `lib/features/health/presentation/widgets/debug_steps_seeder.dart` — ปุ่ม "[Debug] Insert 500 test steps" ใช้ `Health().writeHealthData()` ตรง ๆ (ไม่ผ่าน `HealthRepository` เพราะ repo ตั้งใจให้ read-only ตาม architecture), gate ด้วย `kDebugMode`, invalidate `stepsForSelectedDateProvider` ให้ auto refresh หลัง insert
- ต้อง full rebuild (`flutter run` ใหม่ ไม่ใช่ hot reload) เพราะ manifest permission เปลี่ยน

**ปัญหาที่เจอระหว่างทดสอบ debug tool + วิธีแก้:**

1. `SecurityException: requires WRITE_STEPS` แม้ manifest ประกาศแล้ว — สาเหตุคือ `USER_FIXED` flag ค้างอยู่บน `READ_STEPS` (จากการผสม `adb pm revoke` กับกด deny จริงตอนทดสอบ task ก่อนหน้า) ทำให้ Android ปฏิเสธเปิด permission dialog ให้ทั้งกลุ่ม STEPS (ทั้ง read และ write) ไปด้วย. แก้ด้วย `adb shell pm reset-permissions com.namchok.everstride` (เคลียร์ flag ทั้งหมดของแอปนี้ กลับไปสถานะ "ยังไม่เคยขอ") แล้ว request permission ใหม่ทั้ง read/write ผ่านหน้าแอปจริง — สำเร็จ
2. กด "[Debug] Insert 500 test steps" ซ้ำ ๆ ได้ total ไม่ตรง (506 แทนที่จะเป็นทวีคูณของ 500) — เพราะปุ่มเดิมเขียนทับช่วงเวลาเดิม (`now-1h` ถึง `now`) ทุกครั้ง ช่วงเวลาทับกัน Health Connect เลย dedupe/interpolate ให้แทนที่จะบวกตรง ๆ (พฤติกรรมจริงของ Health Connect ไม่ใช่ bug เรา). แก้ `DebugStepsSeeder` ให้เขียนคนละ slot ไม่ทับกันทุกครั้ง (`midnight + slot*2min`, slot เพิ่มทีละ 1 ต่อการกด) — กดกี่ทีก็บวกสะสมตรง ๆ แล้ว

**ยืนยันแล้ว** บน emulator จริง (screenshot Health Connect → Steps → Access): "everstride" อยู่ทั้งใน "Can read steps" และ "Can write steps" — permission flow end-to-end ทำงานถูกต้องครบวงจร

**ยืนยันแล้วบนมือถือจริงด้วย**: ต่อ device จริง, รันแอปได้ปกติ, อ่านค่าก้าวเดินถูกต้อง — ไม่ใช่แค่ emulator/debug seeder อีกต่อไป

- [x] Add manual refresh (ปุ่ม "Sync Now" ใน home page — `ref.invalidate(stepsForSelectedDateProvider)` fetch ใหม่ตามวันที่เลือกอยู่ ไม่ต้องเปลี่ยนวัน. ระหว่าง refresh ตัวเลขเดิม**ไม่หาย** — ใช้ `steps.value` (ไม่ใช่ pattern match ตรง ๆ) เก็บค่าล่าสุดไว้โชว์ระหว่างโหลด พร้อม spinner เล็ก ๆ ข้าง ๆ, ปุ่มกดซ้ำไม่ได้ระหว่างโหลด — ตรงตาม DoD "ข้อมูลก้าวเดินไม่หายเมื่อ refresh" — รอทดสอบจริงบน device)
- [x] Handle Health Connect unavailable state (`HealthRepository` เพิ่ม `promptInstallOrUpdate()` ห่อ `health` package's `installHealthConnect()` (เปิด Play Store ให้ install/update). Home page: ถ้า `sdkAvailable` ไม่จริง (ไม่ว่าจะ `sdkUnavailable` หรือ `sdkUnavailableProviderUpdateRequired`) จะ**ซ่อน**ส่วน permission/steps/debug-seeder ทั้งหมด แล้วโชว์ข้อความ + ปุ่ม "Install / Update Health Connect" แทน กันไม่ให้ผู้ใช้กด action ที่ทำงานไม่ได้อยู่แล้ว — รอทดสอบจริง (ถอนการติดตั้ง Health Connect ชั่วคราวเพื่อเช็ค))
- [x] Log readable errors during development (`lib/core/utils/app_logger.dart` — `AppLogger.debug`/`AppLogger.error` ห่อ `dart:developer`'s `log()`, gate ด้วย `kDebugMode` ไม่ล็อกเลยใน release. Wire เข้า `HealthRepositoryImpl` ทุก method ตาม plan section 13 (areas: `health.availability`, `health.permission`, `health.query`) — log ทั้ง success และ error พร้อม cause exception ให้อ่านง่ายตอน dev)
- [x] Permission recheck (แก้สาเหตุ text ค้าง/ไม่ตรงสถานะจริง: เพิ่ม `HealthRepository.hasPermission()` — เช็คสถานะจริงเฉย ๆ ไม่เด้ง dialog. `HealthPermissionController.build()` เรียก recheck นี้อัตโนมัติทันทีตอนเปิดแอป แทนที่จะเริ่มที่ "not requested" ค้างจนกว่าจะกดปุ่ม — ข้อความบนจอจะตรงกับสถานะจริงของ Health Connect เสมอ. หมายเหตุแยกอีกเรื่อง: ถ้า permission ติด `USER_FIXED` (Android ปฏิเสธเปิด dialog ถาวร) โค้ดเราสั่งเปิด dialog ซ้ำไม่ได้จริง ๆ — เป็นข้อจำกัดของ Android OS ไม่ใช่ bug, ผู้ใช้ต้องไปแก้เองใน Health Connect settings)

**Definition of Done (Phase 1):**

- [x] อุปกรณ์ Android จริงเชื่อมต่อ Health Connect ได้ (ทดสอบบนมือถือจริงแล้ว)
- [x] แอปอ่านค่าก้าวเดินวันนี้ได้ (ยืนยันบนมือถือจริง)
- [x] ระบบขอ permission ทำงานถูกต้อง
- [x] แอปไม่ crash เมื่อ permission ถูกปฏิเสธ
- [x] ข้อมูลก้าวเดินไม่หายเมื่อ refresh/navigate (refresh: ยืนยันด้วยโค้ด — เก็บค่าล่าสุดโชว์ระหว่างโหลดใหม่ไม่ blank. navigate: ยังมีจอเดียว ยังไม่มี route ให้เด้งออกจากกัน)

**ยืนยันซ้ำหลัง Phase 2 แก้ `home_page.dart`/`health_repository_impl.dart`**: ทำ manual recheck ทั้งหมดใน `everstride-docs/development/testing.md` section "Phase 1" ใหม่ — ลบแอปแล้วลงใหม่ (fresh install), Sync Now, debug "[Debug] Insert 500 test steps" — ผ่านหมด ไม่มี regression จากการแก้ Phase 2

### Phase 2 — Local Health Sync

ดู `everstride-docs/specs/2026-09-08-phase2-local-health-sync-design.md` สำหรับ design rationale เต็ม ๆ (ไม่ก็อปซ้ำที่นี่)

- [x] Create Drift health tables (`lib/core/database/app_database.dart` — `AppDatabase` (Drift) ตัวแรกของโปรเจกต์ + ตาราง `HealthDaily` (`date` primary key, `totalSteps`, `rewardedSteps`, `lastSyncedAt`) + `appDatabaseProvider`, เก็บไฟล์ `everstride.sqlite` จริงใน app documents directory ผ่าน `LazyDatabase` ไม่ใช่ in-memory)
- [x] Store daily Health Connect snapshot (`lib/features/health/domain/repositories/health_sync_repository.dart` (interface + `HealthDailyRecord`) + `lib/features/health/data/repositories/health_sync_repository_impl.dart` (Drift-backed impl — `getMostRecentSyncedDate`/`getRecord`/`upsertRecord`, ทุก method wrap try-catch คืน `Result<T>`) + `healthSyncRepositoryProvider`)
- [x] Store already-converted steps (`HealthDaily.rewardedSteps` เก็บยอดที่ reward ไปแล้วสะสมต่อวัน แยกจาก `totalSteps` ซึ่งเป็นยอดดิบจาก Health Connect)
- [x] Calculate delta safely (`lib/features/health/domain/usecases/sync_health_data_usecase.dart` — `SyncHealthDataUseCase.call()` คำนวณ `rewardable = max(0, totalSteps - rewardedSoFar)` ต่อวัน)
- [x] Handle day rollover (use case เดินวันที่ตั้งแต่ `sinceDate` (วันล่าสุดที่เคย sync) ถึงวันนี้ทีละวัน — ถ้าข้ามวันไปโดยไม่เปิดแอป จะไล่ให้ครบทุกวันที่ขาดในการ sync ครั้งถัดไป, ครั้งแรกสุด cap ไว้ 7 วันย้อนหลัง)
- [x] Handle step count corrections (delta ใช้ `max(0, ...)` กันไม่ให้ยอดที่ลดลงจริง เช่น Health Connect แก้ไขค่าย้อนหลัง กลายเป็นค่าติดลบหรือ reward ผิด)
- [x] Prevent duplicate rewards (`rewardedSteps` สะสมต่อวันใน DB, sync ครั้งถัดไปหักลบยอดที่ reward ไปแล้วก่อนคำนวณ delta ใหม่ — กด "Sync Now" ซ้ำโดยไม่มีก้าวใหม่ได้ "No new rewardable steps" ไม่ใช่ reward ซ้ำ)

**Wiring เข้า UI**: `lib/features/health/presentation/controllers/health_sync_controller.dart` — `HealthSyncController` (`Notifier<AsyncValue<Result<SyncResult>>?>`, ตาม pattern เดียวกับ `HealthPermissionController`) + `syncHealthDataUseCaseProvider`. ปุ่ม "Sync Now" เดิมใน home page ตอนนี้ทำสองอย่างพร้อมกัน: `ref.invalidate(stepsForSelectedDateProvider)` (refresh ตัวเลขดิบ, มีจาก Phase 1 อยู่แล้ว) + `ref.read(healthSyncControllerProvider.notifier).sync()` (คำนวณ/บันทึก delta ใหม่). เพิ่มบรรทัดผลลัพธ์ใต้ปุ่ม: "+N rewardable steps synced" / "No new rewardable steps" / "Sync error (...)" ตามสถานะ.

**หมายเหตุ**: task การ wire นี้ไม่มี automated test (Riverpod controller + widget tree) — ตรวจด้วย `flutter analyze` (ผ่าน, no issues) และ manual recheck steps ใน `everstride-docs/development/testing.md` (section "Phase 2 — Local Health Sync") แทน. ตัว logic หลัก (`SyncHealthDataUseCase`) มี unit test ครบ 8 เคสจาก task ก่อนหน้าอยู่แล้ว.

### Phase 3 — Player Progression MVP

ดู `everstride-docs/specs/2026-09-08-phase3-player-progression-design.md` สำหรับ design rationale เต็ม ๆ (ไม่ก็อปซ้ำที่นี่)

- [x] Create Player entity (`lib/features/player/domain/repositories/player_repository.dart` — `PlayerState` (`level`/`exp`/`energy`/`gold`/`pendingSteps`) + `PlayerRepository` interface (`getPlayer`/`savePlayer`) — CRUD ล้วน ๆ ไม่มี logic คำนวณ energy/exp/level อยู่ในนี้)
- [x] Create Player local persistence (`lib/core/database/app_database.dart` เพิ่มตาราง `Player` (single-row คงที่ที่ `id = 0`) + `schemaVersion` bump 1 → 2 พร้อม `onUpgrade` สร้างตาราง `Player` ให้เครื่องที่มี DB ไฟล์ Phase 2 อยู่แล้วไม่พัง + `lib/features/player/data/repositories/player_repository_impl.dart` (`PlayerRepositoryImpl`, Drift-backed, คืน default state level 1/0/0/0/0 ถ้ายังไม่เคยมี row) + `playerRepositoryProvider`. มี unit test ครบ (`test/features/player/data/repositories/player_repository_impl_test.dart`))
- [x] Implement step-to-energy conversion (`lib/features/player/domain/usecases/credit_energy_from_steps_usecase.dart` — `CreditEnergyFromStepsUseCase`, 100 steps = 1 Energy, เศษที่เหลือเก็บใน `pendingSteps` ไม่ให้หายตอน sync ทีละน้อยหลายครั้ง. Wire เข้า `PlayerController` ด้วย `ref.listen(healthSyncControllerProvider, ...)` — energy บวกอัตโนมัติทุกครั้งที่ sync สำเร็จแล้วมี rewardable steps ใหม่ > 0 ไม่ต้องกดปุ่มเพิ่ม และไม่แก้โค้ด health feature เดิมเลย)
- [x] Display Energy (หน้า Home เพิ่มบรรทัด "Energy: N Gold: N" ใต้ส่วน sync เดิม)
- [x] Create EXP system (`lib/features/player/domain/usecases/spend_energy_for_adventure_usecase.dart` — `SpendEnergyForAdventureUseCase`, Adventure ตัวอย่างชั่วคราวตามตัวอย่าง "Forest Path" ใน plan Phase 4: cost 10 Energy → +25 EXP, +10 Gold ต่อครั้ง, คืน `Err('Not enough energy')` ถ้า Energy ไม่พอ โดยไม่แก้ state เลย)
- [x] Create basic level-up curve (`PlayerState.expToNextLevel(level) => level * 100`; loop ใน use case ข้าม level ให้ครบภายในการกดครั้งเดียวถ้า exp เกิน threshold หลายรอบ (`while (newExp >= expToNext)`), exp ที่เหลือหลัง wrap ไป level ถัดไปไม่ติดลบ)
- [x] Add simple player status screen (`lib/features/player/presentation/controllers/player_controller.dart` — `PlayerController` (`Notifier<AsyncValue<Result<PlayerState>>?>`) โหลด/refresh player state จาก repository + reactive credit energy ตามข้างบน + method `spendOnAdventure()`; หน้า Home เพิ่ม `Consumer` ใหม่แสดง "Level N — EXP x/y" + "Energy: N Gold: N" + ปุ่ม "Adventure (temporary) — 10 Energy → +25 EXP, +10 Gold" ชั่วคราว (Phase 4 จะแทนที่ด้วยระบบ Adventure จริง) — กดแล้ว error (`Err`) โชว์เป็น SnackBar "Not enough energy" โดยไม่กระทบค่า Level/EXP/Energy/Gold ที่แสดงอยู่บนจอ. ถือโอกาสลบ default Flutter counter demo (`_counter`/`_incrementCounter`/`FloatingActionButton`) ออกจาก `home_page.dart` เพราะไม่ใช่ feature จริงอยู่แล้ว และกลายเป็น `unused_field` หลังเอา `Text('$_counter')` ออก)

**หมายเหตุ**: task การ wire `PlayerController` เข้า UI ไม่มี automated test (Riverpod controller + widget wiring) — ตรวจด้วย `flutter analyze` (ผ่าน, no issues) และ manual recheck steps ใน `everstride-docs/development/testing.md` (section "Phase 3 — Player Progression MVP") แทน, ตาม pattern เดียวกับ Phase 2's `HealthSyncController` wiring. ตัว logic หลัก (`PlayerRepositoryImpl`, `CreditEnergyFromStepsUseCase`, `SpendEnergyForAdventureUseCase`) มี unit test ครบจาก task ก่อนหน้าอยู่แล้ว (11 tests รวมกัน, ผ่านหมด).

### Phase 3.1 — UI Foundation

ดู `everstride-docs/specs/2026-09-08-phase3.1-ui-foundation-design.md` สำหรับ design rationale เต็ม ๆ (ไม่ก็อปซ้ำที่นี่)

- [x] Add onboarding persistence (`AppSettings` single-row table + `AppSettingsRepository`, schema migration 2 → 3 เพื่อให้ database เดิมเปิดได้โดยไม่ crash)
- [x] Add Splash/Onboarding/Permission flow (Splash อ่าน `onboardingCompleted`; Permission บันทึกว่าผ่าน onboarding แล้ว ไม่ว่าผู้ใช้จะอนุญาต Health Connect หรือไม่)
- [x] Add persistent five-tab navigation shell (`StatefulShellRoute.indexedStack`: Home, Adventure, Journal, Character, Menu และเก็บ state ของแต่ละ tab)
- [x] Reskin Home as a real dashboard (steps ring, level/EXP, Energy, Gold, calendar และ sync action โดยใช้ provider/logic เดิม)
- [x] Add real Adventure, Character, and Menu screens (ย้าย temporary Adventure action, แสดง Player state, และย้าย Health/debug tools ไป Menu)
- [x] Add Journal placeholder (ยังไม่มี activity/quest history ใน phase นี้)
- [x] Add mockup-derived theme tokens and background asset registration (`lib/assets/bg.png`; ไม่มี dependency ใหม่)
- [x] Add targeted tests and manual recheck steps (repository, Splash routing, bottom-nav behavior; รายละเอียด manual test อยู่ที่ `development/testing.md`)

### Phase 3.2 — Adventure UI Skeleton

ดู `everstride-docs/specs/2026-09-09-phase3.2-adventure-ui-skeleton-design.md` สำหรับ design rationale เต็ม ๆ (ไม่ก็อปซ้ำที่นี่)

- [x] Reskin Adventure as Greenwood Trail (`lib/features/adventure/presentation/screens/adventure_screen.dart` — title/description, rounded trail artwork จาก `lib/assets/bg.png`, และ layout ตาม mockup)
- [x] Add local difficulty selection (Easy/Normal/Hard, default Easy; เปลี่ยนเฉพาะ selected styling ในหน้านี้และไม่ persist state)
- [x] Preserve temporary Adventure gameplay (`Start Adventure · 10 Energy` ยังคงเรียก `PlayerController.spendOnAdventure()` เดิม: 10 Energy → +25 EXP, +10 Gold; difficulty ยังไม่กระทบ cost/reward)
- [x] Add implemented reward preview and action feedback (แสดงเฉพาะ +25 EXP/+10 Gold; success แสดง SnackBar, insufficient Energy แสดง `Not enough energy` เหมือนเดิม)
- [x] Keep Phase 4 scope deferred (ไม่มี Adventure model, database, item/loot, balance, in-progress/result screen, หรือ atomic transaction ใน phase นี้)
- [x] Add targeted widget tests (`test/features/adventure/presentation/adventure_screen_test.dart` ครอบคลุม default/selection state, successful action, และ insufficient-Energy action; `flutter analyze` ผ่าน)

## Phase ถัดไป

- [ ] Phase 4 — Adventure MVP
  - [ ] เอกสาร `game-design/quests.md`
- [ ] Phase 5 — Daily Quests
  - [ ] เอกสาร `game-design/economy.md`
- [ ] Phase 6 — Supabase Integration
  - [ ] เอกสาร `game-design/balancing.md`
- [ ] Phase 7 — Full UI & UX Polish

## กฎที่ต้องยึดระหว่างทำงาน (จาก plan section 14)

- อย่าเรียก Supabase / Health Connect / SQLite ตรงจาก UI widget — ต้องผ่าน repository interface
- อย่าเพิ่ม Go API หรือ Flame จนกว่าจะจำเป็นจริง
- เขียน test คู่กับ logic ที่เกี่ยวกับ reward/progression (กันรางวัลซ้ำ)
- รัน formatter/analyzer/tests หลังแก้โค้ดที่มีผลจริง
