# Project Context

## Product

Everstride is a health-powered RPG...

## Core Loop

Steps -> Energy -> Adventure -> Rewards -> Progression

## Current Stack

- Flutter
- Riverpod
- Health Connect
- Drift
- Supabase

## Architecture Decisions

- Offline-first
- Repository abstraction
- No Go API during MVP
- Supabase must not be called directly from UI

## Current Milestone

Protect cloud saves across devices, collect local balancing observations, and
polish the MVP experience. Health Connect step sync, Energy, Adventures, Daily
Quests, Trail Supplies, and optional Supabase backup are implemented.

Cloud Backup currently supports one primary device safely. A device with an
existing remote save must ask the player to Restore or Replace before writing;
simultaneous play on multiple devices has no conflict-safe merge yet.

## Non-Goals

- PvP
- Guild
- Trading
- Real-time combat
