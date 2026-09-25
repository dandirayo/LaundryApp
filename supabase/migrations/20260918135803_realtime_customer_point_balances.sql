do $$
begin
  if not exists (
    select 1 from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'customer_point_balances'
  ) then
    alter publication supabase_realtime
      add table public.customer_point_balances;
  end if;
end
$$;
