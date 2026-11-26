-- ChipZett server setup: one table that counts free daily uses, and one function that takes a use.
-- Run once in a new Supabase project, then deploy the two functions in supabase/functions with "verify JWT" off
-- and add the secret GROQ_API_KEY (Edge Functions > Secrets). No secret is kept in this repository.
create table if not exists public.agent_usage (day date not null, who text not null, n integer not null default 0, primary key (day, who));
alter table public.agent_usage enable row level security;

create or replace function public.agent_take(p_who text, p_all text, p_user_cap integer, p_all_cap integer)
returns text language plpgsql security definer set search_path to '' as $function$
declare u int; a int; d date := (now() at time zone 'utc')::date;
begin
  if p_who = p_all then return 'all'; end if;
  insert into public.agent_usage(day, who, n) values (d, p_all, 0) on conflict do nothing;
  select n into a from public.agent_usage where day = d and who = p_all for update;
  if a >= p_all_cap then return 'all'; end if;
  insert into public.agent_usage(day, who, n) values (d, p_who, 0) on conflict do nothing;
  select n into u from public.agent_usage where day = d and who = p_who for update;
  if u >= p_user_cap then return 'user'; end if;
  update public.agent_usage set n = n + 1 where day = d and who in (p_all, p_who);
  return 'ok:' || (p_user_cap - u - 1)::text;
end $function$;
revoke all on function public.agent_take(text, text, integer, integer) from public, anon, authenticated;
grant execute on function public.agent_take(text, text, integer, integer) to service_role;

-- ---------- account sync: a signed-in person's notes, one row per note (migration wall_notes_sync) ----------
create table if not exists public.wall_notes (
  user_id uuid not null default auth.uid() references auth.users(id) on delete cascade,
  id text not null check (id ~ '^[A-Za-z0-9_-]{1,40}$'),
  data jsonb not null default '{}'::jsonb check (pg_column_size(data) < 450000),
  deleted boolean not null default false,
  updated_at timestamptz not null default now(),
  primary key (user_id, id)
);
create index if not exists wall_notes_user_updated on public.wall_notes (user_id, updated_at);
alter table public.wall_notes enable row level security;
revoke all on public.wall_notes from anon, public;
grant select, insert, update, delete on public.wall_notes to authenticated;
-- policies: each of select / insert / update / delete is allowed only where (select auth.uid()) = user_id
-- trigger wall_notes_stamp: the server sets updated_at, and one account holds at most 3000 notes
