# Everstride — Agent Instruction

## Before Editing

Before making changes:

1. Inspect the existing implementation first.
2. Read the project context and current progress.
3. Read the active implementation plan for the current task.
4. Read only the game-design/spec documents relevant to the feature being changed.
5. Verify documentation assumptions against the current code before editing.

Do not redesign architecture unnecessarily.

Prefer small, reviewable changes.

Preserve existing naming conventions and project structure unless there is a clear reason to change them.

## Required Reading

Always read:

- `CONTEXT.md`
- `PROGRESS.md`
- the active plan under `plan/` or `specs/`

Then read the relevant design documents for the feature.

Examples:

### Player progression

- `game-design/core-loop.md`
- `game-design/progression.md`
- `game-design/energy-system.md`

### Adventure

- `game-design/core-loop.md`
- `game-design/progression.md`
- `game-design/energy-system.md`
- `game-design/adventure-system.md`

Do not read every document in the repository unless the task actually requires it.

## Source of Truth

Use the following order when understanding the project:

1. User's current instruction
2. Current implementation / tests
3. Active implementation plan or approved spec
4. Game-design documents
5. `PROGRESS.md`
6. `CONTEXT.md`
7. Older documentation

If documentation and code disagree:

- Do not silently choose one.
- Inspect the surrounding implementation and recent changes.
- Preserve currently working behavior unless the task explicitly requires changing it.
- Surface meaningful inconsistencies when they affect the requested work.

Do not assume older plans still describe the current implementation.

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

## Game Design

Game-design documents define gameplay intent and rules.

Implementation plans define how approved rules are implemented.

Do not invent or finalize unresolved game mechanics while coding.

If a required gameplay rule is missing or ambiguous:

- Prefer the approved game-design document.
- If it is still unresolved and materially affects implementation, surface the question rather than silently inventing a permanent rule.

Temporary MVP values should remain clearly identifiable as temporary.

## Testing

Run `flutter format .` and `flutter analyze` freely.

Do not run `flutter test` (or any test command) unless the user explicitly asks for it in that message.

## Git

Never run `git commit` (or any command that creates a commit). Absolutely no exceptions — leave staging/committing to the user.

## Error Handling and Logging

Use the project's `Result<T></t> / Ok<T></t> / Err<T></t>` boundaries where established.
Do not allow raw external/database exceptions to cross repository/use-case boundaries when the existing architecture wraps them.
Use the existing AppLogger.
Do not log sensitive health information unnecessarily.

Expected gameplay outcomes such as "Not enough energy" are not system crashes.

## Documentation

When a change materially affects:

- architecture,
- game rules,
- project progress,
- database schema,
- setup instructions,
- or an accepted technical decision,

update the relevant documentation when the current task includes documentation work.

Avoid copying the same detailed information into multiple documents.

Preferred responsibilities:

```
CONTEXT.md
= What Everstride is and the current architectural context

PROGRESS.md
= What has been implemented and what comes next

DECISIONS.md
= Why major decisions were made

game-design/
= Gameplay rules and intent

specs/
= Approved design rationale for a specific feature

plan/
= Implementation tasks and execution order

AGENTS.md
= How agents should work in the repository
```
