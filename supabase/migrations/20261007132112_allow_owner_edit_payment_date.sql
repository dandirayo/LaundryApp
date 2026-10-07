-- Owners may correct a payment timestamp. The linked cash transaction follows
-- the same timestamp so reports and Buku Kas remain consistent.

create or replace function public.sync_payment_cash_transaction()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_order_number text;
begin
  if tg_op = 'DELETE' then
    delete from public.cash_transactions
    where shop_id = old.shop_id
      and reference_type = 'PAYMENT'
      and reference_id = old.id;
    return old;
  end if;

  select order_number into v_order_number
  from public.orders
  where id = new.order_id and shop_id = new.shop_id;

  insert into public.cash_transactions (
    shop_id, type, category, description, amount, method,
    reference_type, reference_id, created_at
  ) values (
    new.shop_id, 'IN', 'Pembayaran',
    'Pembayaran ' || coalesce(v_order_number, new.order_id::text),
    new.amount, coalesce(nullif(btrim(new.method), ''), 'Tunai'),
    'PAYMENT', new.id, new.created_at
  ) on conflict do nothing;

  update public.cash_transactions
  set type = 'IN',
      category = 'Pembayaran',
      description = 'Pembayaran ' || coalesce(v_order_number, new.order_id::text),
      amount = new.amount,
      method = coalesce(nullif(btrim(new.method), ''), 'Tunai'),
      created_at = new.created_at
  where shop_id = new.shop_id
    and reference_type = 'PAYMENT'
    and reference_id = new.id;

  return new;
end;
$$;

revoke all on function public.sync_payment_cash_transaction() from public;

create or replace function public.update_order_payment_paid_at(
  p_payment_id uuid,
  p_paid_at timestamptz
)
returns timestamptz
language plpgsql
security definer
set search_path = pg_catalog, public
as $$
declare
  v_shop_id uuid := public.current_shop_id();
  v_paid_at timestamptz;
begin
  if (select auth.uid()) is null
     or v_shop_id is null
     or public.current_role() <> 'OWNER' then
    raise exception using
      errcode = '42501',
      message = 'Hanya Owner yang dapat mengubah tanggal pembayaran.';
  end if;

  if p_paid_at is null then
    raise exception 'Tanggal pembayaran wajib diisi.';
  end if;

  if p_paid_at > now() + interval '5 minutes' then
    raise exception 'Tanggal pembayaran tidak boleh berada di masa depan.';
  end if;

  update public.payments
  set created_at = p_paid_at
  where id = p_payment_id
    and shop_id = v_shop_id
  returning created_at into v_paid_at;

  if not found then
    raise exception 'Pembayaran tidak ditemukan.';
  end if;

  return v_paid_at;
end;
$$;

revoke all on function public.update_order_payment_paid_at(uuid, timestamptz)
  from public, anon;
grant execute on function public.update_order_payment_paid_at(uuid, timestamptz)
  to authenticated;
