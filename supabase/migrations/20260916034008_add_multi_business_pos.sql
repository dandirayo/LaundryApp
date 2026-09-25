create schema if not exists private;
revoke all on schema private from public;
grant usage on schema private to authenticated;

create table public.businesses (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  owner_id uuid not null references public.profiles(id) on delete cascade,
  name text not null check (length(btrim(name)) between 2 and 80),
  kind text not null check (kind in ('laundry', 'beverage')),
  status text not null default 'active' check (status in ('active', 'inactive')),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index businesses_one_laundry_per_shop
  on public.businesses (shop_id)
  where kind = 'laundry';
create unique index businesses_unique_name_per_shop
  on public.businesses (shop_id, lower(name));

create table public.business_members (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  profile_id uuid not null references public.profiles(id) on delete cascade,
  is_active boolean not null default true,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, profile_id)
);

create index business_members_profile_id_idx
  on public.business_members (profile_id, is_active);

create table public.pos_products (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  name text not null check (length(btrim(name)) between 2 and 100),
  category text not null default 'Minuman',
  price integer not null default 0 check (price >= 0),
  is_active boolean not null default true,
  sort_order integer not null default 0,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, name)
);

create index pos_products_business_active_idx
  on public.pos_products (business_id, is_active, sort_order, name);

create table public.pos_sales (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  sale_number text not null,
  total integer not null check (total >= 0),
  payment_method text not null default 'Tunai'
    check (payment_method in ('Tunai', 'Transfer', 'QRIS')),
  notes text not null default '',
  sold_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  unique (business_id, sale_number)
);

create index pos_sales_business_created_idx
  on public.pos_sales (business_id, created_at desc);

create table public.pos_sale_items (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  sale_id uuid not null references public.pos_sales(id) on delete cascade,
  product_id uuid references public.pos_products(id) on delete set null,
  product_name text not null,
  quantity integer not null check (quantity > 0),
  unit_price integer not null check (unit_price >= 0),
  subtotal integer not null check (subtotal >= 0)
);

create index pos_sale_items_sale_id_idx on public.pos_sale_items (sale_id);
create index pos_sale_items_business_id_idx
  on public.pos_sale_items (business_id);

create table public.business_daily_operations (
  id uuid primary key default gen_random_uuid(),
  business_id uuid not null references public.businesses(id) on delete cascade,
  operation_date date not null default current_date,
  is_open boolean not null default true,
  note text not null default '',
  updated_by uuid not null references public.profiles(id) on delete restrict,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique (business_id, operation_date)
);

create index business_daily_operations_date_idx
  on public.business_daily_operations (business_id, operation_date desc);

create trigger businesses_touch_updated_at
before update on public.businesses
for each row execute function public.touch_updated_at();

create trigger business_members_touch_updated_at
before update on public.business_members
for each row execute function public.touch_updated_at();

create trigger pos_products_touch_updated_at
before update on public.pos_products
for each row execute function public.touch_updated_at();

create trigger business_daily_operations_touch_updated_at
before update on public.business_daily_operations
for each row execute function public.touch_updated_at();

create or replace function private.can_access_business(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.businesses as business
      join public.profiles as profile
        on profile.id = (select auth.uid())
       and profile.shop_id = business.shop_id
       and profile.is_active
      where business.id = p_business_id
        and (
          business.owner_id = (select auth.uid())
          or exists (
            select 1
            from public.business_members as member
            where member.business_id = business.id
              and member.profile_id = (select auth.uid())
              and member.is_active
          )
        )
    )
$$;

create or replace function private.is_business_owner(p_business_id uuid)
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select
    (select auth.uid()) is not null
    and exists (
      select 1
      from public.businesses as business
      join public.profiles as profile
        on profile.id = (select auth.uid())
       and profile.shop_id = business.shop_id
       and profile.role = 'OWNER'
       and profile.is_active
      where business.id = p_business_id
        and business.owner_id = (select auth.uid())
    )
$$;

revoke all on function private.can_access_business(uuid) from public;
revoke all on function private.is_business_owner(uuid) from public;
grant execute on function private.can_access_business(uuid) to authenticated;
grant execute on function private.is_business_owner(uuid) to authenticated;

alter table public.businesses enable row level security;
alter table public.business_members enable row level security;
alter table public.pos_products enable row level security;
alter table public.pos_sales enable row level security;
alter table public.pos_sale_items enable row level security;
alter table public.business_daily_operations enable row level security;

create policy "members read businesses"
on public.businesses for select to authenticated
using (private.can_access_business(id));

create policy "owners create businesses"
on public.businesses for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and shop_id = public.current_shop_id()
  and public.current_role() = 'OWNER'
);

create policy "owners update businesses"
on public.businesses for update to authenticated
using (private.is_business_owner(id))
with check (
  private.is_business_owner(id)
  and owner_id = (select auth.uid())
  and shop_id = public.current_shop_id()
);

create policy "members read business assignments"
on public.business_members for select to authenticated
using (private.can_access_business(business_id));

create policy "owners add business assignments"
on public.business_members for insert to authenticated
with check (
  private.is_business_owner(business_id)
  and exists (
    select 1
    from public.businesses as business
    join public.profiles as profile
      on profile.id = business_members.profile_id
    where business.id = business_members.business_id
      and profile.shop_id = business.shop_id
      and profile.is_active
  )
);

create policy "owners update business assignments"
on public.business_members for update to authenticated
using (private.is_business_owner(business_id))
with check (private.is_business_owner(business_id));

create policy "owners delete business assignments"
on public.business_members for delete to authenticated
using (private.is_business_owner(business_id));

create policy "members read pos products"
on public.pos_products for select to authenticated
using (private.can_access_business(business_id));

create policy "owners create pos products"
on public.pos_products for insert to authenticated
with check (private.is_business_owner(business_id));

create policy "owners update pos products"
on public.pos_products for update to authenticated
using (private.is_business_owner(business_id))
with check (private.is_business_owner(business_id));

create policy "owners delete pos products"
on public.pos_products for delete to authenticated
using (private.is_business_owner(business_id));

create policy "members read pos sales"
on public.pos_sales for select to authenticated
using (private.can_access_business(business_id));

create policy "members create pos sales"
on public.pos_sales for insert to authenticated
with check (
  private.can_access_business(business_id)
  and sold_by = (select auth.uid())
);

create policy "members read pos sale items"
on public.pos_sale_items for select to authenticated
using (private.can_access_business(business_id));

create policy "members create pos sale items"
on public.pos_sale_items for insert to authenticated
with check (
  private.can_access_business(business_id)
  and exists (
    select 1
    from public.pos_sales as sale
    where sale.id = pos_sale_items.sale_id
      and sale.business_id = pos_sale_items.business_id
  )
  and (
    product_id is null
    or exists (
      select 1
      from public.pos_products as product
      where product.id = pos_sale_items.product_id
        and product.business_id = pos_sale_items.business_id
    )
  )
);

create policy "members read daily operations"
on public.business_daily_operations for select to authenticated
using (private.can_access_business(business_id));

create policy "members create daily operations"
on public.business_daily_operations for insert to authenticated
with check (
  private.can_access_business(business_id)
  and updated_by = (select auth.uid())
);

create policy "members update daily operations"
on public.business_daily_operations for update to authenticated
using (private.can_access_business(business_id))
with check (
  private.can_access_business(business_id)
  and updated_by = (select auth.uid())
);

grant select, insert, update on table public.businesses to authenticated;
grant select, insert, delete on table public.business_members to authenticated;
grant update (is_active, updated_at)
  on table public.business_members to authenticated;
grant select, insert, update, delete on table public.pos_products to authenticated;
grant select on table public.pos_sales to authenticated;
grant select on table public.pos_sale_items to authenticated;
grant select, insert on table public.business_daily_operations to authenticated;
grant update (is_open, note, updated_by, updated_at)
  on table public.business_daily_operations to authenticated;

create or replace function public.create_pos_sale(
  p_business_id uuid,
  p_payment_method text,
  p_notes text,
  p_items jsonb
)
returns uuid
language plpgsql
security definer
set search_path = ''
as $$
declare
  v_sale_id uuid;
  v_sale_number text;
  v_total integer;
  v_valid_items integer;
begin
  if (select auth.uid()) is null
    or not private.can_access_business(p_business_id)
    or not exists (
      select 1
      from public.businesses as business
      where business.id = p_business_id
        and business.kind = 'beverage'
        and business.status = 'active'
    ) then
    raise exception 'Anda tidak memiliki akses ke usaha ini.';
  end if;
  if p_payment_method not in ('Tunai', 'Transfer', 'QRIS') then
    raise exception 'Metode pembayaran tidak valid.';
  end if;
  if jsonb_typeof(p_items) <> 'array' or jsonb_array_length(p_items) = 0 then
    raise exception 'Keranjang masih kosong.';
  end if;

  select coalesce(sum(product.price * requested.quantity), 0), count(*)
  into v_total, v_valid_items
  from jsonb_to_recordset(p_items) as requested(product_id uuid, quantity integer)
  join public.pos_products as product
    on product.id = requested.product_id
   and product.business_id = p_business_id
   and product.is_active
  where requested.quantity > 0;

  if v_valid_items <> jsonb_array_length(p_items) or v_total <= 0 then
    raise exception 'Produk atau jumlah pesanan tidak valid.';
  end if;

  v_sale_number := 'POS-' || to_char(clock_timestamp(), 'YYYYMMDD-HH24MISS-MS')
    || '-' || substr(gen_random_uuid()::text, 1, 4);

  insert into public.pos_sales (
    business_id, sale_number, total, payment_method, notes, sold_by
  ) values (
    p_business_id,
    v_sale_number,
    v_total,
    p_payment_method,
    coalesce(btrim(p_notes), ''),
    (select auth.uid())
  )
  returning id into v_sale_id;

  insert into public.pos_sale_items (
    business_id, sale_id, product_id, product_name,
    quantity, unit_price, subtotal
  )
  select
    p_business_id,
    v_sale_id,
    product.id,
    product.name,
    requested.quantity,
    product.price,
    product.price * requested.quantity
  from jsonb_to_recordset(p_items) as requested(product_id uuid, quantity integer)
  join public.pos_products as product
    on product.id = requested.product_id
   and product.business_id = p_business_id
   and product.is_active
  where requested.quantity > 0;

  return v_sale_id;
end;
$$;

revoke all on function public.create_pos_sale(uuid, text, text, jsonb) from public;
revoke all on function public.create_pos_sale(uuid, text, text, jsonb) from anon;
grant execute on function public.create_pos_sale(uuid, text, text, jsonb)
  to authenticated;

insert into public.businesses (shop_id, owner_id, name, kind, status)
select profile.shop_id, profile.id, shop.name, 'laundry', 'active'
from public.profiles as profile
join public.shops as shop on shop.id = profile.shop_id
where profile.role = 'OWNER'
on conflict do nothing;

insert into public.businesses (shop_id, owner_id, name, kind, status)
select profile.shop_id, profile.id, 'Es Teh Manis', 'beverage', 'active'
from public.profiles as profile
where profile.role = 'OWNER'
on conflict do nothing;

insert into public.business_members (business_id, profile_id, is_active)
select business.id, profile.id, true
from public.businesses as business
join public.profiles as profile on profile.shop_id = business.shop_id
where business.kind = 'laundry'
on conflict (business_id, profile_id) do nothing;

insert into public.business_members (business_id, profile_id, is_active)
select business.id, business.owner_id, true
from public.businesses as business
where business.kind = 'beverage'
on conflict (business_id, profile_id) do nothing;

insert into public.pos_products (
  business_id, name, category, price, sort_order
)
select business.id, product.name, 'Minuman', product.price, product.sort_order
from public.businesses as business
cross join (
  values
    ('Es Teh Manis', 5000, 10),
    ('Es Teh Jumbo', 7000, 20),
    ('Es Teh Lemon', 8000, 30),
    ('Teh Tawar', 3000, 40)
) as product(name, price, sort_order)
where business.kind = 'beverage'
on conflict (business_id, name) do nothing;
