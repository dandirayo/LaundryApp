-- Production operations: weekly schedules, cash closing, audit trail,
-- targeted notifications, and atomic inventory movements.
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

create table if not exists public.cash_closings (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  business_date date not null,
  opening_balance integer not null default 0,
  cash_income integer not null default 0,
  cash_expense integer not null default 0,
  expected_balance integer not null default 0,
  actual_balance integer not null default 0,
  difference integer not null default 0,
  note text not null default '',
  closed_by uuid references public.profiles(id) on delete set null,
  closed_at timestamptz not null default now(),
  unique (shop_id, business_date)
);

create table if not exists public.audit_logs (
  id bigint generated always as identity primary key,
  shop_id uuid not null references public.shops(id) on delete cascade,
  actor_id uuid,
  actor_role text not null default '',
  action text not null,
  entity_table text not null,
  entity_id text not null default '',
  summary text not null default '',
  old_data jsonb,
  new_data jsonb,
  created_at timestamptz not null default now()
);

alter table public.notifications
  add column if not exists target_profile_id uuid references public.profiles(id) on delete cascade,
  add column if not exists updated_at timestamptz not null default now();

create index if not exists idx_weekly_shifts_employee_day
  on public.weekly_shifts(employee_id, day_of_week);
create index if not exists idx_cash_closings_shop_date
  on public.cash_closings(shop_id, business_date desc);
create index if not exists idx_audit_logs_shop_created
  on public.audit_logs(shop_id, created_at desc);
create index if not exists idx_notifications_target_created
  on public.notifications(target_profile_id, created_at desc);

drop trigger if exists weekly_shifts_touch_updated_at on public.weekly_shifts;
create trigger weekly_shifts_touch_updated_at
before update on public.weekly_shifts
for each row execute function public.touch_updated_at();

alter table public.weekly_shifts enable row level security;
alter table public.cash_closings enable row level security;
alter table public.audit_logs enable row level security;

drop policy if exists "members read relevant weekly shifts" on public.weekly_shifts;
create policy "members read relevant weekly shifts"
on public.weekly_shifts for select
using (
  shop_id = public.current_shop_id()
  and (
    public.current_role() = 'OWNER'
    or employee_id = public.current_employee_id()
  )
);

drop policy if exists "owners manage weekly shifts" on public.weekly_shifts;
create policy "owners manage weekly shifts"
on public.weekly_shifts for all
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "owners manage cash closings" on public.cash_closings;
create policy "owners manage cash closings"
on public.cash_closings for all
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "owners read audit logs" on public.audit_logs;
create policy "owners read audit logs"
on public.audit_logs for select
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

drop policy if exists "notifications read own shop" on public.notifications;
drop policy if exists "members update notifications" on public.notifications;
create policy "members read targeted notifications"
on public.notifications for select
using (
  shop_id = public.current_shop_id()
  and (target_profile_id is null or target_profile_id = auth.uid())
);
create policy "members update targeted notifications"
on public.notifications for update
using (
  shop_id = public.current_shop_id()
  and (target_profile_id is null or target_profile_id = auth.uid())
)
with check (
  shop_id = public.current_shop_id()
  and (target_profile_id is null or target_profile_id = auth.uid())
);

create or replace function public.adjust_inventory_stock(
  p_item_id uuid,
  p_quantity numeric,
  p_type text,
  p_note text default ''
)
returns numeric
language plpgsql
security definer
set search_path = public
as $$
declare
  v_item public.inventory_items%rowtype;
  v_new_stock numeric;
begin
  if public.current_role() <> 'OWNER' then
    raise exception 'Hanya Owner yang dapat mengubah stok.';
  end if;
  if p_quantity <= 0 or p_type not in ('IN', 'OUT', 'ADJUSTMENT') then
    raise exception 'Perubahan stok tidak valid.';
  end if;

  select * into v_item
  from public.inventory_items
  where id = p_item_id and shop_id = public.current_shop_id()
  for update;

  if not found then raise exception 'Item stok tidak ditemukan.'; end if;
  v_new_stock := case
    when p_type = 'IN' then v_item.stock + p_quantity
    when p_type = 'OUT' then v_item.stock - p_quantity
    else p_quantity
  end;
  if v_new_stock < 0 then raise exception 'Stok tidak mencukupi.'; end if;

  update public.inventory_items
  set stock = v_new_stock, updated_at = now()
  where id = p_item_id;

  insert into public.inventory_movements (
    shop_id, item_id, item_name, type, quantity, note, created_by
  ) values (
    v_item.shop_id, v_item.id, v_item.name, p_type, p_quantity,
    coalesce(p_note, ''), public.current_employee_id()
  );
  return v_new_stock;
end;
$$;

grant execute on function public.adjust_inventory_stock(uuid, numeric, text, text)
  to authenticated;

create or replace function public.record_order_payment(
  p_order_id uuid,
  p_amount integer,
  p_method text default 'Tunai'
)
returns integer
language plpgsql
security definer
set search_path = public
as $$
declare
  v_order public.orders%rowtype;
  v_new_paid integer;
begin
  if p_amount <= 0 then raise exception 'Nominal pembayaran harus lebih dari nol.'; end if;
  select * into v_order
  from public.orders
  where id = p_order_id and shop_id = public.current_shop_id()
  for update;
  if not found then raise exception 'Pesanan tidak ditemukan.'; end if;

  if v_order.paid_amount >= v_order.total_price then
    raise exception 'Pesanan sudah lunas.';
  end if;

  v_new_paid := least(v_order.total_price, v_order.paid_amount + p_amount);
  insert into public.payments (shop_id, order_id, amount, method, created_by)
  values (v_order.shop_id, v_order.id, v_new_paid - v_order.paid_amount, p_method, public.current_employee_id());
  insert into public.cash_transactions (
    shop_id, type, category, description, amount, method,
    reference_type, reference_id
  ) values (
    v_order.shop_id, 'IN', 'Pembayaran',
    'Pembayaran ' || v_order.order_number,
    v_new_paid - v_order.paid_amount, p_method, 'ORDER', v_order.id
  );
  update public.orders
  set paid_amount = v_new_paid,
      payment_status = case when v_new_paid >= total_price then 'paid' else 'partial' end,
      updated_at = now()
  where id = v_order.id;
  return v_new_paid;
end;
$$;

grant execute on function public.record_order_payment(uuid, integer, text)
  to authenticated;

create or replace function public.write_audit_log()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_old jsonb := case when tg_op = 'INSERT' then null else to_jsonb(old) end;
  v_new jsonb := case when tg_op = 'DELETE' then null else to_jsonb(new) end;
  v_shop_id uuid := coalesce((v_new ->> 'shop_id')::uuid, (v_old ->> 'shop_id')::uuid);
  v_entity_id text := coalesce(v_new ->> 'id', v_old ->> 'id', '');
begin
  insert into public.audit_logs (
    shop_id, actor_id, actor_role, action, entity_table,
    entity_id, summary, old_data, new_data
  ) values (
    v_shop_id, auth.uid(), coalesce(public.current_role(), ''), tg_op,
    tg_table_name, v_entity_id, tg_op || ' ' || tg_table_name, v_old, v_new
  );
  if tg_op = 'DELETE' then
    return old;
  end if;
  return new;
end;
$$;

drop trigger if exists audit_employees on public.employees;
create trigger audit_employees after insert or update or delete on public.employees
for each row execute function public.write_audit_log();
drop trigger if exists audit_orders on public.orders;
create trigger audit_orders after insert or update or delete on public.orders
for each row execute function public.write_audit_log();
drop trigger if exists audit_employee_requests on public.employee_requests;
create trigger audit_employee_requests after insert or update or delete on public.employee_requests
for each row execute function public.write_audit_log();
drop trigger if exists audit_inventory_items on public.inventory_items;
create trigger audit_inventory_items after insert or update or delete on public.inventory_items
for each row execute function public.write_audit_log();
drop trigger if exists audit_weekly_shifts on public.weekly_shifts;
create trigger audit_weekly_shifts after insert or update or delete on public.weekly_shifts
for each row execute function public.write_audit_log();

create or replace function public.notify_request_workflow()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_target uuid;
begin
  if tg_op = 'INSERT' then
    insert into public.notifications (
      shop_id, target_profile_id, title, message, type, action_route
    )
    select
      new.shop_id, p.id, 'Request baru dari ' || new.employee_name,
      new.type || ': ' || new.reason, 'REQUEST', '/requests/review'
    from public.profiles p
    where p.shop_id = new.shop_id and p.role = 'OWNER' and p.is_active;
  elsif old.status is distinct from new.status then
    select id into v_target from public.profiles
    where employee_id = new.employee_id and is_active
    limit 1;
    if v_target is not null then
      insert into public.notifications (
        shop_id, target_profile_id, title, message, type, action_route
      ) values (
        new.shop_id, v_target, 'Status request diperbarui',
        new.type || ' sekarang ' || new.status || '. ' || new.review_note,
        'REQUEST', '/requests/me'
      );
    end if;
  end if;
  return new;
end;
$$;

drop trigger if exists employee_request_notifications on public.employee_requests;
create trigger employee_request_notifications
after insert or update of status on public.employee_requests
for each row execute function public.notify_request_workflow();

do $$
declare
  v_table text;
begin
  foreach v_table in array array[
    'weekly_shifts', 'cash_closings', 'audit_logs',
    'inventory_movements', 'notifications', 'cash_transactions'
  ] loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = v_table
    ) then
      execute format('alter publication supabase_realtime add table public.%I', v_table);
    end if;
  end loop;
end
$$;
