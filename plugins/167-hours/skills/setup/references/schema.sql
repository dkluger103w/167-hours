-- 167 Hours: Between Sessions
-- Database schema. Apply once to a fresh Supabase project.
-- Every table is owned by one user (user_id) with row-level security.
-- Link tables use composite foreign keys (id, user_id) so rows from
-- different users can never be linked to each other.

create type public.entry_type as enum (
  'thought', 'feeling', 'urge', 'event', 'win', 'sleep', 'note'
);
create type public.person_status as enum ('living', 'deceased', 'unknown');
create type public.pattern_status as enum ('active', 'easing', 'resolved');

create or replace function public.set_updated_at()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

-- Profiles -----------------------------------------------------------

create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  therapist_name text,
  next_session_at timestamptz,
  session_cycle_days int not null default 7 check (session_cycle_days between 1 and 60),
  timezone text not null default 'America/New_York',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);
create trigger profiles_set_updated_at before update on public.profiles
  for each row execute function public.set_updated_at();
alter table public.profiles enable row level security;
create policy "profiles_select_own" on public.profiles
  for select to authenticated using ((select auth.uid()) = id);
create policy "profiles_insert_own" on public.profiles
  for insert to authenticated with check ((select auth.uid()) = id);
create policy "profiles_update_own" on public.profiles
  for update to authenticated using ((select auth.uid()) = id) with check ((select auth.uid()) = id);

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id) values (new.id);
  return new;
end;
$$;
revoke execute on function public.handle_new_user() from public, anon, authenticated;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Entries ------------------------------------------------------------

create table public.entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  occurred_at timestamptz not null default now(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  type public.entry_type not null default 'note',
  trigger text,
  automatic_thought text,
  emotion text,
  intensity int check (intensity between 0 and 10),
  urge text,
  action_taken text,
  acted_on_urge boolean,
  sleep_hours numeric(4,1) check (sleep_hours between 0 and 24),
  notes text,
  tags text[] not null default '{}',
  flag_for_session boolean not null default false,
  private boolean not null default false,
  unique (id, user_id)
);
create index entries_user_occurred_idx on public.entries (user_id, occurred_at desc);
create trigger entries_set_updated_at before update on public.entries
  for each row execute function public.set_updated_at();

-- Session summaries (reports for the therapist) -----------------------

create table public.session_summaries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  period_start timestamptz not null,
  period_end timestamptz not null,
  title text,
  content_md text not null,
  report_html text,
  pdf_filename text,
  sent_to text,
  created_at timestamptz not null default now(),
  check (period_end > period_start),
  unique (id, user_id)
);
create index session_summaries_user_period_idx on public.session_summaries (user_id, period_end desc);

-- People -------------------------------------------------------------

create table public.people (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  aliases text[] not null default '{}',
  relationship text,
  status public.person_status not null default 'living',
  important_dates text,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);
create index people_user_idx on public.people (user_id);
create index people_aliases_idx on public.people using gin (aliases);
create trigger people_set_updated_at before update on public.people
  for each row execute function public.set_updated_at();

create table public.entry_people (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  entry_id uuid not null,
  person_id uuid not null,
  primary key (entry_id, person_id),
  foreign key (entry_id, user_id) references public.entries (id, user_id) on delete cascade,
  foreign key (person_id, user_id) references public.people (id, user_id) on delete cascade
);
create index entry_people_person_idx on public.entry_people (person_id, user_id);
create index entry_people_user_idx on public.entry_people (user_id);

-- Patterns -----------------------------------------------------------

create table public.patterns (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  description text,
  first_noticed date,
  status public.pattern_status not null default 'active',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  unique (user_id, name)
);
create trigger patterns_set_updated_at before update on public.patterns
  for each row execute function public.set_updated_at();

create table public.entry_patterns (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  entry_id uuid not null,
  pattern_id uuid not null,
  primary key (entry_id, pattern_id),
  foreign key (entry_id, user_id) references public.entries (id, user_id) on delete cascade,
  foreign key (pattern_id, user_id) references public.patterns (id, user_id) on delete cascade
);
create index entry_patterns_pattern_idx on public.entry_patterns (pattern_id, user_id);
create index entry_patterns_user_idx on public.entry_patterns (user_id);

-- Therapy sessions ---------------------------------------------------

create table public.sessions (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  session_at timestamptz not null,
  clinician text,
  format text,
  summary_id uuid,
  topics text,
  takeaways text,
  homework text,
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  foreign key (summary_id, user_id) references public.session_summaries (id, user_id) on delete set null (summary_id)
);
create index sessions_user_at_idx on public.sessions (user_id, session_at desc);
create trigger sessions_set_updated_at before update on public.sessions
  for each row execute function public.set_updated_at();

-- Coping tools -------------------------------------------------------

create table public.tools (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  name text not null,
  description text,
  source text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id),
  unique (user_id, name)
);
create trigger tools_set_updated_at before update on public.tools
  for each row execute function public.set_updated_at();

create table public.tool_uses (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  tool_id uuid not null,
  entry_id uuid,
  used_at timestamptz not null default now(),
  helped int check (helped between 0 and 10),
  notes text,
  created_at timestamptz not null default now(),
  foreign key (tool_id, user_id) references public.tools (id, user_id) on delete cascade,
  foreign key (entry_id, user_id) references public.entries (id, user_id) on delete set null (entry_id)
);
create index tool_uses_user_at_idx on public.tool_uses (user_id, used_at desc);

-- Life history -------------------------------------------------------

create table public.life_events (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  title text not null,
  occurred_on date,
  approx_when text,
  age_at_event int,
  description text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (id, user_id)
);
create index life_events_user_idx on public.life_events (user_id, occurred_on);
create trigger life_events_set_updated_at before update on public.life_events
  for each row execute function public.set_updated_at();

create table public.life_event_people (
  user_id uuid not null default auth.uid() references auth.users (id) on delete cascade,
  life_event_id uuid not null,
  person_id uuid not null,
  primary key (life_event_id, person_id),
  foreign key (life_event_id, user_id) references public.life_events (id, user_id) on delete cascade,
  foreign key (person_id, user_id) references public.people (id, user_id) on delete cascade
);
create index life_event_people_user_idx on public.life_event_people (user_id);

-- Safety plan --------------------------------------------------------

create table public.safety_plans (
  user_id uuid primary key default auth.uid() references auth.users (id) on delete cascade,
  warning_signs text[] not null default '{}',
  coping_steps text[] not null default '{}',
  reasons text[] not null default '{}',
  contacts jsonb not null default '[]',
  professional_contacts jsonb not null default '[]',
  crisis_line text not null default 'Call or text 988 (Suicide and Crisis Lifeline). Emergency: 911.',
  updated_at timestamptz not null default now()
);
create trigger safety_plans_set_updated_at before update on public.safety_plans
  for each row execute function public.set_updated_at();

-- Row-level security for every user-owned table ------------------------

do $$
declare t text;
begin
  foreach t in array array[
    'entries','session_summaries','people','entry_people','patterns','entry_patterns',
    'sessions','tools','tool_uses','life_events','life_event_people','safety_plans'
  ] loop
    execute format('alter table public.%I enable row level security', t);
    execute format(
      'create policy %I on public.%I for all to authenticated using ((select auth.uid()) = user_id) with check ((select auth.uid()) = user_id)',
      t || '_own_rows', t);
  end loop;
end $$;
