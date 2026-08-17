-- Support the unified request workflow and keep employee data isolated.
create or replace function public.current_employee_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select employee_id from public.profiles where id = auth.uid()
$$;

grant execute on function public.current_employee_id() to authenticated;

drop policy if exists "requests read own shop" on public.employee_requests;
drop policy if exists "members insert requests" on public.employee_requests;

create policy "owners read shop requests employees read own"
on public.employee_requests for select
using (
  shop_id = public.current_shop_id()
  and (
    public.current_role() = 'OWNER'
    or employee_id = public.current_employee_id()
  )
);

create policy "employees insert own requests"
on public.employee_requests for insert
with check (
  shop_id = public.current_shop_id()
  and employee_id = public.current_employee_id()
  and public.current_role() = 'EMPLOYEE'
);

create index if not exists idx_employee_requests_employee_created
  on public.employee_requests(employee_id, created_at desc);

do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'employee_requests'
  ) then
    alter publication supabase_realtime add table public.employee_requests;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'employees'
  ) then
    alter publication supabase_realtime add table public.employees;
  end if;

  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'inventory_items'
  ) then
    alter publication supabase_realtime add table public.inventory_items;
  end if;
end
$$;
