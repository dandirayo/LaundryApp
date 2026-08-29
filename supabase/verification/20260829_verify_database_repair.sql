-- Read-only verification for 20260829051637_repair_database_consistency.sql.
-- Run the whole file in Supabase SQL Editor after the migration commits.

with required_realtime(table_name) as (
  select unnest(array[
    'cash_transactions',
    'customers',
    'employee_requests',
    'expenses',
    'inventory_items',
    'inventory_movements',
    'notifications',
    'orders',
    'payroll_payments',
    'weekly_shifts'
  ])
), required_triggers(table_name, trigger_name) as (
  values
    ('payments', 'trg_sync_payment_cash'),
    ('expenses', 'trg_sync_expense_cash'),
    ('payroll_payments', 'trg_validate_payroll_payment'),
    ('payroll_payments', 'trg_sync_payroll_cash'),
    ('employee_requests', 'trg_sync_employee_request_cash'),
    ('orders', 'trg_sync_order_status_financials')
), required_policies(table_name, policy_name) as (
  values
    ('expenses', 'owners select expenses'),
    ('expenses', 'owners insert expenses'),
    ('payroll_payments', 'owners select payroll'),
    ('payroll_payments', 'owners insert payroll'),
    ('cash_transactions', 'owners manage cash transactions'),
    ('employee_requests', 'owners read shop requests employees read own'),
    ('employee_requests', 'employees insert own requests'),
    ('employee_requests', 'owners update requests'),
    ('attendance_records', 'owners read shop attendance employees read own'),
    ('attendance_records', 'employees insert own attendance'),
    ('weekly_shifts', 'members read relevant weekly shifts'),
    ('weekly_shifts', 'owners insert weekly shifts'),
    ('weekly_shifts', 'owners update weekly shifts'),
    ('weekly_shifts', 'owners delete weekly shifts'),
    ('inventory_items', 'inventory items read own shop'),
    ('inventory_items', 'owners insert inventory items'),
    ('inventory_items', 'owners update inventory items'),
    ('inventory_items', 'owners delete inventory items'),
    ('notifications', 'members read targeted notifications')
), checks(check_name, passed, details) as (
  values
    (
      'payroll_payments exists',
      to_regclass('public.payroll_payments') is not null,
      coalesce(to_regclass('public.payroll_payments')::text, 'missing')
    ),
    (
      'payroll_payments Flutter columns',
      (
        select count(*) = 10
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'payroll_payments'
          and column_name in (
            'id', 'shop_id', 'employee_id', 'period_start', 'period_end',
            'amount', 'method', 'paid_by', 'paid_at', 'note'
          )
      ),
      'expected 10 repository columns'
    ),
    (
      'customers.phone nullable',
      (
        select is_nullable = 'YES'
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'customers'
          and column_name = 'phone'
      ),
      'customers.phone must accept NULL'
    ),
    (
      'customers.normalized_phone nullable',
      (
        select is_nullable = 'YES'
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'customers'
          and column_name = 'normalized_phone'
      ),
      'customers.normalized_phone must accept NULL'
    ),
    (
      'orders.customer_phone_snapshot non-null',
      (
        select is_nullable = 'NO'
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'orders'
          and column_name = 'customer_phone_snapshot'
      ),
      'snapshot remains text NOT NULL with empty-string fallback'
    ),
    (
      'create_laundry_order exists',
      to_regprocedure(
        'public.create_laundry_order(uuid,uuid,text,timestamptz,integer,text,jsonb)'
      ) is not null,
      'expected seven-argument RPC'
    ),
    (
      'create_laundry_order coalesces phone',
      position(
        'coalesce(nullif(btrim(v_customer.phone), ''''), '''')'
        in lower(coalesce(pg_get_functiondef(to_regprocedure(
          'public.create_laundry_order(uuid,uuid,text,timestamptz,integer,text,jsonb)'
        )), ''))
      ) > 0,
      'RPC definition must convert NULL/blank phone to empty snapshot'
    ),
    (
      'record_order_payment uses payment trigger',
      position(
        'insert into public.cash_transactions'
        in lower(coalesce(pg_get_functiondef(to_regprocedure(
          'public.record_order_payment(uuid,integer,text)'
        )), ''))
      ) = 0,
      'RPC must not also insert a second cash row'
    ),
    (
      'required Realtime tables published',
      not exists (
        select 1
        from required_realtime required
        where not exists (
          select 1
          from pg_publication_tables published
          where published.pubname = 'supabase_realtime'
            and published.schemaname = 'public'
            and published.tablename = required.table_name
        )
      ),
      'all ten Flutter subscription tables'
    ),
    (
      'required triggers enabled',
      not exists (
        select 1
        from required_triggers required
        where not exists (
          select 1
          from pg_trigger trigger
          join pg_class relation on relation.oid = trigger.tgrelid
          join pg_namespace namespace on namespace.oid = relation.relnamespace
          where namespace.nspname = 'public'
            and relation.relname = required.table_name
            and trigger.tgname = required.trigger_name
            and not trigger.tgisinternal
            and trigger.tgenabled <> 'D'
        )
      ),
      'payment, expense, payroll, request, and order-status triggers'
    ),
    (
      'required RLS policies exist',
      not exists (
        select 1
        from required_policies required
        where not exists (
          select 1
          from pg_policies policy
          where policy.schemaname = 'public'
            and policy.tablename = required.table_name
            and policy.policyname = required.policy_name
        )
      ),
      'Owner/Employee policy set'
    ),
    (
      'RLS enabled on repaired tables',
      not exists (
        select 1
        from unnest(array[
          'shops', 'profiles', 'employees', 'service_categories', 'services',
          'customers', 'orders', 'order_items', 'cashbook_entries',
          'shop_settings', 'cash_closings', 'audit_logs', 'expenses',
          'payroll_payments', 'cash_transactions', 'payments',
          'employee_requests', 'attendance_records', 'weekly_shifts',
          'inventory_items', 'inventory_movements', 'notifications'
        ]) as expected(table_name)
        where not coalesce((
          select relation.relrowsecurity
          from pg_class relation
          join pg_namespace namespace on namespace.oid = relation.relnamespace
          where namespace.nspname = 'public'
            and relation.relname = expected.table_name
        ), false)
      ),
      'all exposed operational tables'
    ),
    (
      'no duplicate one-to-one cash source',
      not exists (
        select 1
        from public.cash_transactions
        where reference_id is not null
          and reference_type in ('EXPENSE', 'PAYROLL', 'PAYMENT', 'EMPLOYEE_REQUEST')
        group by shop_id, reference_type, reference_id
        having count(*) > 1
      ),
      'one cash row per source UUID'
    ),
    (
      'authenticated Data API grants',
      has_table_privilege('authenticated', 'public.payroll_payments', 'SELECT')
      and has_table_privilege('authenticated', 'public.payroll_payments', 'INSERT')
      and has_table_privilege('authenticated', 'public.expenses', 'SELECT')
      and has_table_privilege('authenticated', 'public.expenses', 'INSERT')
      and has_table_privilege('authenticated', 'public.cash_transactions', 'SELECT'),
      'explicit grants required by current Supabase Data API defaults'
    ),
    (
      'anon cannot access financial tables',
      not has_table_privilege('anon', 'public.payroll_payments', 'SELECT')
      and not has_table_privilege('anon', 'public.expenses', 'SELECT')
      and not has_table_privilege('anon', 'public.cash_transactions', 'SELECT'),
      'financial tables are not anonymous API endpoints'
    ),
    (
      'legacy cashbook is not application-writable',
      not has_table_privilege('authenticated', 'public.cashbook_entries', 'INSERT')
      and not has_table_privilege('authenticated', 'public.cashbook_entries', 'UPDATE')
      and not has_table_privilege('authenticated', 'public.cashbook_entries', 'DELETE'),
      'cash_transactions is the single application cash ledger'
    ),
    (
      'employees PIN is not exposed',
      not exists (
        select 1
        from information_schema.columns
        where table_schema = 'public'
          and table_name = 'employees'
          and column_name = 'pin'
          and (
            has_column_privilege('authenticated', 'public.employees', 'pin', 'SELECT')
            or has_column_privilege('authenticated', 'public.employees', 'pin', 'INSERT')
            or has_column_privilege('authenticated', 'public.employees', 'pin', 'UPDATE')
          )
      ),
      'login secrets remain in Supabase Auth, never an authenticated table column'
    ),
    (
      'attendance bucket is private',
      exists (
        select 1
        from storage.buckets
        where id = 'attendance-photos'
          and public = false
      ),
      'attendance-photos must exist as a private bucket'
    ),
    (
      'attendance storage policies exist',
      (
        select count(*) = 3
        from pg_policies
        where schemaname = 'storage'
          and tablename = 'objects'
          and policyname in (
            'members upload attendance photos',
            'members read attendance photos',
            'members delete attendance photos'
          )
      ),
      'shop/employee scoped upload, read, and cleanup policies'
    ),
    (
      'deduplication archive is protected',
      to_regclass('public.database_repair_archive') is not null
      and not has_table_privilege(
        'authenticated', 'public.database_repair_archive', 'SELECT'
      )
      and not has_table_privilege(
        'authenticated', 'public.database_repair_archive', 'INSERT'
      ),
      'removed duplicate rows remain recoverable only by service role/database admin'
    )
)
select
  case when passed then 'PASS' else 'FAIL' end as status,
  check_name,
  details
from checks
order by passed, check_name;

-- Detail: exact Realtime publication membership.
select schemaname, tablename
from pg_publication_tables
where pubname = 'supabase_realtime'
order by schemaname, tablename;

-- Detail: enabled non-internal triggers on the repaired tables.
select
  namespace.nspname as schema_name,
  relation.relname as table_name,
  trigger.tgname as trigger_name,
  trigger.tgenabled
from pg_trigger trigger
join pg_class relation on relation.oid = trigger.tgrelid
join pg_namespace namespace on namespace.oid = relation.relnamespace
where namespace.nspname = 'public'
  and relation.relname in (
    'payments', 'expenses', 'payroll_payments',
    'employee_requests', 'orders'
  )
  and not trigger.tgisinternal
order by relation.relname, trigger.tgname;

-- Detail: policies and target roles.
select schemaname, tablename, policyname, roles, cmd, qual, with_check
from pg_policies
where schemaname = 'public'
  and tablename in (
    'expenses', 'payroll_payments', 'cash_transactions', 'payments',
    'employee_requests', 'attendance_records', 'weekly_shifts',
    'inventory_items', 'inventory_movements', 'notifications'
  )
order by tablename, policyname;
