-- Buying stock is one database transaction: quantity, movement, expense, and
-- its existing cashbook trigger either all succeed or all roll back.
create or replace function public.record_inventory_purchase(
  p_item_id uuid,
  p_quantity numeric,
  p_amount integer,
  p_method text,
  p_note text default ''
)
returns uuid
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_item public.inventory_items%rowtype;
  v_employee_id uuid;
  v_movement_id uuid;
  v_expense_id uuid;
  v_description text;
begin
  if (select auth.uid()) is null
     or public.current_role() not in ('OWNER', 'EMPLOYEE') then
    raise exception 'Akun tidak diizinkan mencatat pembelian stok.';
  end if;
  v_employee_id := public.current_employee_id();
  if public.current_role() = 'EMPLOYEE' and v_employee_id is null then
    raise exception 'Akun karyawan belum terhubung.';
  end if;
  if p_quantity is null or p_quantity <= 0 or p_amount is null or p_amount <= 0 then
    raise exception 'Jumlah dan nominal pembelian harus lebih dari nol.';
  end if;
  if p_method not in ('Tunai', 'Transfer', 'QRIS') then
    raise exception 'Metode pembayaran tidak dikenal.';
  end if;

  select * into v_item
  from public.inventory_items
  where id = p_item_id and shop_id = public.current_shop_id() and is_active
  for update;
  if not found then
    raise exception 'Barang stok tidak ditemukan atau tidak aktif.';
  end if;

  update public.inventory_items
  set stock = stock + p_quantity, updated_at = now()
  where id = v_item.id;

  insert into public.inventory_movements (
    shop_id, item_id, item_name, type, quantity, note, created_by
  ) values (
    v_item.shop_id, v_item.id, v_item.name, 'IN', p_quantity,
    'Pembelian' || case when nullif(btrim(p_note), '') is null
      then '' else ' - ' || left(btrim(p_note), 500) end,
    v_employee_id
  ) returning id into v_movement_id;

  v_description := 'Beli ' || v_item.name || ' - ' ||
    p_quantity::text || ' ' || v_item.unit ||
    case when nullif(btrim(p_note), '') is null
      then '' else ' - ' || left(btrim(p_note), 500) end;
  insert into public.expenses (
    shop_id, description, category, amount, method, created_by,
    source_type, source_id
  ) values (
    v_item.shop_id, v_description, 'Stok', p_amount, p_method,
    v_employee_id, 'INVENTORY_PURCHASE', v_movement_id
  ) returning id into v_expense_id;

  return v_expense_id;
end;
$$;

-- Usage changes physical stock only. The cost was already recorded when bought.
create or replace function public.record_inventory_usage(
  p_item_id uuid,
  p_quantity numeric,
  p_note text default ''
)
returns numeric
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_item public.inventory_items%rowtype;
  v_employee_id uuid;
  v_new_stock numeric;
begin
  if (select auth.uid()) is null
     or public.current_role() not in ('OWNER', 'EMPLOYEE') then
    raise exception 'Akun tidak diizinkan memakai stok.';
  end if;
  v_employee_id := public.current_employee_id();
  if public.current_role() = 'EMPLOYEE' and v_employee_id is null then
    raise exception 'Akun karyawan belum terhubung.';
  end if;
  if p_quantity is null or p_quantity <= 0 then
    raise exception 'Jumlah pemakaian harus lebih dari nol.';
  end if;

  select * into v_item
  from public.inventory_items
  where id = p_item_id and shop_id = public.current_shop_id() and is_active
  for update;
  if not found then
    raise exception 'Barang stok tidak ditemukan atau tidak aktif.';
  end if;
  v_new_stock := v_item.stock - p_quantity;
  if v_new_stock < 0 then
    raise exception 'Stok tidak mencukupi.';
  end if;

  update public.inventory_items
  set stock = v_new_stock, updated_at = now()
  where id = v_item.id;
  insert into public.inventory_movements (
    shop_id, item_id, item_name, type, quantity, note, created_by
  ) values (
    v_item.shop_id, v_item.id, v_item.name, 'OUT', p_quantity,
    'Pemakaian' || case when nullif(btrim(p_note), '') is null
      then '' else ' - ' || left(btrim(p_note), 500) end,
    v_employee_id
  );
  return v_new_stock;
end;
$$;

revoke all on function public.record_inventory_purchase(uuid, numeric, integer, text, text)
  from public, anon;
revoke all on function public.record_inventory_usage(uuid, numeric, text)
  from public, anon;
grant execute on function public.record_inventory_purchase(uuid, numeric, integer, text, text)
  to authenticated;
grant execute on function public.record_inventory_usage(uuid, numeric, text)
  to authenticated;
