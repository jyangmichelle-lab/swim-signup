-- ============================================
-- Migration: 2026-04-29
-- Adds per-swimmer profiles (multi-kid families share one parent email).
-- The booking child_name field stays free-text for backward compat;
-- swimmer profiles are coach-managed reference data so coach can see
-- age + season group without parsing the notes field.
-- ============================================

create table if not exists swimmers (
  id uuid primary key default gen_random_uuid(),
  parent_email text not null references parents(email) on update cascade on delete cascade,
  swimmer_name text not null,
  birth_year int check (birth_year between 1900 and 2100),
  birth_month int check (birth_month between 1 and 12),
  notes text,
  created_at timestamptz default now()
);

create index if not exists idx_swimmers_parent_email on swimmers (parent_email);

alter table swimmers enable row level security;

drop policy if exists "anyone read swimmers" on swimmers;
drop policy if exists "coach manage swimmers" on swimmers;

-- read open: parent UI shows "your registered swimmers" hint, anonymous needs read access.
-- write closed to coach (auth required); RLS ensures parents can't add fake kids.
create policy "anyone read swimmers" on swimmers for select using (true);
create policy "coach manage swimmers" on swimmers for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- Realtime so admin/coach UI updates instantly when swimmer rows change.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'swimmers'
  ) then
    execute 'alter publication supabase_realtime add table swimmers';
  end if;
end $$;
