# Phase 7 — Full UI & UX Polish Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Apply the user's art direction (jade/mint/deep-navy/warm-cream palette, "soft fantasy, rounded, friendly, nature + journey" mood) app-wide, and land the specific polish points every game-design doc's "Phase 7" handoff note already asked for: clearer reward/level feedback, warmer non-shaming copy, one deliberate reveal animation, and basic accessibility coverage. No new mechanics, no mascot illustration integration (explicitly deferred by the user — the mascot asset exists at `lib/assets/branding/logo-mark.png` but this phase is scoped to "UI and tone," not artwork placement).

**Architecture:** Phase 7 has no dedicated game-design doc — its scope is assembled from the scattered "Phase 7 can polish X" notes in `adventure-system.md`, `economy.md`, `quests.md`, and `balancing.md` (result presentation, loading/empty states, Gold feedback, animations, accessibility — every one of them also repeats "not authorization to introduce new mechanics"). The concrete palette and specific polish targets below were decided in this planning session from the user's art direction plus those scattered notes, the same situation as Phase 5.1's economy design and Phase 6.1's metrics scope.

**Design plan:**

- **Color** — sampled by eye from the mascot artwork (`lib/assets/branding/logo-mark.png`) rather than picked generically:
  - `jade` `#2E9B5F` — brand seed color (drives `ColorScheme.fromSeed`, so icons/selection tints/ripples derive from it app-wide).
  - `mint` `#A9F1C9` — reserved for the one accent moment this phase adds (the claimable-Quest label background) — not spread across every surface.
  - `deepNavy` `#16233D` — primary text and primary-button fill (this is what "dark pill button" already meant in the app before this phase; it now has a name).
  - `warmCream` `#FBF6EC` — background, slightly warmer than the current `#F7F4EC`.
  - `amber` `#E8B93F` — unchanged, already correct for EXP/Gold iconography.
  - `berry` `#C65D5D` — new: insufficient-Energy/-Gold dialogs and `colorScheme.error`. Muted warm red-brown, not an alarm-red, so a "can't do this yet" moment still reads as *soft fantasy*, not a system error.
- **Type** — no new font (this project has never added one and Phase 7 doesn't need to be the phase that does); the existing Material type scale (`titleLarge`/`bodyMedium`/`bodySmall` etc., already used throughout) is used consistently rather than ad hoc inline `TextStyle` literals wherever this phase touches a screen.
- **Layout/shape principle** — spend the one bold move on the claimable-Quest label (a mint pill with deep-navy text, which preserves normal-text contrast) and the level-up reveal (Task 2); everything else stays quiet and disciplined. This deliberately avoids the "identical rounded card + identical grey shadow on everything" generic pattern — this phase does not touch `Card`'s shape, only the specific labels/dialogs/animation named below.
- **Theme modes** — the app uses `ThemeMode.system`, so both `light` and `dark` must receive explicit scaffold, app-bar, and primary-button colors. The dark theme may use dark surfaces, but its text/button contrast must remain deliberate rather than relying on `ColorScheme.fromSeed` defaults.
- **Style check:** Middle-dot cost badges (`"Start Adventure · 10 Energy"`) already exist in this codebase as an established mobile-game convention, not a newly-added meta-string pattern — left as-is, not treated as something to "fix."

**Tech Stack:** Flutter, Dart 3. No new dependencies (the level-up reveal uses Flutter's built-in `TweenAnimationBuilder`, not a new animation package).

**Spec:** No single spec doc — see "Architecture" above. `everstride-docs/game-design/adventure-system.md`, `economy.md`, `quests.md`, and `balancing.md`'s own "Phase 7" / "Full UI and UX polish" sections are the closest thing to a spec, each cited at the task that answers it.

## Global Constraints

- **No new mechanics.** Every game-design doc's Phase 7 note repeats this. If a polish idea would change a cost, reward, target, or state-transition rule, it does not belong in this plan — flag it back to game design instead of building it here.
- **Mascot artwork integration is out of scope.** Home already uses the existing horizontal logo. Adding any *new* mascot placement is a separate, later decision the user explicitly deferred; do not add `Image.asset('lib/assets/branding/logo-mark.png', ...)` anywhere in this plan.
- **`AppTheme.primaryColor`/`accentGreen`/`accentBlue` are removed, not renamed-and-kept.** Confirmed by grep before this plan was written: nothing outside `app_theme.dart` and `main.dart` references any `AppTheme.*` constant directly (the one other place a theme value is read is `Theme.of(context).colorScheme.primary` in `AdventureScreen`'s `_RewardCard`, which is unaffected by this rename since it goes through the `ColorScheme`, not a direct constant reference). Removing the unused constants instead of keeping vestigial old names is intentional, not an oversight.
- **Motion is spent in exactly one place this phase:** the level-up reveal on `AdventureResultScreen` (Task 2). Do not add hover/entrance animations to cards, list items, or buttons elsewhere — that scattering is the generic pattern this plan deliberately avoids.
- **Every new/changed animation respects reduced motion** (`MediaQuery.of(context).disableAnimations`) — skip the animated build entirely and render the end state directly when true.
- **Copy changes preserve the existing DoD/invariant behavior exactly** — this phase changes wording and color, never a threshold, a condition, or which branch of a `switch` fires. Use neutral, active language: explain what happened and how to proceed, and keep the same verb from action to confirmation (for example, "Claim" → "Claimed!").
- All commands below assume the working directory is `everstride-mobile/`.
- **Commit policy: not yet confirmed for this run.** Same standing note as every plan since Phase 4 — `everstride-docs/AGENTS.md` prohibits `git commit`/`flutter test` without per-run authorization, not requested yet for this plan. Recent runs (Phase 6.1) were authorized with no `Co-Authored-By` trailer and no push; get the equivalent confirmation before executing this one.

---

### Task 1: Palette tokens

**Files:**

- Modify: `everstride-mobile/lib/app/theme/app_theme.dart`

**Interfaces:**

- Produces: `AppTheme.jade`, `AppTheme.mint`, `AppTheme.deepNavy`, `AppTheme.warmCream`, `AppTheme.amber`, `AppTheme.berry` (all `Color` constants); `AppTheme.backgroundColor`, `AppTheme.surfaceColor`, `AppTheme.textPrimaryColor`, `AppTheme.textSecondaryColor` (unchanged names, updated/aliased values); `AppTheme.light`/`AppTheme.dark` (unchanged signatures — `main.dart` doesn't change). Tasks 2–3 consume `AppTheme.jade`, `AppTheme.textSecondaryColor`, and `Theme.of(context).colorScheme.error` (which Task 1 wires to `berry`).

No test — this is a colors-only visual change, verified by `flutter analyze` and manual comparison against the mascot artwork's palette during manual recheck (Task 6).

- [x] **Step 1: Replace the theme**

```dart
// lib/app/theme/app_theme.dart
import 'package:flutter/material.dart';

class AppTheme {
  const AppTheme._();

  // Brand palette sampled from the mascot artwork
  // (lib/assets/branding/logo-mark.png): jade body, mint highlights,
  // deep-navy eyes, warm-cream paper. See this repo's Phase 7 plan for the
  // full rationale — there is no single upstream design doc for this phase.
  static const jade = Color(0xFF2E9B5F);
  static const mint = Color(0xFFA9F1C9);
  static const deepNavy = Color(0xFF16233D);
  static const warmCream = Color(0xFFFBF6EC);
  static const amber = Color(0xFFE8B93F);
  static const berry = Color(0xFFC65D5D);

  static const backgroundColor = warmCream;
  static const surfaceColor = Colors.white;
  static const textPrimaryColor = deepNavy;
  static const textSecondaryColor = Color(0xFF5B6B7A);

  static ThemeData get light => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: backgroundColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: jade,
      brightness: Brightness.light,
      surface: surfaceColor,
      error: berry,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: backgroundColor,
      foregroundColor: textPrimaryColor,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: deepNavy,
        foregroundColor: Colors.white,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );

  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: deepNavy,
    colorScheme: ColorScheme.fromSeed(
      seedColor: jade,
      brightness: Brightness.dark,
      surface: const Color(0xFF20314F),
      error: berry,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: deepNavy,
      foregroundColor: warmCream,
      elevation: 0,
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: jade,
        foregroundColor: deepNavy,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        padding: const EdgeInsets.symmetric(vertical: 16),
      ),
    ),
  );
}
```

- [x] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!" — if this reports unused-constant warnings for anything besides what this file intentionally removed, stop and check for a reference this plan's grep missed rather than silencing the warning.

- [ ] **Step 3: Stage (do not commit without confirmed authorization)**

```bash
git add lib/app/theme/app_theme.dart
```

---

### Task 2: Level-up reveal animation and Quest-claim confirmation

**Files:**

- Modify: `everstride-mobile/lib/features/adventure/presentation/screens/adventure_result_screen.dart`
- Modify: `everstride-mobile/lib/features/journal/presentation/screens/journal_screen.dart`

**Interfaces:**

- Consumes: `AppTheme.jade` (Task 1); `AdventureResult.leveledUp` (existing, unchanged); `questControllerProvider.claim` (existing, unchanged — this task only adds a UI-side success branch, no controller change).
- Produces: no new public interface — both changes are additions to existing widgets' `build` methods. Nothing later in this plan consumes them further.

- [x] **Step 1: Add the level-up reveal**

Open `lib/features/adventure/presentation/screens/adventure_result_screen.dart`. Read it fresh first. Add the import:

```dart
import '../../../../app/theme/app_theme.dart';
```

Replace the level-up block:

```dart
              const Icon(Icons.check_circle, size: 64, color: AppTheme.jade),
              const SizedBox(height: 16),
              const Text(
                'Adventure Complete!',
                style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text('${result.adventureName} — ${result.difficultyLabel}'),
              const SizedBox(height: 24),
              if (result.leveledUp) ...[
                _LevelUpReveal(
                  text: 'Level Up! ${result.levelBefore} → ${result.playerAfter.level}',
                ),
                const SizedBox(height: 16),
              ],
```

(only the icon's `color:` and the `if (result.leveledUp)` block change — everything else in `build` is unchanged, including the `_ResultRow`s and the `Continue` button below).

Add the new widget at the bottom of the file, alongside `_ResultRow`:

```dart
/// The one deliberate motion moment this phase adds — everything else in
/// this screen (and this app's polish pass generally) stays static. Skips
/// the animation entirely under reduced-motion settings.
class _LevelUpReveal extends StatelessWidget {
  const _LevelUpReveal({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final textWidget = Text(
      text,
      style: Theme.of(
        context,
      ).textTheme.titleLarge?.copyWith(color: AppTheme.jade, fontWeight: FontWeight.bold),
    );
    if (MediaQuery.of(context).disableAnimations) return textWidget;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.6, end: 1.0),
      duration: const Duration(milliseconds: 450),
      curve: Curves.elasticOut,
      builder: (context, scale, child) => Transform.scale(scale: scale, child: child),
      child: textWidget,
    );
  }
}
```

- [x] **Step 2: Add a Quest-claim confirmation**

Open `lib/features/journal/presentation/screens/journal_screen.dart`. Read it fresh first. In `_QuestCard`'s `ElevatedButton.onPressed`, replace the existing `Err`-only handling with a full switch so a successful claim gets its own confirmation (matching the button's own verb, per this plan's writing-tone constraint: "Claim" → "Claimed!"):

```dart
                if (instance.status == QuestStatus.claimable)
                  ElevatedButton(
                    onPressed: () async {
                      final result = await ref
                          .read(questControllerProvider.notifier)
                          .claim(instance);
                      if (!context.mounted) return;
                      switch (result) {
                        case Ok():
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Claimed! +${instance.expReward} EXP, +${instance.goldReward} Gold',
                              ),
                            ),
                          );
                        case Err(:final failure):
                          ScaffoldMessenger.of(
                            context,
                          ).showSnackBar(SnackBar(content: Text(failure.message)));
                      }
                    },
                    child: const Text('Claim'),
                  ),
```

- [x] **Step 3: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 4: Stage (do not commit without confirmed authorization)**

```bash
git add lib/features/adventure/presentation/screens/adventure_result_screen.dart lib/features/journal/presentation/screens/journal_screen.dart
```

---

### Task 3: Copy tone, error-dialog restyle, and clearer Quest status

**Files:**

- Modify: `everstride-mobile/lib/features/adventure/presentation/screens/adventure_screen.dart`
- Modify: `everstride-mobile/lib/features/journal/presentation/screens/journal_screen.dart`

**Interfaces:**

- Consumes: `AppTheme.jade`/`AppTheme.textSecondaryColor` (Task 1); `Theme.of(context).colorScheme.error` (wired to `berry` by Task 1).
- Produces: no new public interface. Nothing later in this plan consumes anything from this task.

- [x] **Step 1: Restyle the insufficient-Gold dialog**

Open `lib/features/adventure/presentation/screens/adventure_screen.dart`. Read it fresh first. Replace `_showInsufficientGoldDialog`:

```dart
  Future<void> _showInsufficientGoldDialog(int currentGold) => showDialog<void>(
    context: context,
    builder: (context) => AlertDialog(
      icon: Icon(Icons.savings_outlined, color: Theme.of(context).colorScheme.error),
      title: Text('Not enough Gold', style: TextStyle(color: Theme.of(context).colorScheme.error)),
      content: Text('Trail Supplies cost $_trailSuppliesCost Gold — you have $currentGold.'),
      actions: [
        TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
      ],
    ),
  );
```

- [x] **Step 2: Restyle the insufficient-Energy dialog**

In the same file, replace `_showInsufficientEnergyDialog`:

```dart
  Future<void> _showInsufficientEnergyDialog(
    AdventureDifficulty difficulty,
    int currentEnergy,
  ) {
    return showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        icon: Icon(Icons.bolt, color: Theme.of(context).colorScheme.error),
        title: Text('Not enough Energy', style: TextStyle(color: Theme.of(context).colorScheme.error)),
        content: Text(
          '${_adventure.name} (${difficulty.label}) costs ${difficulty.energyCost} Energy — '
          'you have $currentEnergy. Walk a little more to earn Energy, then try again.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(), child: const Text('Got it')),
        ],
      ),
    );
  }
```

Both dialogs keep their exact existing meaning and both required elements (explain what happened and how to proceed) — only wording is tightened and the icon/title now use the brand error color instead of default `AlertDialog` styling.

- [x] **Step 3: Give each Quest status a plain-language label with accessible contrast**

Open `lib/features/journal/presentation/screens/journal_screen.dart`. Read it fresh first. Add the import:

```dart
import '../../../../app/theme/app_theme.dart';
```

Replace the bare `Text(instance.status.name)` in `_QuestCard` (currently showing the raw enum value, e.g. `"inProgress"`) with:

```dart
                _QuestStatusLabel(status: instance.status),
```

Add this private widget alongside `_QuestCard`. Claimable uses a mint pill with
deep-navy text instead of jade text on cream, so the normal-size label retains
readable contrast. Other statuses remain quiet muted text.

```dart
class _QuestStatusLabel extends StatelessWidget {
  const _QuestStatusLabel({required this.status});

  final QuestStatus status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      QuestStatus.inProgress => 'In Progress',
      QuestStatus.claimable => 'Ready to claim',
      QuestStatus.claimed => 'Claimed',
      QuestStatus.expired => 'Expired',
    };
    if (status != QuestStatus.claimable) {
      return Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w600,
          color: AppTheme.textSecondaryColor,
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.mint,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontWeight: FontWeight.w700,
          color: AppTheme.deepNavy,
        ),
      ),
    );
  }
}
```

Also soften the loading state at the top of `JournalScreen.build` (currently `const Center(child: Text('Loading...'))`):

```dart
        body: const Center(child: Text("Gathering today's Quests…")),
```

- [x] **Step 4: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 5: Stage (do not commit without confirmed authorization)**

```bash
git add lib/features/adventure/presentation/screens/adventure_screen.dart lib/features/journal/presentation/screens/journal_screen.dart
```

---

### Task 4: Accessibility — icon-only button labels

**Files:**

- Modify: `everstride-mobile/lib/app/screens/home_screen.dart`

**Interfaces:** none — this adds `tooltip` values to two existing `IconButton`s (Flutter's `tooltip` parameter provides both the long-press tooltip and the screen-reader label in one place — no `Semantics` wrapper needed). Nothing later in this plan depends on this.

Home's calendar and sync `IconButton`s are the only icon-only, unlabeled interactive controls found in this app during this plan's review (`AppShell`'s `NavigationDestination`s already carry `label`s; every other button in the app has visible text). Existing tap targets are all standard Material `IconButton`/`ElevatedButton` sizes (≥48dp) already — no sizing change is needed.

- [x] **Step 1: Add tooltips**

Open `lib/app/screens/home_screen.dart`. Read it fresh first. Add `tooltip: 'Pick a date'` to the calendar `IconButton` in the `AppBar`'s `actions`, and `tooltip: 'Sync now'` to the sync `IconButton` in `_Dashboard`:

```dart
          IconButton(
            tooltip: 'Pick a date',
            icon: const Icon(Icons.calendar_today_outlined),
            onPressed: () async {
```

```dart
          child: IconButton(
            tooltip: 'Sync now',
            icon: (steps.isLoading || (sync?.isLoading ?? false))
```

- [x] **Step 2: Run the analyzer**

Run: `flutter analyze`
Expected: "No issues found!"

- [ ] **Step 3: Stage (do not commit without confirmed authorization)**

```bash
git add lib/app/screens/home_screen.dart
```

---

### Task 5: Widget-test the changed feedback and accessibility states

**Files:**

- Modify or create: `everstride-mobile/test/features/adventure/presentation/adventure_result_screen_test.dart`
- Modify or create: `everstride-mobile/test/features/journal/presentation/journal_screen_test.dart`
- Modify or create: `everstride-mobile/test/app/screens/home_screen_test.dart`

These tests exercise presentation only. Reuse the fake repositories/controllers
and provider overrides established by the existing Adventure widget test; do not
call Health Connect, Drift, or Supabase from a widget test.

- [x] **Step 1: Cover the result and Journal feedback**

Add widget coverage that verifies:

- a result with `leveledUp: true` renders the `Level Up!` line;
- with `MediaQueryData(disableAnimations: true)`, that line renders its final
  state directly without pumping the reveal duration;
- a successful Quest claim shows `Claimed! +N EXP, +M Gold`, while a failed
  claim still shows the existing failure message;
- all four Quest states render their plain-language labels, and a claimable
  Quest uses the mint label treatment with deep-navy text.

- [x] **Step 2: Cover Home control labels**

Pump Home with the existing provider overrides and verify the calendar and sync
`IconButton`s expose `Pick a date` and `Sync now` tooltips. This validates the
screen-reader label path without asserting incidental icon implementation.

- [x] **Step 3: Run targeted widget tests and the analyzer**

Run:

```bash
flutter test test/features/adventure/presentation/adventure_result_screen_test.dart test/features/journal/presentation/journal_screen_test.dart test/app/screens/home_screen_test.dart
flutter analyze
```

Expected: all targeted tests pass and the analyzer reports no issues. Per
`AGENTS.md`, request explicit permission in the execution run before invoking
`flutter test`.

- [ ] **Step 4: Stage (do not commit without confirmed authorization)**

```bash
git add test/features/adventure/presentation/adventure_result_screen_test.dart test/features/journal/presentation/journal_screen_test.dart test/app/screens/home_screen_test.dart
```

---

### Task 6: Update manual recheck doc and progress tracker

**Files:**

- Modify: `everstride-docs/development/testing.md`
- Modify: `everstride-docs/PROGRESS.md`

**Interfaces:** none — pure documentation, no code.

- [x] **Step 1: Add a Phase 7 section to the manual recheck doc**

Open `everstride-docs/development/testing.md`. Add this section after the current last Phase section:

```markdown
## Phase 7 — Full UI & UX Polish

1. Open the app → background reads as warm cream, primary buttons are
   deep navy, and interactive accents (selected nav icon, selected
   difficulty chip) read as jade — compare against
   `lib/assets/branding/logo-mark.png` for the intended family of colors.
2. Complete an Adventure that crosses a level boundary → the "Level Up!"
   line visibly scales/settles into place once (not on every result,
   only when `leveledUp` is true); toggle the OS's "reduce motion"
   accessibility setting and repeat — the text appears immediately with
   no animation.
3. Claim any Daily Quest → a "Claimed! +N EXP, +M Gold" confirmation
   appears (previously nothing was shown on success, only on failure).
4. Attempt an Adventure with insufficient Energy, then insufficient Gold
   (with Trail Supplies checked) → both dialogs show a warm red-brown
   icon/title (not default Material red or plain black) and explain the
   cost and current balance plus what to do next.
5. Open Journal → each Quest shows a plain-language status ("In Progress"
   / "Ready to claim" / "Claimed") instead of a raw code-style word;
   "Ready to claim" is a mint pill with deep-navy text, while the others
   use muted grey-navy text.
6. Long-press Home's calendar and sync icons → tooltips "Pick a date" /
   "Sync now" appear; with a screen reader on, both are announced.
7. Switch the OS between light and dark modes → both modes keep intentional
   scaffold, app-bar, and primary-button contrast; no generated seed color
   makes essential text or buttons hard to read.
```

- [x] **Step 2: Update `everstride-docs/PROGRESS.md`**

Add a "Phase 7 — Full UI & UX Polish" section (mirroring the existing phase sections' style: mixed Thai/English prose, `- [x]` lines for the real deliverables — jade/mint/deep-navy/warm-cream palette tokens, the level-up reveal animation, the Quest-claim confirmation, the restyled insufficient-Energy/-Gold dialogs, plain-language Quest status labels, Home's icon tooltips — each with a short build note in the same voice as the existing sections). Note explicitly that this phase has no dedicated game-design doc (scope came from scattered "Phase 7" notes across `adventure-system.md`/`economy.md`/`quests.md`/`balancing.md` plus the user's art direction given directly in this planning session), and that mascot-artwork placement was explicitly deferred, not forgotten. Reference the four game-design docs' own "Phase 7"/"Full UI and UX polish" sections for the polish rationale instead of repeating it.

- [ ] **Step 3: Stage (do not commit without confirmed authorization)**

```bash
cd ../everstride-docs
git add development/testing.md PROGRESS.md
```
