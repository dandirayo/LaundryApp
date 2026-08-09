-- Fix permanen agar Owner dapat membuat akun karyawan lewat Edge Function.
-- Jalankan di Supabase SQL Editor.

grant usage on schema public to anon, authenticated;
grant select, insert, update, delete on public.employees to authenticated;
grant select, insert, update, delete on public.profiles to authenticated;

drop policy if exists "owners insert employee profiles" on public.profiles;
create policy "owners insert employee profiles"
on public.profiles for insert
with check (
  shop_id = public.current_shop_id()
  and public.current_role() = 'OWNER'
  and role = 'EMPLOYEE'
);

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

drop policy if exists "owners manage employees" on public.employees;
create policy "owners manage employees"
on public.employees for all
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');
