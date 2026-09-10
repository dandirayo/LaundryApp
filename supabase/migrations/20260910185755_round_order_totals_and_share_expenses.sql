create or replace function public.round_order_total(p_amount integer)
returns integer
language sql
immutable
strict
set search_path = pg_catalog
as $$
  select case
    when mod(greatest(p_amount, 0), 1000) <= 500
      then (greatest(p_amount, 0) / 1000) * 1000
    else ((greatest(p_amount, 0) / 1000) + 1) * 1000
  end;
$$;

revoke all on function public.round_order_total(integer) from public, anon;
grant execute on function public.round_order_total(integer) to authenticated;
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
      category_snapshot, unit, quantity, unit_price, subtotal
    ) values (
      v_shop_id,
      v_order_id,
      v_service_id,
      coalesce(nullif(btrim(v_item ->> 'service_name'), ''), 'Layanan'),
      coalesce(v_item ->> 'category', ''),
      upper(coalesce(nullif(btrim(v_item ->> 'unit'), ''), 'PCS')),
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


drop policy if exists "owners select expenses" on public.expenses;
drop policy if exists "owners insert expenses" on public.expenses;
drop policy if exists "owners update expenses" on public.expenses;
drop policy if exists "owners delete expenses" on public.expenses;
drop policy if exists "employees select own expenses" on public.expenses;
drop policy if exists "employees insert own expenses" on public.expenses;
drop policy if exists "members select shop expenses" on public.expenses;
drop policy if exists "members insert shop expenses" on public.expenses;

create policy "members select shop expenses"
on public.expenses for select to authenticated
using (shop_id = public.current_shop_id());

create policy "members insert shop expenses"
on public.expenses for insert to authenticated
with check (
  shop_id = public.current_shop_id()
  and (
    (public.current_role() = 'OWNER' and created_by is null)
    or (
      public.current_role() = 'EMPLOYEE'
      and created_by = public.current_employee_id()
    )
  )
  and coalesce(source_type, '') = ''
);

create policy "owners update expenses"
on public.expenses for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "owners delete expenses"
on public.expenses for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');