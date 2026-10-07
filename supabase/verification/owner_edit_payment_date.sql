-- Transactional regression: Owner can correct a payment timestamp, the linked
-- cash row follows it, and an Employee is denied. Every test row is rolled back.
begin;
set local role authenticated;
set local request.jwt.claim.sub = 'c06fd99f-84f8-412c-9c95-49db26bacfce';

do $$
declare
  v_customer uuid;
  v_service public.services%rowtype;
  v_order uuid;
  v_payment uuid;
  v_paid_at timestamptz := date_trunc('minute', now() - interval '2 days');
begin
  select * into strict v_service
  from public.services
  where shop_id = public.current_shop_id()
    and is_active
  order by sort_order
  limit 1;

  insert into public.customers (shop_id, name)
  values (public.current_shop_id(), 'Payment date regression (rolled back)')
  returning id into v_customer;

  select order_id into v_order
  from public.create_laundry_order(
    v_customer,
    null,
    'Payment date regression (rolled back)',
    now() + interval '3 days',
    1000,
    'Tunai',
    jsonb_build_array(jsonb_build_object(
      'service_id', v_service.id,
      'service_name', v_service.item_name,
      'unit', v_service.unit,
      'quantity', 1,
      'unit_price', greatest(v_service.price, 1000),
      'subtotal', greatest(v_service.price, 1000)
    ))
  );

  select id into strict v_payment
  from public.payments
  where order_id = v_order;

  perform public.update_order_payment_paid_at(v_payment, v_paid_at);
  perform set_config('test.payment_id', v_payment::text, true);

  if not exists (
    select 1
    from public.payments
    where id = v_payment and created_at = v_paid_at
  ) then
    raise exception 'Owner payment timestamp was not updated';
  end if;

  if not exists (
    select 1
    from public.cash_transactions
    where reference_type = 'PAYMENT'
      and reference_id = v_payment
      and created_at = v_paid_at
  ) then
    raise exception 'Cash timestamp did not follow payment timestamp';
  end if;
end $$;

set local request.jwt.claim.sub = 'd4cbfe9d-7a80-4b6b-b66c-98267e82a75e';
do $$
begin
  begin
    perform public.update_order_payment_paid_at(
      current_setting('test.payment_id')::uuid,
      now() - interval '1 day'
    );
    raise exception 'Employee unexpectedly edited a payment timestamp';
  exception
    when insufficient_privilege then null;
  end;
end $$;

rollback;
select 'PASS: Owner edits payment and cash date; Employee denied; rows rolled back' as result;
