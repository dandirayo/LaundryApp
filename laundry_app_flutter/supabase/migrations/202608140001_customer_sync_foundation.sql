alter table public.customers
  add column if not exists updated_at timestamptz not null default now(),
  add column if not exists deleted_at timestamptz,
  add column if not exists deleted_by uuid references public.profiles(id) on delete set null;

alter table public.customers
  alter column phone drop not null,
  alter column phone drop default,
  alter column normalized_phone drop not null,
  alter column normalized_phone drop default;

update public.customers
set phone = null
where btrim(coalesce(phone, '')) = '';

update public.customers
set normalized_phone = null
where btrim(coalesce(normalized_phone, '')) = '';

create index if not exists idx_customers_shop_created
  on public.customers(shop_id, created_at desc)
  where deleted_at is null;

create index if not exists idx_customers_shop_updated
  on public.customers(shop_id, updated_at desc)
  where deleted_at is null;

create index if not exists idx_customers_shop_normalized_phone
  on public.customers(shop_id, normalized_phone)
  where normalized_phone is not null and deleted_at is null;

do $$
begin
  alter publication supabase_realtime add table public.customers;
exception
  when duplicate_object then null;
  when undefined_object then null;
end $$;
