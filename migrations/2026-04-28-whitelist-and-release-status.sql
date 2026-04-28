-- ============================================
-- Migration: 2026-04-28
-- Adds parent whitelist + release status fields for v2 (post-coach-feedback)
--
-- Run order: paste this whole file into Supabase SQL Editor and Run.
-- Idempotent guards (if not exists / drop policy if exists) are used so
-- re-running is safe in case of partial failure.
-- ============================================

-- 1) parent whitelist
-- Emails are stored lowercase (CHECK constraint) so equality comparisons
-- without lower() use the primary-key index.
create table if not exists parents (
  email text primary key check (email = lower(email)),
  parent_name text not null,
  notes text,
  is_regular boolean default false,
  added_at timestamptz default now(),
  added_by uuid references auth.users(id)
);

create index if not exists idx_parents_is_regular on parents (is_regular);

alter table parents enable row level security;

drop policy if exists "anyone read parents" on parents;
drop policy if exists "coach manage parents" on parents;

-- read open: anonymous parent UI checks "is my email on the list"
-- write closed to coach/admin (auth required)
create policy "anyone read parents" on parents for select using (true);
create policy "coach manage parents" on parents for all
  using (auth.role() = 'authenticated')
  with check (auth.role() = 'authenticated');

-- Realtime so admin/coach UI updates instantly when whitelist changes.
-- Wrapped in DO to avoid "table already in publication" error on re-run.
do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime' and tablename = 'parents'
  ) then
    execute 'alter publication supabase_realtime add table parents';
  end if;
end $$;

-- 2) Tighten insert policies: anonymous insert only allowed when email is whitelisted
drop policy if exists "anyone insert bookings" on bookings;
create policy "whitelisted insert bookings" on bookings for insert
  with check (
    auth.role() = 'authenticated'
    OR exists (select 1 from parents where parents.email = lower(bookings.email))
  );

drop policy if exists "anyone insert requests" on recurring_requests;
create policy "whitelisted insert requests" on recurring_requests for insert
  with check (
    auth.role() = 'authenticated'
    OR exists (select 1 from parents where parents.email = lower(recurring_requests.email))
  );

-- 3) releases: status + confirm fields (used by Phase 3 email confirm flow)
-- Adding now so future migrations don't need to touch hot tables.
alter table releases add column if not exists status text default 'open';
alter table releases add column if not exists confirm_token uuid;
alter table releases add column if not exists confirmed_at timestamptz;

-- valid status values: 'open' (default, new behavior matches v1), 'regular_held',
-- 'open_for_pickup', 'booked', 'cancelled'. Phase 3 will start populating these.
