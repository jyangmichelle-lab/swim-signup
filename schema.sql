-- ============================================
-- 0) Admin 名单(超级管理员,如开发者本人)
-- ============================================
create table app_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  name text not null,
  added_at timestamptz default now()
);

-- 判断当前登录用户是否为 admin 的辅助函数
create or replace function is_admin() returns boolean
language sql security definer stable
as $$
  select exists (select 1 from app_admins where user_id = auth.uid());
$$;

-- 1) 释放表(教练发布的可预约时段)
create table releases (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  minute int not null,
  created_at timestamptz default now(),
  unique(date, minute)
);

-- 2) 单次预约
create table bookings (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  minute int not null,
  child_name text not null,
  parent_name text not null,
  email text not null,
  phone text not null,
  cancelled boolean default false,
  attendance text,
  created_at timestamptz default now()
);
create index on bookings (email);
create index on bookings (date, minute);

-- 3) 循环预约申请
create table recurring_requests (
  id uuid primary key default gen_random_uuid(),
  dow int not null,
  minute int not null,
  child_name text not null,
  parent_name text not null,
  email text not null,
  phone text not null,
  start_date date not null,
  status text default 'pending',
  created_at timestamptz default now()
);

-- 4) 已批准的循环预约
create table recurring_approved (
  id uuid primary key default gen_random_uuid(),
  dow int not null,
  minute int not null,
  child_name text not null,
  parent_name text not null,
  email text not null,
  phone text not null,
  start_date date not null,
  cancelled boolean default false,
  cancelled_dates date[] default '{}',
  attendance jsonb default '{}'::jsonb,
  created_at timestamptz default now()
);
create index on recurring_approved (email);
create index on recurring_approved (dow, minute);

-- ============================================
-- 启用 RLS
-- ============================================
alter table app_admins enable row level security;
alter table releases enable row level security;
alter table bookings enable row level security;
alter table recurring_requests enable row level security;
alter table recurring_approved enable row level security;

-- app_admins: 只 admin 自己能读自己,admin 能读所有
create policy "admin can read admins" on app_admins for select using (is_admin() or user_id = auth.uid());
create policy "admin can manage admins" on app_admins for all using (is_admin()) with check (is_admin());

-- releases: 所有人读,教练写,admin全权
create policy "anyone read releases" on releases for select using (true);
create policy "coach write releases" on releases for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- bookings: 所有人读+插入,任何人改(包括家长取消),admin 全权
create policy "anyone read bookings" on bookings for select using (true);
create policy "anyone insert bookings" on bookings for insert with check (true);
create policy "anyone update bookings" on bookings for update using (true) with check (true);
create policy "coach delete bookings" on bookings for delete using (auth.role() = 'authenticated');

-- recurring_requests: 所有人读+插入,教练改,admin全权
create policy "anyone read requests" on recurring_requests for select using (true);
create policy "anyone insert requests" on recurring_requests for insert with check (true);
create policy "coach update requests" on recurring_requests for update using (auth.role() = 'authenticated');
create policy "coach delete requests" on recurring_requests for delete using (auth.role() = 'authenticated');

-- recurring_approved: 所有人读,教练插入,任何人改(家长取消单次),教练删
create policy "anyone read approved" on recurring_approved for select using (true);
create policy "coach insert approved" on recurring_approved for insert with check (auth.role() = 'authenticated');
create policy "anyone update approved" on recurring_approved for update using (true) with check (true);
create policy "coach delete approved" on recurring_approved for delete using (auth.role() = 'authenticated');

-- ============================================
-- 启用 Realtime(教练发布家长立刻看到)
-- ============================================
alter publication supabase_realtime add table releases;
alter publication supabase_realtime add table bookings;
alter publication supabase_realtime add table recurring_requests;
alter publication supabase_realtime add table recurring_approved;