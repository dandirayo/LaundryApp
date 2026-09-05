-- Transactional regression: a loyal-customer kilo order may use actual weight
-- below the normal 3 kg floor. Every row is rolled back.
begin;
set local role authenticated;
set local request.jwt.claim.sub = 'd4cbfe9d-7a80-4b6b-b66c-98267e82a75e';
do $$
declare
  v_customer uuid;
  v_service public.services%rowtype;
  v_order uuid;
begin
  select * into strict v_service
  from public.services
  where shop_id = public.current_shop_id()
    and unit = 'KG'
    and is_active = true
  order by sort_order
  limit 1;

  insert into public.customers (shop_id, name)
  values (public.current_shop_id(), 'Below 3 kg regression (rolled back)')
  returning id into v_customer;

  select order_id into v_order
  from public.create_laundry_order(
    v_customer,
    public.current_employee_id(),
    'Permintaan pelanggan setia (rolled back)',
    now() + interval '3 days',
    0,
    'Tunai',
    jsonb_build_array(jsonb_build_object(
      'service_id', v_service.id,
      'service_name', v_service.item_name,
      'unit', 'KG',
      'quantity', 2.4,
      'unit_price', v_service.price,
      'subtotal', round(v_service.price * 2.4)
    ))
  );

  if not exists (
    select 1 from public.order_items
    where order_id = v_order and quantity = 2.4
  ) then
    raise exception '2.4 kg was not stored exactly';
  end if;
end $$;
rollback;
select 'PASS: 2.4 kg loyal-customer order accepted; test rows rolled back' as result;
