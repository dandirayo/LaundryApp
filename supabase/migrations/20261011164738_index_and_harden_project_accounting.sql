-- Trigger helpers are internal; clients use table operations or the exposed RPCs.
revoke all on function public.sync_project_payment_cash() from public, anon, authenticated;
revoke all on function public.validate_project_child() from public, anon, authenticated;
revoke all on function public.validate_order_item_incentive() from public, anon, authenticated;

create index laundry_projects_customer_idx on public.laundry_projects(customer_id);
create index laundry_project_batches_shop_date_idx
on public.laundry_project_batches(shop_id, processed_at desc);
create index laundry_project_batches_employee_idx
on public.laundry_project_batches(employee_id) where employee_id is not null;
create index laundry_project_payments_shop_date_idx
on public.laundry_project_payments(shop_id, created_at desc);
create index laundry_project_payments_created_by_idx
on public.laundry_project_payments(created_by) where created_by is not null;
create index order_item_incentives_employee_idx
on public.order_item_incentives(employee_id, earned_at desc);
create index order_item_incentives_order_idx
on public.order_item_incentives(order_id);
create index order_items_incentive_employee_idx
on public.order_items(incentive_employee_id) where incentive_employee_id is not null;
