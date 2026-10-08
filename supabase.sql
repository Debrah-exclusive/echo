-- ECHO global leaderboard. Paste this whole file into the Supabase SQL Editor and press Run.

create table public.scores (
  id bigint generated always as identity primary key,
  mode text not null check (mode in ('levels', 'endless', 'daily')),
  day text not null default '',                 -- the date for daily runs, empty for the other modes
  name text not null check (char_length(name) between 2 and 10),
  score integer not null check (score between 1 and 100000),
  level integer not null default 1,
  echoes integer not null default 0,
  updated_at timestamptz not null default now(),
  unique (mode, day, name)                      -- one row per player per board
);

-- Players can read the board but cannot write to the table directly.
alter table public.scores enable row level security;
create policy "Anyone can read scores" on public.scores
  for select to anon, authenticated using (true);

-- The only way to write: adds the player's row, or raises their score if this run beat it.
create or replace function public.submit_score(
  p_mode text, p_day text, p_name text, p_score integer, p_level integer, p_echoes integer
) returns void
language sql security definer set search_path = public as $$
  insert into scores (mode, day, name, score, level, echoes)
  values (p_mode, case when p_mode = 'daily' then p_day else '' end, upper(trim(p_name)), p_score, p_level, p_echoes)
  on conflict (mode, day, name) do update
    set score = excluded.score, level = excluded.level, echoes = excluded.echoes, updated_at = now()
    where excluded.score > scores.score;
$$;

grant execute on function public.submit_score(text, text, text, integer, integer, integer) to anon, authenticated;
