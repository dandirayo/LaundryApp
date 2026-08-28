-- Pelanggan boleh tidak memiliki nomor WhatsApp, tetapi snapshot pesanan
-- harus selalu berupa teks agar sesuai dengan constraint tabel orders.
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
set search_path = public
as $$
declare
  v_customer public.customers%rowtype;
  v_order_id uuid := gen_random_uuid();
  v_order_number text;
  v_total integer;
  v_item jsonb;
begin
  select * into v_customer
  from public.customers
  where id = p_customer_id
    and shop_id = public.current_shop_id();

  if not found then
    raise exception 'Pelanggan tidak ditemukan.';
  end if;
  if jsonb_array_length(coalesce(p_items, '[]'::jsonb)) = 0 then
    raise exception 'Pesanan harus memiliki layanan.';
  end if;

  select coalesce(sum((item ->> 'subtotal')::integer), 0)
  into v_total
  from jsonb_array_elements(p_items) item;

  if v_total <= 0 then
    raise exception 'Total pesanan tidak valid.';
  end if;
  if p_paid_amount < 0 or p_paid_amount > v_total then
    raise exception 'Nominal pembayaran awal tidak valid.';
  end if;

  v_order_number := 'IDL-' || to_char(now(), 'YYYYMMDD') || '-' ||
    upper(substr(replace(v_order_id::text, '-', ''), 1, 6));

  insert into public.orders (
    id, shop_id, order_number, customer_id, customer_name_snapshot,
    customer_phone_snapshot, assigned_employee_id, order_status,
    payment_status, total_price, paid_amount, note, due_at
  ) values (
    v_order_id, v_customer.shop_id, v_order_number, v_customer.id,
    coalesce(v_customer.name, 'Pelanggan'),
    coalesce(v_customer.phone, ''),
    p_assigned_employee_id, 'received',
    case when p_paid_amount = 0 then 'unpaid'
         when p_paid_amount >= v_total then 'paid'
         else 'partial' end,
    v_total, p_paid_amount, coalesce(p_note, ''), coalesce(p_due_at, now())
  );

  for v_item in select * from jsonb_array_elements(p_items) loop
    insert into public.order_items (
      shop_id, order_id, service_id, service_name_snapshot,
      category_snapshot, unit, quantity, unit_price, subtotal
    ) values (
      v_customer.shop_id, v_order_id, null,
      coalesce(v_item ->> 'service_name', 'Layanan'),
      coalesce(v_item ->> 'category', ''),
      coalesce(v_item ->> 'unit', 'PCS'),
      (v_item ->> 'quantity')::numeric,
      (v_item ->> 'unit_price')::integer,
      (v_item ->> 'subtotal')::integer
    );
  end loop;

  if p_paid_amount > 0 then
    insert into public.payments (
      shop_id, order_id, amount, method, created_by
    ) values (
      v_customer.shop_id, v_order_id, p_paid_amount,
      coalesce(p_payment_method, 'Tunai'), public.current_employee_id()
    );
    insert into public.cash_transactions (
      shop_id, type, category, description, amount, method,
      reference_type, reference_id
    ) values (
      v_customer.shop_id, 'IN', 'Pembayaran',
      'Pembayaran awal ' || v_order_number, p_paid_amount,
      coalesce(p_payment_method, 'Tunai'), 'ORDER', v_order_id
    );
  end if;

  return query select v_order_id, v_order_number;
end;
$$;

grant execute on function public.create_laundry_order(
  uuid, uuid, text, timestamptz, integer, text, jsonb
) to authenticated;
