-- Canonical production repair for LaundryApp.
-- Safe to rerun against an existing database: every object is created or
-- replaced idempotently, and legacy duplicate cash rows are removed before
-- the source uniqueness guard is installed.

begin;

select pg_advisory_xact_lock(hashtext('laundry_app_database_repair_20260829'));

create extension if not exists pgcrypto;

-- Baseline migration once granted broad privileges to every future object.
-- Reset those defaults so every new table/RPC must opt in explicitly.
alter default privileges in schema public
  revoke all on tables from anon, authenticated;
alter default privileges in schema public
  revoke all on sequences from anon, authenticated;
alter default privileges in schema public
  revoke execute on functions from public, anon, authenticated;

do $$
begin
  if to_regclass('public.shops') is null
     or to_regclass('public.employees') is null
     or to_regclass('public.profiles') is null
     or to_regclass('public.customers') is null
     or to_regclass('public.orders') is null
     or to_regclass('public.order_items') is null
     or to_regclass('public.payments') is null
     or to_regclass('public.cash_transactions') is null
     or to_regclass('public.employee_requests') is null then
    raise exception
      'LaundryApp baseline schema is incomplete. Apply the canonical migrations before this repair.';
  end if;
end
$$;

-- ---------------------------------------------------------------------------
-- Nullable customer phone contract and non-null order snapshot contract.
-- ---------------------------------------------------------------------------

alter table public.customers
  add column if not exists phone text,
  add column if not exists normalized_phone text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.customers
  alter column phone drop not null,
  alter column phone drop default,
  alter column normalized_phone drop not null,
  alter column normalized_phone drop default;

update public.customers
set phone = null
where btrim(coalesce(phone, '')) = '';

update public.customers
set normalized_phone = null
where btrim(coalesce(normalized_phone, '')) = '';

alter table public.orders
  add column if not exists customer_phone_snapshot text,
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz;

update public.orders
set customer_phone_snapshot = ''
where customer_phone_snapshot is null;

alter table public.orders
  alter column customer_phone_snapshot set default '',
  alter column customer_phone_snapshot set not null;

alter table public.payments
  add column if not exists method text not null default 'Tunai',
  add column if not exists note text not null default '',
  add column if not exists created_by uuid references public.employees(id) on delete set null;

alter table public.employee_requests
  add column if not exists payment_method text not null default 'Tunai';

-- ---------------------------------------------------------------------------
-- Missing operational tables required by the Flutter repositories.
-- ---------------------------------------------------------------------------

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
  target_profile_id uuid references public.profiles(id) on delete cascade,
  title text not null,
  message text not null default '',
  type text not null default 'INFO',
  action_route text not null default '',
  is_read boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.notifications
  add column if not exists target_profile_id uuid references public.profiles(id) on delete cascade,
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.weekly_shifts (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  employee_name text not null,
  day_of_week integer not null check (day_of_week between 1 and 7),
  start_time time not null default '06:00',
  end_time time not null default '14:00',
  is_day_off boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (shop_id, employee_id, day_of_week)
);

create index if not exists idx_inventory_items_shop_active
  on public.inventory_items(shop_id, is_active, name);
create index if not exists idx_inventory_movements_item_created
  on public.inventory_movements(item_id, created_at desc);
create index if not exists idx_notifications_shop_read_created
  on public.notifications(shop_id, is_read, created_at desc);
create index if not exists idx_weekly_shifts_employee_day
  on public.weekly_shifts(employee_id, day_of_week);

create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  description text not null,
  category text not null default 'Operasional',
  amount integer not null check (amount > 0),
  method text not null default 'Tunai',
  created_by uuid references public.employees(id) on delete set null,
  source_type text not null default '',
  source_id uuid,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.expenses
  add column if not exists description text,
  add column if not exists category text not null default 'Operasional',
  add column if not exists amount integer,
  add column if not exists method text not null default 'Tunai',
  add column if not exists created_by uuid references public.employees(id) on delete set null,
  add column if not exists source_type text not null default '',
  add column if not exists source_id uuid,
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.payroll_payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  amount integer not null check (amount > 0),
  method text not null default 'Tunai',
  paid_by uuid references public.profiles(id) on delete set null,
  paid_at timestamptz not null default now(),
  note text not null default '',
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.payroll_payments
  add column if not exists shop_id uuid references public.shops(id) on delete cascade,
  add column if not exists employee_id uuid references public.employees(id) on delete cascade,
  add column if not exists period_start date,
  add column if not exists period_end date,
  add column if not exists amount integer,
  add column if not exists method text not null default 'Tunai',
  add column if not exists paid_by uuid references public.profiles(id) on delete set null,
  add column if not exists paid_at timestamptz not null default now(),
  add column if not exists note text not null default '',
  add column if not exists created_at timestamptz not null default now(),
  add column if not exists updated_at timestamptz not null default now();

-- Preserve every row removed by deterministic deduplication. This internal
-- archive has no application policies or anon/authenticated privileges.
create table if not exists public.database_repair_archive (
  id bigint generated by default as identity primary key,
  repair_batch text not null,
  source_table text not null,
  source_id uuid not null,
  row_data jsonb not null,
  archived_at timestamptz not null default now(),
  unique (repair_batch, source_table, source_id)
);

alter table public.database_repair_archive enable row level security;
revoke all on table public.database_repair_archive from anon, authenticated;
grant all on table public.database_repair_archive to service_role;

update public.payroll_payments
set created_at = paid_at
where created_at is distinct from paid_at
  and created_at > paid_at;

create index if not exists idx_expenses_shop_created
  on public.expenses(shop_id, created_at desc);
create index if not exists idx_payroll_payments_shop_paid
  on public.payroll_payments(shop_id, paid_at desc);
create index if not exists idx_payroll_payments_employee_period
  on public.payroll_payments(employee_id, period_start desc);
create unique index if not exists uq_expenses_source
  on public.expenses(shop_id, source_type, source_id)
  where source_id is not null and source_type <> '';

-- The Flutter payroll workflow treats one employee/week as one payment.
-- Retain the first row if an older, unconstrained schema accepted duplicates.
with ranked as (
  select
    id,
    row_number() over (
      partition by shop_id, employee_id, period_start
      order by paid_at, id
    ) as row_number
  from public.payroll_payments
  where shop_id is not null
    and employee_id is not null
    and period_start is not null
), duplicates as (
  select id from ranked where row_number > 1
)
insert into public.database_repair_archive (
  repair_batch, source_table, source_id, row_data
)
select
  '20260829051637',
  'cash_transactions',
  cash.id,
  to_jsonb(cash)
from public.cash_transactions as cash
join duplicates on duplicates.id = cash.reference_id
where cash.reference_type = 'PAYROLL'
on conflict (repair_batch, source_table, source_id) do nothing;

with ranked as (
  select
    id,
    row_number() over (
      partition by shop_id, employee_id, period_start
      order by paid_at, id
    ) as row_number
  from public.payroll_payments
  where shop_id is not null
    and employee_id is not null
    and period_start is not null
), duplicates as (
  select id from ranked where row_number > 1
)
delete from public.cash_transactions cash
using duplicates
where cash.reference_type = 'PAYROLL'
  and cash.reference_id = duplicates.id;

with ranked as (
  select
    id,
    row_number() over (
      partition by shop_id, employee_id, period_start
      order by paid_at, id
    ) as row_number
  from public.payroll_payments
  where shop_id is not null
    and employee_id is not null
    and period_start is not null
)
insert into public.database_repair_archive (
  repair_batch, source_table, source_id, row_data
)
select
  '20260829051637',
  'payroll_payments',
  payroll.id,
  to_jsonb(payroll)
from public.payroll_payments as payroll
join ranked on ranked.id = payroll.id
where ranked.row_number > 1
on conflict (repair_batch, source_table, source_id) do nothing;

with ranked as (
  select
    id,
    row_number() over (
      partition by shop_id, employee_id, period_start
      order by paid_at, id
    ) as row_number
  from public.payroll_payments
  where shop_id is not null
    and employee_id is not null
    and period_start is not null
)
delete from public.payroll_payments payroll
using ranked
where payroll.id = ranked.id
  and ranked.row_number > 1;

create unique index if not exists uq_payroll_employee_period
  on public.payroll_payments(shop_id, employee_id, period_start);

-- Remove only duplicates for one-to-one source types. Legacy ORDER rows are
-- intentionally excluded because an order may have several partial payments.
with ranked as (
  select
    id,
    row_number() over (
      partition by shop_id, reference_type, reference_id
      order by created_at, id
    ) as row_number
  from public.cash_transactions
  where reference_id is not null
    and reference_type in ('EXPENSE', 'PAYROLL', 'PAYMENT', 'EMPLOYEE_REQUEST')
)
insert into public.database_repair_archive (
  repair_batch, source_table, source_id, row_data
)
select
  '20260829051637',
  'cash_transactions',
  cash.id,
  to_jsonb(cash)
from public.cash_transactions as cash
join ranked on ranked.id = cash.id
where ranked.row_number > 1
on conflict (repair_batch, source_table, source_id) do nothing;

with ranked as (
  select
    id,
    row_number() over (
      partition by shop_id, reference_type, reference_id
      order by created_at, id
    ) as row_number
  from public.cash_transactions
  where reference_id is not null
    and reference_type in ('EXPENSE', 'PAYROLL', 'PAYMENT', 'EMPLOYEE_REQUEST')
)
delete from public.cash_transactions cash
using ranked
where cash.id = ranked.id
  and ranked.row_number > 1;

create unique index if not exists uq_cash_transactions_source
  on public.cash_transactions(shop_id, reference_type, reference_id)
  where reference_id is not null
    and reference_type in ('EXPENSE', 'PAYROLL', 'PAYMENT', 'EMPLOYEE_REQUEST');

-- ---------------------------------------------------------------------------
-- Active-profile helpers used by every policy and RPC.
-- ---------------------------------------------------------------------------

create or replace function public.current_shop_id()
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select profile.shop_id
  from public.profiles as profile
  where profile.id = (select auth.uid())
    and profile.is_active
  limit 1
$$;

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select profile.role
  from public.profiles as profile
  where profile.id = (select auth.uid())
    and profile.is_active
  limit 1
$$;

create or replace function public.current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select profile.employee_id
  from public.profiles as profile
  where profile.id = (select auth.uid())
    and profile.is_active
  limit 1
$$;

revoke all on function public.current_shop_id() from public;
revoke all on function public.current_role() from public;
revoke all on function public.current_employee_id() from public;
grant execute on function public.current_shop_id() to authenticated;
grant execute on function public.current_role() to authenticated;
grant execute on function public.current_employee_id() to authenticated;

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
set search_path = pg_catalog, public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

revoke all on function public.touch_updated_at() from public;

-- These are internal trigger functions, not public Data API RPC endpoints.
revoke all on function public.notify_request_workflow() from public;
revoke all on function public.write_audit_log() from public;

-- adjust_inventory_stock is an intentional authenticated RPC with an Owner
-- authorization check in its body. Remove the inherited anonymous execute.
revoke all on function public.adjust_inventory_stock(uuid, numeric, text, text)
  from public;
grant execute on function public.adjust_inventory_stock(uuid, numeric, text, text)
  to authenticated;

-- This RPC is intentionally callable before sign-in because the current login
-- UI displays active employee usernames before the PIN is submitted.
create or replace function public.get_login_employees()
returns table(id uuid, name text, username text)
language sql
stable
security definer
set search_path = pg_catalog, public
as $$
  select employee.id, employee.name, profile.username
  from public.employees as employee
  join public.profiles as profile on profile.employee_id = employee.id
  where employee.is_active
    and employee.role = 'EMPLOYEE'
    and profile.is_active
    and profile.username is not null
  order by employee.name
$$;

revoke all on function public.get_login_employees() from public;
grant execute on function public.get_login_employees() to anon, authenticated;

-- ---------------------------------------------------------------------------
-- Atomic payment RPCs. Cash rows are generated only by the payment trigger.
-- ---------------------------------------------------------------------------

create or replace function public.create_laundry_order(
  p_customer_id uuid,
  p_assigned_employee_id uuid,
  p_note text,
  p_due_at timestamptz,
  p_paid_amount integer,
  p_payment_method text,
  p_items jsonb
)
returns table(order_id uuid, order_number text)
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_customer public.customers%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_order_number text;
  v_total integer;
  v_paid_amount integer := coalesce(p_paid_amount, 0);
  v_item jsonb;
begin
  if (select auth.uid()) is null or v_shop_id is null then
    raise exception using errcode = '42501', message = 'Sesi pengguna tidak valid.';
  end if;

  select * into v_customer
  from public.customers
  where id = p_customer_id
    and shop_id = v_shop_id
    and deleted_at is null;

  if not found then
    raise exception 'Pelanggan tidak ditemukan.';
  end if;

  if p_assigned_employee_id is not null and not exists (
    select 1
    from public.employees
    where id = p_assigned_employee_id
      and shop_id = v_shop_id
      and is_active
  ) then
    raise exception 'Karyawan yang ditugaskan tidak valid.';
  end if;

  if p_items is null
     or jsonb_typeof(p_items) <> 'array'
     or jsonb_array_length(p_items) = 0 then
    raise exception 'Pesanan harus memiliki layanan.';
  end if;

  if exists (
    select 1
    from jsonb_array_elements(p_items) as item
    where coalesce((item ->> 'quantity')::numeric, 0) <= 0
       or coalesce((item ->> 'unit_price')::integer, -1) < 0
       or coalesce((item ->> 'subtotal')::integer, -1) < 0
       or (item ->> 'subtotal')::integer <>
          round((item ->> 'quantity')::numeric * (item ->> 'unit_price')::integer)::integer
  ) then
    raise exception 'Detail harga layanan tidak valid.';
  end if;

  select coalesce(sum((item ->> 'subtotal')::integer), 0)
  into v_total
  from jsonb_array_elements(p_items) as item;

  if v_total <= 0 then
    raise exception 'Total pesanan tidak valid.';
  end if;
  if v_paid_amount < 0 or v_paid_amount > v_total then
    raise exception 'Nominal pembayaran awal tidak valid.';
  end if;

  v_order_number := 'IDL-' || to_char(clock_timestamp(), 'YYYYMMDD') || '-' ||
    upper(substr(replace(v_order_id::text, '-', ''), 1, 6));

  insert into public.orders (
    id, shop_id, order_number, customer_id, customer_name_snapshot,
    customer_phone_snapshot, assigned_employee_id, order_status,
    payment_status, total_price, paid_amount, note, due_at
  ) values (
    v_order_id,
    v_shop_id,
    v_order_number,
    v_customer.id,
    coalesce(nullif(btrim(v_customer.name), ''), 'Pelanggan'),
    coalesce(nullif(btrim(v_customer.phone), ''), ''),
    p_assigned_employee_id,
    'received',
    case
      when v_paid_amount = 0 then 'unpaid'
      when v_paid_amount >= v_total then 'paid'
      else 'partial'
    end,
    v_total,
    v_paid_amount,
    coalesce(p_note, ''),
    coalesce(p_due_at, now())
  );

  for v_item in select * from jsonb_array_elements(p_items)
  loop
    insert into public.order_items (
      shop_id, order_id, service_id, service_name_snapshot,
      category_snapshot, unit, quantity, unit_price, subtotal
    ) values (
      v_shop_id,
      v_order_id,
      null,
      coalesce(nullif(btrim(v_item ->> 'service_name'), ''), 'Layanan'),
      coalesce(v_item ->> 'category', ''),
      coalesce(nullif(btrim(v_item ->> 'unit'), ''), 'PCS'),
      (v_item ->> 'quantity')::numeric,
      (v_item ->> 'unit_price')::integer,
      (v_item ->> 'subtotal')::integer
    );
  end loop;

  if v_paid_amount > 0 then
    insert into public.payments (
      shop_id, order_id, amount, method, created_by
    ) values (
      v_shop_id,
      v_order_id,
      v_paid_amount,
      coalesce(nullif(btrim(p_payment_method), ''), 'Tunai'),
      public.current_employee_id()
    );
  end if;

  return query select v_order_id, v_order_number;
end;
$$;

create or replace function public.record_order_payment(
  p_order_id uuid,
  p_amount integer,
  p_method text default 'Tunai'
)
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_order public.orders%rowtype;
  v_new_paid integer;
begin
  if (select auth.uid()) is null or v_shop_id is null then
    raise exception using errcode = '42501', message = 'Sesi pengguna tidak valid.';
  end if;
  if coalesce(p_amount, 0) <= 0 then
    raise exception 'Nominal pembayaran harus lebih dari nol.';
  end if;

  select * into v_order
  from public.orders
  where id = p_order_id
    and shop_id = v_shop_id
    and deleted_at is null
  for update;

  if not found then
    raise exception 'Pesanan tidak ditemukan.';
  end if;
  if v_order.paid_amount >= v_order.total_price then
    raise exception 'Pesanan sudah lunas.';
  end if;

  v_new_paid := least(v_order.total_price, v_order.paid_amount + p_amount);

  insert into public.payments (
    shop_id, order_id, amount, method, created_by
  ) values (
    v_order.shop_id,
    v_order.id,
    v_new_paid - v_order.paid_amount,
    coalesce(nullif(btrim(p_method), ''), 'Tunai'),
    public.current_employee_id()
  );

  update public.orders
  set paid_amount = v_new_paid,
      payment_status = case when v_new_paid >= total_price then 'paid' else 'partial' end,
      updated_at = now()
  where id = v_order.id;

  return v_new_paid;
end;
$$;

revoke all on function public.create_laundry_order(
  uuid, uuid, text, timestamptz, integer, text, jsonb
) from public;
revoke all on function public.record_order_payment(uuid, integer, text) from public;
grant execute on function public.create_laundry_order(
  uuid, uuid, text, timestamptz, integer, text, jsonb
) to authenticated;
grant execute on function public.record_order_payment(uuid, integer, text)
  to authenticated;

-- ---------------------------------------------------------------------------
-- One source row -> one cash transaction. UPDATE and DELETE stay synchronized.
-- ---------------------------------------------------------------------------

create or replace function public.sync_payment_cash_transaction()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order_number text;
begin
  if tg_op = 'DELETE' then
    delete from public.cash_transactions
    where shop_id = old.shop_id
      and reference_type = 'PAYMENT'
      and reference_id = old.id;
    return old;
  end if;

  select order_number into v_order_number
  from public.orders
  where id = new.order_id and shop_id = new.shop_id;

  insert into public.cash_transactions (
    shop_id, type, category, description, amount, method,
    reference_type, reference_id
  ) values (
    new.shop_id, 'IN', 'Pembayaran',
    'Pembayaran ' || coalesce(v_order_number, new.order_id::text),
    new.amount, coalesce(nullif(btrim(new.method), ''), 'Tunai'),
    'PAYMENT', new.id
  ) on conflict do nothing;

  update public.cash_transactions
  set type = 'IN',
      category = 'Pembayaran',
      description = 'Pembayaran ' || coalesce(v_order_number, new.order_id::text),
      amount = new.amount,
      method = coalesce(nullif(btrim(new.method), ''), 'Tunai')
  where shop_id = new.shop_id
    and reference_type = 'PAYMENT'
    and reference_id = new.id;

  return new;
end;
$$;

create or replace function public.sync_expense_cash_transaction()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if tg_op = 'DELETE' then
    delete from public.cash_transactions
    where shop_id = old.shop_id
      and reference_type = 'EXPENSE'
      and reference_id = old.id;
    return old;
  end if;

  insert into public.cash_transactions (
    shop_id, type, category, description, amount, method,
    reference_type, reference_id
  ) values (
    new.shop_id, 'OUT', new.category, new.description, new.amount,
    coalesce(nullif(btrim(new.method), ''), 'Tunai'), 'EXPENSE', new.id
  ) on conflict do nothing;

  update public.cash_transactions
  set type = 'OUT',
      category = new.category,
      description = new.description,
      amount = new.amount,
      method = coalesce(nullif(btrim(new.method), ''), 'Tunai')
  where shop_id = new.shop_id
    and reference_type = 'EXPENSE'
    and reference_id = new.id;

  return new;
end;
$$;

create or replace function public.validate_payroll_payment()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
begin
  if new.period_end < new.period_start then
    raise exception 'Periode gaji tidak valid.';
  end if;
  if new.amount <= 0 then
    raise exception 'Nominal gaji harus lebih dari nol.';
  end if;
  if not exists (
    select 1
    from public.employees
    where id = new.employee_id
      and shop_id = new.shop_id
  ) then
    raise exception 'Karyawan gaji tidak berada di toko yang sama.';
  end if;
  if new.paid_by is null and (select auth.uid()) is not null then
    new.paid_by := (select auth.uid());
  end if;
  return new;
end;
$$;

create or replace function public.sync_payroll_cash_transaction()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_employee_name text;
begin
  if tg_op = 'DELETE' then
    delete from public.cash_transactions
    where shop_id = old.shop_id
      and reference_type = 'PAYROLL'
      and reference_id = old.id;
    return old;
  end if;

  select name into v_employee_name
  from public.employees
  where id = new.employee_id and shop_id = new.shop_id;

  insert into public.cash_transactions (
    shop_id, type, category, description, amount, method,
    reference_type, reference_id
  ) values (
    new.shop_id, 'OUT', 'Gaji',
    'Gaji ' || coalesce(v_employee_name, 'Karyawan') || ' ' ||
      to_char(new.period_start, 'DD Mon YYYY') || ' - ' ||
      to_char(new.period_end, 'DD Mon YYYY'),
    new.amount, coalesce(nullif(btrim(new.method), ''), 'Tunai'),
    'PAYROLL', new.id
  ) on conflict do nothing;

  update public.cash_transactions
  set type = 'OUT',
      category = 'Gaji',
      description = 'Gaji ' || coalesce(v_employee_name, 'Karyawan') || ' ' ||
        to_char(new.period_start, 'DD Mon YYYY') || ' - ' ||
        to_char(new.period_end, 'DD Mon YYYY'),
      amount = new.amount,
      method = coalesce(nullif(btrim(new.method), ''), 'Tunai')
  where shop_id = new.shop_id
    and reference_type = 'PAYROLL'
    and reference_id = new.id;

  return new;
end;
$$;

create or replace function public.sync_employee_request_cash_transaction()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_category text;
begin
  if tg_op = 'DELETE' then
    delete from public.cash_transactions
    where shop_id = old.shop_id
      and reference_type = 'EMPLOYEE_REQUEST'
      and reference_id = old.id;
    return old;
  end if;

  if new.status <> 'paid' or new.amount <= 0 then
    delete from public.cash_transactions
    where shop_id = new.shop_id
      and reference_type = 'EMPLOYEE_REQUEST'
      and reference_id = new.id;
    return new;
  end if;

  v_category := case
    when new.type ilike '%Kasbon%' then 'Kasbon'
    when new.type ilike '%Insentif%' then 'Insentif'
    when new.type ilike '%Pengeluaran%' then 'Pengeluaran'
    else 'Request Karyawan'
  end;

  insert into public.cash_transactions (
    shop_id, type, category, description, amount, method,
    reference_type, reference_id
  ) values (
    new.shop_id, 'OUT', v_category,
    new.type || ' ' || new.employee_name || ' - ' || coalesce(new.reason, ''),
    new.amount, coalesce(nullif(btrim(new.payment_method), ''), 'Tunai'),
    'EMPLOYEE_REQUEST', new.id
  ) on conflict do nothing;

  update public.cash_transactions
  set type = 'OUT',
      category = v_category,
      description = new.type || ' ' || new.employee_name || ' - ' || coalesce(new.reason, ''),
      amount = new.amount,
      method = coalesce(nullif(btrim(new.payment_method), ''), 'Tunai')
  where shop_id = new.shop_id
    and reference_type = 'EMPLOYEE_REQUEST'
    and reference_id = new.id;

  return new;
end;
$$;

drop trigger if exists trg_expense_to_cash on public.expenses;
drop trigger if exists trg_payroll_to_cash on public.payroll_payments;
drop trigger if exists trg_sync_payment_cash on public.payments;
drop trigger if exists trg_sync_expense_cash on public.expenses;
drop trigger if exists trg_validate_payroll_payment on public.payroll_payments;
drop trigger if exists trg_sync_payroll_cash on public.payroll_payments;
drop trigger if exists trg_sync_employee_request_cash on public.employee_requests;

drop function if exists public.expense_to_cash_transaction();
drop function if exists public.payroll_to_cash_transaction();

create trigger trg_sync_payment_cash
after insert or update or delete on public.payments
for each row execute function public.sync_payment_cash_transaction();

create trigger trg_sync_expense_cash
after insert or update or delete on public.expenses
for each row execute function public.sync_expense_cash_transaction();

create trigger trg_validate_payroll_payment
before insert or update on public.payroll_payments
for each row execute function public.validate_payroll_payment();

create trigger trg_sync_payroll_cash
after insert or update or delete on public.payroll_payments
for each row execute function public.sync_payroll_cash_transaction();

create trigger trg_sync_employee_request_cash
after insert or update or delete on public.employee_requests
for each row execute function public.sync_employee_request_cash_transaction();

revoke all on function public.sync_payment_cash_transaction() from public;
revoke all on function public.sync_expense_cash_transaction() from public;
revoke all on function public.validate_payroll_payment() from public;
revoke all on function public.sync_payroll_cash_transaction() from public;
revoke all on function public.sync_employee_request_cash_transaction() from public;

-- Backfill cash rows that are missing. ON CONFLICT plus the partial unique index
-- makes this block safe when the migration is executed more than once.
insert into public.cash_transactions (
  shop_id, type, category, description, amount, method,
  reference_type, reference_id, created_at
)
select
  expense.shop_id, 'OUT', expense.category, expense.description,
  expense.amount, expense.method, 'EXPENSE', expense.id, expense.created_at
from public.expenses as expense
where not exists (
  select 1 from public.cash_transactions as cash
  where cash.shop_id = expense.shop_id
    and cash.reference_type = 'EXPENSE'
    and cash.reference_id = expense.id
)
on conflict do nothing;

insert into public.cash_transactions (
  shop_id, type, category, description, amount, method,
  reference_type, reference_id, created_at
)
select
  payroll.shop_id, 'OUT', 'Gaji',
  'Gaji ' || employee.name || ' ' ||
    to_char(payroll.period_start, 'DD Mon YYYY') || ' - ' ||
    to_char(payroll.period_end, 'DD Mon YYYY'),
  payroll.amount, payroll.method, 'PAYROLL', payroll.id, payroll.paid_at
from public.payroll_payments as payroll
join public.employees as employee
  on employee.id = payroll.employee_id and employee.shop_id = payroll.shop_id
where not exists (
  select 1 from public.cash_transactions as cash
  where cash.shop_id = payroll.shop_id
    and cash.reference_type = 'PAYROLL'
    and cash.reference_id = payroll.id
)
on conflict do nothing;

insert into public.cash_transactions (
  shop_id, type, category, description, amount, method,
  reference_type, reference_id, created_at
)
select
  request.shop_id,
  'OUT',
  case
    when request.type ilike '%Kasbon%' then 'Kasbon'
    when request.type ilike '%Insentif%' then 'Insentif'
    when request.type ilike '%Pengeluaran%' then 'Pengeluaran'
    else 'Request Karyawan'
  end,
  request.type || ' ' || request.employee_name || ' - ' || coalesce(request.reason, ''),
  request.amount,
  request.payment_method,
  'EMPLOYEE_REQUEST',
  request.id,
  coalesce(request.reviewed_at, request.created_at)
from public.employee_requests as request
where request.status = 'paid'
  and request.amount > 0
  and not exists (
    select 1 from public.cash_transactions as cash
    where cash.shop_id = request.shop_id
      and cash.reference_type = 'EMPLOYEE_REQUEST'
      and cash.reference_id = request.id
  )
on conflict do nothing;

-- ---------------------------------------------------------------------------
-- Order status side effects use source columns and the canonical cash triggers.
-- ---------------------------------------------------------------------------

create or replace function public.sync_order_status_financials()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_shoe_pairs numeric;
  v_employee_name text;
  v_amount integer;
begin
  if new.deleted_at is distinct from old.deleted_at
     and public.current_role() is distinct from 'OWNER' then
    raise exception using
      errcode = '42501',
      message = 'Hanya Owner yang dapat menghapus atau memulihkan pesanan.';
  end if;

  if new.order_status = 'picked_up' and new.paid_amount < new.total_price then
    raise exception 'Pesanan belum lunas. Bayar dulu sebelum diambil.';
  end if;

  if new.order_status = 'ready' and old.order_status is distinct from 'ready' then
    select coalesce(sum(quantity), 0)
    into v_shoe_pairs
    from public.order_items
    where order_id = new.id
      and (
        lower(service_name_snapshot || ' ' || unit) like '%sepatu%'
        or lower(service_name_snapshot || ' ' || unit) like '%pasang%'
      );

    if v_shoe_pairs > 0 then
      select name into v_employee_name
      from public.employees
      where id = new.assigned_employee_id and shop_id = new.shop_id;

      v_amount := (v_shoe_pairs * 10000)::integer;

      insert into public.expenses (
        shop_id, description, category, amount, method, created_by,
        source_type, source_id
      ) values (
        new.shop_id,
        'Insentif cuci ' || round(v_shoe_pairs)::text ||
          ' pasang sepatu untuk ' || coalesce(v_employee_name, 'Karyawan') ||
          ', Nota ' || new.order_number,
        'Insentif Cuci Sepatu',
        v_amount,
        'Tunai',
        new.assigned_employee_id,
        'ORDER_INCENTIVE',
        new.id
      ) on conflict do nothing;
    end if;
  end if;

  if (old.order_status = 'ready' and new.order_status is distinct from 'ready')
     or (new.deleted_at is not null and old.deleted_at is null) then
    delete from public.expenses
    where shop_id = new.shop_id
      and (
        (source_type = 'ORDER_INCENTIVE' and source_id = new.id)
        or (
          source_id is null
          and category = 'Insentif Cuci Sepatu'
          and description like '%Nota ' || new.order_number
        )
      );
  end if;

  if new.deleted_at is not null and old.deleted_at is null then
    -- Remove legacy order-level cash rows first. New payment-level cash rows
    -- are deleted automatically by trg_sync_payment_cash.
    delete from public.cash_transactions
    where shop_id = new.shop_id
      and reference_type = 'ORDER'
      and reference_id = new.id;

    delete from public.payments
    where shop_id = new.shop_id and order_id = new.id;
  end if;

  return new;
end;
$$;

drop trigger if exists trg_sync_order_status_financials on public.orders;
create trigger trg_sync_order_status_financials
before update on public.orders
for each row execute function public.sync_order_status_financials();
revoke all on function public.sync_order_status_financials() from public;

-- ---------------------------------------------------------------------------
-- Explicit grants and RLS. Payroll, expenses, and cashbook are Owner-only.
-- Employee access is limited to operational rows required by the application.
-- ---------------------------------------------------------------------------

grant usage on schema public to anon, authenticated, service_role;

revoke all on table public.expenses from anon, authenticated;
revoke all on table public.payroll_payments from anon, authenticated;
revoke all on table public.cash_transactions from anon, authenticated;
revoke all on table public.payments from anon, authenticated;
revoke all on table public.employee_requests from anon, authenticated;
revoke all on table public.attendance_records from anon, authenticated;
revoke all on table public.weekly_shifts from anon, authenticated;
revoke all on table public.inventory_items from anon, authenticated;
revoke all on table public.inventory_movements from anon, authenticated;
revoke all on table public.notifications from anon, authenticated;

grant select, insert, update, delete on table public.expenses to authenticated;
grant select, insert, update, delete on table public.payroll_payments to authenticated;
grant select, insert, update, delete on table public.cash_transactions to authenticated;
grant select on table public.payments to authenticated;
grant select, insert, update on table public.employee_requests to authenticated;
grant select, insert on table public.attendance_records to authenticated;
grant select, insert, update, delete on table public.weekly_shifts to authenticated;
grant select, insert, update, delete on table public.inventory_items to authenticated;
grant select on table public.inventory_movements to authenticated;
grant select, update, delete on table public.notifications to authenticated;

grant all on table public.expenses to service_role;
grant all on table public.payroll_payments to service_role;
grant all on table public.cash_transactions to service_role;
grant all on table public.payments to service_role;
grant all on table public.employee_requests to service_role;
grant all on table public.attendance_records to service_role;
grant all on table public.weekly_shifts to service_role;
grant all on table public.inventory_items to service_role;
grant all on table public.inventory_movements to service_role;
grant all on table public.notifications to service_role;

alter table public.expenses enable row level security;
alter table public.payroll_payments enable row level security;
alter table public.cash_transactions enable row level security;
alter table public.payments enable row level security;
alter table public.employee_requests enable row level security;
alter table public.attendance_records enable row level security;
alter table public.weekly_shifts enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_movements enable row level security;
alter table public.notifications enable row level security;

drop policy if exists "expenses read own shop" on public.expenses;
drop policy if exists "members insert expenses" on public.expenses;
drop policy if exists "owner manage expenses" on public.expenses;
drop policy if exists "owner delete expenses" on public.expenses;
drop policy if exists "owners select expenses" on public.expenses;
drop policy if exists "owners insert expenses" on public.expenses;
drop policy if exists "owners update expenses" on public.expenses;
drop policy if exists "owners delete expenses" on public.expenses;
create policy "owners select expenses"
on public.expenses for select to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners insert expenses"
on public.expenses for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners update expenses"
on public.expenses for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners delete expenses"
on public.expenses for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "payroll read own shop" on public.payroll_payments;
drop policy if exists "owner insert payroll" on public.payroll_payments;
drop policy if exists "owner update payroll" on public.payroll_payments;
drop policy if exists "owner delete payroll" on public.payroll_payments;
drop policy if exists "owners select payroll" on public.payroll_payments;
drop policy if exists "owners insert payroll" on public.payroll_payments;
drop policy if exists "owners update payroll" on public.payroll_payments;
drop policy if exists "owners delete payroll" on public.payroll_payments;
create policy "owners select payroll"
on public.payroll_payments for select to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners insert payroll"
on public.payroll_payments for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners update payroll"
on public.payroll_payments for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners delete payroll"
on public.payroll_payments for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "cash read own shop" on public.cash_transactions;
drop policy if exists "members insert cash" on public.cash_transactions;
drop policy if exists "owner update cash" on public.cash_transactions;
drop policy if exists "owner delete cash" on public.cash_transactions;
drop policy if exists "owners manage cash transactions" on public.cash_transactions;
create policy "owners manage cash transactions"
on public.cash_transactions for all to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "payments read own shop" on public.payments;
drop policy if exists "members insert payments" on public.payments;
drop policy if exists "members read payments" on public.payments;
create policy "members read payments"
on public.payments for select to authenticated
using (shop_id = public.current_shop_id());

drop policy if exists "requests read own shop" on public.employee_requests;
drop policy if exists "members insert requests" on public.employee_requests;
drop policy if exists "owners read shop requests employees read own" on public.employee_requests;
drop policy if exists "employees insert own requests" on public.employee_requests;
drop policy if exists "owners update requests" on public.employee_requests;
create policy "owners read shop requests employees read own"
on public.employee_requests for select to authenticated
using (
  shop_id = public.current_shop_id()
  and (public.current_role() = 'OWNER' or employee_id = public.current_employee_id())
);
create policy "employees insert own requests"
on public.employee_requests for insert to authenticated
with check (
  shop_id = public.current_shop_id()
  and employee_id = public.current_employee_id()
  and public.current_role() = 'EMPLOYEE'
  and status = 'pending'
);
create policy "owners update requests"
on public.employee_requests for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "attendance read own shop" on public.attendance_records;
drop policy if exists "members insert attendance" on public.attendance_records;
drop policy if exists "owners read shop attendance employees read own" on public.attendance_records;
drop policy if exists "employees insert own attendance" on public.attendance_records;
create policy "owners read shop attendance employees read own"
on public.attendance_records for select to authenticated
using (
  shop_id = public.current_shop_id()
  and (public.current_role() = 'OWNER' or employee_id = public.current_employee_id())
);
create policy "employees insert own attendance"
on public.attendance_records for insert to authenticated
with check (
  shop_id = public.current_shop_id()
  and employee_id = public.current_employee_id()
  and public.current_role() = 'EMPLOYEE'
);

drop policy if exists "members read relevant weekly shifts" on public.weekly_shifts;
drop policy if exists "owners manage weekly shifts" on public.weekly_shifts;
drop policy if exists "owners insert weekly shifts" on public.weekly_shifts;
drop policy if exists "owners update weekly shifts" on public.weekly_shifts;
drop policy if exists "owners delete weekly shifts" on public.weekly_shifts;
create policy "members read relevant weekly shifts"
on public.weekly_shifts for select to authenticated
using (
  shop_id = public.current_shop_id()
  and (public.current_role() = 'OWNER' or employee_id = public.current_employee_id())
);
create policy "owners insert weekly shifts"
on public.weekly_shifts for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners update weekly shifts"
on public.weekly_shifts for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners delete weekly shifts"
on public.weekly_shifts for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "inventory items read own shop" on public.inventory_items;
drop policy if exists "owners manage inventory items" on public.inventory_items;
drop policy if exists "owners insert inventory items" on public.inventory_items;
drop policy if exists "owners update inventory items" on public.inventory_items;
drop policy if exists "owners delete inventory items" on public.inventory_items;
create policy "inventory items read own shop"
on public.inventory_items for select to authenticated
using (shop_id = public.current_shop_id());
create policy "owners insert inventory items"
on public.inventory_items for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners update inventory items"
on public.inventory_items for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners delete inventory items"
on public.inventory_items for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "inventory movements read own shop" on public.inventory_movements;
drop policy if exists "members insert inventory movements" on public.inventory_movements;
create policy "inventory movements read own shop"
on public.inventory_movements for select to authenticated
using (shop_id = public.current_shop_id());

drop policy if exists "notifications read own shop" on public.notifications;
drop policy if exists "members update notifications" on public.notifications;
drop policy if exists "members read targeted notifications" on public.notifications;
drop policy if exists "members update targeted notifications" on public.notifications;
drop policy if exists "members delete targeted notifications" on public.notifications;
create policy "members read targeted notifications"
on public.notifications for select to authenticated
using (
  shop_id = public.current_shop_id()
  and (target_profile_id is null or target_profile_id = (select auth.uid()))
);
create policy "members update targeted notifications"
on public.notifications for update to authenticated
using (
  shop_id = public.current_shop_id()
  and (target_profile_id is null or target_profile_id = (select auth.uid()))
)
with check (
  shop_id = public.current_shop_id()
  and (target_profile_id is null or target_profile_id = (select auth.uid()))
);
create policy "members delete targeted notifications"
on public.notifications for delete to authenticated
using (
  shop_id = public.current_shop_id()
  and (target_profile_id is null or target_profile_id = (select auth.uid()))
);

-- Move the previously loose employee-profile policy into migration history.
drop policy if exists "owners insert employee profiles" on public.profiles;
create policy "owners insert employee profiles"
on public.profiles for insert to authenticated
with check (
  shop_id = public.current_shop_id()
  and public.current_role() = 'OWNER'
  and role = 'EMPLOYEE'
);

-- Normalize the remaining core policies from the baseline migrations. Older
-- definitions targeted PUBLIC implicitly and several FOR ALL policies
-- overlapped their SELECT policies.
revoke all on table public.shops from anon, authenticated;
revoke all on table public.profiles from anon, authenticated;
revoke all on table public.employees from anon, authenticated;
revoke all on table public.service_categories from anon, authenticated;
revoke all on table public.services from anon, authenticated;
revoke all on table public.customers from anon, authenticated;
revoke all on table public.orders from anon, authenticated;
revoke all on table public.order_items from anon, authenticated;
revoke all on table public.cashbook_entries from anon, authenticated;
revoke all on table public.shop_settings from anon, authenticated;
revoke all on table public.cash_closings from anon, authenticated;
revoke all on table public.audit_logs from anon, authenticated;

alter table public.shops enable row level security;
alter table public.profiles enable row level security;
alter table public.employees enable row level security;
alter table public.service_categories enable row level security;
alter table public.services enable row level security;
alter table public.customers enable row level security;
alter table public.orders enable row level security;
alter table public.order_items enable row level security;
alter table public.cashbook_entries enable row level security;
alter table public.shop_settings enable row level security;
alter table public.cash_closings enable row level security;
alter table public.audit_logs enable row level security;

grant select, update on table public.shops to authenticated;
grant select, insert, update on table public.profiles to authenticated;
grant select (
  id, shop_id, name, phone, position, role, shift_start, shift_end,
  late_tolerance_minutes, weekly_salary, is_active, created_at, updated_at
) on table public.employees to authenticated;
grant insert (
  id, shop_id, name, phone, position, role, shift_start, shift_end,
  late_tolerance_minutes, weekly_salary, is_active
) on table public.employees to authenticated;
grant update (
  name, phone, position, role, shift_start, shift_end,
  late_tolerance_minutes, weekly_salary, is_active, updated_at
) on table public.employees to authenticated;
grant delete on table public.employees to authenticated;
grant select, insert, update, delete on table public.service_categories to authenticated;
grant select, insert, update, delete on table public.services to authenticated;
grant select, insert, update on table public.customers to authenticated;
grant select, insert, update, delete on table public.orders to authenticated;
grant select, insert, update, delete on table public.order_items to authenticated;
-- cash_transactions is the only application-facing cash ledger. Keep the
-- historical cashbook_entries table intact for data recovery, but do not
-- expose it to anon/authenticated clients or create new rows in it.
grant select, insert, update, delete on table public.shop_settings to authenticated;
grant select, insert, update, delete on table public.cash_closings to authenticated;
grant select on table public.audit_logs to authenticated;

drop policy if exists "shop members read own shop" on public.shops;
drop policy if exists "owners update own shop" on public.shops;
create policy "shop members read own shop"
on public.shops for select to authenticated
using (id = public.current_shop_id());
create policy "owners update own shop"
on public.shops for update to authenticated
using (id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "profiles read own shop" on public.profiles;
drop policy if exists "profiles update self" on public.profiles;
drop policy if exists "profiles update self or owner manages shop" on public.profiles;
create policy "profiles read own shop"
on public.profiles for select to authenticated
using (id = (select auth.uid()) or shop_id = public.current_shop_id());
create policy "profiles update self or owner manages shop"
on public.profiles for update to authenticated
using (
  id = (select auth.uid())
  or (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
)
with check (
  shop_id = public.current_shop_id()
  and (
    public.current_role() = 'OWNER'
    or (
      id = (select auth.uid())
      and role = public.current_role()
      and employee_id is not distinct from public.current_employee_id()
    )
  )
);

drop policy if exists "employees read own shop" on public.employees;
drop policy if exists "owners manage employees" on public.employees;
drop policy if exists "owners insert employees" on public.employees;
drop policy if exists "owners update employees" on public.employees;
drop policy if exists "owners delete employees" on public.employees;
create policy "employees read own shop"
on public.employees for select to authenticated
using (shop_id = public.current_shop_id());
create policy "owners insert employees"
on public.employees for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners update employees"
on public.employees for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners delete employees"
on public.employees for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "service categories read own shop" on public.service_categories;
drop policy if exists "owners manage service categories" on public.service_categories;
drop policy if exists "owners insert service categories" on public.service_categories;
drop policy if exists "owners update service categories" on public.service_categories;
drop policy if exists "owners delete service categories" on public.service_categories;
create policy "service categories read own shop"
on public.service_categories for select to authenticated
using (shop_id = public.current_shop_id());
create policy "owners insert service categories"
on public.service_categories for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners update service categories"
on public.service_categories for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners delete service categories"
on public.service_categories for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "services read own shop" on public.services;
drop policy if exists "owners manage services" on public.services;
drop policy if exists "owners insert services" on public.services;
drop policy if exists "owners update services" on public.services;
drop policy if exists "owners delete services" on public.services;
create policy "services read own shop"
on public.services for select to authenticated
using (shop_id = public.current_shop_id());
create policy "owners insert services"
on public.services for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners update services"
on public.services for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners delete services"
on public.services for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "customers read own shop" on public.customers;
drop policy if exists "members insert customers" on public.customers;
drop policy if exists "owners update customers" on public.customers;
create policy "customers read own shop"
on public.customers for select to authenticated
using (shop_id = public.current_shop_id());
create policy "members insert customers"
on public.customers for insert to authenticated
with check (shop_id = public.current_shop_id());
create policy "owners update customers"
on public.customers for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "orders read own shop" on public.orders;
drop policy if exists "members insert orders" on public.orders;
drop policy if exists "members update orders" on public.orders;
drop policy if exists "owners delete orders" on public.orders;
create policy "orders read own shop"
on public.orders for select to authenticated
using (shop_id = public.current_shop_id());
create policy "members insert orders"
on public.orders for insert to authenticated
with check (shop_id = public.current_shop_id());
create policy "members update orders"
on public.orders for update to authenticated
using (shop_id = public.current_shop_id())
with check (shop_id = public.current_shop_id());
create policy "owners delete orders"
on public.orders for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "order items read own shop" on public.order_items;
drop policy if exists "members insert order items" on public.order_items;
drop policy if exists "members update order items" on public.order_items;
drop policy if exists "owners delete order items" on public.order_items;
create policy "order items read own shop"
on public.order_items for select to authenticated
using (shop_id = public.current_shop_id());
create policy "members insert order items"
on public.order_items for insert to authenticated
with check (shop_id = public.current_shop_id());
create policy "members update order items"
on public.order_items for update to authenticated
using (shop_id = public.current_shop_id())
with check (shop_id = public.current_shop_id());
create policy "owners delete order items"
on public.order_items for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "cashbook entries read own shop" on public.cashbook_entries;
drop policy if exists "members insert cashbook entries" on public.cashbook_entries;
drop policy if exists "owners update cashbook entries" on public.cashbook_entries;

drop policy if exists "settings read own shop" on public.shop_settings;
drop policy if exists "owners manage settings" on public.shop_settings;
drop policy if exists "owners insert settings" on public.shop_settings;
drop policy if exists "owners update settings" on public.shop_settings;
drop policy if exists "owners delete settings" on public.shop_settings;
create policy "settings read own shop"
on public.shop_settings for select to authenticated
using (shop_id = public.current_shop_id());
create policy "owners insert settings"
on public.shop_settings for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners update settings"
on public.shop_settings for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy "owners delete settings"
on public.shop_settings for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "owners manage cash closings" on public.cash_closings;
create policy "owners manage cash closings"
on public.cash_closings for all to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "owners read audit logs" on public.audit_logs;
create policy "owners read audit logs"
on public.audit_logs for select to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

-- ---------------------------------------------------------------------------
-- Storage: private attendance photos, scoped by shop and employee folder.
-- Re-assert these objects here because production migration history was empty.
-- ---------------------------------------------------------------------------

insert into storage.buckets (id, name, public)
values ('attendance-photos', 'attendance-photos', false)
on conflict (id) do update set public = false;

drop policy if exists "members upload attendance photos" on storage.objects;
drop policy if exists "members read attendance photos" on storage.objects;
drop policy if exists "members delete attendance photos" on storage.objects;

create policy "members upload attendance photos"
on storage.objects for insert to authenticated
with check (
  bucket_id = 'attendance-photos'
  and (storage.foldername(name))[1] = public.current_shop_id()::text
  and (
    public.current_role() = 'OWNER'
    or (storage.foldername(name))[2] = public.current_employee_id()::text
  )
);

create policy "members read attendance photos"
on storage.objects for select to authenticated
using (
  bucket_id = 'attendance-photos'
  and (storage.foldername(name))[1] = public.current_shop_id()::text
  and (
    public.current_role() = 'OWNER'
    or (storage.foldername(name))[2] = public.current_employee_id()::text
  )
);

create policy "members delete attendance photos"
on storage.objects for delete to authenticated
using (
  bucket_id = 'attendance-photos'
  and (storage.foldername(name))[1] = public.current_shop_id()::text
  and (
    public.current_role() = 'OWNER'
    or (storage.foldername(name))[2] = public.current_employee_id()::text
  )
);

-- ---------------------------------------------------------------------------
-- Realtime: only add relations that the Flutter client actually subscribes to.
-- Do not modify objects inside the locked-down realtime schema.
-- ---------------------------------------------------------------------------

do $$
declare
  v_table text;
begin
  if not exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) then
    execute 'create publication supabase_realtime';
  end if;

  foreach v_table in array array[
    'cash_transactions',
    'customers',
    'employee_requests',
    'expenses',
    'inventory_items',
    'inventory_movements',
    'notifications',
    'orders',
    'payroll_payments',
    'weekly_shifts'
  ]
  loop
    if to_regclass(format('public.%I', v_table)) is not null
       and not exists (
         select 1
         from pg_publication_tables
         where pubname = 'supabase_realtime'
           and schemaname = 'public'
           and tablename = v_table
       ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        v_table
      );
    end if;
  end loop;
end
$$;

notify pgrst, 'reload schema';

commit;
