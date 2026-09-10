create table if not exists public.player_saves (
  user_id uuid primary key references auth.users (id) on delete cascade,
  level integer not null,
  exp integer not null,
  energy integer not null,
  gold integer not null,
  pending_steps integer not null,
  has_reconciled_historical_steps boolean not null default false,
  health_daily jsonb not null default '[]'::jsonb,
  daily_quest_instances jsonb not null default '[]'::jsonb,
  schema_version integer not null default 1,
  updated_at timestamptz not null default now()
);

alter table public.player_saves enable row level security;

create policy "Users read their own player save"
  on public.player_saves for select using (auth.uid() = user_id);

create policy "Users insert their own player save"
  on public.player_saves for insert with check (auth.uid() = user_id);

create policy "Users update their own player save"
  on public.player_saves for update using (auth.uid() = user_id)
  with check (auth.uid() = user_id);
