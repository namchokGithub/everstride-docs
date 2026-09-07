# Agent Instructions

## Before Editing

- Inspect existing implementation first.
- Do not redesign architecture unnecessarily.
- Prefer small changes.
- Preserve existing naming conventions.

## Flutter

- Keep business logic out of widgets.
- Use Riverpod for application state.
- Use GoRouter for navigation.
- Access external systems through repositories.

## Health

- Health Connect must only be accessed through HealthRepository.
- Never award steps twice.
- Permission denial must not crash the app.

## Supabase

- Do not call Supabase directly from UI.
- Never use service-role keys in Flutter.
- Respect RLS.

## Testing

Run `flutter format .` and `flutter analyze` freely.

Do not run `flutter test` (or any test command) unless the user explicitly asks for it in that message.

## Git

Never run `git commit` (or any command that creates a commit). Absolutely no exceptions — leave staging/committing to the user.
