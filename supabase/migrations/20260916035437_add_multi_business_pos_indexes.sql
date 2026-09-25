create index if not exists businesses_owner_id_idx
  on public.businesses (owner_id);

create index if not exists business_daily_operations_updated_by_idx
  on public.business_daily_operations (updated_by);

create index if not exists pos_sale_items_product_id_idx
  on public.pos_sale_items (product_id);

create index if not exists pos_sales_sold_by_idx
  on public.pos_sales (sold_by);
