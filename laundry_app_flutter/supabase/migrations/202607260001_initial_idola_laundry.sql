create extension if not exists pgcrypto;

create table if not exists public.shops (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  phone text not null default '',
  address text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.employees (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  phone text not null default '',
  position text not null default 'Operator',
  role text not null default 'EMPLOYEE' check (role in ('OWNER', 'EMPLOYEE')),
  shift_start time not null default '06:00',
  shift_end time not null default '14:00',
  late_tolerance_minutes integer not null default 120,
  weekly_salary integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now()
);

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  full_name text not null,
  role text not null check (role in ('OWNER', 'EMPLOYEE')),
  is_active boolean not null default true,
  avatar_url text,
  phone text,
  username text unique,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.service_categories (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  sort_order integer not null default 0,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  unique (shop_id, name)
);

create table if not exists public.services (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  category_id uuid references public.service_categories(id) on delete set null,
  category_name text not null default '',
  item_name text not null,
  size_variant text not null default '',
  material_variant text not null default '',
  unit text not null default 'PCS',
  price integer not null default 0 check (price >= 0),
  estimated_hours integer not null default 0,
  is_express boolean not null default false,
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.customers (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  phone text not null default '',
  normalized_phone text not null default '',
  address text not null default '',
  note text not null default '',
  created_at timestamptz not null default now(),
  unique (shop_id, normalized_phone)
);

create table if not exists public.orders (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  order_number text not null,
  customer_id uuid not null references public.customers(id) on delete restrict,
  customer_name_snapshot text not null,
  customer_phone_snapshot text not null default '',
  assigned_employee_id uuid references public.employees(id) on delete set null,
  order_status text not null default 'received',
  payment_status text not null default 'unpaid',
  total_price integer not null default 0,
  paid_amount integer not null default 0,
  note text not null default '',
  created_at timestamptz not null default now(),
  due_at timestamptz not null default now(),
  unique (shop_id, order_number)
);

create table if not exists public.order_items (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  service_id uuid references public.services(id) on delete set null,
  service_name_snapshot text not null,
  category_snapshot text not null default '',
  unit text not null default 'PCS',
  quantity numeric not null default 1 check (quantity > 0),
  unit_price integer not null default 0,
  subtotal integer not null default 0
);

create table if not exists public.payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  order_id uuid not null references public.orders(id) on delete cascade,
  amount integer not null check (amount > 0),
  method text not null default 'Tunai',
  created_at timestamptz not null default now()
);

create table if not exists public.cash_transactions (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  type text not null check (type in ('IN', 'OUT')),
  category text not null,
  description text not null default '',
  amount integer not null check (amount >= 0),
  method text not null default 'Tunai',
  reference_type text not null default '',
  reference_id uuid,
  created_at timestamptz not null default now()
);

create table if not exists public.attendance_records (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  employee_name text not null,
  type text not null check (type in ('CHECK_IN', 'CHECK_OUT')),
  status text not null default 'on_time',
  late_minutes integer not null default 0,
  photo_path text not null default '',
  created_at timestamptz not null default now()
);

create table if not exists public.employee_requests (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  employee_id uuid references public.employees(id) on delete set null,
  employee_name text not null,
  type text not null,
  reason text not null default '',
  amount integer not null default 0,
  status text not null default 'pending',
  review_note text not null default '',
  created_at timestamptz not null default now(),
  reviewed_at timestamptz
);

create index if not exists idx_profiles_shop_id on public.profiles(shop_id);
create index if not exists idx_services_shop_id_category on public.services(shop_id, category_name, item_name);
create index if not exists idx_customers_shop_id on public.customers(shop_id);
create index if not exists idx_orders_shop_id_created_at on public.orders(shop_id, created_at desc);
create index if not exists idx_order_items_order_id on public.order_items(order_id);
create index if not exists idx_payments_order_id on public.payments(order_id);
create index if not exists idx_cash_shop_id_created_at on public.cash_transactions(shop_id, created_at desc);

create or replace function public.current_shop_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select shop_id from public.profiles where id = auth.uid()
$$;

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

drop trigger if exists profiles_touch_updated_at on public.profiles;
create trigger profiles_touch_updated_at
before update on public.profiles
for each row execute function public.touch_updated_at();

alter table public.shops enable row level security;
alter table public.employees enable row level security;
alter table public.profiles enable row level security;
alter table public.service_categories enable row level security;
alter table public.services enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.payments enable row level security;
alter table public.cash_transactions enable row level security;
alter table public.attendance_records enable row level security;
alter table public.employee_requests enable row level security;

create policy "shop members read own shop"
on public.shops for select
using (id = public.current_shop_id());

create policy "owners update own shop"
on public.shops for update
using (id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "profiles read own shop"
on public.profiles for select
using (shop_id = public.current_shop_id());

create policy "profiles update self"
on public.profiles for update
using (id = auth.uid() or (shop_id = public.current_shop_id() and public.current_role() = 'OWNER'))
with check (shop_id = public.current_shop_id());

create policy "employees read own shop"
on public.employees for select
using (shop_id = public.current_shop_id());

create policy "owners manage employees"
on public.employees for all
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "service categories read own shop"
on public.service_categories for select
using (shop_id = public.current_shop_id());

create policy "owners manage service categories"
on public.service_categories for all
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "services read own shop"
on public.services for select
using (shop_id = public.current_shop_id());

create policy "owners manage services"
on public.services for all
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "customers read own shop"
on public.customers for select
using (shop_id = public.current_shop_id());

create policy "members insert customers"
on public.customers for insert
with check (shop_id = public.current_shop_id());

create policy "owners update customers"
on public.customers for update
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id());

create policy "orders read own shop"
on public.orders for select
using (shop_id = public.current_shop_id());

create policy "members insert orders"
on public.orders for insert
with check (shop_id = public.current_shop_id());

create policy "members update orders"
on public.orders for update
using (shop_id = public.current_shop_id())
with check (shop_id = public.current_shop_id());

create policy "owners delete orders"
on public.orders for delete
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "order items read own shop"
on public.order_items for select
using (shop_id = public.current_shop_id());

create policy "members insert order items"
on public.order_items for insert
with check (shop_id = public.current_shop_id());

create policy "members update order items"
on public.order_items for update
using (shop_id = public.current_shop_id())
with check (shop_id = public.current_shop_id());

create policy "owners delete order items"
on public.order_items for delete
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "payments read own shop"
on public.payments for select
using (shop_id = public.current_shop_id());

create policy "members insert payments"
on public.payments for insert
with check (shop_id = public.current_shop_id());

create policy "cash read own shop"
on public.cash_transactions for select
using (shop_id = public.current_shop_id());

create policy "members insert cash"
on public.cash_transactions for insert
with check (shop_id = public.current_shop_id());

create policy "attendance read own shop"
on public.attendance_records for select
using (shop_id = public.current_shop_id());

create policy "members insert attendance"
on public.attendance_records for insert
with check (shop_id = public.current_shop_id());

create policy "requests read own shop"
on public.employee_requests for select
using (shop_id = public.current_shop_id());

create policy "members insert requests"
on public.employee_requests for insert
with check (shop_id = public.current_shop_id());

create policy "owners update requests"
on public.employee_requests for update
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id());
