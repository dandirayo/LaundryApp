-- 1. expenses table
create table if not exists public.expenses (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  description text not null,
  category text not null default 'Operasional',
  amount integer not null check (amount > 0),
  method text not null default 'Tunai',
  created_by uuid references public.employees(id) on delete set null,
  created_at timestamptz not null default now()
);

-- 2. payroll_payments table  
create table if not exists public.payroll_payments (
  id uuid primary key default gen_random_uuid(),
  shop_id uuid not null references public.shops(id) on delete cascade,
  employee_id uuid not null references public.employees(id) on delete cascade,
  period_start date not null,
  period_end date not null,
  amount integer not null check (amount > 0),
  method text not null default 'Tunai',
  paid_by uuid references public.profiles(id) on delete set null,
  paid_at timestamptz not null default now(),
  note text not null default '',
  unique (shop_id, employee_id, period_start)
);

-- 3. RLS for expenses
alter table public.expenses enable row level security;
create policy "expenses read own shop" on public.expenses for select using (shop_id = public.current_shop_id());
create policy "members insert expenses" on public.expenses for insert with check (shop_id = public.current_shop_id());
create policy "owner manage expenses" on public.expenses for update using (shop_id = public.current_shop_id());
create policy "owner delete expenses" on public.expenses for delete using (shop_id = public.current_shop_id());

-- 4. RLS for payroll_payments
alter table public.payroll_payments enable row level security;
create policy "payroll read own shop" on public.payroll_payments for select using (shop_id = public.current_shop_id());
create policy "owner insert payroll" on public.payroll_payments for insert with check (shop_id = public.current_shop_id());
create policy "owner update payroll" on public.payroll_payments for update using (shop_id = public.current_shop_id());
create policy "owner delete payroll" on public.payroll_payments for delete using (shop_id = public.current_shop_id());

-- 5. Trigger: auto-create cash_transaction when expense is inserted
create or replace function public.expense_to_cash_transaction()
returns trigger
language plpgsql
security definer
as $$
begin
  insert into public.cash_transactions (shop_id, type, category, description, amount, method, reference_type, reference_id)
  values (NEW.shop_id, 'OUT', NEW.category, NEW.description, NEW.amount, NEW.method, 'EXPENSE', NEW.id);
  return NEW;
end;
$$;

create trigger trg_expense_to_cash
after insert on public.expenses
for each row execute function public.expense_to_cash_transaction();

-- 6. Trigger: auto-create cash_transaction when payroll payment is inserted
create or replace function public.payroll_to_cash_transaction()
returns trigger
language plpgsql
security definer
as $$
declare
  emp_name text;
begin
  select name into emp_name from public.employees where id = NEW.employee_id;
  insert into public.cash_transactions (shop_id, type, category, description, amount, method, reference_type, reference_id)
  values (NEW.shop_id, 'OUT', 'Gaji', 'Gaji mingguan ' || coalesce(emp_name, 'Karyawan'), NEW.amount, NEW.method, 'PAYROLL', NEW.id);
  return NEW;
end;
$$;

create trigger trg_payroll_to_cash
after insert on public.payroll_payments
for each row execute function public.payroll_to_cash_transaction();

-- 7. Add owner update/delete policies for cash_transactions if not exists
do $$ begin
  if not exists (select 1 from pg_policies where tablename = 'cash_transactions' and policyname = 'owner update cash') then
    create policy "owner update cash" on public.cash_transactions for update using (shop_id = public.current_shop_id());
  end if;
  if not exists (select 1 from pg_policies where tablename = 'cash_transactions' and policyname = 'owner delete cash') then
    create policy "owner delete cash" on public.cash_transactions for delete using (shop_id = public.current_shop_id());
  end if;
end $$;

-- 8. Realtime for new tables
alter publication supabase_realtime add table public.expenses;
alter publication supabase_realtime add table public.payroll_payments;

-- 9. Grant permissions
grant all on public.expenses to anon, authenticated, service_role;
grant all on public.payroll_payments to anon, authenticated, service_role;
