-- Large laundry jobs are tracked by project and daily batches. Revenue enters
-- the cash ledger only when a project payment is recorded.
create table public.laundry_projects (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  customer_id uuid not null references public.customers(id),
  title text not null check (length(btrim(title)) > 0),
  target_pieces integer not null check (target_pieces > 0),
  pricing_unit text not null check (pricing_unit in ('KG', 'PIECE')),
  unit_price integer not null check (unit_price >= 0),
  status text not null default 'active' check (status in ('active', 'completed', 'cancelled')),
  note text not null default '',
  due_at timestamptz,
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table public.laundry_project_batches (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  project_id uuid not null references public.laundry_projects(id) on delete restrict,
  pieces integer not null check (pieces > 0),
  weight_kg numeric(10,2) not null check (weight_kg > 0),
  employee_id uuid references public.employees(id),
  note text not null default '',
  processed_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create table public.laundry_project_payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  project_id uuid not null references public.laundry_projects(id) on delete restrict,
  amount integer not null check (amount > 0),
  method text not null check (length(btrim(method)) > 0),
  created_by uuid references auth.users(id) default auth.uid(),
  created_at timestamptz not null default now()
);

create index laundry_projects_shop_idx on public.laundry_projects(shop_id, created_at desc);
create index laundry_project_batches_project_idx on public.laundry_project_batches(project_id, processed_at desc);
create index laundry_project_payments_project_idx on public.laundry_project_payments(project_id, created_at desc);
create unique index cash_project_payment_source_idx
on public.cash_transactions(shop_id, reference_type, reference_id)
where reference_type = 'PROJECT_PAYMENT' and reference_id is not null;

create or replace function public.validate_project_child()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
begin
  if not exists (
    select 1 from public.laundry_projects p
    where p.id = new.project_id and p.shop_id = new.shop_id and p.status <> 'cancelled'
  ) then
    raise exception 'Proyek tidak ditemukan atau sudah dibatalkan.';
  end if;
  return new;
end;
$$;
create trigger validate_project_batch before insert or update on public.laundry_project_batches
for each row execute function public.validate_project_child();
create trigger validate_project_payment before insert or update on public.laundry_project_payments
for each row execute function public.validate_project_child();

create or replace function public.sync_project_payment_cash()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if tg_op = 'DELETE' then
    delete from public.cash_transactions
    where shop_id = old.shop_id and reference_type = 'PROJECT_PAYMENT' and reference_id = old.id;
    return old;
  end if;
  insert into public.cash_transactions (
    shop_id, type, category, description, amount, method, reference_type, reference_id, created_at
  ) values (
    new.shop_id, 'IN', 'Pembayaran Proyek',
    'Pembayaran proyek ' || (select title from public.laundry_projects where id = new.project_id),
    new.amount, new.method, 'PROJECT_PAYMENT', new.id, new.created_at
  ) on conflict do nothing;
  update public.cash_transactions set amount = new.amount, method = new.method,
    created_at = new.created_at
  where shop_id = new.shop_id and reference_type = 'PROJECT_PAYMENT' and reference_id = new.id;
  return new;
end;
$$;
create trigger sync_project_payment_cash after insert or update or delete
on public.laundry_project_payments for each row execute function public.sync_project_payment_cash();

alter table public.laundry_projects enable row level security;
alter table public.laundry_project_batches enable row level security;
alter table public.laundry_project_payments enable row level security;
grant select, insert, update, delete on public.laundry_projects,
  public.laundry_project_batches, public.laundry_project_payments to authenticated;

create policy projects_read on public.laundry_projects for select to authenticated
using (shop_id = public.current_shop_id());
create policy projects_insert on public.laundry_projects for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER'
  and created_by = (select auth.uid())
  and exists (select 1 from public.customers c where c.id = customer_id and c.shop_id = shop_id));
create policy projects_update on public.laundry_projects for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy batches_read on public.laundry_project_batches for select to authenticated
using (shop_id = public.current_shop_id());
create policy batches_insert on public.laundry_project_batches for insert to authenticated
with check (shop_id = public.current_shop_id()
  and (employee_id is null or exists (
    select 1 from public.employees e where e.id = employee_id and e.shop_id = shop_id)));
create policy batches_update on public.laundry_project_batches for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy batches_delete on public.laundry_project_batches for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
create policy project_payments_read on public.laundry_project_payments for select to authenticated
using (shop_id = public.current_shop_id());
create policy project_payments_insert on public.laundry_project_payments for insert to authenticated
with check (shop_id = public.current_shop_id() and created_by = (select auth.uid()));
create policy project_payments_update on public.laundry_project_payments for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

-- Incentives are selected per order item. Earned and paid are separate events.
alter table public.order_items
  add column incentive_rate integer not null default 0 check (incentive_rate in (0, 10000, 15000, 20000)),
  add column incentive_employee_id uuid references public.employees(id);

create table public.order_item_incentives (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id),
  order_id uuid not null references public.orders(id),
  order_item_id uuid not null unique references public.order_items(id),
  employee_id uuid not null references public.employees(id),
  item_kind text not null check (item_kind in ('sepatu', 'helm', 'tas')),
  quantity integer not null check (quantity > 0),
  rate integer not null check (rate in (10000, 15000, 20000)),
  amount integer generated always as (quantity * rate) stored,
  earned_at timestamptz not null default now(),
  paid_at timestamptz,
  paid_method text,
  expense_id uuid unique references public.expenses(id),
  created_at timestamptz not null default now(),
  check ((paid_at is null and paid_method is null and expense_id is null)
    or (paid_at is not null and paid_method is not null and expense_id is not null))
);
create index order_item_incentives_shop_idx on public.order_item_incentives(shop_id, earned_at desc);
alter table public.order_item_incentives enable row level security;
grant select on public.order_item_incentives to authenticated;
create policy incentives_read on public.order_item_incentives for select to authenticated
using (shop_id = public.current_shop_id());

create or replace function public.configure_order_item_incentives(
  p_order_id uuid, p_choices jsonb
) returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_choice jsonb;
  v_item public.order_items%rowtype;
  v_rate integer;
  v_employee_id uuid;
begin
  if (select auth.uid()) is null or v_shop_id is null then
    raise exception using errcode = '42501', message = 'Sesi pengguna tidak valid.';
  end if;
  if not exists (select 1 from public.orders
      where id = p_order_id and shop_id = v_shop_id and deleted_at is null
        and order_status in ('received', 'processing')) then
    raise exception 'Insentif hanya dapat diatur sebelum pesanan selesai.';
  end if;
  if p_choices is null or jsonb_typeof(p_choices) <> 'array' then
    raise exception 'Pilihan insentif tidak valid.';
  end if;
  for v_choice in select * from jsonb_array_elements(p_choices) loop
    select * into v_item from public.order_items
    where id = (v_choice ->> 'order_item_id')::uuid
      and order_id = p_order_id and shop_id = v_shop_id;
    if not found then raise exception 'Item pesanan tidak ditemukan.'; end if;
    v_rate := (v_choice ->> 'rate')::integer;
    v_employee_id := nullif(v_choice ->> 'employee_id', '')::uuid;
    if v_rate not in (0, 10000, 15000, 20000) then
      raise exception 'Nominal insentif tidak valid.';
    end if;
    if v_rate > 0 and (
      public.incentive_item_kind(v_item.service_name_snapshot) is null
      or upper(v_item.unit) not in ('PAIR', 'PIECE', 'ITEM')
      or v_item.quantity <> trunc(v_item.quantity)
      or v_employee_id is null
      or not exists (select 1 from public.employees
        where id = v_employee_id and shop_id = v_shop_id and is_active)
    ) then
      raise exception 'Insentif hanya untuk sepatu, helm, atau tas dengan karyawan aktif.';
    end if;
    update public.order_items set incentive_rate = v_rate,
      incentive_employee_id = case when v_rate > 0 then v_employee_id else null end
    where id = v_item.id;
  end loop;
end;
$$;
revoke all on function public.configure_order_item_incentives(uuid, jsonb) from public, anon;
grant execute on function public.configure_order_item_incentives(uuid, jsonb) to authenticated;

create or replace function public.incentive_item_kind(p_name text)
returns text language sql immutable set search_path = pg_catalog as $$
  select case when lower(p_name) like '%sepatu%' then 'sepatu'
    when lower(p_name) like '%helm%' then 'helm'
    when lower(p_name) like '%tas%' then 'tas'
    else null end;
$$;
revoke all on function public.incentive_item_kind(text) from public, anon;
grant execute on function public.incentive_item_kind(text) to authenticated;

create or replace function public.sync_order_status_financials()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
begin
  if new.deleted_at is distinct from old.deleted_at
     and public.current_role() is distinct from 'OWNER' then
    raise exception using errcode = '42501', message = 'Hanya Owner yang dapat menghapus atau memulihkan pesanan.';
  end if;

  if new.order_status = 'ready' and old.order_status is distinct from 'ready' then
    insert into public.order_item_incentives (
      shop_id, order_id, order_item_id, employee_id, item_kind, quantity, rate
    )
    select new.shop_id, new.id, item.id,
      coalesce(item.incentive_employee_id, new.assigned_employee_id),
      public.incentive_item_kind(item.service_name_snapshot), item.quantity::integer,
      item.incentive_rate
    from public.order_items item
    where item.order_id = new.id and item.incentive_rate > 0
      and item.quantity = trunc(item.quantity)
      and public.incentive_item_kind(item.service_name_snapshot) is not null
      and coalesce(item.incentive_employee_id, new.assigned_employee_id) is not null
    on conflict (order_item_id) do nothing;
  end if;

  if new.deleted_at is not null and old.deleted_at is null then
    -- Paid incentives remain in the cash history. Unpaid accruals can be removed.
    delete from public.order_item_incentives
    where order_id = new.id and paid_at is null;
    delete from public.cash_transactions
    where shop_id = new.shop_id and reference_type = 'ORDER' and reference_id = new.id;
    delete from public.payments where shop_id = new.shop_id and order_id = new.id;
  end if;
  return new;
end;
$$;
revoke all on function public.sync_order_status_financials() from public, anon;

create or replace function public.pay_order_item_incentive(
  p_incentive_id uuid, p_method text default 'Tunai'
) returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_incentive public.order_item_incentives%rowtype;
  v_expense_id uuid;
begin
  if (select auth.uid()) is null or public.current_role() <> 'OWNER' then
    raise exception using errcode = '42501', message = 'Hanya Owner yang dapat membayar insentif.';
  end if;
  if btrim(coalesce(p_method, '')) = '' then raise exception 'Metode pembayaran wajib dipilih.'; end if;
  select * into v_incentive from public.order_item_incentives
  where id = p_incentive_id and shop_id = public.current_shop_id() for update;
  if not found then raise exception 'Insentif tidak ditemukan.'; end if;
  if v_incentive.paid_at is not null then raise exception 'Insentif sudah dibayar.'; end if;
  insert into public.expenses (
    shop_id, description, category, amount, method, created_by, source_type, source_id
  ) values (
    v_incentive.shop_id,
    'Insentif ' || v_incentive.item_kind || ' nota ' ||
      (select order_number from public.orders where id = v_incentive.order_id),
    'Insentif Karyawan', v_incentive.amount, p_method, null,
    'ORDER_ITEM_INCENTIVE', v_incentive.id
  ) returning id into v_expense_id;
  update public.order_item_incentives
  set paid_at = now(), paid_method = p_method, expense_id = v_expense_id
  where id = v_incentive.id;
end;
$$;
revoke all on function public.pay_order_item_incentive(uuid, text) from public, anon;
grant execute on function public.pay_order_item_incentive(uuid, text) to authenticated;

-- Owner can inspect corrections from both clients without changing the audit trail.
create trigger audit_laundry_projects after insert or update or delete
on public.laundry_projects for each row execute function public.write_audit_log();
create trigger audit_laundry_project_batches after insert or update or delete
on public.laundry_project_batches for each row execute function public.write_audit_log();
create trigger audit_laundry_project_payments after insert or update or delete
on public.laundry_project_payments for each row execute function public.write_audit_log();
create trigger audit_order_item_incentives after insert or update or delete
on public.order_item_incentives for each row execute function public.write_audit_log();
create trigger audit_services after insert or update or delete
on public.services for each row execute function public.write_audit_log();
create trigger audit_order_items after insert or update or delete
on public.order_items for each row execute function public.write_audit_log();

-- Keep the new tables visible to the same-shop realtime clients.
do $$ begin
  alter publication supabase_realtime add table public.laundry_projects,
    public.laundry_project_batches, public.laundry_project_payments,
    public.order_item_incentives;
exception when duplicate_object then null;
end $$;

-- Keep order creation and the item incentive choice in one transaction.
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
  v_service_id uuid;
  v_received_by_employee_id uuid := public.current_employee_id();
  v_received_by_name text;
begin
  if (select auth.uid()) is null or v_shop_id is null then
    raise exception using errcode = '42501', message = 'Sesi pengguna tidak valid.';
  end if;

  select coalesce(nullif(btrim(profile.full_name), ''), employee.name, 'Pengguna')
  into v_received_by_name
  from public.profiles as profile
  left join public.employees as employee on employee.id = profile.employee_id
  where profile.id = (select auth.uid())
  limit 1;

  v_received_by_name := coalesce(v_received_by_name, 'Pengguna');

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

  if exists (
    select 1
    from jsonb_array_elements(p_items) as item
    where nullif(btrim(coalesce(item ->> 'service_id', '')), '') is not null
      and not exists (
        select 1
        from public.services as service
        where service.id = (item ->> 'service_id')::uuid
          and service.shop_id = v_shop_id
          and service.is_active
      )
  ) then
    raise exception 'Layanan pesanan tidak valid atau belum sinkron.';
  end if;

  if exists (
    select 1 from jsonb_array_elements(p_items) as item
    where coalesce((item ->> 'incentive_rate')::integer, 0)
        not in (0, 10000, 15000, 20000)
      or (coalesce((item ->> 'incentive_rate')::integer, 0) > 0 and (
        public.incentive_item_kind(item ->> 'service_name') is null
        or upper(coalesce(item ->> 'unit', '')) not in ('PAIR', 'PIECE', 'ITEM')
        or (item ->> 'quantity')::numeric <> trunc((item ->> 'quantity')::numeric)
        or nullif(item ->> 'incentive_employee_id', '') is null
        or not exists (
          select 1 from public.employees e
          where e.id = (item ->> 'incentive_employee_id')::uuid
            and e.shop_id = v_shop_id and e.is_active
        )
      ))
  ) then
    raise exception 'Insentif hanya untuk sepatu, helm, atau tas dengan karyawan aktif.';
  end if;

  select coalesce(sum((item ->> 'subtotal')::integer), 0)
  into v_total
  from jsonb_array_elements(p_items) as item;

  v_total := public.round_order_total(v_total);

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
    customer_phone_snapshot, assigned_employee_id, received_by_employee_id,
    received_by_name_snapshot, order_status, payment_status, total_price,
    paid_amount, note, due_at
  ) values (
    v_order_id,
    v_shop_id,
    v_order_number,
    v_customer.id,
    coalesce(nullif(btrim(v_customer.name), ''), 'Pelanggan'),
    coalesce(nullif(btrim(v_customer.phone), ''), ''),
    p_assigned_employee_id,
    v_received_by_employee_id,
    v_received_by_name,
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
    v_service_id := nullif(btrim(coalesce(v_item ->> 'service_id', '')), '')::uuid;

    insert into public.order_items (
      shop_id, order_id, service_id, service_name_snapshot,
      category_snapshot, unit, quantity, unit_price, subtotal,
      incentive_rate, incentive_employee_id
    ) values (
      v_shop_id,
      v_order_id,
      v_service_id,
      coalesce(nullif(btrim(v_item ->> 'service_name'), ''), 'Layanan'),
      coalesce(v_item ->> 'category', ''),
      upper(coalesce(nullif(btrim(v_item ->> 'unit'), ''), 'PCS')),
      (v_item ->> 'quantity')::numeric,
      (v_item ->> 'unit_price')::integer,
      (v_item ->> 'subtotal')::integer,
      coalesce((v_item ->> 'incentive_rate')::integer, 0),
      nullif(v_item ->> 'incentive_employee_id', '')::uuid
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
