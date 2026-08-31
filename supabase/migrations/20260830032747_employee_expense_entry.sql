drop policy if exists "owners select expenses" on public.expenses;
drop policy if exists "owners insert expenses" on public.expenses;
drop policy if exists "owners update expenses" on public.expenses;
drop policy if exists "owners delete expenses" on public.expenses;
drop policy if exists "employees select own expenses" on public.expenses;
drop policy if exists "employees insert own expenses" on public.expenses;

create policy "owners select expenses"
on public.expenses for select to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "owners insert expenses"
on public.expenses for insert to authenticated
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "owners update expenses"
on public.expenses for update to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER')
with check (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "owners delete expenses"
on public.expenses for delete to authenticated
using (shop_id = public.current_shop_id() and public.current_role() = 'OWNER');

create policy "employees select own expenses"
on public.expenses for select to authenticated
using (
  shop_id = public.current_shop_id()
  and public.current_role() = 'EMPLOYEE'
  and created_by = public.current_employee_id()
);

create policy "employees insert own expenses"
on public.expenses for insert to authenticated
with check (
  shop_id = public.current_shop_id()
  and public.current_role() = 'EMPLOYEE'
  and created_by = public.current_employee_id()
  and coalesce(source_type, '') = ''
);
