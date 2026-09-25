-- Round every non-thousand order total upward and add durable, targeted
-- notifications for order/payment workflow changes.

create or replace function public.round_order_total(p_amount integer)
returns integer
language sql
immutable
set search_path = pg_catalog, public
as $$
  select case
    when greatest(p_amount, 0) = 0 then 0
    when mod(greatest(p_amount, 0), 1000) = 0 then greatest(p_amount, 0)
    else ((greatest(p_amount, 0) / 1000) + 1) * 1000
  end;
$$;

revoke all on function public.round_order_total(integer) from public, anon;
grant execute on function public.round_order_total(integer) to authenticated;

create or replace function public.notify_request_workflow()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_target uuid;
  v_status_label text;
begin
  if tg_op = 'INSERT' then
    insert into public.notifications (
      shop_id, target_profile_id, title, message, type, action_route,
      reference_type, reference_id
    )
    select
      new.shop_id,
      profile.id,
      'Pengajuan baru dari ' || new.employee_name,
      new.type || ': ' || new.reason,
      'REQUEST',
      '/requests/review',
      'EMPLOYEE_REQUEST',
      new.id
    from public.profiles as profile
    where profile.shop_id = new.shop_id
      and profile.role = 'OWNER'
      and profile.is_active;
  elsif old.status is distinct from new.status then
    v_status_label := case new.status
      when 'approved' then 'disetujui'
      when 'rejected' then 'ditolak'
      when 'paid' then 'dibayar'
      when 'completed' then 'disetujui'
      else new.status
    end;

    select profile.id into v_target
    from public.profiles as profile
    where profile.employee_id = new.employee_id
      and profile.shop_id = new.shop_id
      and profile.is_active
    limit 1;

    if v_target is not null then
      insert into public.notifications (
        shop_id, target_profile_id, title, message, type, action_route,
        reference_type, reference_id
      ) values (
        new.shop_id,
        v_target,
        'Status pengajuan diperbarui',
        new.type || ' kamu ' || v_status_label ||
          case
            when btrim(coalesce(new.review_note, '')) = '' then '.'
            else '. Catatan: ' || new.review_note
          end,
        'REQUEST',
        '/requests/me',
        'EMPLOYEE_REQUEST',
        new.id
      );
    end if;
  end if;

  return new;
end;
$$;

revoke all on function public.notify_request_workflow() from public;

create or replace function public.notify_order_workflow()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order_status_changed boolean := old.order_status is distinct from new.order_status;
  v_payment_changed boolean :=
    old.payment_status is distinct from new.payment_status
    or old.paid_amount is distinct from new.paid_amount;
  v_status_label text;
  v_title text;
  v_message text := '';
  v_type text := 'ORDER';
begin
  if not v_order_status_changed and not v_payment_changed then
    return new;
  end if;

  if v_order_status_changed then
    v_status_label := case new.order_status
      when 'received' then 'Diterima'
      when 'processing' then 'Diproses'
      when 'ready' then 'Siap Diambil'
      when 'picked_up' then 'Diambil'
      when 'cancelled' then 'Dibatalkan'
      else new.order_status
    end;
    v_message := 'Status ' || new.order_number || ' menjadi ' || v_status_label || '.';
  end if;

  if v_payment_changed then
    v_type := 'PAYMENT';
    v_message := v_message || case when v_message = '' then '' else ' ' end ||
      case new.payment_status
        when 'paid' then 'Pembayaran sudah lunas.'
        when 'partial' then 'Dibayar Rp' || new.paid_amount::text ||
          ', sisa Rp' || greatest(new.total_price - new.paid_amount, 0)::text || '.'
        else 'Belum dibayar, sisa Rp' ||
          greatest(new.total_price - new.paid_amount, 0)::text || '.'
      end;
  end if;

  v_title := case
    when v_order_status_changed and v_payment_changed then
      'Pesanan dan pembayaran diperbarui'
    when v_payment_changed then 'Pembayaran ' || new.order_number
    else 'Status pesanan ' || new.order_number
  end;

  insert into public.notifications (
    shop_id, target_profile_id, title, message, type, action_route,
    reference_type, reference_id
  )
  select
    new.shop_id,
    profile.id,
    v_title,
    new.customer_name_snapshot || ': ' || v_message,
    v_type,
    '/orders/' || new.id::text,
    'ORDER_WORKFLOW',
    new.id
  from public.profiles as profile
  where profile.shop_id = new.shop_id
    and profile.is_active
    and profile.id is distinct from (select auth.uid())
    and (
      profile.role = 'OWNER'
      or (
        profile.role = 'EMPLOYEE'
        and profile.employee_id = new.assigned_employee_id
      )
    );

  return new;
end;
$$;

drop trigger if exists order_workflow_notifications on public.orders;
create trigger order_workflow_notifications
after update of order_status, payment_status, paid_amount on public.orders
for each row execute function public.notify_order_workflow();

revoke all on function public.notify_order_workflow() from public;

