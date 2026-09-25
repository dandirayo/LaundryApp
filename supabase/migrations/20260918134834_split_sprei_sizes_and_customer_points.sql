-- Keep old services for historical order snapshots, but offer a size and price
-- for each new Sprei Besar order. Existing custom services are untouched.
insert into public.services (
  shop_id, category_id, category_name, item_name, size_variant,
  material_variant, unit, price, estimated_hours, is_express,
  is_active, sort_order
)
select legacy.shop_id, legacy.category_id, legacy.category_name,
  'Sprei Besar', variants.size, variants.treatment, legacy.unit,
  variants.price, legacy.estimated_hours, false, true, variants.sort_order
from public.services as legacy
cross join (values
  ('160x200', 'Cuci Setrika', 25000, 154),
  ('180x200', 'Cuci Setrika', 30000, 155),
  ('200x200', 'Cuci Setrika', 35000, 156),
  ('160x200', 'Setrika Saja', 15000, 157),
  ('180x200', 'Setrika Saja', 18000, 158),
  ('200x200', 'Setrika Saja', 20000, 159)
) as variants(size, treatment, price, sort_order)
where legacy.item_name = 'Sprei Besar (160, 180, 200)'
  and legacy.size_variant = 'Cuci Setrika'
  and not exists (
    select 1 from public.services as existing
    where existing.shop_id = legacy.shop_id
      and existing.item_name = 'Sprei Besar'
      and existing.size_variant = variants.size
      and existing.material_variant = variants.treatment
  );

update public.services
set is_active = false
where item_name = 'Sprei Besar (160, 180, 200)'
  and size_variant in ('Cuci Setrika', 'Setrika Saja');

-- One point for every completed Rp10,000 of a fully paid order. The ledger is
-- keyed by order so a repeated payment update cannot award points twice.
create table public.customer_point_events (
  order_id uuid primary key references public.orders(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  customer_id uuid not null references public.customers(id) on delete cascade,
  points integer not null check (points >= 0),
  updated_at timestamptz not null default now()
);

create index customer_point_events_customer_idx
  on public.customer_point_events (shop_id, customer_id);

create table public.customer_point_balances (
  customer_id uuid primary key references public.customers(id) on delete cascade,
  shop_id uuid not null references public.shops(id) on delete cascade,
  points integer not null default 0 check (points >= 0),
  updated_at timestamptz not null default now()
);

create index customer_point_balances_shop_idx
  on public.customer_point_balances (shop_id, customer_id);

alter table public.customer_point_events enable row level security;
alter table public.customer_point_balances enable row level security;

create policy "Staff can read their shop point events"
on public.customer_point_events for select to authenticated
using (shop_id = (select public.current_shop_id()));

create policy "Staff can read their shop point balances"
on public.customer_point_balances for select to authenticated
using (shop_id = (select public.current_shop_id()));

revoke all on public.customer_point_events from anon, authenticated;
revoke all on public.customer_point_balances from anon, authenticated;
grant select on public.customer_point_events to authenticated;
grant select on public.customer_point_balances to authenticated;

create schema if not exists app_private;

create function app_private.sync_customer_points()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  earned integer;
begin
  earned := case
    when new.deleted_at is null and new.payment_status = 'paid'
      and new.paid_amount >= new.total_price and new.total_price > 0
    then floor(new.total_price / 10000.0)::integer
    else 0
  end;

  insert into public.customer_point_events
    (order_id, shop_id, customer_id, points, updated_at)
  values (new.id, new.shop_id, new.customer_id, earned, now())
  on conflict (order_id) do update set
    points = excluded.points,
    updated_at = now();

  insert into public.customer_point_balances
    (customer_id, shop_id, points, updated_at)
  values (
    new.customer_id, new.shop_id,
    (select coalesce(sum(points), 0)::integer
     from public.customer_point_events
     where customer_id = new.customer_id and shop_id = new.shop_id),
    now()
  )
  on conflict (customer_id) do update set
    points = excluded.points,
    updated_at = now();

  return new;
end;
$$;

revoke all on function app_private.sync_customer_points() from public, anon, authenticated;

create trigger sync_customer_points_after_order
after insert or update of payment_status, paid_amount, total_price, deleted_at
on public.orders
for each row execute function app_private.sync_customer_points();

insert into public.customer_point_events
  (order_id, shop_id, customer_id, points)
select id, shop_id, customer_id, floor(total_price / 10000.0)::integer
from public.orders
where deleted_at is null and payment_status = 'paid'
  and paid_amount >= total_price and total_price >= 10000
on conflict (order_id) do nothing;

insert into public.customer_point_balances
  (customer_id, shop_id, points)
select customer_id, shop_id, sum(points)::integer
from public.customer_point_events
group by customer_id, shop_id
on conflict (customer_id) do update set points = excluded.points;
