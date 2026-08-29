-- MANUAL DATABASE CHANGE REQUIRED: apply this migration to the linked project.
-- Adds durable navigation metadata without changing existing notification rows.
alter table public.notifications
  add column if not exists reference_type text not null default '',
  add column if not exists reference_id uuid;

create index if not exists idx_notifications_reference
  on public.notifications(shop_id, reference_type, reference_id)
  where reference_id is not null;

grant select, update, delete on table public.notifications to authenticated;
alter table public.notifications enable row level security;
