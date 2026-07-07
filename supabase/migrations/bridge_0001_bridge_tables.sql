-- bridge_0001_bridge_tables.sql
-- Coordination bridge storage (slice #0). Namespace: bridge_*  (no app tables touched).
-- Applied by the STRATEGIST via the Supabase connector, not by the builder.

create table if not exists bridge_builds (
  id            uuid primary key default gen_random_uuid(),
  track         text not null default 'main',          -- main | frontend | infra | bridge
  task_id       text not null,                         -- e.g. "P1.coreEngine"
  spec          text not null,                         -- scope, acceptance, file boundaries, must-not-touch
  model         text,                                  -- optional builder model hint
  status        text not null default 'requested'
                  check (status in ('requested','in_progress','blocked','completed','abandoned')),
  verification  jsonb,                                 -- {typecheck, tests, commit, notes} posted by builder
  hot_files     text[] not null default '{}',          -- files this slice touches (lock-awareness)
  requested_by  text not null default 'claude',
  created_at    timestamptz not null default now(),
  updated_at    timestamptz not null default now()
);

create table if not exists bridge_updates (            -- append-only progress log
  id           uuid primary key default gen_random_uuid(),
  build_id     uuid not null references bridge_builds(id) on delete cascade,
  author       text not null,                          -- 'cursor' | 'claude'
  summary      text not null,
  status       text,                                   -- mirrors build status at time of update
  verification jsonb,
  created_at   timestamptz not null default now()
);

create table if not exists bridge_decisions (          -- locked-decision changes (Claude only writes these)
  id         uuid primary key default gen_random_uuid(),
  title      text not null,
  detail     text not null,
  supersedes text,                                      -- which prior decision/file this changes
  created_at timestamptz not null default now()
);

create table if not exists bridge_state (              -- single-row snapshot for fast "where are we"
  id             int primary key default 1 check (id = 1),
  current_slice  text,
  current_status text,
  open_hot_files text[] not null default '{}',
  last_updated   timestamptz not null default now()
);

insert into bridge_state (id) values (1) on conflict (id) do nothing;

-- Helpful index for the hot-file lock-check on request_build (scans non-terminal builds).
create index if not exists bridge_builds_active_idx
  on bridge_builds (status)
  where status in ('requested','in_progress','blocked');
