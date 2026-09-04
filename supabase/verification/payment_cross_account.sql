-- Transactional regression test: every test row is rolled back.
begin;
set local role authenticated;
set local request.jwt.claim.sub = 'd4cbfe9d-7a80-4b6b-b66c-98267e82a75e';
do $$
declare
  v_order uuid;
  v_customer uuid;
begin
  insert into public.customers (shop_id, name)
  values (public.current_shop_id(), 'Sync regression customer (rolled back)')
  returning id into v_customer;
  select order_id into v_order from public.create_laundry_order(
    v_customer,
    public.current_employee_id(), 'Sync regression (rolled back)',
    now() + interval '3 days', 0, 'Tunai',
    '[{"service_name":"Sync test","unit":"PCS","quantity":1,"unit_price":20000,"subtotal":20000}]'::jsonb
  );
  perform set_config('test.order_id', v_order::text, true);
  perform public.record_order_payment(v_order, 20000, 'Tunai');
  if not exists (select 1 from public.orders where id=v_order and paid_amount=20000) then
    raise exception 'Ratna cannot see paid order';
  end if;
end $$;
set local request.jwt.claim.sub = '147f106d-9313-4ab7-b413-82448ab90b10';
do $$ begin
  if not exists (select 1 from public.orders where id=current_setting('test.order_id')::uuid and paid_amount=20000) then
    raise exception 'Yani cannot see paid order';
  end if;
end $$;
set local request.jwt.claim.sub = 'c06fd99f-84f8-412c-9c95-49db26bacfce';
do $$ begin
  if (select coalesce(sum(c.amount),0) from public.cash_transactions c
      join public.payments p on p.id=c.reference_id and c.reference_type='PAYMENT'
      where p.order_id=current_setting('test.order_id')::uuid) <> 20000 then
    raise exception 'Owner cash ledger is not synchronized';
  end if;
end $$;
rollback;
select 'PASS: Ratna payment, Yani order, Owner ledger; test rows rolled back' as result;
