# Everstride — Progress Tracker

อ้างอิงแผนงานที่ `everstride-docs/plan/EVERSTRIDE_PLAN.md`

## สถานะปัจจุบัน (2026-09-07, อัปเดตล่าสุด)

ตรวจสอบ repo จริง (`everstride-mobile/`) แล้วพบว่า:

- **Flutter project สร้างแล้ว** — มี `pubspec.yaml`, `lib/main.dart`
- `flutter analyze` ผ่าน ไม่มี issue
- **Android emulator** — ✅ ยืนยันแล้วว่า build ขึ้นจริงบน `Pixel_10_Pro` emulator, เปิดแอปได้สำเร็จ (ปิด emulator แล้วหลังเช็ค)
- **Riverpod** — ✅ wire แล้ว — `main.dart` ห่อ `MyApp` ด้วย `ProviderScope`
- **GoRouter** — ✅ wire แล้ว — `lib/app/router.dart` มี route `/`, `MaterialApp.router` ใช้งานจริง, `MyHomePage` ย้ายไป `lib/app/home_page.dart`
- **minSdk** — ✅ bump เป็น `26` ใน `android/app/build.gradle.kts` แล้ว (Health Connect ต้องการ API 26 ขึ้นไป)

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

- [x] Detect Health Connect availability (`health` package เพิ่มแล้ว, `HealthConnectDataSource` + `HealthRepositoryImpl.isAvailable()` เช็ค `getHealthConnectSdkStatus()`, AndroidManifest เพิ่ม `<queries>` สำหรับ `com.google.android.apps.healthdata`, `main.dart` เรียก `Health().configure()`, หน้า Home แสดงสถานะ "Health Connect: available/not available". ✅ ยืนยันแล้วบน emulator จริง — เห็น "Health Connect: available". `requestPermissions()`/`getTodaySteps()` ยัง throw `UnimplementedError` รอ task ถัดไป)
- [x] Request required permissions (`MainActivity` เปลี่ยนเป็น `FlutterFragmentActivity` แล้ว, `AndroidManifest.xml` เพิ่ม `READ_STEPS` permission + permission-rationale intent-filter + `ViewPermissionUsageActivity` alias, `HealthConnectDataSource.hasStepsPermission()`/`requestStepsPermission()` ขอแค่ steps ตาม plan section 7, `HealthRepositoryImpl.requestPermissions()` implement จริง, หน้า Home มีปุ่ม "Request Health Permission" + สถานะ granted/denied. ✅ ยืนยันแล้วบน emulator จริง — กดปุ่มแล้วได้ "Permission: granted")

  ![granted](image/PROGRESS/1788805440434.png)

- [x] Handle permission denied state (ไม่ crash โดยดีไซน์เดิม — `health` package คืน `Future<bool>` ตอนขอ permission ไม่ throw ตอน deny, + `Result`/`Err` + `AsyncValue.guard` ดักซ้ำอีกชั้น. เพิ่ม hint text "Steps can't be read without this permission. Tap below to try again." ตอน denied ใน home page, ปุ่มกด retry ได้เรื่อย ๆ. ✅ ยืนยันแล้วบน emulator จริง — revoke permission ผ่าน `adb shell pm revoke`, กด deny ใน dialog, เห็น "Permission: denied" + hint text ถูกต้อง ไม่ crash)
- [x] Read today's steps (`HealthRepository` เพิ่ม `getStepsForDate(DateTime)`, `getTodaySteps()` เรียกต่อด้วย `DateTime.now()`; `HealthConnectDataSource.getTotalSteps()` ใช้ `health` package's `getTotalStepsInInterval()`; ทำเกินสโคปนิดตามที่สั่ง — เพิ่มความสามารถเลือกวันย้อนหลังได้ด้วย ไม่ใช่แค่ today)
- [x] Display current step count (`lib/features/health/presentation/controllers/steps_controller.dart` — `selectedDateProvider` (`Notifier<DateTime>`, ค่าเริ่มต้น = วันนี้) + `stepsForSelectedDateProvider` (`FutureProvider<Result<int>>`, re-fetch อัตโนมัติเมื่อวันที่เปลี่ยน). Home page แสดง "Steps on YYYY-MM-DD: N" + ปุ่ม "Pick a date" (`showDatePicker`, จำกัดช่วง 365 วันย้อนหลังถึงวันนี้). หมายเหตุ: Riverpod 3 เอา `StateProvider` ออกแล้ว ใช้ `Notifier<DateTime>` แทน)

**เจอปัญหาระหว่างทดสอบ**: อ่านได้ 0 steps ทั้งที่ Samsung Health (บน emulator) โชว์ 31 steps — สาเหตุคือ permission "write" ให้ Samsung Health sync เข้า Health Connect ไม่ได้แปลว่า data ถูกเขียนจริงแล้ว (emulator ไม่มี sensor เดินจริง, sync ของ Samsung Health ไม่แน่นอน). แก้ด้วยการเพิ่มเครื่องมือ debug-only สำหรับยัด test data เข้า Health Connect เอง:

- `android/app/src/debug/AndroidManifest.xml` เพิ่ม `WRITE_STEPS` (debug build เท่านั้น, ไม่ขึ้น release)
- `lib/features/health/presentation/widgets/debug_steps_seeder.dart` — ปุ่ม "[Debug] Insert 500 test steps" ใช้ `Health().writeHealthData()` ตรง ๆ (ไม่ผ่าน `HealthRepository` เพราะ repo ตั้งใจให้ read-only ตาม architecture), gate ด้วย `kDebugMode`, invalidate `stepsForSelectedDateProvider` ให้ auto refresh หลัง insert
- ต้อง full rebuild (`flutter run` ใหม่ ไม่ใช่ hot reload) เพราะ manifest permission เปลี่ยน

**ปัญหาที่เจอระหว่างทดสอบ debug tool + วิธีแก้:**

1. `SecurityException: requires WRITE_STEPS` แม้ manifest ประกาศแล้ว — สาเหตุคือ `USER_FIXED` flag ค้างอยู่บน `READ_STEPS` (จากการผสม `adb pm revoke` กับกด deny จริงตอนทดสอบ task ก่อนหน้า) ทำให้ Android ปฏิเสธเปิด permission dialog ให้ทั้งกลุ่ม STEPS (ทั้ง read และ write) ไปด้วย. แก้ด้วย `adb shell pm reset-permissions com.namchok.everstride` (เคลียร์ flag ทั้งหมดของแอปนี้ กลับไปสถานะ "ยังไม่เคยขอ") แล้ว request permission ใหม่ทั้ง read/write ผ่านหน้าแอปจริง — สำเร็จ
2. กด "[Debug] Insert 500 test steps" ซ้ำ ๆ ได้ total ไม่ตรง (506 แทนที่จะเป็นทวีคูณของ 500) — เพราะปุ่มเดิมเขียนทับช่วงเวลาเดิม (`now-1h` ถึง `now`) ทุกครั้ง ช่วงเวลาทับกัน Health Connect เลย dedupe/interpolate ให้แทนที่จะบวกตรง ๆ (พฤติกรรมจริงของ Health Connect ไม่ใช่ bug เรา). แก้ `DebugStepsSeeder` ให้เขียนคนละ slot ไม่ทับกันทุกครั้ง (`midnight + slot*2min`, slot เพิ่มทีละ 1 ต่อการกด) — กดกี่ทีก็บวกสะสมตรง ๆ แล้ว

✅ ยืนยันแล้วบน emulator จริง (screenshot Health Connect → Steps → Access): "everstride" อยู่ทั้งใน "Can read steps" และ "Can write steps" — permission flow end-to-end ทำงานถูกต้องครบวงจร

- [ ] Add manual refresh
- [ ] Handle Health Connect unavailable state
- [ ] Log readable errors during development
- [ ] Permission recheck, อยากเพิ่มการเช็ค permission หายุ่งเกี่ยวกับ App อื่นๆ หรือ Health Connect เพราะเข้ามาตอนแรก Perrmission ขึ้น Denied ตลอด แต่ Sync ได้คิดว่าไม่ได้อัปเดต Text เฉยๆ

**Definition of Done (Phase 1):**

- อุปกรณ์ Android จริงเชื่อมต่อ Health Connect ได้
- แอปอ่านค่าก้าวเดินวันนี้ได้
- ระบบขอ permission ทำงานถูกต้อง
- แอปไม่ crash เมื่อ permission ถูกปฏิเสธ
- ข้อมูลก้าวเดินไม่หายเมื่อ refresh/navigate

## Phase ถัดไป (ยังไม่เริ่ม จนกว่า Phase 1 เสถียร)

- [ ] Phase 2 — Local Health Sync (กันรางวัลซ้ำ)
- [ ] Phase 3 — Player Progression MVP (steps → Energy → EXP)
- [ ] Phase 4 — Adventure MVP
- [ ] Phase 5 — Daily Quests
- [ ] Phase 6 — Supabase Integration

## กฎที่ต้องยึดระหว่างทำงาน (จาก plan section 14)

- อย่าเรียก Supabase / Health Connect / SQLite ตรงจาก UI widget — ต้องผ่าน repository interface
- อย่าเพิ่ม Go API หรือ Flame จนกว่าจะจำเป็นจริง
- เขียน test คู่กับ logic ที่เกี่ยวกับ reward/progression (กันรางวัลซ้ำ)
- รัน formatter/analyzer/tests หลังแก้โค้ดที่มีผลจริง
