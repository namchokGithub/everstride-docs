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

- [ ] Detect Health Connect availability
- [ ] Request required permissions
- [ ] Handle permission denied state
- [ ] Read today's steps
- [ ] Display current step count
- [ ] Add manual refresh
- [ ] Handle Health Connect unavailable state
- [ ] Log readable errors during development

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
