-- Complete online schema for the operational app without dropping old data.
create extension if not exists pgcrypto;

alter table public.shops
  add column if not exists updated_at timestamptz not null default now();

alter table public.employees
  add column if not exists position text not null default 'Operator',
  add column if not exists shift_start time not null default '06:00',
  add column if not exists shift_end time not null default '14:00',
  add column if not exists late_tolerance_minutes integer not null default 120,
  add column if not exists updated_at timestamptz not null default now();

alter table public.customers
  add column if not exists updated_at timestamptz not null default now();

alter table public.orders
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz;

alter table public.payments
  add column if not exists method text not null default 'Tunai',
  add column if not exists note text not null default '',
  add column if not exists created_by uuid references public.employees(id) on delete set null;

create table if not exists public.cashbook_entries (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  type text not null check (type in ('IN', 'OUT')),
  category text not null,
  description text not null default '',
  amount integer not null check (amount >= 0),
  method text not null default 'Tunai',
  reference_type text not null default '',
  reference_id uuid,
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

insert into public.cashbook_entries (
  id, shop_id, type, category, description, amount, method,
  reference_type, reference_id, created_at
)
select
  id, shop_id, type, category, description, amount, method,
  reference_type, reference_id, created_at
from public.cash_transactions
on conflict (id) do nothing;

create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  name text not null,
  stock numeric not null default 0,
  unit text not null default 'pcs',
  min_stock numeric not null default 0,
  purchase_price integer not null default 0,
  note text not null default '',
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, name)
);

create table if not exists public.inventory_movements (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  item_id uuid not null references public.inventory_items(id) on delete cascade,
  item_name text not null,
  type text not null check (type in ('IN', 'OUT', 'ADJUSTMENT')),
  quantity numeric not null check (quantity > 0),
  note text not null default '',
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now()
);

create table if not exists public.notifications (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  title text not null,
  message text not null default '',
  type text not null default 'INFO',
  action_route text not null default '',
  is_read boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.shop_settings (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  key text not null,
  value jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, key)
);

create index if not exists idx_cashbook_entries_shop_created
  on public.cashbook_entries(shop_id, created_at desc);
create index if not exists idx_inventory_items_shop_active
  on public.inventory_items(shop_id, is_active, name);
create index if not exists idx_inventory_movements_item_created
  on public.inventory_movements(item_id, created_at desc);
create index if not exists idx_notifications_shop_read_created
  on public.notifications(shop_id, is_read, created_at desc);
create index if not exists idx_shop_settings_shop_key
  on public.shop_settings(shop_id, key);

alter table public.cashbook_entries enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.notifications enable row level security;
alter table public.shop_settings enable row level security;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;

drop policy if exists "cashbook entries read own shop" on public.cashbook_entries;
create policy "cashbook entries read own shop"
on public.cashbook_entries for select
using (shop_id = public.current_shop_id());

drop policy if exists "members insert cashbook entries" on public.cashbook_entries;
create policy "members insert cashbook entries"
on public.cashbook_entries for insert
with check (shop_id = public.current_shop_id());

drop policy if exists "owners update cashbook entries" on public.cashbook_entries;
create policy "owners update cashbook entries"
on public.cashbook_entries for update
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id());

drop policy if exists "inventory items read own shop" on public.inventory_items;
create policy "inventory items read own shop"
on public.inventory_items for select
using (shop_id = public.current_shop_id());

drop policy if exists "owners manage inventory items" on public.inventory_items;
create policy "owners manage inventory items"
on public.inventory_items for all
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id());

drop policy if exists "inventory movements read own shop" on public.inventory_movements;
create policy "inventory movements read own shop"
on public.inventory_movements for select
using (shop_id = public.current_shop_id());

drop policy if exists "members insert inventory movements" on public.inventory_movements;
create policy "members insert inventory movements"
on public.inventory_movements for insert
with check (shop_id = public.current_shop_id());

drop policy if exists "notifications read own shop" on public.notifications;
create policy "notifications read own shop"
on public.notifications for select
using (shop_id = public.current_shop_id());

drop policy if exists "members update notifications" on public.notifications;
create policy "members update notifications"
on public.notifications for update
using (shop_id = public.current_shop_id())
with check (shop_id = public.current_shop_id());

drop policy if exists "settings read own shop" on public.shop_settings;
create policy "settings read own shop"
on public.shop_settings for select
using (shop_id = public.current_shop_id());

drop policy if exists "owners manage settings" on public.shop_settings;
create policy "owners manage settings"
on public.shop_settings for all
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id());
