-- Keep every table used by a Postgres Changes subscription in the
-- supabase_realtime publication. The catalog check makes this migration safe
-- when a table was already enabled manually from the Supabase dashboard.
do $$
declare
  table_name text;
begin
  foreach table_name in array array[
    'attendance_records',
    'order_items',
    'payments',
    'profiles'
  ]
  loop
    if not exists (
      select 1
      from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = table_name
    ) then
      execute format(
        'alter publication supabase_realtime add table public.%I',
        table_name
      );
    end if;
  end loop;
end
$$;
