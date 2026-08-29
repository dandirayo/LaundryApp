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

grant execute on function public.create_laundry_order(
  uuid, uuid, text, timestamptz, integer, text, jsonb
) to authenticated;

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
    when new.type ilike '%Insentif%' or new.type ilike '%Lembur%' then 'Insentif'
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

revoke all on function public.sync_employee_request_cash_transaction() from public;

with matched_services as (
  select distinct on (item.id)
    item.id as order_item_id,
    service.id as service_id
  from public.order_items as item
  join public.services as service
    on service.shop_id = item.shop_id
   and upper(service.unit) = upper(item.unit)
   and service.price = item.unit_price
   and (
     btrim(service.item_name || ' ' ||
       btrim(concat_ws(' ', nullif(service.size_variant, ''), nullif(service.material_variant, ''))))
       = btrim(item.service_name_snapshot)
     or service.item_name = item.service_name_snapshot
   )
  where item.service_id is null
  order by item.id, service.is_active desc, service.sort_order, service.created_at
)
update public.order_items as item
set service_id = matched.service_id
from matched_services as matched
where item.id = matched.order_item_id;

with duplicate_services as (
  select
    id,
    row_number() over (
      partition by shop_id, category_name, item_name, size_variant,
        material_variant, upper(unit), price
      order by is_active desc, sort_order, created_at
    ) as duplicate_rank
  from public.services
)
update public.services as service
set is_active = false
from duplicate_services as duplicate
where service.id = duplicate.id
  and duplicate.duplicate_rank > 1;

insert into public.cash_transactions (
  shop_id, type, category, description, amount, method,
  reference_type, reference_id, created_at
)
select
  request.shop_id,
  'OUT',
  case
    when request.type ilike '%Kasbon%' then 'Kasbon'
    when request.type ilike '%Insentif%' or request.type ilike '%Lembur%' then 'Insentif'
    when request.type ilike '%Pengeluaran%' then 'Pengeluaran'
    else 'Request Karyawan'
  end,
  request.type || ' ' || request.employee_name || ' - ' || coalesce(request.reason, ''),
  request.amount,
  coalesce(nullif(btrim(request.payment_method), ''), 'Tunai'),
  'EMPLOYEE_REQUEST',
  request.id,
  coalesce(request.reviewed_at, request.created_at)
from public.employee_requests as request
where request.status = 'paid'
  and request.amount > 0
  and not exists (
    select 1
    from public.cash_transactions as cash
    where cash.shop_id = request.shop_id
      and cash.reference_type = 'EMPLOYEE_REQUEST'
      and cash.reference_id = request.id
  )
on conflict do nothing;
