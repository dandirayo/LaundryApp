-- Idola Laundry only. No order snapshots, payments, or kilogram prices are changed.
-- Match existing IDs first so historical service references remain valid.
create temporary table _idola_service_catalog (
  local_id text not null,
  previous_id uuid,
  category_name text not null,
  item_name text not null,
  size_variant text not null,
  unit text not null,
  price integer not null,
  estimated_hours integer not null,
  is_express boolean not null,
  sort_order integer not null,
  target_id uuid
) on commit drop;

insert into _idola_service_catalog (
  local_id, previous_id, category_name, item_name, size_variant, unit,
  price, estimated_hours, is_express, sort_order
) values
  ('service-pakaian-rok-cuci-setrika', null, 'Pakaian', 'Rok', 'Cuci Setrika', 'PIECE', 15000, 72, false, 109),
  ('service-pakaian-rok-setrika-saja', null, 'Pakaian', 'Rok', 'Setrika Saja', 'PIECE', 10000, 72, false, 110),
  ('service-pakaian-kemeja-cuci-setrika', '93b3774b-4a3c-4bb7-b1d2-b6fea7cfa8af', 'Pakaian', 'Kemeja', 'Cuci Setrika', 'PIECE', 15000, 72, false, 111),
  ('service-pakaian-kemeja-setrika-saja', null, 'Pakaian', 'Kemeja', 'Setrika Saja', 'PIECE', 10000, 72, false, 112),
  ('service-pakaian-kerudung-kecil-s-m-l-cuci-setrika', null, 'Pakaian', 'Kerudung Kecil (S, M, L)', 'Cuci Setrika', 'PIECE', 15000, 72, false, 113),
  ('service-pakaian-kerudung-kecil-s-m-l-setrika-saja', null, 'Pakaian', 'Kerudung Kecil (S, M, L)', 'Setrika Saja', 'PIECE', 10000, 72, false, 114),
  ('service-pakaian-kerudung-besar-xl-xxl-cuci-setrika', null, 'Pakaian', 'Kerudung Besar (XL, XXL)', 'Cuci Setrika', 'PIECE', 20000, 72, false, 115),
  ('service-pakaian-kerudung-besar-xl-xxl-setrika-saja', null, 'Pakaian', 'Kerudung Besar (XL, XXL)', 'Setrika Saja', 'PIECE', 15000, 72, false, 116),
  ('service-pakaian-bandana', null, 'Pakaian', 'Bandana', '', 'PIECE', 5000, 72, false, 117),
  ('service-pakaian-daleman-baju-pengantin', null, 'Pakaian', 'Daleman Baju Pengantin', '', 'PIECE', 15000, 72, false, 118),
  ('service-pakaian-gaun-pengantin', null, 'Pakaian', 'Gaun Pengantin', '', 'PIECE', 50000, 72, false, 119),
  ('service-pakaian-kamisol', null, 'Pakaian', 'Kamisol', '', 'PIECE', 10000, 72, false, 120),
  ('service-pakaian-kamisol-anak', null, 'Pakaian', 'Kamisol Anak', '', 'PIECE', 5000, 72, false, 121),
  ('service-pakaian-pashmina', null, 'Pakaian', 'Pashmina', '', 'PIECE', 15000, 72, false, 122),
  ('service-pakaian-rompi', null, 'Pakaian', 'Rompi', '', 'PIECE', 15000, 72, false, 123),
  ('service-pakaian-rompi-anak', null, 'Pakaian', 'Rompi Anak', '', 'PIECE', 10000, 72, false, 124),
  ('service-pakaian-wearpack', null, 'Pakaian', 'Wearpack', '', 'PIECE', 20000, 72, false, 125),
  ('service-pakaian-kaos-sedang-normal', '44c84078-a452-4e13-8740-5e894c760b6a', 'Pakaian', 'Kaos', 'Sedang Normal', 'PIECE', 5000, 72, false, 126),
  ('service-pakaian-kaos-sedang-bagus', '4f84ea94-7584-4250-b93f-cffd38720955', 'Pakaian', 'Kaos', 'Sedang Bagus', 'PIECE', 7000, 72, false, 127),
  ('service-pakaian-kaos-besar-normal', '04b5c781-753f-44ce-9d2b-8bf98cf0013a', 'Pakaian', 'Kaos', 'Besar Normal', 'PIECE', 6000, 72, false, 128),
  ('service-pakaian-celana-panjang-normal', 'c41191cc-1449-4399-b0eb-9403a27a2abe', 'Pakaian', 'Celana Panjang', 'Normal', 'PIECE', 20000, 72, false, 129),
  ('service-setelan-atasan-bawahan-kaos-celana-cuci-setrika', null, 'Setelan (Atasan + Bawahan)', 'Kaos + Celana', 'Cuci Setrika', 'SET', 25000, 72, false, 130),
  ('service-setelan-atasan-bawahan-kaos-celana-setrika-saja', null, 'Setelan (Atasan + Bawahan)', 'Kaos + Celana', 'Setrika Saja', 'SET', 15000, 72, false, 131),
  ('service-setelan-atasan-bawahan-kemeja-celana-panjang-cuci-setrika', null, 'Setelan (Atasan + Bawahan)', 'Kemeja + Celana Panjang', 'Cuci Setrika', 'SET', 25000, 72, false, 132),
  ('service-setelan-atasan-bawahan-kemeja-celana-panjang-setrika-saja', null, 'Setelan (Atasan + Bawahan)', 'Kemeja + Celana Panjang', 'Setrika Saja', 'SET', 15000, 72, false, 133),
  ('service-setelan-atasan-bawahan-jas-celana-panjang-cuci-setrika', null, 'Setelan (Atasan + Bawahan)', 'Jas + Celana Panjang', 'Cuci Setrika', 'SET', 40000, 72, false, 134),
  ('service-setelan-atasan-bawahan-jas-celana-panjang-setrika-saja', null, 'Setelan (Atasan + Bawahan)', 'Jas + Celana Panjang', 'Setrika Saja', 'SET', 25000, 72, false, 135),
  ('service-setelan-atasan-bawahan-kebaya-panjang-sarung-cuci-setrika', null, 'Setelan (Atasan + Bawahan)', 'Kebaya Panjang + Sarung', 'Cuci Setrika', 'SET', 35000, 72, false, 136),
  ('service-setelan-atasan-bawahan-kebaya-panjang-sarung-setrika-saja', null, 'Setelan (Atasan + Bawahan)', 'Kebaya Panjang + Sarung', 'Setrika Saja', 'SET', 25000, 72, false, 137),
  ('service-setelan-atasan-bawahan-kebaya-pendek-sarung-cuci-setrika', null, 'Setelan (Atasan + Bawahan)', 'Kebaya Pendek + Sarung', 'Cuci Setrika', 'SET', 25000, 72, false, 138),
  ('service-setelan-atasan-bawahan-kebaya-pendek-sarung-setrika-saja', null, 'Setelan (Atasan + Bawahan)', 'Kebaya Pendek + Sarung', 'Setrika Saja', 'SET', 15000, 72, false, 139),
  ('service-setelan-atasan-bawahan-baju-koko-sarung-cuci-setrika', null, 'Setelan (Atasan + Bawahan)', 'Baju Koko + Sarung', 'Cuci Setrika', 'SET', 30000, 72, false, 140),
  ('service-setelan-atasan-bawahan-baju-koko-sarung-setrika-saja', null, 'Setelan (Atasan + Bawahan)', 'Baju Koko + Sarung', 'Setrika Saja', 'SET', 20000, 72, false, 141),
  ('service-setelan-atasan-bawahan-baju-damkar-cuci-setrika', null, 'Setelan (Atasan + Bawahan)', 'Baju Damkar', 'Cuci Setrika', 'SET', 25000, 72, false, 142),
  ('service-jas-dan-jaket-jas-cuci-setrika', null, 'Jas dan Jaket', 'Jas', 'Cuci Setrika', 'PIECE', 25000, 72, false, 143),
  ('service-jas-dan-jaket-jas-setrika-saja', null, 'Jas dan Jaket', 'Jas', 'Setrika Saja', 'PIECE', 15000, 72, false, 144),
  ('service-jas-dan-jaket-blazer-cuci-setrika', null, 'Jas dan Jaket', 'Blazer', 'Cuci Setrika', 'PIECE', 25000, 72, false, 145),
  ('service-jas-dan-jaket-jaket-cuci-setrika', '7235c481-9baf-4b51-9509-c87a138e0cb3', 'Jas dan Jaket', 'Jaket', 'Cuci Setrika', 'PIECE', 20000, 72, false, 146),
  ('service-jas-dan-jaket-jaket-setrika-saja', null, 'Jas dan Jaket', 'Jaket', 'Setrika Saja', 'PIECE', 15000, 72, false, 147),
  ('service-jas-dan-jaket-hoodie-cuci-setrika', null, 'Jas dan Jaket', 'Hoodie', 'Cuci Setrika', 'PIECE', 20000, 72, false, 148),
  ('service-jas-dan-jaket-hoodie-setrika-saja', null, 'Jas dan Jaket', 'Hoodie', 'Setrika Saja', 'PIECE', 15000, 72, false, 149),
  ('service-jas-dan-jaket-sweater-cuci-setrika', null, 'Jas dan Jaket', 'Sweater', 'Cuci Setrika', 'PIECE', 20000, 72, false, 150),
  ('service-jas-dan-jaket-sweater-setrika-saja', null, 'Jas dan Jaket', 'Sweater', 'Setrika Saja', 'PIECE', 15000, 72, false, 151),
  ('service-jas-dan-jaket-jaket-kulit', null, 'Jas dan Jaket', 'Jaket Kulit', '', 'PIECE', 50000, 72, false, 152),
  ('service-jas-dan-jaket-jaket-tebal-bulu', '787b0bbf-91b0-4814-aac8-b4f1043e31d3', 'Jas dan Jaket', 'Jaket', 'Tebal/Bulu', 'PIECE', 35000, 72, false, 153),
  ('service-perlengkapan-tidur-sprei-besar-160-180-200-cuci-setrika', '2901a4c4-609b-47d2-952e-c4f02cb6b36b', 'Perlengkapan Tidur', 'Sprei Besar (160, 180, 200)', 'Cuci Setrika', 'PIECE', 15000, 72, false, 154),
  ('service-perlengkapan-tidur-sprei-besar-160-180-200-setrika-saja', null, 'Perlengkapan Tidur', 'Sprei Besar (160, 180, 200)', 'Setrika Saja', 'PIECE', 9000, 72, false, 155),
  ('service-perlengkapan-tidur-sprei-balon-cuci-setrika', null, 'Perlengkapan Tidur', 'Sprei Balon', 'Cuci Setrika', 'PIECE', 20000, 72, false, 156),
  ('service-perlengkapan-tidur-sprei-balon-setrika-saja', null, 'Perlengkapan Tidur', 'Sprei Balon', 'Setrika Saja', 'PIECE', 12000, 72, false, 157),
  ('service-perlengkapan-tidur-selimut-kecil-90-100-120-cuci-setrika', null, 'Perlengkapan Tidur', 'Selimut Kecil (90, 100, 120)', 'Cuci Setrika', 'PIECE', 10000, 72, false, 158),
  ('service-perlengkapan-tidur-selimut-kecil-90-100-120-setrika-saja', null, 'Perlengkapan Tidur', 'Selimut Kecil (90, 100, 120)', 'Setrika Saja', 'PIECE', 6000, 72, false, 159),
  ('service-perlengkapan-tidur-selimut-besar-160-180-200-cuci-setrika', null, 'Perlengkapan Tidur', 'Selimut Besar (160, 180, 200)', 'Cuci Setrika', 'PIECE', 15000, 72, false, 160),
  ('service-perlengkapan-tidur-selimut-besar-160-180-200-setrika-saja', null, 'Perlengkapan Tidur', 'Selimut Besar (160, 180, 200)', 'Setrika Saja', 'PIECE', 9000, 72, false, 161),
  ('service-perlengkapan-tidur-alas-kasur-springbed', null, 'Perlengkapan Tidur', 'Alas Kasur Springbed', '', 'PIECE', 15000, 72, false, 162),
  ('service-perlengkapan-tidur-kelambu-tempat-tidur-besar', null, 'Perlengkapan Tidur', 'Kelambu Tempat Tidur Besar', '', 'PIECE', 25000, 72, false, 163),
  ('service-perlengkapan-tidur-kelambu-tempat-tidur-sedang', null, 'Perlengkapan Tidur', 'Kelambu Tempat Tidur Sedang', '', 'PIECE', 20000, 72, false, 164),
  ('service-perlengkapan-tidur-kelambu-tempat-tidur-kecil', null, 'Perlengkapan Tidur', 'Kelambu Tempat Tidur Kecil', '', 'PIECE', 15000, 72, false, 165),
  ('service-perlengkapan-tidur-sprei-small', 'c8a9ffbb-a9de-4267-8e92-1d65d2fef76b', 'Perlengkapan Tidur', 'Sprei', 'Small', 'PIECE', 10000, 72, false, 166),
  ('service-perlengkapan-tidur-sprei-medium', '80db9556-379c-47c7-93a5-1c54a34fa946', 'Perlengkapan Tidur', 'Sprei', 'Medium', 'PIECE', 13000, 72, false, 167),
  ('service-perlengkapan-tidur-bed-cover-sedang-katun', 'ac75a24e-492f-4595-b91d-5af093f9970e', 'Perlengkapan Tidur', 'Bed Cover', 'Sedang Katun', 'PIECE', 35000, 72, false, 168),
  ('service-perlengkapan-tidur-bed-cover-besar-katun', '9afbed4b-0f17-448a-80fd-42de427d7ec0', 'Perlengkapan Tidur', 'Bed Cover', 'Besar Katun', 'PIECE', 50000, 72, false, 169),
  ('service-perlengkapan-tidur-bed-cover-besar-bulu-angsa', '7f9ab418-a298-47ab-9321-55fe6e9f98f5', 'Perlengkapan Tidur', 'Bed Cover', 'Besar Bulu Angsa', 'PIECE', 130000, 72, false, 170),
  ('service-perlengkapan-tidur-selimut-tebal', '29c9696a-bc50-401f-9a16-5b76600b8561', 'Perlengkapan Tidur', 'Selimut', 'Tebal', 'PIECE', 15000, 72, false, 171),
  ('service-handuk-handuk-kecil', '47b68af6-507a-4f01-bf24-757fac6b6158', 'Handuk', 'Handuk', 'Kecil', 'PIECE', 10000, 72, false, 172),
  ('service-handuk-handuk-sedang', null, 'Handuk', 'Handuk', 'Sedang', 'PIECE', 15000, 72, false, 173),
  ('service-handuk-handuk-besar', '415c7789-cdce-4199-be6e-46d70af38a0e', 'Handuk', 'Handuk', 'Besar', 'PIECE', 20000, 72, false, 174),
  ('service-perlengkapan-ibadah-mukena-cuci-setrika', null, 'Perlengkapan Ibadah', 'Mukena', 'Cuci Setrika', 'SET', 20000, 72, false, 175),
  ('service-perlengkapan-ibadah-mukena-setrika-saja', null, 'Perlengkapan Ibadah', 'Mukena', 'Setrika Saja', 'SET', 15000, 72, false, 176),
  ('service-perlengkapan-ibadah-sajadah-tipis-cuci-setrika', null, 'Perlengkapan Ibadah', 'Sajadah Tipis', 'Cuci Setrika', 'PIECE', 10000, 72, false, 177),
  ('service-perlengkapan-ibadah-sajadah-tipis-setrika-saja', null, 'Perlengkapan Ibadah', 'Sajadah Tipis', 'Setrika Saja', 'PIECE', 6000, 72, false, 178),
  ('service-perlengkapan-ibadah-sajadah-tebal-cuci-setrika', null, 'Perlengkapan Ibadah', 'Sajadah Tebal', 'Cuci Setrika', 'PIECE', 15000, 72, false, 179),
  ('service-perlengkapan-ibadah-sajadah-tebal-setrika-saja', null, 'Perlengkapan Ibadah', 'Sajadah Tebal', 'Setrika Saja', 'PIECE', 9000, 72, false, 180),
  ('service-perlengkapan-bayi-alas-box-bayi', null, 'Perlengkapan Bayi', 'Alas Box Bayi', '', 'PIECE', 20000, 72, false, 181),
  ('service-perlengkapan-bayi-alas-keranjang-bayi', null, 'Perlengkapan Bayi', 'Alas Keranjang Bayi', '', 'PIECE', 10000, 72, false, 182),
  ('service-perlengkapan-bayi-baby-walker', null, 'Perlengkapan Bayi', 'Baby Walker', '', 'PIECE', 30000, 72, false, 183),
  ('service-perlengkapan-bayi-bemper-bayi-kecil', null, 'Perlengkapan Bayi', 'Bemper Bayi Kecil', '', 'PIECE', 15000, 72, false, 184),
  ('service-perlengkapan-bayi-bemper-bayi-sedang', null, 'Perlengkapan Bayi', 'Bemper Bayi Sedang', '', 'PIECE', 20000, 72, false, 185),
  ('service-perlengkapan-bayi-boks-bayi', null, 'Perlengkapan Bayi', 'Boks Bayi', '', 'PIECE', 50000, 72, false, 186),
  ('service-perlengkapan-bayi-busa-alas-keranjang-bayi', null, 'Perlengkapan Bayi', 'Busa Alas Keranjang Bayi', '', 'PIECE', 15000, 72, false, 187),
  ('service-perlengkapan-bayi-perlak', null, 'Perlengkapan Bayi', 'Perlak', '', 'PIECE', 15000, 72, false, 188),
  ('service-perlengkapan-rumah-alas-piring-meja-makan', null, 'Perlengkapan Rumah', 'Alas Piring Meja Makan', '', 'PIECE', 5000, 72, false, 189),
  ('service-perlengkapan-rumah-alas-sofa', null, 'Perlengkapan Rumah', 'Alas Sofa', '', 'PIECE', 10000, 72, false, 190),
  ('service-perlengkapan-rumah-bantal-kursi', null, 'Perlengkapan Rumah', 'Bantal Kursi', '', 'PIECE', 15000, 72, false, 191),
  ('service-perlengkapan-rumah-bantal-lantai', null, 'Perlengkapan Rumah', 'Bantal Lantai', '', 'PIECE', 20000, 72, false, 192),
  ('service-perlengkapan-rumah-bantalan-tempat-duduk', null, 'Perlengkapan Rumah', 'Bantalan Tempat Duduk', '', 'PIECE', 30000, 72, false, 193),
  ('service-perlengkapan-rumah-kap-lampu-besar', null, 'Perlengkapan Rumah', 'Kap Lampu Besar', '', 'PIECE', 20000, 72, false, 194),
  ('service-perlengkapan-rumah-kap-lampu-sedang', null, 'Perlengkapan Rumah', 'Kap Lampu Sedang', '', 'PIECE', 15000, 72, false, 195),
  ('service-perlengkapan-rumah-keset-tebal', null, 'Perlengkapan Rumah', 'Keset Tebal', '', 'PIECE', 10000, 72, false, 196),
  ('service-perlengkapan-rumah-keset-tipis', null, 'Perlengkapan Rumah', 'Keset Tipis', '', 'PIECE', 5000, 72, false, 197),
  ('service-perlengkapan-rumah-tikar', null, 'Perlengkapan Rumah', 'Tikar', '', 'PIECE', 25000, 72, false, 198),
  ('service-perlengkapan-rumah-karpet-per-m2', '259697b6-c190-4d7c-9b4d-52dccdc3a6c1', 'Perlengkapan Rumah', 'Karpet', 'per m2', 'M2', 47000, 72, false, 199),
  ('service-kain-dan-gorden-kain-3-m', null, 'Kain dan Gorden', 'Kain (<3 m)', '', 'PIECE', 15000, 72, false, 200),
  ('service-kain-dan-gorden-kain-pantai', null, 'Kain dan Gorden', 'Kain Pantai', '', 'PIECE', 15000, 72, false, 201),
  ('service-kain-dan-gorden-kain-payung', null, 'Kain dan Gorden', 'Kain Payung', '', 'PIECE', 15000, 72, false, 202),
  ('service-kain-dan-gorden-kain-songket', null, 'Kain dan Gorden', 'Kain Songket', '', 'PIECE', 15000, 72, false, 203),
  ('service-kain-dan-gorden-kain-ulos', null, 'Kain dan Gorden', 'Kain Ulos', '', 'PIECE', 15000, 72, false, 204),
  ('service-kain-dan-gorden-gorden', null, 'Kain dan Gorden', 'Gorden', '', 'M2', 15000, 72, false, 205),
  ('service-kain-dan-gorden-gorden-setrika-saja', null, 'Kain dan Gorden', 'Gorden', 'Setrika Saja', 'M2', 9000, 72, false, 206),
  ('service-tas-tas-ransel-kecil', null, 'Tas', 'Tas Ransel', 'Kecil', 'PIECE', 10000, 72, false, 207),
  ('service-tas-tas-ransel-sedang', null, 'Tas', 'Tas Ransel', 'Sedang', 'PIECE', 15000, 72, false, 208),
  ('service-tas-tas-ransel-besar', null, 'Tas', 'Tas Ransel', 'Besar', 'PIECE', 20000, 72, false, 209),
  ('service-perlengkapan-kendaraan-bantalan-sandaran-mobil', null, 'Perlengkapan Kendaraan', 'Bantalan Sandaran Mobil', '', 'PIECE', 10000, 72, false, 210),
  ('service-perlengkapan-kendaraan-cover-tutup-mobil', null, 'Perlengkapan Kendaraan', 'Cover (Tutup) Mobil', '', 'PIECE', 25000, 72, false, 211),
  ('service-perlengkapan-kendaraan-cover-tutup-motor', null, 'Perlengkapan Kendaraan', 'Cover (Tutup) Motor', '', 'PIECE', 20000, 72, false, 212),
  ('service-boneka-boneka-xs', 'be87a1ae-e6e6-4ffa-abce-cafb7efdc30f', 'Boneka', 'Boneka', 'XS', 'PIECE', 38000, 72, false, 213),
  ('service-boneka-boneka-s', 'fa71113e-210f-487b-bea3-6f837ecd0ac1', 'Boneka', 'Boneka', 'S', 'PIECE', 45000, 72, false, 214),
  ('service-boneka-boneka-m', 'e2494b28-0099-450b-b5aa-6a014302af63', 'Boneka', 'Boneka', 'M', 'PIECE', 53000, 72, false, 215),
  ('service-boneka-boneka-l', '6babd30e-571a-43ee-934f-f1dbee226e0f', 'Boneka', 'Boneka', 'L', 'PIECE', 67000, 72, false, 216),
  ('service-boneka-boneka-xl', '32033377-4037-4a14-aed7-c457b5ba8704', 'Boneka', 'Boneka', 'XL', 'PIECE', 158000, 72, false, 217),
  ('service-sepatu-reguler', null, 'Sepatu', 'Cuci Sepatu', 'Reguler', 'PAIR', 25000, 72, false, 218),
  ('service-helm-reguler', null, 'Helm', 'Cuci Helm', 'Reguler', 'ITEM', 20000, 72, false, 219),
  ('service-lainnya-bendera-besar', null, 'Lainnya', 'Bendera Besar', '', 'PIECE', 20000, 72, false, 220),
  ('service-lainnya-bendera-kecil', null, 'Lainnya', 'Bendera Kecil', '', 'PIECE', 15000, 72, false, 221),
  ('service-lainnya-body-protector', null, 'Lainnya', 'Body Protector', '', 'PIECE', 50000, 72, false, 222),
  ('service-lainnya-bendera-meteran', null, 'Lainnya', 'Bendera', 'Meteran', 'M2', 5000, 72, false, 223),
  ('service-extra-express', null, 'Layanan Tambahan', 'Express', 'Tambahan', 'ITEM', 5000, 24, true, 224),
  ('service-extra-noda-berat', null, 'Layanan Tambahan', 'Noda Berat', 'Tambahan', 'ITEM', 5000, 72, false, 225);

insert into public.service_categories (shop_id, name, sort_order, is_active)
select shop.id, root.name, root.sort_order, true
from public.shops shop
cross join (values ('Kiloan', 10), ('Satuan', 20)) root(name, sort_order)
where shop.id = '00000000-0000-0000-0000-000000000001'
on conflict (shop_id, name)
do update set sort_order = excluded.sort_order, is_active = true;

update _idola_service_catalog d
set target_id = (
  select s.id from public.services s
  where s.shop_id = '00000000-0000-0000-0000-000000000001'
    and upper(s.unit) = d.unit
    and (
      s.id = d.previous_id or (
        s.item_name = d.item_name
        and trim(concat_ws(' ', nullif(s.size_variant, ''), nullif(s.material_variant, ''))) = d.size_variant
      )
    )
  order by (s.id = d.previous_id) desc nulls last, s.is_active desc, s.created_at, s.id
  limit 1
);

-- Retire only exact duplicates of the catalog variants; never delete services.
update public.services s
set is_active = false
from _idola_service_catalog d
where s.shop_id = '00000000-0000-0000-0000-000000000001'
  and s.id is distinct from d.target_id
  and s.item_name = d.item_name
  and trim(concat_ws(' ', nullif(s.size_variant, ''), nullif(s.material_variant, ''))) = d.size_variant
  and upper(s.unit) = d.unit;

update public.services s
set category_id = category.id,
    category_name = d.category_name,
    item_name = d.item_name,
    size_variant = d.size_variant,
    material_variant = '',
    unit = d.unit,
    price = d.price,
    estimated_hours = d.estimated_hours,
    is_express = d.is_express,
    is_active = true,
    sort_order = d.sort_order
from _idola_service_catalog d
join public.service_categories category
  on category.shop_id = '00000000-0000-0000-0000-000000000001'
 and category.name = case when d.unit = 'KG' then 'Kiloan' else 'Satuan' end
where s.id = d.target_id;

insert into public.services (
  shop_id, category_id, category_name, item_name, size_variant,
  material_variant, unit, price, estimated_hours, is_express, is_active, sort_order
)
select category.shop_id, category.id, d.category_name, d.item_name, d.size_variant,
       '', d.unit, d.price, d.estimated_hours, d.is_express, true, d.sort_order
from _idola_service_catalog d
join public.service_categories category
  on category.shop_id = '00000000-0000-0000-0000-000000000001'
 and category.name = case when d.unit = 'KG' then 'Kiloan' else 'Satuan' end
where d.target_id is null;

-- Group any custom services by billing unit without changing their prices.
update public.services s
set category_id = category.id
from public.service_categories category
where s.shop_id = '00000000-0000-0000-0000-000000000001'
  and category.shop_id = s.shop_id
  and category.name = case when upper(s.unit) = 'KG' then 'Kiloan' else 'Satuan' end
  and s.category_id is distinct from category.id;

update public.service_categories category
set is_active = false
where category.shop_id = '00000000-0000-0000-0000-000000000001'
  and category.name not in ('Kiloan', 'Satuan');
