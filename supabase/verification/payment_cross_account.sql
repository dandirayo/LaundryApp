-- Transactional regression test: every test row is rolled back.
begin;
set local role authenticated;
set local request.jwt.claim.sub = 'd4cbfe9d-7a80-4b6b-b66c-98267e82a75e';
do $$
declare
  v_order uuid;
  v_customer uuid;
  v_service uuid;
begin
  select id into strict v_service from public.services
    where shop_id=public.current_shop_id() and unit='KG'
      and price=12000 and is_active=true limit 1;
  insert into public.customers (shop_id, name)
  values (public.current_shop_id(), 'Sync regression customer (rolled back)')
  returning id into v_customer;
  select order_id into v_order from public.create_laundry_order(
    v_customer,
    public.current_employee_id(), 'Sync regression (rolled back)',
    now() + interval '3 days', 0, 'Tunai',
    jsonb_build_array(jsonb_build_object('service_id', v_service,
      'service_name', 'Sync test kilat', 'unit', 'KG', 'quantity', 5,
      'unit_price', 12000, 'subtotal', 60000))
  );
  perform set_config('test.order_id', v_order::text, true);
  if not exists (select 1 from public.orders where id=v_order and paid_amount=0 and total_price=60000) then
    raise exception 'Unpaid kiloan order was not saved correctly';
  end if;
  if exists (select 1 from public.payments where order_id=v_order) then
    raise exception 'Unpaid order must not create a payment';
  end if;
  perform public.record_order_payment(v_order, 60000, 'Tunai');
  if not exists (select 1 from public.orders where id=v_order and paid_amount=60000) then
    raise exception 'Ratna cannot see paid order';
  end if;
end $$;
set local request.jwt.claim.sub = '147f106d-9313-4ab7-b413-82448ab90b10';
do $$ begin
  if not exists (select 1 from public.orders where id=current_setting('test.order_id')::uuid and paid_amount=60000) then
    raise exception 'Yani cannot see paid order';
  end if;
end $$;
set local request.jwt.claim.sub = 'c06fd99f-84f8-412c-9c95-49db26bacfce';
do $$ begin
  if (select coalesce(sum(c.amount),0) from public.cash_transactions c
      join public.payments p on p.id=c.reference_id and c.reference_type='PAYMENT'
      where p.order_id=current_setting('test.order_id')::uuid) <> 60000 then
    raise exception 'Owner cash ledger is not synchronized';
  end if;
end $$;
rollback;
select 'PASS: unpaid 5 KG order saved, Ratna payment, Yani order, Owner ledger; test rows rolled back' as result;
