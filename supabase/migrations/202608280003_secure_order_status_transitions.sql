-- Migration: Secure Order Status Transitions and Financial Sync
-- Path: supabase/migrations/202608280003_secure_order_status_transitions.sql

create or replace function public.sync_order_status_financials()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_shoe_pairs numeric;
  v_incentive_exists boolean;
  v_employee_name text;
  v_description text;
  v_amount integer;
  v_expense_id uuid;
begin
  -- 1. Enforce payment before picking up
  if NEW.order_status = 'picked_up' and NEW.paid_amount < NEW.total_price then
    raise exception 'Pesanan belum lunas. Bayar dulu sebelum diambil.';
  end if;

  -- 2. Handle shoe incentive when status changes to 'ready'
  if NEW.order_status = 'ready' and OLD.order_status <> 'ready' then
    -- Count shoe items in the order
    select coalesce(sum(quantity), 0)
    into v_shoe_pairs
    from public.order_items
    where order_id = NEW.id
      and (lower(service_name_snapshot) || ' ' || lower(unit) like '%sepatu%'
           or lower(service_name_snapshot) || ' ' || lower(unit) like '%pasang%');

    if v_shoe_pairs > 0 then
      -- Check if shoe incentive was already recorded for this order to prevent duplicates
      select exists (
        select 1 from public.expenses
        where shop_id = NEW.shop_id
          and description like '%Nota ' || NEW.order_number
          and category = 'Insentif Cuci Sepatu'
      ) into v_incentive_exists;

      if not v_incentive_exists then
        -- Get assigned employee name
        select name into v_employee_name
        from public.employees
        where id = NEW.assigned_employee_id;

        v_amount := (v_shoe_pairs * 10000)::integer;
        v_description := 'Insentif cuci ' || round(v_shoe_pairs)::text || ' pasang sepatu untuk ' || coalesce(v_employee_name, 'Karyawan') || ', Nota ' || NEW.order_number;

        -- Insert into expenses (which triggers trg_expense_to_cash automatically)
        insert into public.expenses (
          shop_id, description, category, amount, method, created_by, created_at
        ) values (
          NEW.shop_id, v_description, 'Insentif Cuci Sepatu', v_amount, 'Tunai', NEW.assigned_employee_id, now()
        );
      end if;
    end if;
  end if;

  -- 3. If status is rolled back from 'ready' to something else, or cancelled, clean up the incentive
  if OLD.order_status = 'ready' and NEW.order_status <> 'ready' then
    -- Find and delete the expense and corresponding cash transaction
    for v_expense_id in
      select id from public.expenses
      where shop_id = NEW.shop_id
        and description like '%Nota ' || NEW.order_number
        and category = 'Insentif Cuci Sepatu'
    loop
      delete from public.cash_transactions
      where shop_id = NEW.shop_id
        and reference_type = 'EXPENSE'
        and reference_id = v_expense_id;

      delete from public.expenses
      where id = v_expense_id;
    end loop;
  end if;

  -- 4. If order is soft-deleted, clean up payments, cash transactions, and expenses
  if NEW.deleted_at is not null and OLD.deleted_at is null then
    -- Delete cash transactions associated with this order's payments
    delete from public.cash_transactions
    where shop_id = NEW.shop_id
      and reference_type = 'ORDER'
      and reference_id = NEW.id;

    -- Delete payments
    delete from public.payments
    where shop_id = NEW.shop_id
      and order_id = NEW.id;

    -- Clean up shoe incentive expense and its cash transaction
    for v_expense_id in
      select id from public.expenses
      where shop_id = NEW.shop_id
        and description like '%Nota ' || NEW.order_number
        and category = 'Insentif Cuci Sepatu'
    loop
      delete from public.cash_transactions
      where shop_id = NEW.shop_id
        and reference_type = 'EXPENSE'
        and reference_id = v_expense_id;

      delete from public.expenses
      where id = v_expense_id;
    end loop;
  end if;

  return NEW;
end;
$$;

drop trigger if exists trg_sync_order_status_financials on public.orders;
create trigger trg_sync_order_status_financials
before update on public.orders
for each row execute function public.sync_order_status_financials();
