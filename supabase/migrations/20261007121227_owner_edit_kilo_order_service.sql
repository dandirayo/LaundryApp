-- Allow an owner to replace the service used by existing kiloan order items.
-- The item snapshots, order total, payment status, and due date are updated in
-- one transaction so the receipt can never observe a partially updated order.

create or replace function public.update_order_kilo_services(
  p_order_id uuid,
  p_replacements jsonb
)
returns void
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_order public.orders%rowtype;
  v_replacement jsonb;
  v_item_id uuid;
  v_service_id uuid;
  v_service public.services%rowtype;
  v_subtotal integer;
  v_total integer;
  v_max_hours integer;
begin
  if (select auth.uid()) is null
     or v_shop_id is null
     or public.current_role() is distinct from 'OWNER' then
    raise exception using
      errcode = '42501',
      message = 'Hanya Owner yang dapat mengganti layanan pesanan.';
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

  if p_replacements is null
     or jsonb_typeof(p_replacements) <> 'array'
     or jsonb_array_length(p_replacements) = 0 then
    raise exception 'Pilih minimal satu layanan kiloan yang akan diubah.';
  end if;

  for v_replacement in select * from jsonb_array_elements(p_replacements)
  loop
    begin
      v_item_id := (v_replacement ->> 'item_id')::uuid;
      v_service_id := (v_replacement ->> 'service_id')::uuid;
    exception when invalid_text_representation then
      raise exception 'Data perubahan layanan tidak valid.';
    end;

    if not exists (
      select 1
      from public.order_items as item
      where item.id = v_item_id
        and item.order_id = p_order_id
        and item.shop_id = v_shop_id
        and upper(btrim(item.unit)) = 'KG'
    ) then
      raise exception 'Item kiloan pesanan tidak ditemukan.';
    end if;

    select * into v_service
    from public.services
    where id = v_service_id
      and shop_id = v_shop_id
      and is_active
      and upper(btrim(unit)) = 'KG';

    if not found then
      raise exception 'Layanan pengganti harus merupakan layanan kiloan aktif.';
    end if;

    update public.order_items
    set service_id = v_service.id,
        service_name_snapshot = concat_ws(
          ' ',
          nullif(btrim(v_service.item_name), ''),
          nullif(btrim(v_service.size_variant), ''),
          nullif(btrim(v_service.material_variant), '')
        ),
        category_snapshot = coalesce(v_service.category_name, ''),
        unit = 'KG',
        unit_price = v_service.price,
        subtotal = round(quantity * v_service.price)::integer
    where id = v_item_id
      and order_id = p_order_id
      and shop_id = v_shop_id;
  end loop;

  select coalesce(sum(item.subtotal), 0)
  into v_subtotal
  from public.order_items as item
  where item.order_id = p_order_id
    and item.shop_id = v_shop_id;

  v_total := public.round_order_total(v_subtotal);
  if v_total < v_order.paid_amount then
    raise exception
      'Total baru tidak boleh lebih kecil dari pembayaran yang sudah diterima.';
  end if;

  select coalesce(max(service.estimated_hours), 0)
  into v_max_hours
  from public.order_items as item
  left join public.services as service
    on service.id = item.service_id
   and service.shop_id = v_shop_id
  where item.order_id = p_order_id
    and item.shop_id = v_shop_id;

  update public.orders
  set total_price = v_total,
      payment_status = case
        when paid_amount = 0 then 'unpaid'
        when paid_amount >= v_total then 'paid'
        else 'partial'
      end,
      due_at = created_at + (v_max_hours * interval '1 hour'),
      updated_at = now()
  where id = p_order_id
    and shop_id = v_shop_id;
end;
$$;

revoke all on function public.update_order_kilo_services(uuid, jsonb)
from public, anon;
grant execute on function public.update_order_kilo_services(uuid, jsonb)
to authenticated;
