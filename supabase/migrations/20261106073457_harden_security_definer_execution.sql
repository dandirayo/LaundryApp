-- SECURITY DEFINER helpers are part of RLS and remain available to signed-in
-- users. Anonymous callers must not be able to invoke them directly.
revoke execute on function public.current_shop_id() from public, anon;
revoke execute on function public.current_role() from public, anon;
revoke execute on function public.current_employee_id() from public, anon;

grant execute on function public.current_shop_id() to authenticated, service_role;
grant execute on function public.current_role() to authenticated, service_role;
grant execute on function public.current_employee_id() to authenticated, service_role;

-- These RPCs validate the authenticated user and shop inside their bodies.
-- Keep the app-facing grant, but remove the accidental anonymous surface.
revoke execute on function public.adjust_inventory_stock(
  uuid,
  numeric,
  text,
  text
) from public, anon;
revoke execute on function public.record_order_payment(
  uuid,
  integer,
  text
) from public, anon;

grant execute on function public.adjust_inventory_stock(
  uuid,
  numeric,
  text,
  text
) to authenticated, service_role;
grant execute on function public.record_order_payment(
  uuid,
  integer,
  text
) to authenticated, service_role;

-- Trigger functions are invoked by Postgres, not through the REST API.
revoke execute on function public.write_audit_log()
  from public, anon, authenticated;
grant execute on function public.write_audit_log() to service_role;

-- Intentional exception: the sign-in screen uses this restricted directory
-- before authentication. Its body exposes only the login-picker fields.
revoke execute on function public.get_login_employees() from public;
grant execute on function public.get_login_employees()
  to anon, authenticated, service_role;
