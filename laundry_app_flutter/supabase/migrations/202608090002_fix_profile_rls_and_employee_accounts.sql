-- Fix recursive profile RLS and add fields required by employee login accounts.
alter table public.employees
  add column if not exists position text not null default 'Operator';

alter table public.profiles
  add column if not exists username text;

create unique index if not exists profiles_username_unique
  on public.profiles (lower(username))
  where username is not null;

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on all tables in schema public to authenticated;
grant usage, select on all sequences in schema public to authenticated;
alter default privileges in schema public
  grant select, insert, update, delete on tables to authenticated;
alter default privileges in schema public
  grant usage, select on sequences to authenticated;

create or replace function public.current_shop_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select shop_id from public.profiles where id = auth.uid()
$$;

create or replace function public.current_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select role from public.profiles where id = auth.uid()
$$;

revoke all on function public.current_shop_id() from public;
revoke all on function public.current_role() from public;
grant execute on function public.current_shop_id() to authenticated;
grant execute on function public.current_role() to authenticated;

drop policy if exists "profiles read own shop" on public.profiles;
create policy "profiles read own shop"
on public.profiles for select
using (id = auth.uid() or shop_id = public.current_shop_id());

drop policy if exists "profiles update self" on public.profiles;
create policy "profiles update self"
on public.profiles for update
using (
  id = auth.uid()
  or (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
)
with check (shop_id = public.current_shop_id());
