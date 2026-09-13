-- Allow staff to record that laundry was collected while payment remains due.
-- Payment status stays independent and overdue-payment reminders keep working.
create or replace function public.sync_order_status_financials()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_shoe_pairs numeric;
  v_employee_name text;
  v_amount integer;
begin
  if new.deleted_at is distinct from old.deleted_at
     and public.current_role() is distinct from 'OWNER' then
    raise exception using
      errcode = '42501',
      message = 'Hanya Owner yang dapat menghapus atau memulihkan pesanan.';
  end if;

  if new.order_status = 'ready' and old.order_status is distinct from 'ready' then
    select coalesce(sum(quantity), 0)
    into v_shoe_pairs
    from public.order_items
    where order_id = new.id
      and (
        lower(service_name_snapshot || ' ' || unit) like '%sepatu%'
        or lower(service_name_snapshot || ' ' || unit) like '%pasang%'
      );

    if v_shoe_pairs > 0 then
      select name into v_employee_name
      from public.employees
      where id = new.assigned_employee_id and shop_id = new.shop_id;

      v_amount := (v_shoe_pairs * 10000)::integer;
      insert into public.expenses (
        shop_id, description, category, amount, method, created_by,
        source_type, source_id
      ) values (
        new.shop_id,
        'Insentif cuci ' || round(v_shoe_pairs)::text ||
          ' pasang sepatu untuk ' || coalesce(v_employee_name, 'Karyawan') ||
          ', Nota ' || new.order_number,
        'Insentif Cuci Sepatu',
        v_amount,
        'Tunai',
        new.assigned_employee_id,
        'ORDER_INCENTIVE',
        new.id
      ) on conflict do nothing;
    end if;
  end if;

  if (old.order_status = 'ready' and new.order_status is distinct from 'ready')
     or (new.deleted_at is not null and old.deleted_at is null) then
    delete from public.expenses
    where shop_id = new.shop_id
      and (
        (source_type = 'ORDER_INCENTIVE' and source_id = new.id)
        or (
          source_id is null
          and category = 'Insentif Cuci Sepatu'
          and description like '%Nota ' || new.order_number
        )
      );
  end if;

  if new.deleted_at is not null and old.deleted_at is null then
    delete from public.cash_transactions
    where shop_id = new.shop_id
      and reference_type = 'ORDER'
      and reference_id = new.id;

    delete from public.payments
    where shop_id = new.shop_id and order_id = new.id;
  end if;

  return new;
end;
$$;

revoke all on function public.sync_order_status_financials() from public;
