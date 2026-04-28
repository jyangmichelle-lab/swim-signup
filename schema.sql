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

-- 1) 家长白名单 (v5: 只有白名单内邮箱才能报名)
create table parents (
  email text primary key check (email = lower(email)),
  parent_name text not null,
  notes text,
  is_regular boolean default false,
  added_at timestamptz default now(),
  added_by uuid references auth.users(id)
);
create index on parents (is_regular);

-- 1.1) 学员 (一家可多娃, 共用同一个家长邮箱)
create table swimmers (
  id uuid primary key default gen_random_uuid(),
  parent_email text not null references parents(email) on update cascade on delete cascade,
  swimmer_name text not null,
  birth_year int check (birth_year between 1900 and 2100),
  birth_month int check (birth_month between 1 and 12),
  notes text,
  created_at timestamptz default now()
);
create index on swimmers (parent_email);

-- 2) 释放表(教练发布的可预约时段)
create table releases (
  id uuid primary key default gen_random_uuid(),
  date date not null,
  minute int not null,
  status text default 'open',          -- 'open' | 'regular_held' | 'open_for_pickup' | 'booked' | 'cancelled' (Phase 3 用)
  confirm_token uuid,                  -- Phase 3: 24h confirm 流程的 token
  confirmed_at timestamptz,            -- Phase 3
  created_at timestamptz default now(),
  unique(date, minute)
);

-- 3) 单次预约
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

-- 4) 循环预约申请
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

-- 5) 已批准的循环预约
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
alter table parents enable row level security;
alter table swimmers enable row level security;
alter table releases enable row level security;
alter table bookings enable row level security;
alter table recurring_requests enable row level security;
alter table recurring_approved enable row level security;

-- app_admins: 只 admin 自己能读自己,admin 能读所有
create policy "admin can read admins" on app_admins for select using (is_admin() or user_id = auth.uid());
create policy "admin can manage admins" on app_admins for all using (is_admin()) with check (is_admin());

-- parents (白名单): 所有人读(家长UI要校验),教练/admin 改
create policy "anyone read parents" on parents for select using (true);
create policy "coach manage parents" on parents for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- swimmers: 所有人读(家长报名时显示自家娃名字提示),教练/admin 改
create policy "anyone read swimmers" on swimmers for select using (true);
create policy "coach manage swimmers" on swimmers for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- releases: 所有人读,教练写,admin全权
create policy "anyone read releases" on releases for select using (true);
create policy "coach write releases" on releases for all using (auth.role() = 'authenticated') with check (auth.role() = 'authenticated');

-- bookings: 所有人读, 白名单邮箱才能插入, 任何人改(家长取消), 教练删
create policy "anyone read bookings" on bookings for select using (true);
create policy "whitelisted insert bookings" on bookings for insert with check (
  auth.role() = 'authenticated'
  OR exists (select 1 from parents where parents.email = lower(bookings.email))
);
create policy "anyone update bookings" on bookings for update using (true) with check (true);
create policy "coach delete bookings" on bookings for delete using (auth.role() = 'authenticated');

-- recurring_requests: 所有人读, 白名单邮箱才能插入, 教练改/删
create policy "anyone read requests" on recurring_requests for select using (true);
create policy "whitelisted insert requests" on recurring_requests for insert with check (
  auth.role() = 'authenticated'
  OR exists (select 1 from parents where parents.email = lower(recurring_requests.email))
);
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
alter publication supabase_realtime add table parents;
alter publication supabase_realtime add table swimmers;
alter publication supabase_realtime add table releases;
alter publication supabase_realtime add table bookings;
alter publication supabase_realtime add table recurring_requests;
alter publication supabase_realtime add table recurring_approved;