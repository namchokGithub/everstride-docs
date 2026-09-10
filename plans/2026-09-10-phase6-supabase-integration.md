# Phase 6 — Supabase Integration Implementation Plan

> **For implementers:** Follow the tasks in order and keep their checkboxes
> current. Manual Supabase dashboard actions remain user-owned.

**Goal:** Let a player optionally create an account (email/password) and back up their Player progression (Level/EXP/Energy/Gold/pending Steps) to Supabase, restorable on a new device. Local play remains fully functional and authoritative with no account — this is a backup/restore feature, not a login gate.

**Architecture:** There is no game-design doc for this phase (unlike Phase 4/5/5.1) — the source is `EVERSTRIDE_PLAN.md`'s own "Phase 6 — Supabase Integration" section, which lists the initial tables and explicitly leaves "define local-first conflict strategy" as an open task for this plan to answer. That answer, confirmed with the user before this plan was written: **local is always authoritative during normal play.** Cloud is a backup/restore point, not a second source of truth to merge against:

- After every successful local Player mutation while signed in, the new state is pushed to Supabase (last-write-wins, no merge logic).
- On sign-in, an existing cloud save is never overwritten until the device is
  already linked to that exact account or the player explicitly selects
  **Replace cloud backup**. A device with no account link must choose between
  **Restore cloud backup** (the safe default) and Replace, even if startup
  reconciliation has already populated a local Player row.

**Backup scope (corrected):** A fresh local database performs a seven-day
Health Connect catch-up, not a one-day sync. Therefore restoring only Player
stats would let it credit Energy again; likewise, omitting today's quest state
could permit a Daily Quest reward to be claimed again. Phase 6 backs up one
atomic gameplay snapshot: Player state, `health_daily` checkpoint rows, and
`daily_quest_instances`. Inventory and any future non-implemented state remain
out of scope. `profiles` is deferred until a profile feature actually writes
to it — Supabase Auth does not create public profile rows by itself.

**Tech Stack:** Flutter, Dart 3, Riverpod 3, `supabase_flutter` (already a dependency, never yet initialized). Postgres schema/RLS changes happen in the Supabase SQL editor, not through Drift (Drift only ever managed the local SQLite file).

**Spec:** `everstride-docs/EVERSTRIDE_PLAN.md`'s "Phase 6 — Supabase Integration" section. The concrete auth method (email/password) and conflict strategy above were decided in this planning session, not pre-specified — same situation as Phase 5.1's economy design.

## Global Constraints

- **Auth is optional, never a gate.** No route in this app requires being signed in. Reached only via the Menu tab's existing "Player" row (previously a static placeholder), which becomes a real sign-in/sign-out entry point.
- **`features/player` never imports from `features/auth`.** The dependency runs the other way: a new `PlayerCloudSyncController` (in `features/auth`) listens to `playerControllerProvider` and pushes to Supabase — mirroring exactly how `QuestController` listens to `healthSyncControllerProvider` without `features/health` knowing Quest exists. `PlayerController` itself is not modified in this plan.
- **No merge logic, ever.** Every authorized push is a full overwrite of the cloud row (`upsert`) with whatever the local `Player` row currently holds. Every restore is a full overwrite of the local row. There is no field-by-field reconciliation and none should be added — that is what "local-first, no merge" means here.
- **The cloud unit is one snapshot, not independent rows.** A `player_saves`
  row contains the Player fields plus JSON snapshots of `health_daily` and
  `daily_quest_instances`; its single upsert is the backup transaction. This
  prevents a restored player from receiving duplicate Energy or quest rewards.
- **An existing cloud save is never silently overwritten.** If the device has
  no `linkedCloudUserId`, or it is linked to a different account, sign-in must
  stop at `requiresRestoreOrOverwriteConfirmation` and must not enqueue a
  backup. The Menu offers **Restore cloud backup** (replace local state) and
  the destructive **Replace cloud backup** (overwrite remote state). Cancel
  leaves both sides unchanged. Only the same linked account may push normally;
  an account with no cloud save may receive the local backup without a choice.
- **Cloud sync is serialized and latest-state-wins.** The sync controller must
  allow at most one request at a time and coalesce intervening local changes
  into one later upload of the newest complete snapshot. An older request must
  never finish after, and overwrite, a newer state.
- **RLS is mandatory from the first migration.** Every table this plan creates enables row-level security with policies scoped to `auth.uid()` before the app ever writes to it. Never ship a table without RLS enabled, even temporarily.
- **`hasReconciledHistoricalSteps` is forced `true` on a cloud restore.** A restored account's Player row did not just materialize from nothing — its Energy/Gold/EXP already reflect whatever the original device's own reconciliation and play history produced. Restoring it and then letting `ReconcileHistoricalEnergyUseCase` run its own pristine-player migration on top would be wrong (it only ever intends to run once, on a genuinely untouched player). Setting the flag on restore prevents that.
- A missing or invalid `.env` configuration must not prevent local play. Only
  initialize Supabase when both `SUPABASE_URL` and `SUPABASE_ANON_KEY` are
  present; otherwise expose Cloud Backup as unavailable in Menu and keep every
  local route functional.
- Reward-adjacent logic gets real tests: bootstrap restore/push, snapshot
  round-trip for Health and quest state, account-overwrite confirmation, and
  serialized/coalesced push ordering. Widget tests cover sign-up confirmation
  and restore-refresh feedback; analyzer and manual recheck cover real
  Supabase/RLS wiring.
- All commands below assume the working directory is `everstride-mobile/`, except Task 1's Supabase dashboard steps (not a terminal command at all).
- **Commit policy: not yet confirmed for this run.** Same standing note as every plan since Phase 4 — `everstride-docs/AGENTS.md` prohibits `git commit`/`flutter test` without per-run authorization, not requested yet for this plan. The last confirmed convention across Phase 3/3.1/4/5/5.1 was: authorized, no `Co-Authored-By` trailer. `git push` is never allowed, under any circumstance, for any run of this plan.
- This plan asks for real credentials and writes SQL that grants a real external service access to player data. Treat Task 1 and Task 3's SQL step as things to run carefully and read before pasting, not as something to automate away.

---

### Task 1 (manual — no code): Configure the Supabase project

**This task is not executed by an agent.** It requires a human with access to create/own a Supabase account and project. Do this before Task 2.

- [x] **Step 1:** Create a project at supabase.com (or use an existing one dedicated to this app).
- [x] **Step 2:** From Project Settings → API, copy the **anon/public key** and Project URL (not the service-role key — that must never appear in the Flutter app or its repository, per `everstride-docs/AGENTS.md`).
- [x] **Step 3:** In `everstride-mobile/.env` (already gitignored), set:
  ```
  SUPABASE_URL=<project url>
  SUPABASE_ANON_KEY=<anon key>
  ```
- [x] **Step 4:** Under Authentication → Providers, confirm Email provider is enabled (it is by default). For local development, consider disabling "Confirm email" under Authentication → Settings so sign-up works immediately without an email round-trip — re-enable it before any real release.

---

### Task 2: Optional Supabase initialization, real auth, and the sign-in/sign-up screen

**Files:**

- Modify: `everstride-mobile/lib/main.dart`
- Create: `everstride-mobile/lib/features/auth/domain/repositories/auth_repository.dart` (replaces the existing empty marker interface)
- Create: `everstride-mobile/lib/features/auth/data/repositories/auth_repository_impl.dart`
- Create: `everstride-mobile/lib/features/auth/presentation/controllers/auth_controller.dart`
- Create: `everstride-mobile/lib/features/auth/presentation/screens/auth_screen.dart`
- Modify: `everstride-mobile/lib/app/router.dart`
- Modify: `everstride-mobile/lib/features/settings/presentation/screens/menu_screen.dart`

**Interfaces:**

- Consumes: `Env.supabaseUrl`/`Env.supabaseAnonKey` (existing); `Result`/`Ok`/`Err`/`Failure`, `AppLogger` (existing).
- Produces: `AuthUser` (`id`, `email`); abstract `AuthRepository` (`currentUser` getter, `authStateChanges()` stream, `signUp`/`signIn`/`signOut`); `AuthRepositoryImpl`; `authRepositoryProvider`; `AuthController` (`Notifier<AuthUser?>`) with `signUp`/`signIn`/`signOut`; `authControllerProvider`; `AuthScreen`; route `/auth`. Task 3 consumes `AuthController.signIn`'s hook point to run the bootstrap sync; Task 4 consumes `authControllerProvider` to know whether to push.

> **Correction:** `signUp` must return an auth outcome, not only an
> `AuthUser`: `signedIn(AuthUser)` or `emailConfirmationRequired`. The latter
> must not start backup work or dismiss the Auth screen. The legacy Task 2
> snippets below are illustrative only where they conflict with this outcome
> or config-gated initialization.

- [x] **Step 1: Initialize Supabase only when configured**

Open `lib/main.dart`. Add the import and the initialize call, right after `Env.load()`:

```dart
import 'package:supabase_flutter/supabase_flutter.dart';
```

```dart
  await Env.load();
  if (Env.hasSupabaseConfig) {
    await Supabase.initialize(url: Env.supabaseUrl, anonKey: Env.supabaseAnonKey);
  }
  await Health().configure();
```

Add `Env.hasSupabaseConfig`. Provide an unavailable `AuthRepository` when
configuration is absent, so Menu can say “Cloud Backup unavailable” and local
play still starts. Do not call `Supabase.instance` from that path.

- [x] **Step 2: Write the `AuthRepository` interface**

```dart
// lib/features/auth/domain/repositories/auth_repository.dart
import '../../../../core/errors/result.dart';

class AuthUser {
  const AuthUser({required this.id, required this.email});

  final String id;
  final String email;
}

/// Abstracts Supabase Auth so UI/other features never call it directly.
abstract class AuthRepository {
  AuthUser? get currentUser;
  Stream<AuthUser?> authStateChanges();
  Future<Result<AuthUser>> signUp({required String email, required String password});
  Future<Result<AuthUser>> signIn({required String email, required String password});
  Future<Result<bool>> signOut();
}
```

- [x] **Step 3: Write the Supabase-backed implementation**

```dart
// lib/features/auth/data/repositories/auth_repository_impl.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthRepositoryImpl implements AuthRepository {
  AuthRepositoryImpl(this._client);

  final SupabaseClient _client;

  AuthUser? _toAuthUser(User? user) =>
      user == null ? null : AuthUser(id: user.id, email: user.email ?? '');

  @override
  AuthUser? get currentUser => _toAuthUser(_client.auth.currentUser);

  @override
  Stream<AuthUser?> authStateChanges() =>
      _client.auth.onAuthStateChange.map((data) => _toAuthUser(data.session?.user));

  @override
  Future<Result<AuthUser>> signUp({required String email, required String password}) async {
    try {
      final response = await _client.auth.signUp(email: email, password: password);
      final user = response.user;
      if (user == null) return const Err(Failure('Sign up did not return a user'));
      AppLogger.debug('auth.state', 'Signed up ${user.id}');
      return Ok(AuthUser(id: user.id, email: user.email ?? email));
    } on AuthException catch (e) {
      AppLogger.error('auth.state', 'Sign up failed', e);
      return Err(Failure(e.message, cause: e));
    } catch (e) {
      AppLogger.error('auth.state', 'Sign up failed', e);
      return Err(Failure('Sign up failed', cause: e));
    }
  }

  @override
  Future<Result<AuthUser>> signIn({required String email, required String password}) async {
    try {
      final response = await _client.auth.signInWithPassword(email: email, password: password);
      final user = response.user;
      if (user == null) return const Err(Failure('Sign in did not return a user'));
      AppLogger.debug('auth.state', 'Signed in ${user.id}');
      return Ok(AuthUser(id: user.id, email: user.email ?? email));
    } on AuthException catch (e) {
      AppLogger.error('auth.state', 'Sign in failed', e);
      return Err(Failure(e.message, cause: e));
    } catch (e) {
      AppLogger.error('auth.state', 'Sign in failed', e);
      return Err(Failure('Sign in failed', cause: e));
    }
  }

  @override
  Future<Result<bool>> signOut() async {
    try {
      await _client.auth.signOut();
      return const Ok(true);
    } catch (e) {
      AppLogger.error('auth.state', 'Sign out failed', e);
      return Err(Failure('Sign out failed', cause: e));
    }
  }
}

final authRepositoryProvider = Provider<AuthRepository>((ref) {
  return AuthRepositoryImpl(Supabase.instance.client);
});
```

- [x] **Step 4: Write `AuthController`**

Task 3 extends `signIn` below with the bootstrap-sync call — this step's version is complete and correct on its own; Task 3 modifies it, not replaces it.

```dart
// lib/features/auth/presentation/controllers/auth_controller.dart
import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../domain/repositories/auth_repository.dart';

class AuthController extends Notifier<AuthUser?> {
  @override
  AuthUser? build() {
    final repo = ref.watch(authRepositoryProvider);
    final subscription = repo.authStateChanges().listen((user) => state = user);
    ref.onDispose(subscription.cancel);
    return repo.currentUser;
  }

  Future<Result<AuthUser>> signUp({required String email, required String password}) {
    return ref.read(authRepositoryProvider).signUp(email: email, password: password);
  }

  Future<Result<AuthUser>> signIn({required String email, required String password}) {
    return ref.read(authRepositoryProvider).signIn(email: email, password: password);
  }

  Future<Result<bool>> signOut() => ref.read(authRepositoryProvider).signOut();
}

final authControllerProvider = NotifierProvider<AuthController, AuthUser?>(AuthController.new);
```

- [x] **Step 5: Write the sign-in/sign-up screen**

```dart
// lib/features/auth/presentation/screens/auth_screen.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/errors/result.dart';
import '../controllers/auth_controller.dart';

class AuthScreen extends ConsumerStatefulWidget {
  const AuthScreen({super.key});

  @override
  ConsumerState<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends ConsumerState<AuthScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  var _isSignUp = false;
  var _isSubmitting = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _isSubmitting = true;
      _errorMessage = null;
    });
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final controller = ref.read(authControllerProvider.notifier);
    final result = _isSignUp
        ? await controller.signUp(email: email, password: password)
        : await controller.signIn(email: email, password: password);
    if (!mounted) return;
    setState(() => _isSubmitting = false);
    switch (result) {
      case Ok(:final value) when value.requiresEmailConfirmation:
        setState(() => _errorMessage = 'Check your email to confirm your account.');
      case Ok():
        context.pop();
      case Err(:final failure):
        setState(() => _errorMessage = failure.message);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(_isSignUp ? 'Sign Up' : 'Sign In')),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _emailController,
              decoration: const InputDecoration(labelText: 'Email'),
              keyboardType: TextInputType.emailAddress,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _passwordController,
              decoration: const InputDecoration(labelText: 'Password'),
              obscureText: true,
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 12),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
            ],
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submit,
              child: _isSubmitting
                  ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                  : Text(_isSignUp ? 'Sign Up' : 'Sign In'),
            ),
            TextButton(
              onPressed: () => setState(() => _isSignUp = !_isSignUp),
              child: Text(
                _isSignUp ? 'Already have an account? Sign In' : "Don't have an account? Sign Up",
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

`signUp` must distinguish a created user with no session (email confirmation
required) from a signed-in user. Only a successful session may close this
screen, show “Signed in”, and run bootstrap backup. Validate empty email and
password before calling the repository.

- [x] **Step 6: Add the `/auth` route**

Open `lib/app/router.dart`. Add the import and one top-level route (a sibling of `/adventure-result` — outside the shell, full-screen):

```dart
import '../features/auth/presentation/screens/auth_screen.dart';
```

```dart
    GoRoute(path: '/auth', builder: (context, state) => const AuthScreen()),
```

- [x] **Step 7: Wire Menu's Player row to real sign-in/sign-out**

Open `lib/features/settings/presentation/screens/menu_screen.dart`. Add the imports:

```dart
import 'package:go_router/go_router.dart';

import '../../../auth/presentation/controllers/auth_controller.dart';
```

Replace the existing static `ListTile` (`leading: CircleAvatar(child: Icon(Icons.person))`, `title: Text('Player')`, `subtitle: Text('View Profile')`) with:

```dart
          Consumer(
            builder: (context, ref, _) {
              final authUser = ref.watch(authControllerProvider);
              return ListTile(
                leading: const CircleAvatar(child: Icon(Icons.person)),
                title: Text(authUser?.email ?? 'Guest'),
                subtitle: Text(authUser == null ? 'Tap to sign in' : 'Signed in'),
                onTap: () => context.push('/auth'),
                trailing: authUser == null
                    ? null
                    : TextButton(
                        onPressed: () => ref.read(authControllerProvider.notifier).signOut(),
                        child: const Text('Sign Out'),
                      ),
              );
            },
          ),
```

(`MenuScreen` is already a `ConsumerWidget` reading other providers via its own `ref` — this row uses a nested `Consumer` only so its rebuilds don't also rebuild the rest of the screen on every auth-state change; using the outer `ref` directly would work too, this is a minor optimization, not a requirement.)

When Supabase is not configured, this row must instead show “Cloud Backup
unavailable”, disable its navigation, and leave the rest of Menu/local gameplay
available. When backup is pending or failed, show that status and a Retry
Backup action; do not imply that the current local state is safely backed up.

- [x] **Step 8: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 9: Stage (do not commit without confirmed authorization)**

```bash
git add lib/main.dart lib/features/auth/domain/repositories/auth_repository.dart lib/features/auth/data/repositories/auth_repository_impl.dart lib/features/auth/presentation/controllers/auth_controller.dart lib/features/auth/presentation/screens/auth_screen.dart lib/app/router.dart lib/features/settings/presentation/screens/menu_screen.dart
```

---

### Task 3: Atomic `player_saves` snapshot, RLS, and safe bootstrap sync

**Files:**

- Create: `everstride-mobile/lib/features/player/domain/repositories/player_cloud_repository.dart`
- Create: `everstride-mobile/lib/features/player/data/repositories/player_cloud_repository_impl.dart`
- Create: `everstride-mobile/lib/features/player/domain/usecases/bootstrap_cloud_sync_usecase.dart`
- Modify: `everstride-mobile/lib/features/auth/presentation/controllers/auth_controller.dart` (extend `signIn`)
- Test: `everstride-mobile/test/features/player/domain/usecases/bootstrap_cloud_sync_usecase_test.dart`

**Interfaces:**

- Consumes: `PlayerRepository`, `HealthSyncRepository`, `QuestRepository`, and
  the local `AppSettings` account-link field; `AuthController`'s successful
  authenticated-session hook.
- Produces: `CloudGameSnapshot` (Player state, Health checkpoints, Daily
  Quest instances, schema version); `PlayerCloudRepository`
  (`fetch(userId)`, `push(userId, snapshot)`); `BootstrapCloudSyncUseCase`;
  and `BootstrapCloudSyncOutcome` (`restored`, `pushed`,
  `requiresRestoreOrOverwriteConfirmation`). Task 4 consumes the same snapshot
  repository for ongoing pushes.

Before coding, extend the local repository interfaces with the minimal list
and replace operations needed for a snapshot. Restore all three local data
sets in one local Drift transaction. Add a nullable `linkedCloudUserId` to
`AppSettings` with a Drift migration; set it only after a completed restore or
push. This is how the app distinguishes a routine sign-in to the same account
from a potentially destructive account switch.

- [x] **Step 1: Add a versioned Supabase migration for `player_saves` and RLS**

Create `everstride-docs/supabase/migrations/2026-09-10_phase6_player_saves.sql`.
Review it, commit it with the code, then apply that exact SQL in the Supabase
SQL editor. Do not keep the only copy of a production schema change in the
dashboard history.

```sql
create table public.player_saves (
  user_id uuid primary key references auth.users(id) on delete cascade,
  level integer not null,
  exp integer not null,
  energy integer not null,
  gold integer not null,
  pending_steps integer not null,
  health_daily jsonb not null default '[]'::jsonb,
  daily_quest_instances jsonb not null default '[]'::jsonb,
  schema_version integer not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.player_saves enable row level security;

create policy "Users can view own player save" on public.player_saves
  for select using (auth.uid() = user_id);
create policy "Users can insert own player save" on public.player_saves
  for insert with check (auth.uid() = user_id);
create policy "Users can update own player save" on public.player_saves
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
```

`profiles` is deliberately deferred: Supabase Auth does not write it, and
there is no profile feature in this phase. Add it later with either an
`auth.users` trigger or an explicit profile-create use case.

The JSON arrays are an atomic backup payload, not a query API. Serialize only
the fields already persisted locally: `HealthDailyRecord` date/steps/rewarded
steps/checkpoint and every `QuestInstance` field needed to restore status and
claims. Validate the snapshot `schema_version` before restore and fail safely
with a visible “backup needs an app update” message for an unknown version.

**Required implementation contract**

```dart
class CloudGameSnapshot {
  const CloudGameSnapshot({
    required this.schemaVersion,
    required this.player,
    required this.healthDaily,
    required this.dailyQuestInstances,
  });

  final int schemaVersion;
  final PlayerState player;
  final List<HealthDailyRecord> healthDaily;
  final List<QuestInstance> dailyQuestInstances;
}

abstract class PlayerCloudRepository {
  Future<Result<CloudGameSnapshot?>> fetch(String userId);
  Future<Result<bool>> push(String userId, CloudGameSnapshot snapshot);
}
```

`LocalGameSnapshotRepository.read()` and `.replace()` own reading and
transactional replacement of Player, `health_daily`, and quest instances.
`BootstrapCloudSyncUseCase` reads local and remote snapshots before making a
decision: no remote save pushes; the same linked account pushes; any existing
remote save with a missing or different account link returns
`requiresRestoreOrOverwriteConfirmation` without any local or remote write.
`restoreCloudBackup()` is the only method that replaces local state, and
`confirmOverwrite()` is the only method that replaces that account's cloud
save. While the choice is pending, `PlayerCloudSyncController` must not enqueue
a backup. After a restore, call `PlayerController.reload()` through its
mutation queue before closing the auth screen.

- [x] **Step 2: Write the `PlayerCloudRepository` interface**

Implement the interface shown in the required contract above, with no
Player-only variant. `fetch` decodes the Player fields, `health_daily`,
`daily_quest_instances`, and `schema_version` into one `CloudGameSnapshot`.
`push` accepts that same complete snapshot.

- [x] **Step 3: Write the Supabase-backed implementation**

`PlayerCloudRepositoryImpl` is a thin Supabase mapping. Use `maybeSingle()`;
on a row, decode the scalar Player columns and both JSON arrays, rejecting an
unknown `schema_version`. On push, upsert every field from one snapshot in one
request: scalar Player fields, `health_daily`, `daily_quest_instances`,
`schema_version`, and `updated_at`. Return `Err(Failure(...))` on transport or
decode errors. Keep pull-vs-push decisions outside this repository.

- [x] **Step 4: Write failing tests for `BootstrapCloudSyncUseCase`**

Create fakes for `PlayerCloudRepository` and `LocalGameSnapshotRepository`.
Every fake and expectation must use `CloudGameSnapshot`. The red/green suite
must prove:

- A device with no linked account returns
  `requiresRestoreOrOverwriteConfirmation` for an existing cloud save, even
  if startup reconciliation has made local state non-pristine; it makes no
  cloud push. Explicit restore replaces Player, Health checkpoint rows, and
  claimed Quest instances in one local replacement.
- An absent cloud save pushes the complete local snapshot.
- An unknown snapshot version leaves local data unchanged and returns an error.
- The same linked account can push a non-pristine local snapshot.
- A missing or different linked account with a remote save returns
  `requiresRestoreOrOverwriteConfirmation` and performs no write until
  explicit `restoreCloudBackup()` or `confirmOverwrite()`.

- [ ] **Step 5: Run tests to verify they fail**

Run: `flutter test test/features/player/domain/usecases/bootstrap_cloud_sync_usecase_test.dart`
Expected: FAIL — `bootstrap_cloud_sync_usecase.dart` doesn't exist yet.

- [x] **Step 6: Write `BootstrapCloudSyncUseCase`**

Implement `BootstrapCloudSyncUseCase` against `LocalGameSnapshotRepository`
and `PlayerCloudRepository`, not individual Player repositories. It must:

1. Read the local `CloudGameSnapshot` and linked-account id, then fetch the
   remote snapshot.
2. Reject unknown schema versions before any local mutation.
3. Return `requiresRestoreOrOverwriteConfirmation` without a write when a
   remote snapshot exists but the local `linkedCloudUserId` is missing or
   belongs to another account.
4. Push `read()`'s complete local snapshot only when there is no remote save
   or the account is already linked.
5. Allow an explicit `restoreCloudBackup()` to transactionally
   `replace(remoteSnapshot)`, or explicit `confirmOverwrite()` to push local
   state over the remote backup.
6. Persist the linked-account id after a successful restore or push.

After a restore, `AuthController` must await `PlayerController.reload()` via
its mutation queue before closing the auth screen.

- [ ] **Step 7: Run tests to verify they pass**

Run: `flutter test test/features/player/domain/usecases/bootstrap_cloud_sync_usecase_test.dart`
Expected: PASS — complete snapshot, account-protection, unknown-version, and
restore-refresh cases all pass.

- [x] **Step 8: Wire bootstrap into every authenticated session**

Open `lib/features/auth/presentation/controllers/auth_controller.dart`. Add the imports:

```dart
import '../../../player/data/repositories/player_cloud_repository_impl.dart';
import '../../../player/data/repositories/player_repository_impl.dart';
import '../../../player/domain/usecases/bootstrap_cloud_sync_usecase.dart';
```

Replace `signIn`:

```dart
  Future<Result<AuthUser>> signIn({required String email, required String password}) async {
    final result = await ref.read(authRepositoryProvider).signIn(email: email, password: password);
    if (result case Ok(:final value)) {
      final bootstrapResult = await BootstrapCloudSyncUseCase(
        ref.read(playerRepositoryProvider),
        ref.read(playerCloudRepositoryProvider),
      ).call(value.id);
      if (bootstrapResult case Err(:final failure)) {
        AppLogger.error('player.cloud', 'Failed to bootstrap cloud sync', failure);
      }
    }
    return result;
  }
```

Add the `AppLogger` import too:

```dart
import '../../../../core/utils/app_logger.dart';
```

Run bootstrap after both sign-in and sign-up when an actual session exists.
Surface its failure or `requiresRestoreOrOverwriteConfirmation` in Auth/Menu instead of
only logging it. A bootstrap failure does not revoke authentication, but the
UI must show that Cloud Backup is pending/failed and offer retry.

- [x] **Step 9: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 10: Stage (do not commit without confirmed authorization)**

```bash
git add lib/core/database lib/features/player lib/features/health lib/features/quest lib/features/auth test/features/player/domain/usecases/bootstrap_cloud_sync_usecase_test.dart
cd ../everstride-docs && git add supabase/migrations/2026-09-10_phase6_player_saves.sql
```

---

### Task 4: Serialized full-snapshot backup after local changes

**Files:**

- Create: `everstride-mobile/lib/features/auth/presentation/controllers/player_cloud_sync_controller.dart`
- Modify: `everstride-mobile/lib/app/shell/app_shell.dart`

**Interfaces:**

- Consumes: `authControllerProvider`, Player, Health-sync, and Quest change
  signals; `LocalGameSnapshotRepository`; `playerCloudRepositoryProvider`.
- Produces: `PlayerCloudSyncController` with a visible backup status and retry
  action. It is a self-contained side effect but must snapshot all backed-up
  local data immediately before each actual upload.

- [x] **Step 1: Write the controller**

```dart
// lib/features/auth/presentation/controllers/player_cloud_sync_controller.dart
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/errors/result.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../player/data/repositories/player_cloud_repository_impl.dart';
import '../../../player/domain/repositories/player_repository.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import 'auth_controller.dart';

/// Pushes the latest complete local snapshot whenever backed-up state changes,
/// but only while signed in. This is the ongoing half of Phase 6's
/// local-first sync — the one-time pull-or-push decision at sign-in itself
/// is BootstrapCloudSyncUseCase. features/player is not modified for this;
/// this listens to it from features/auth instead, the same direction every
/// other cross-feature reactive listener in this codebase already uses.
class PlayerCloudSyncController extends Notifier<CloudBackupStatus> {
  @override
  CloudBackupStatus build() {
    // Listen to Player, Health, and Quest completion. Each listener calls
    // schedulePush(), which coalesces state changes while an upload is active.
    return const CloudBackupStatus.idle();
  }

  // Keep one upload in flight. Before every upload, read a fresh complete
  // snapshot. If any change arrives while uploading, upload only that newest
  // snapshot after the first request finishes.
}

final playerCloudSyncControllerProvider =
    NotifierProvider<PlayerCloudSyncController, CloudBackupStatus>(
      PlayerCloudSyncController.new,
    );
```

- [x] **Step 2: Activate the controller from `AppShell`**

Open `lib/app/shell/app_shell.dart`. `PlayerCloudSyncController`'s `build()` needs to run once for its `ref.listen` to start — add one line reading it, right at the top of `AppShell.build`:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
```

```dart
import '../../features/auth/presentation/controllers/player_cloud_sync_controller.dart';
```

```dart
class AppShell extends ConsumerWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    ref.watch(playerCloudSyncControllerProvider);
    return Scaffold(
      body: navigationShell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: navigationShell.currentIndex,
        onDestinationSelected: navigationShell.goBranch,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.explore_outlined), selectedIcon: Icon(Icons.explore), label: 'Adventure'),
          NavigationDestination(icon: Icon(Icons.menu_book_outlined), selectedIcon: Icon(Icons.menu_book), label: 'Journal'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Character'),
          NavigationDestination(icon: Icon(Icons.menu), selectedIcon: Icon(Icons.menu), label: 'Menu'),
        ],
      ),
    );
  }
}
```

`AppShell` changes from `StatelessWidget` to `ConsumerWidget` (it needs a `WidgetRef` now) — this is the only structural change to the class; the `NavigationBar` and its destinations (verified against the current file while writing this plan) are unchanged.

- [x] **Step 3: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Stage (do not commit without confirmed authorization)**

```bash
git add lib/features/auth/presentation/controllers/player_cloud_sync_controller.dart lib/app/shell/app_shell.dart
```

---

### Task 5: Update manual recheck doc and progress tracker

**Files:**

- Modify: `everstride-docs/development/testing.md`
- Modify: `everstride-docs/PROGRESS.md`

**Interfaces:** none — pure documentation, no code.

- [x] **Step 1: Add a Phase 6 section to the manual recheck doc**

Open `everstride-docs/development/testing.md`. Add this section after the existing "Phase 5.1" section:

```markdown
## Phase 6 — Supabase Integration

1. Remove Supabase values from `.env` and launch the app → all local gameplay
   works; Menu says Cloud Backup is unavailable rather than crashing.
2. With configuration present, create an account. If email confirmation is
   enabled, the app says to check email and does not claim that the user is
   signed in until a session exists.
3. Sign up/sign in with existing local progress → verify one `player_saves`
   row contains matching Player fields plus `health_daily` and daily quest
   arrays, then make an Adventure and a Quest claim → one later snapshot
   reflects the newest complete state.
4. Uninstall/reinstall, sign in to the same account, and verify Character
   refreshes immediately. Sync Health Connect and open Journal: no historical
   Energy or already-claimed Daily Quest reward is granted again.
5. Create progress under account A, sign out, then sign in to account B that
   already has a save → an overwrite confirmation appears. Cancel preserves
   B's cloud data; confirm is the only action that may replace it.
6. Turn off network, make local progress, then restore connectivity and use
   Retry Backup → local play was uninterrupted and the latest snapshot reaches
   Supabase. Sign-in failures show a clear error, not a crash.
7. In the Supabase dashboard, confirm unauthenticated access is denied and an
   authenticated user can select/update only their own `player_saves` row.
```

- [x] **Step 2: Update `everstride-docs/PROGRESS.md`**

Add a "Phase 6 — Supabase Integration" section (mirroring the existing phase
sections' style) for optional, config-gated Supabase initialization; real
email/password auth; account-switch confirmation; the RLS-protected atomic
`player_saves` snapshot; restore of Player, Health checkpoint, and Daily Quest
state; and serialized/retryable backup. Note that there was no game-design doc
for this phase, and that local-first/no-merge, account protection, and the
expanded snapshot scope were decisions made in this plan. Reference
`EVERSTRIDE_PLAN.md`'s Phase 6 for its original, narrower scope.

- [ ] **Step 3: Stage (do not commit without confirmed authorization)**

```bash
cd ../everstride-docs
git add development/testing.md PROGRESS.md
```
