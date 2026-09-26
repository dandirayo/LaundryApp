-- Unit-price update transcribed from the three owner-confirmed handwritten pages.
-- All KG services and historical order-item snapshots remain unchanged.
create temporary table _handwritten_unit_catalog (
  local_id text not null,
  old_item_name text,
  old_variant_name text,
  old_unit text,
  category_name text not null,
  item_name text not null,
  variant_name text not null,
  unit text not null,
  price integer not null check (price > 0),
  sort_order integer not null,
  target_id uuid
) on commit drop;

insert into _handwritten_unit_catalog (
  local_id, old_item_name, old_variant_name, old_unit,
  category_name, item_name, variant_name, unit, price, sort_order
)
values
  ('service-pakaian-kaos-sedang-normal', 'Kaos', 'Sedang Normal', 'PIECE', 'Pakaian', 'Kaos', 'Normal', 'PIECE', 10000, 126),
  ('service-pakaian-kaos-sedang-bagus', 'Kaos', 'Sedang Bagus', 'PIECE', 'Pakaian', 'Kaos', 'Bagus', 'PIECE', 15000, 127),
  ('service-pakaian-kaos-besar-normal', 'Kaos', 'Besar Normal', 'PIECE', 'Pakaian', 'Kaos', 'Besar Normal', 'PIECE', 15000, 128),
  ('service-setelan-atasan-bawahan-baju-damkar-cuci-setrika', 'Baju Damkar', 'Cuci Setrika', 'SET', 'Setelan (Atasan + Bawahan)', 'Baju Damkar', 'Reguler', 'SET', 30000, 142),
  ('service-perlengkapan-tidur-sprei-small', 'Sprei', 'Small', 'PIECE', 'Perlengkapan Tidur', 'Sprei Saja', '', 'PIECE', 10000, 166),
  ('service-perlengkapan-tidur-sprei-medium', 'Sprei', 'Medium', 'PIECE', 'Perlengkapan Tidur', 'Sprei Set', 'Sedang', 'PIECE', 15000, 167),
  ('service-perlengkapan-tidur-bed-cover-sedang-katun', 'Bed Cover', 'Sedang Katun', 'PIECE', 'Perlengkapan Tidur', 'Bed Cover', 'Sedang', 'PIECE', 25000, 168),
  ('service-perlengkapan-tidur-bed-cover-besar-katun', 'Bed Cover', 'Besar Katun', 'PIECE', 'Perlengkapan Tidur', 'Bed Cover', 'Besar', 'PIECE', 30000, 169),
  ('service-perlengkapan-tidur-bed-cover-besar-bulu-angsa', 'Bed Cover', 'Besar Bulu Angsa', 'PIECE', 'Perlengkapan Tidur', 'Bed Cover', 'Jumbo', 'PIECE', 35000, 170),
  ('service-handuk-handuk-kecil', 'Handuk', 'Kecil', 'PIECE', 'Handuk', 'Handuk', 'Kecil', 'PIECE', 5000, 172),
  ('service-handuk-handuk-sedang', 'Handuk', 'Sedang', 'PIECE', 'Handuk', 'Handuk', 'Sedang', 'PIECE', 7500, 173),
  ('service-handuk-handuk-besar', 'Handuk', 'Besar', 'PIECE', 'Handuk', 'Handuk', 'Besar', 'PIECE', 10000, 174),
  ('service-perlengkapan-rumah-karpet-per-m2', 'Karpet', 'per m2', 'M2', 'Perlengkapan Rumah', 'Karpet', 'Tebal', 'M', 20000, 199),
  ('service-kain-dan-gorden-gorden', 'Gorden', '', 'M2', 'Kain dan Gorden', 'Kain Gorden', 'Dalam', 'M', 3500, 205),
  ('service-kain-dan-gorden-gorden-setrika-saja', 'Gorden', 'Setrika Saja', 'M2', 'Kain dan Gorden', 'Kain Gorden', 'Tipis', 'M', 5000, 206),
  ('service-tas-tas-ransel-kecil', 'Tas Ransel', 'Kecil', 'PIECE', 'Tas', 'Tas Ransel', 'Kecil', 'PIECE', 25000, 207),
  ('service-tas-tas-ransel-sedang', 'Tas Ransel', 'Sedang', 'PIECE', 'Tas', 'Tas Ransel', 'Sedang', 'PIECE', 35000, 208),
  ('service-tas-tas-ransel-besar', 'Tas Ransel', 'Besar', 'PIECE', 'Tas', 'Tas Ransel', 'Besar', 'PIECE', 45000, 209),
  ('service-boneka-boneka-xs', 'Boneka', 'XS', 'PIECE', 'Boneka', 'Boneka', 'XS', 'PIECE', 10000, 213),
  ('service-boneka-boneka-s', 'Boneka', 'S', 'PIECE', 'Boneka', 'Boneka', 'S', 'PIECE', 15000, 214),
  ('service-boneka-boneka-m', 'Boneka', 'M', 'PIECE', 'Boneka', 'Boneka', 'M', 'PIECE', 20000, 215),
  ('service-boneka-boneka-l', 'Boneka', 'L', 'PIECE', 'Boneka', 'Boneka', 'L', 'PIECE', 25000, 216),
  ('service-boneka-boneka-xl', 'Boneka', 'XL', 'PIECE', 'Boneka', 'Boneka', 'XL', 'PIECE', 35000, 217),
  ('service-sepatu-reguler', 'Cuci Sepatu', 'Reguler', 'PAIR', 'Sepatu', 'Sepatu', 'Biasa', 'PAIR', 35000, 218),
  ('service-helm-reguler', 'Cuci Helm', 'Reguler', 'ITEM', 'Helm', 'Helm', '', 'ITEM', 35000, 219),
  ('service-setelan-atasan-bawahan-baju-damkar-kilat', null, null, null, 'Setelan (Atasan + Bawahan)', 'Baju Damkar', 'Kilat', 'SET', 40000, 247),
  ('service-setelan-atasan-bawahan-baju-tentara-reguler', null, null, null, 'Setelan (Atasan + Bawahan)', 'Baju Tentara', 'Reguler', 'SET', 30000, 248),
  ('service-setelan-atasan-bawahan-baju-tentara-kilat', null, null, null, 'Setelan (Atasan + Bawahan)', 'Baju Tentara', 'Kilat', 'SET', 40000, 249),
  ('service-perlengkapan-tidur-sprei-set-besar', null, null, null, 'Perlengkapan Tidur', 'Sprei Set', 'Besar', 'PIECE', 20000, 250),
  ('service-handuk-handuk-jumbo', null, null, null, 'Handuk', 'Handuk', 'Jumbo', 'PIECE', 15000, 251),
  ('service-perlengkapan-rumah-karpet-tipis', null, null, null, 'Perlengkapan Rumah', 'Karpet', 'Tipis', 'M', 15000, 252),
  ('service-kain-dan-gorden-gorden-tebal', null, null, null, 'Kain dan Gorden', 'Kain Gorden', 'Tebal', 'M', 7500, 253),
  ('service-boneka-boneka-xxl', null, null, null, 'Boneka', 'Boneka', 'XXL', 'PIECE', 50000, 254),
  ('service-boneka-boneka-xxxl', null, null, null, 'Boneka', 'Boneka', 'XXXL', 'PIECE', 70000, 255),
  ('service-sepatu-bagus', null, null, null, 'Sepatu', 'Sepatu', 'Bagus', 'PAIR', 40000, 256);

update _handwritten_unit_catalog d
set target_id = (
  select s.id
  from public.services s
  where d.old_item_name is not null
    and s.shop_id = '00000000-0000-0000-0000-000000000001'
    and s.item_name = d.old_item_name
    and trim(concat_ws(' ', nullif(s.size_variant, ''), nullif(s.material_variant, ''))) = d.old_variant_name
    and upper(s.unit) = d.old_unit
  order by s.is_active desc, s.created_at, s.id
  limit 1
);

update public.services s
set category_id = category.id,
    category_name = d.category_name,
    item_name = d.item_name,
    size_variant = d.variant_name,
    material_variant = '',
    unit = d.unit,
    price = d.price,
    estimated_hours = 72,
    is_express = d.variant_name = 'Kilat',
    is_active = true,
    sort_order = d.sort_order
from _handwritten_unit_catalog d
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
       d.variant_name, '', d.unit, d.price, 72,
       d.variant_name = 'Kilat', true, d.sort_order
from _handwritten_unit_catalog d
join public.service_categories category
  on category.shop_id = '00000000-0000-0000-0000-000000000001'
 and category.name = 'Satuan'
where d.target_id is null;
