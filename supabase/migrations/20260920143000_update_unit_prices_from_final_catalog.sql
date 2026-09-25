-- Apply the verified unit-price rows from "Harga Satuan Laundry Update Final".
-- Kilogram services and historical order-item snapshots are intentionally unchanged.
create temporary table _final_unit_catalog (
  local_id text not null,
  category_name text not null,
  item_name text not null,
  variant_name text not null,
  unit text not null,
  price integer not null check (price > 0),
  sort_order integer not null,
  target_id uuid
) on commit drop;

insert into _final_unit_catalog
  (local_id, category_name, item_name, variant_name, unit, price, sort_order)
values
  ('sprei-besar-160-cuci-setrika', 'Perlengkapan Tidur', 'Sprei Besar', '160x200 Cuci Setrika', 'PIECE', 15000, 154),
  ('sprei-besar-180-cuci-setrika', 'Perlengkapan Tidur', 'Sprei Besar', '180x200 Cuci Setrika', 'PIECE', 15000, 155),
  ('sprei-besar-200-cuci-setrika', 'Perlengkapan Tidur', 'Sprei Besar', '200x200 Cuci Setrika', 'PIECE', 15000, 156),
  ('service-pakaian-baju-muslim', 'Pakaian', 'Baju Muslim', '', 'PIECE', 15000, 226),
  ('service-pakaian-baju-muslim-panjang', 'Pakaian', 'Baju Muslim Panjang', '', 'PIECE', 20000, 227),
  ('service-pakaian-baju-balet-anak', 'Pakaian', 'Baju Balet Anak', '', 'PIECE', 15000, 228),
  ('service-pakaian-baju-bayi', 'Pakaian', 'Baju Bayi', '', 'PIECE', 5000, 229),
  ('service-pakaian-baju-kaos', 'Pakaian', 'Baju Kaos', '', 'PIECE', 15000, 230),
  ('service-pakaian-baju-ihrom', 'Pakaian', 'Baju Ihrom', '', 'PIECE', 15000, 231),
  ('service-pakaian-baju-koko', 'Pakaian', 'Baju Koko', '', 'PIECE', 10000, 232),
  ('service-pakaian-baju-lab', 'Pakaian', 'Baju Lab', '', 'PIECE', 20000, 233),
  ('service-pakaian-baju-muslim-selutut', 'Pakaian', 'Baju Muslim Selutut', '', 'PIECE', 15000, 234),
  ('service-pakaian-baju-renang', 'Pakaian', 'Baju Renang', '', 'PIECE', 15000, 235),
  ('service-pakaian-baju-safari', 'Pakaian', 'Baju Safari', '', 'PIECE', 15000, 236),
  ('service-pakaian-baju-tidur', 'Pakaian', 'Baju Tidur', '', 'PIECE', 15000, 237),
  ('service-pakaian-celana-panjang', 'Pakaian', 'Celana Panjang', '', 'PIECE', 15000, 238),
  ('service-pakaian-celana-pendek', 'Pakaian', 'Celana Pendek', '', 'PIECE', 15000, 239),
  ('service-pakaian-celana-bayi', 'Pakaian', 'Celana Bayi', '', 'PIECE', 5000, 240),
  ('service-pakaian-daster', 'Pakaian', 'Daster', '', 'PIECE', 20000, 241),
  ('service-pakaian-gamis', 'Pakaian', 'Gamis', '', 'PIECE', 20000, 242),
  ('service-pakaian-gaun', 'Pakaian', 'Gaun', '', 'PIECE', 25000, 243),
  ('service-pakaian-kebaya-pendek', 'Pakaian', 'Kebaya Pendek', '', 'PIECE', 15000, 244),
  ('service-pakaian-kebaya-panjang', 'Pakaian', 'Kebaya Panjang', '', 'PIECE', 20000, 245),
  ('service-kain-dan-gorden-kain-3-m-meter', 'Kain dan Gorden', 'Kain (>3 M) / Meter', '', 'M2', 3000, 246);

update _final_unit_catalog d
set target_id = (
  select s.id
  from public.services s
  where s.shop_id = '00000000-0000-0000-0000-000000000001'
    and upper(s.unit) = d.unit
    and s.item_name = d.item_name
    and trim(concat_ws(' ', nullif(s.size_variant, ''), nullif(s.material_variant, ''))) = d.variant_name
  order by s.is_active desc, s.created_at, s.id
  limit 1
);

update public.services s
set category_id = category.id,
    category_name = d.category_name,
    item_name = d.item_name,
    unit = d.unit,
    price = d.price,
    estimated_hours = 72,
    is_express = false,
    is_active = true,
    sort_order = d.sort_order
from _final_unit_catalog d
join public.service_categories category
  on category.shop_id = '00000000-0000-0000-0000-000000000001'
 and category.name = 'Satuan'
where s.id = d.target_id;

insert into public.services (
  shop_id, category_id, category_name, item_name, size_variant,
  material_variant, unit, price, estimated_hours, is_express, is_active,
  sort_order
)
select category.shop_id, category.id, d.category_name, d.item_name,
       d.variant_name, '', d.unit, d.price, 72, false, true, d.sort_order
from _final_unit_catalog d
join public.service_categories category
  on category.shop_id = '00000000-0000-0000-0000-000000000001'
 and category.name = 'Satuan'
where d.target_id is null;
