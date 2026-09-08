# Everstride Documentation

> The product, architecture, delivery plan, and working agreements behind Everstride.

Everstride is an Android-first, health-powered RPG where real-world walking becomes in-game progression. This repository is the source of truth for the project's intent, technical decisions, and current delivery status.

## At a glance

| Area               | Current direction                               |
| ------------------ | ----------------------------------------------- |
| Product            | Turn real-world activity into RPG progression   |
| Primary platform   | Android                                         |
| Mobile stack       | Flutter, Riverpod, GoRouter                     |
| Health integration | Android Health Connect                          |
| Current milestone  | Reliably read today's steps from Health Connect |

## Documentation map

| Document                                            | Purpose                                                              |
| --------------------------------------------------- | -------------------------------------------------------------------- |
| [Project context](CONTEXT.md)                       | Product vision, core loop, stack, constraints, and current milestone |
| [Development plan](EVERSTRIDE_PLAN.md)              | MVP scope, architecture principles, and phased implementation plan   |
| [Progress tracker](PROGRESS.md)                     | What is complete, what is next, and the active checklist             |
| [Architecture decisions](DECISIONS.md)              | Key technical decisions, their rationale, and revisit conditions     |
| [Working agreement](AGENTS.md)                      | Guardrails for contributors and AI agents working in this repository |
| [Manual recheck steps](development/testing.md)      | Quick smoke-test steps to confirm each phase still works             |
| [Core game loop](game-design/core-loop.md)          | Player-facing flow from real-world activity to RPG progression       |
| [Energy system](game-design/energy-system.md)       | Rules for earning, storing, and spending Energy                      |
| [Player progression](game-design/progression.md)    | MVP rules for EXP, gold, levels, and character advancement           |
| [Mobile app README](../everstride-mobile/README.md) | Local setup and day-to-day development for the Flutter application   |

## Where to start

Choose the path that fits what you need:

- **New to Everstride?** Read [Project context](CONTEXT.md), then [Development plan](plan/EVERSTRIDE_PLAN.md).
- **Ready to contribute?** Follow the [mobile app setup guide](../everstride-mobile/README.md), then read the [working agreement](AGENTS.md).
- **Picking up implementation work?** Start with the [progress tracker](PROGRESS.md); it identifies the current priority and next concrete tasks.
- **Questioning an architectural choice?** Check [Architecture decisions](DECISIONS.md) before proposing a change.

## Product loop

```text
Real-world steps → Energy → Adventures and quests → EXP, gold, and items → Character progression
```

The MVP begins with a deliberately narrow foundation: read today's steps from Health Connect safely and reliably. RPG systems, sync, and cloud features follow only after that milestone is stable.

## Contribution principles

- Keep UI code independent from Health Connect, SQLite, and Supabase; access external systems through repositories.
- Preserve the offline-first direction and avoid infrastructure that the MVP does not yet need.
- Protect progression logic from duplicate rewards.
- Record significant architectural changes in [DECISIONS.md](DECISIONS.md) and update [PROGRESS.md](PROGRESS.md) when implementation status changes.

See [AGENTS.md](AGENTS.md) for the complete repository-specific rules.

## Repository layout

```text
everstrides/
├── everstride-docs/       # Product, planning, architecture, and delivery docs
└── everstride-mobile/     # Flutter application
```

---

**Project status:** Early MVP development. The active implementation priority is tracked in [PROGRESS.md](PROGRESS.md).
