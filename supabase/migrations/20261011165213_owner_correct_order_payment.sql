-- An owner correction must update the payment, order balance, cash ledger,
-- and immutable audit trail in the same transaction.
create or replace function public.owner_correct_order_payment(
  p_payment_id uuid,
  p_amount integer,
  p_method text,
  p_paid_at timestamptz
) returns void language plpgsql security definer
set search_path = pg_catalog, public as $$
declare
  v_payment public.payments%rowtype;
  v_order public.orders%rowtype;
  v_order_id uuid;
  v_other_paid integer;
  v_total_paid integer;
begin
  if (select auth.uid()) is null or public.current_role() <> 'OWNER' then
    raise exception using errcode = '42501', message = 'Hanya Owner yang dapat mengoreksi pembayaran.';
  end if;
  if p_amount <= 0 or btrim(coalesce(p_method, '')) = '' or p_paid_at is null
     or p_paid_at > now() + interval '5 minutes' then
    raise exception 'Nominal, metode, atau tanggal pembayaran tidak valid.';
  end if;

  select order_id into v_order_id from public.payments
  where id = p_payment_id and shop_id = public.current_shop_id();
  if not found then raise exception 'Pembayaran tidak ditemukan.'; end if;
  select * into v_order from public.orders
  where id = v_order_id and shop_id = public.current_shop_id()
    and deleted_at is null for update;
  if not found then raise exception 'Pesanan tidak ditemukan.'; end if;
  select * into v_payment from public.payments
  where id = p_payment_id and order_id = v_order.id and shop_id = v_order.shop_id for update;
  if not found then raise exception 'Pembayaran tidak ditemukan.'; end if;
  select coalesce(sum(amount), 0) into v_other_paid from public.payments
  where order_id = v_order.id and id <> v_payment.id;
  v_total_paid := v_other_paid + p_amount;
  if v_total_paid > v_order.total_price then
    raise exception 'Total pembayaran melebihi tagihan pesanan.';
  end if;

  update public.payments set amount = p_amount, method = btrim(p_method), created_at = p_paid_at
  where id = v_payment.id;
  update public.orders set paid_amount = v_total_paid,
    payment_status = case when v_total_paid = 0 then 'unpaid'
      when v_total_paid >= v_order.total_price then 'paid' else 'partial' end,
    updated_at = now()
  where id = v_order.id;
end;
$$;
revoke all on function public.owner_correct_order_payment(uuid, integer, text, timestamptz)
from public, anon;
grant execute on function public.owner_correct_order_payment(uuid, integer, text, timestamptz)
to authenticated;

create trigger audit_payments after insert or update or delete
on public.payments for each row execute function public.write_audit_log();
