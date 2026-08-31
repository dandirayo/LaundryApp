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
      'Request baru dari ' || new.employee_name,
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
      when 'completed' then 'selesai'
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
        'Status request diperbarui',
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

drop trigger if exists employee_request_notifications on public.employee_requests;
create trigger employee_request_notifications
after insert or update of status on public.employee_requests
for each row execute function public.notify_request_workflow();

create or replace function public.notify_owner_new_employee_order()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_actor_name text;
begin
  if public.current_role() is distinct from 'EMPLOYEE' then
    return new;
  end if;

  select coalesce(
    nullif(btrim(employee.name), ''),
    nullif(btrim(profile.full_name), ''),
    'Karyawan'
  )
  into v_actor_name
  from public.profiles as profile
  left join public.employees as employee
    on employee.id = profile.employee_id
   and employee.shop_id = profile.shop_id
  where profile.id = (select auth.uid())
    and profile.shop_id = new.shop_id
    and profile.is_active
  limit 1;

  insert into public.notifications (
    shop_id, target_profile_id, title, message, type, action_route,
    reference_type, reference_id
  )
  select
    new.shop_id,
    profile.id,
    'Pesanan baru dari ' || coalesce(v_actor_name, 'Karyawan'),
    new.order_number || ' untuk ' || new.customer_name_snapshot ||
      ' total Rp' || new.total_price::text || '.',
    'ORDER',
    '/orders/' || new.id::text,
    'ORDER',
    new.id
  from public.profiles as profile
  where profile.shop_id = new.shop_id
    and profile.role = 'OWNER'
    and profile.is_active
    and profile.id is distinct from (select auth.uid());

  return new;
end;
$$;

drop trigger if exists order_created_owner_notifications on public.orders;
create trigger order_created_owner_notifications
after insert on public.orders
for each row execute function public.notify_owner_new_employee_order();

revoke all on function public.notify_request_workflow() from public;
revoke all on function public.notify_owner_new_employee_order() from public;
