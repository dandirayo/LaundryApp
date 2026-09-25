-- Notification functions are invoked by database triggers only. Keep clients
-- from calling them directly while preserving trigger execution by the owner.
revoke all on function public.notify_request_workflow() from public, anon, authenticated;
revoke all on function public.notify_order_workflow() from public, anon, authenticated;
