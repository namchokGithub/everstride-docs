# Architecture Decisions

## ADR-001: Flutter over Native Kotlin

Reason:

- Faster UI iteration
- Cross-platform potential
- Health Connect is sufficient for MVP

## ADR-002: Supabase over Firebase

Reason:

- PostgreSQL
- Relational game data
- Learning goal
- Easier future backend integration

## ADR-003: No Go API during MVP

Reason:

- Reduce infrastructure complexity
- Validate game loop first

Revisit when:

- Anti-cheat is required
- Competitive features are introduced
- Server-authoritative economy is needed

## ADR-004: flutter_dotenv over --dart-define-from-file for environment configuration

Reason:

- `.gitignore` already anticipated a dotenv-style `.env` file before this decision
- Runtime file load (`Env.load()`) keeps config out of build command lines and CI configs
- `.env.example` gives contributors an obvious, self-documenting template to copy

Trade-off:

- Adds one dependency (`flutter_dotenv`) and requires declaring `.env` as a Flutter asset
- `--dart-define-from-file` would avoid the dependency and bundle nothing into the compiled asset bundle, at the cost of a longer run command and one more file to keep in sync per environment

Revisit when:

- Multiple environments (dev/staging/prod) need separate configs and the asset-bundling approach becomes awkward
