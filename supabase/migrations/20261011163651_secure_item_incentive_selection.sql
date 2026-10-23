-- Avoid treating "Atasan" as a bag because it contains the letters "tas".
create or replace function public.incentive_item_kind(p_name text)
returns text language sql immutable set search_path = pg_catalog as $$
  select case
    when coalesce(p_name, '') ~* '(^|[^[:alnum:]])sepatu([^[:alnum:]]|$)' then 'sepatu'
    when coalesce(p_name, '') ~* '(^|[^[:alnum:]])helm([^[:alnum:]]|$)' then 'helm'
    when coalesce(p_name, '') ~* '(^|[^[:alnum:]])tas([^[:alnum:]]|$)' then 'tas'
    else null end;
$$;

create or replace function public.validate_order_item_incentive()
returns trigger language plpgsql set search_path = pg_catalog, public as $$
declare
  v_status text;
begin
  if tg_op = 'UPDATE' and
     (new.incentive_rate, new.incentive_employee_id) is not distinct from
     (old.incentive_rate, old.incentive_employee_id) then
    return new;
  end if;

  select order_status into v_status from public.orders
  where id = new.order_id and shop_id = new.shop_id;
  if v_status not in ('received', 'processing') then
    raise exception 'Insentif hanya dapat diatur sebelum pesanan selesai.';
  end if;
  if tg_op = 'INSERT' and new.incentive_rate > 0 and current_user <> 'postgres' then
    raise exception using errcode = '42501', message = 'Gunakan form pesanan untuk menetapkan insentif.';
  end if;
  if tg_op = 'UPDATE' and current_user <> 'postgres' and public.current_role() <> 'OWNER' then
    raise exception using errcode = '42501', message = 'Hanya Owner yang dapat mengoreksi insentif.';
  end if;
  if new.incentive_rate > 0 and (
    public.incentive_item_kind(new.service_name_snapshot) is null
    or upper(new.unit) not in ('PAIR', 'PIECE', 'ITEM')
    or new.quantity <> trunc(new.quantity)
    or new.incentive_employee_id is null
    or not exists (
      select 1 from public.employees e
      where e.id = new.incentive_employee_id and e.shop_id = new.shop_id and e.is_active
    )
  ) then
    raise exception 'Insentif hanya untuk sepatu, helm, atau tas dengan karyawan aktif.';
  end if;
  return new;
end;
$$;
create trigger validate_order_item_incentive before insert or update
on public.order_items for each row execute function public.validate_order_item_incentive();

create or replace function public.configure_order_item_incentives(
  p_order_id uuid, p_choices jsonb
) returns void language plpgsql security definer set search_path = pg_catalog, public as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_choice jsonb;
  v_item public.order_items%rowtype;
  v_rate integer;
  v_employee_id uuid;
begin
  if (select auth.uid()) is null or v_shop_id is null or public.current_role() <> 'OWNER' then
    raise exception using errcode = '42501', message = 'Hanya Owner yang dapat mengoreksi insentif.';
  end if;
  if not exists (select 1 from public.orders
      where id = p_order_id and shop_id = v_shop_id and deleted_at is null
        and order_status in ('received', 'processing')) then
    raise exception 'Insentif hanya dapat diatur sebelum pesanan selesai.';
  end if;
  if p_choices is null or jsonb_typeof(p_choices) <> 'array' then
    raise exception 'Pilihan insentif tidak valid.';
  end if;
  for v_choice in select * from jsonb_array_elements(p_choices) loop
    select * into v_item from public.order_items
    where id = (v_choice ->> 'order_item_id')::uuid
      and order_id = p_order_id and shop_id = v_shop_id;
    if not found then raise exception 'Item pesanan tidak ditemukan.'; end if;
    v_rate := (v_choice ->> 'rate')::integer;
    v_employee_id := nullif(v_choice ->> 'employee_id', '')::uuid;
    if v_rate not in (0, 10000, 15000, 20000) then
      raise exception 'Nominal insentif tidak valid.';
    end if;
    if v_rate > 0 and (
      public.incentive_item_kind(v_item.service_name_snapshot) is null
      or upper(v_item.unit) not in ('PAIR', 'PIECE', 'ITEM')
      or v_item.quantity <> trunc(v_item.quantity)
      or v_employee_id is null
      or not exists (select 1 from public.employees
        where id = v_employee_id and shop_id = v_shop_id and is_active)
    ) then
      raise exception 'Insentif hanya untuk sepatu, helm, atau tas dengan karyawan aktif.';
    end if;
    update public.order_items set incentive_rate = v_rate,
      incentive_employee_id = case when v_rate > 0 then v_employee_id else null end
    where id = v_item.id;
  end loop;
end;
$$;
