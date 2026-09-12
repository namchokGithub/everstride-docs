# Everstride — Progress Tracker

อ้างอิงแผนงานที่ [EVERSTRIDE_PLAN.md](EVERSTRIDE_PLAN.md)

## สถานะปัจจุบัน (2026-09-10, อัปเดตล่าสุด)

Phase 0–6 เสร็จแล้ว: Health Connect sync, Player progression, Greenwood Trail,
Daily Quests, Trail Supplies, และ Supabase Auth/Cloud Backup ทำงานแล้ว

สิ่งที่ต้องระวัง: Cloud Backup ยังปลอดภัยสำหรับการเล่นหลักเครื่องเดียวเท่านั้น
สองเครื่องที่ผูกบัญชีเดียวกันสามารถเขียน snapshot ทับกันได้ จึงต้องทำ
Multi-device Save Safety ก่อนเปิดให้เล่นสลับเครื่องอย่างเป็นทางการ

## เป้าหมายถัดไป

1. ออกแบบ Multi-device Save Safety และทดสอบ conflict/offline restore
2. ทำ Phase 6.1 Balancing Metrics Instrumentation และเก็บ baseline การเล่น
3. ทำ Phase 7 Full UI & UX Polish

## Checklist implementation history

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

### Phase 4 — Adventure MVP

ดู `everstride-docs/game-design/adventure-system.md` สำหรับ game-design rationale และ difficulty matrix เต็ม ๆ (ไม่ก็อปซ้ำที่นี่)

- [x] Add static Adventure content (`Adventure`/`AdventureDifficulty` + `greenwoodTrail` catalog: Easy 10/25/10, Normal 20/55/22, Hard 30/90/36; ไม่มี Drift table หรือ AdventureRun history)
- [x] Generalize Adventure resolution (`SpendEnergyForAdventureUseCase` และ `PlayerController.spendOnAdventure` รับ energy cost/EXP/Gold จาก caller เป็น primitive values; player feature ไม่ import adventure feature)
- [x] Add real per-difficulty Adventure screen (preview, CTA, และ controller call ใช้ selected Greenwood Trail difficulty ค่าเดียวกัน)
- [x] Add dedicated result screen (`/adventure-result` อยู่นอก bottom-nav shell, แสดง Energy/EXP/Gold, Lv/EXP หลัง resolve, และ Level Up callout; Continue pop กลับ Adventure tab)
- [x] Handle insufficient Energy and duplicate starts (dialog บอก cost/current Energy แบบชัดเจนโดยไม่เปลี่ยน Player state; in-flight guard ป้องกัน double-tap resolve ซ้ำ)
- [x] Add focused automated coverage (catalog 1 test, reward math 6 tests, Adventure UI/navigation/dialog/double-tap 4 widget tests; `flutter analyze` ผ่าน)
- [x] Add Phase 4 manual recheck (`development/testing.md` ครอบคลุม tier values, result, level up, insufficient Energy, duplicate tap, และ persistence)

### Phase 5 — Daily Quests

ดู `everstride-docs/game-design/quests.md` สำหรับ game-design rationale และ Quest values เต็ม ๆ (ไม่ก็อปซ้ำที่นี่)

- [x] Add fixed Daily Quest content (`QuestDefinition`/`QuestInstance` + catalog 3 quests: 1,000 Steps, 3,000 Steps, และ 1 Adventure completion)
- [x] Add local Quest persistence (`DailyQuestInstances` Drift table, schema migration 5 → 6, และ `QuestRepository`)
- [x] Add lazy rollover and Step progress (`EnsureDailyQuestsUseCase` สร้าง Quest วันนี้, expire Quest เก่า, และอ่าน total steps จาก local health sync record)
- [x] Add Adventure progress and safe claims (`RecordAdventureCompletionUseCase`; `ClaimDailyQuestUseCase` re-check stored state และให้ EXP/Gold พร้อม claimed state ใน Drift transaction)
- [x] Add Quest controller and Journal UI (Sync refreshes Step quests, Adventure success advances Trailbound, Claim reloads Player state)
- [x] Add focused automated coverage and Phase 5 manual recheck (`quest_catalog`, repository round-trip, rollover, Adventure completion, stale duplicate claim; `flutter analyze` ผ่าน)

### Phase 5.1 — Economy: Trail Supplies

ดู `everstride-docs/game-design/economy.md` สำหรับ economy principles; ราคา 30 Gold และโบนัส ×1.5 เป็น decision ของ Phase 5.1 (ไม่มี inventory หรือ purchase record)

- [x] Add optional Trail Supplies spending (30 Gold ต่อ Adventure run, floor-rounded ×1.5 EXP/Gold, ทุก difficulty)
- [x] Make Adventure/Quest Player mutations transaction-safe (shared Drift transaction boundary ป้องกัน Player update หายเมื่อ claim กับ Adventure เกิดพร้อมกัน)
- [x] Add Adventure toggle/result accounting (แสดง Gold ที่จ่าย, reset toggle หลัง run สำเร็จ, และป้องกัน Gold ไม่พอ)
- [x] Add targeted coverage (Gold math, invalid costs, cross-feature transaction, Adventure UI/result/reset; `flutter analyze` ผ่าน)

### Phase 6 — Supabase Integration

ไม่มี game-design doc สำหรับ phase นี้; ใช้แนวทาง local-first/no-merge และป้องกันการเขียนทับข้อมูลข้าม account ตาม plan

- [x] Add optional Supabase initialization (ไม่มี URL/key แอปยังทำงาน local-only; มี config จึงเปิด Supabase)
- [x] Add email/password authentication (Sign Up, Sign In, Sign Out, email-confirmation state, และ Menu backup status/retry)
- [x] Add account protection (remote save ที่มีอยู่จะไม่ถูกเขียนทับเมื่อเครื่องยังไม่เคยผูก account; ผู้ใช้ต้องเลือก Restore หรือยืนยัน Replace cloud backup)
- [x] Add atomic cloud snapshot (`player_saves` เก็บ Player, `health_daily`, และ Daily Quest instances พร้อม RLS; migration ถูก apply กับ Supabase project แล้ว)
- [x] Add safe restore and serialized backup (replace local state ใน Drift transaction, refresh Player หลัง restore, และ coalesce backup request)
- [x] Connect real Supabase project and smoke-test auth (สร้าง confirmed test user และ Sign In จากแอปได้; `flutter analyze` ผ่าน)
- [x] Re-run full manual cloud recheck after account-link safety fix (fresh install → sign in → Restore, explicit Replace, account switching, offline retry, และ RLS isolation ตาม `development/testing.md`)

### Phase 6.1 — Balancing Metrics Instrumentation

อ้างอิง [implementation plan](plans/2026-09-10-phase6.1-balancing-metrics.md)
และ [balancing.md](game-design/balancing.md) — phase นี้เก็บ observation
เท่านั้น ไม่มีการเปลี่ยน balance values และข้อมูล metrics เป็น local-only;
uninstall/clear-data/restore cloud ไม่กู้คืน event history

- [x] Add append-only Drift `MetricEvents` storage (schema 7 → 8) และ safe `MetricsRecorder` ที่ไม่ทำให้ gameplay failure กลายเป็น error ของผู้เล่น
- [x] Instrument health sync, positive Energy credit, Adventure attempts/rejections, Quest rollover, และ persisted Quest claims
- [x] Add focused storage/recorder, Adventure, และ Quest rollover coverage; `flutter analyze` ผ่าน
- [ ] Run the Phase 6.1 manual database checks in `development/testing.md` on a debuggable device build
- [ ] Collect a clearly labelled one-to-two-week baseline before changing balance values

## Phase ถัดไป

- [ ] Phase 7 — Full UI & UX Polish
- [ ] Phase 7.1 — Multi-device Save Safety — ออกแบบและวางแผนรองรับบัญชีเดียวบนหลายเครื่องก่อน implement

**ข้อจำกัดปัจจุบัน:** Login บัญชีเดียวกันได้หลายเครื่อง แต่หลังผูกบัญชีแล้วแต่ละเครื่องยัง upsert snapshot ของตัวเองทับ cloud ได้ ไม่มีการตรวจ revision ข้ามเครื่องหรือ merge ความคืบหน้า ข้อมูลเก่าจึงอาจทับข้อมูลใหม่ได้ การ serialize upload ใน Phase 6 ป้องกันลำดับ request ภายในเครื่องเดียวเท่านั้น ระหว่างนี้ควรเล่นหลักเครื่องเดียว

**ลำดับงานที่แนะนำ:**

1. ออกแบบ Multi-device Save Safety ก่อนเปิดให้เล่นสลับเครื่อง: กำหนดพฤติกรรมเมื่อ local/cloud ต่างกันและเมื่อกลับจาก offline โดยเริ่มจากตรวจ revision และปฏิเสธการเขียนข้อมูลเก่าที่ฝั่ง server แบบ atomic พร้อมเก็บ local progress ไว้ให้ผู้ใช้ตัดสินใจ การ fetch ก่อน push อย่างเดียวไม่ป้องกันสองเครื่องเขียนพร้อมกัน
2. กำหนดวิธีย้ายเครื่อง/แก้ conflict ที่ผู้ใช้เข้าใจได้ รวมถึงการเล่น offline พร้อมกัน และกติกา Steps/Quest ข้ามเครื่องเพื่อไม่ให้รับรางวัลซ้ำ ห้ามบวก Energy/Gold ของสอง snapshot เข้าด้วยกันโดยตรง; เลือกนโยบายใน spec ก่อน implement
3. ยืนยันด้วยสองเครื่องจริงหรือ integration tests: A อัปเดต cloud แล้ว B ส่ง save เก่า, เขียนพร้อมกัน, offline แล้ว reconnect, retry หลัง request ขาดการตอบกลับ และ restore ตามด้วย Health sync ต้องไม่ทับความคืบหน้าเงียบ ๆ หรือให้รางวัลซ้ำ
4. ทำ Phase 6.1 แล้วเก็บ baseline 1–2 สัปดาห์ก่อนปรับ balance ครั้งใหญ่ ระหว่างที่ multi-device ยังไม่พร้อมสามารถเก็บข้อมูลด้วยเครื่องหลักเครื่องเดียวได้ โดยแยก session ที่ใช้ debug Steps ออกจากการเล่นจริง
5. ทำ Phase 7 โดยเน้นสถานะ backup/conflict, ความชัดเจนของค่าใช้จ่ายและรางวัล, และ feedback หลัง sync/Adventure/Quest จากนั้นค่อยเลือกปรับ balance ตามข้อมูลและความคิดเห็นผู้เล่น

รายการ Multi-device ข้างต้นเป็นข้อเสนอสำหรับ spec/plan ถัดไป ยังไม่ใช่ความสามารถที่ implement แล้ว และยังไม่รับรองการ merge การเล่นพร้อมกันหลายเครื่อง

## กฎที่ต้องยึดระหว่างทำงาน (จาก plan section 14)

- อย่าเรียก Supabase / Health Connect / SQLite ตรงจาก UI widget — ต้องผ่าน repository interface
- อย่าเพิ่ม Go API หรือ Flame จนกว่าจะจำเป็นจริง
- เขียน test คู่กับ logic ที่เกี่ยวกับ reward/progression (กันรางวัลซ้ำ)
- รัน formatter/analyzer/tests หลังแก้โค้ดที่มีผลจริง
