create extension if not exists pg_cron;

create or replace function public.notify_unpaid_order_reminders()
returns integer
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_inserted_count integer := 0;
  v_today_start timestamptz :=
    date_trunc('day', now() at time zone 'Asia/Jakarta') at time zone 'Asia/Jakarta';
begin
  with overdue_orders as (
    select
      orders.id,
      orders.shop_id,
      orders.order_number,
      orders.customer_name_snapshot,
      orders.assigned_employee_id,
      orders.total_price,
      orders.paid_amount,
      orders.due_at
    from public.orders as orders
    where orders.deleted_at is null
      and orders.order_status <> 'cancelled'
      and orders.payment_status <> 'paid'
      and orders.total_price > 0
      and orders.paid_amount < orders.total_price
      and orders.due_at < now()
  ),
  recipients as (
    select
      overdue_orders.id as order_id,
      overdue_orders.shop_id,
      overdue_orders.order_number,
      overdue_orders.customer_name_snapshot,
      overdue_orders.total_price,
      overdue_orders.paid_amount,
      overdue_orders.due_at,
      profiles.id as profile_id
    from overdue_orders
    join public.profiles as profiles
      on profiles.shop_id = overdue_orders.shop_id
     and profiles.is_active
     and (
       profiles.role = 'OWNER'
       or (
         profiles.role = 'EMPLOYEE'
         and profiles.employee_id = overdue_orders.assigned_employee_id
       )
     )
  ),
  inserted as (
    insert into public.notifications (
      shop_id,
      target_profile_id,
      title,
      message,
      type,
      action_route,
      reference_type,
      reference_id
    )
    select
      recipients.shop_id,
      recipients.profile_id,
      'Reminder pembayaran ' || recipients.order_number,
      recipients.customer_name_snapshot || ' masih kurang Rp' ||
        greatest(recipients.total_price - recipients.paid_amount, 0)::text ||
        '. Jatuh tempo ' ||
        to_char(recipients.due_at at time zone 'Asia/Jakarta', 'DD/MM/YYYY HH24:MI') ||
        ' WIB.',
      'PAYMENT',
      '/orders/' || recipients.order_id::text,
      'ORDER_UNPAID_REMINDER',
      recipients.order_id
    from recipients
    where not exists (
      select 1
      from public.notifications as existing
      where existing.shop_id = recipients.shop_id
        and existing.target_profile_id = recipients.profile_id
        and existing.type = 'PAYMENT'
        and existing.reference_type = 'ORDER_UNPAID_REMINDER'
        and existing.reference_id = recipients.order_id
        and existing.created_at >= v_today_start
    )
    returning 1
  )
  select count(*) into v_inserted_count
  from inserted;

  return v_inserted_count;
end;
$$;

select cron.schedule(
  'unpaid-order-reminders-daily',
  '0 2 * * *',
  $$select public.notify_unpaid_order_reminders();$$
);

revoke all on function public.notify_unpaid_order_reminders() from public;
