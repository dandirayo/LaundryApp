-- Jalankan file ini di Supabase SQL Editor untuk memastikan akun Owner
-- yang dipakai login memiliki profile OWNER aktif.

-- 1. Lihat semua user Auth dan profile yang tersambung.
select
  u.id as auth_user_id,
  u.email,
  p.full_name,
  p.role,
  p.is_active,
  p.shop_id,
  p.employee_id
from auth.users u
left join public.profiles p on p.id = u.id
order by u.created_at desc;

-- 2. Pastikan data toko utama ada.
insert into public.shops (id, name, phone, address)
values (
  '00000000-0000-0000-0000-000000000001',
  'Idola Laundry',
  '0812-2000-3075',
  'Bekasi'
)
on conflict (id) do update set
  name = excluded.name,
  phone = excluded.phone,
  address = excluded.address;

-- 3. Pastikan data employee Owner ada.
insert into public.employees (
  id,
  shop_id,
  name,
  phone,
  position,
  role,
  shift_start,
  shift_end,
  late_tolerance_minutes,
  weekly_salary,
  is_active
)
values (
  '20000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'Owner Idola',
  '0812-2000-3075',
  'Owner',
  'OWNER',
  '06:00',
  '20:00',
  120,
  0,
  true
)
on conflict (id) do update set
  name = excluded.name,
  phone = excluded.phone,
  position = excluded.position,
  role = excluded.role,
  shift_start = excluded.shift_start,
  shift_end = excluded.shift_end,
  late_tolerance_minutes = excluded.late_tolerance_minutes,
  is_active = true;

-- 4. Ganti UUID di bawah kalau auth_user_id Owner kamu berbeda.
insert into public.profiles (
  id,
  shop_id,
  employee_id,
  full_name,
  role,
  is_active,
  phone,
  username
)
values (
  'c06fd99f-84f8-412c-9c95-49db26bacfce',
  '00000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'Owner Idola',
  'OWNER',
  true,
  '0812-2000-3075',
  'owner'
)
on conflict (id) do update set
  shop_id = excluded.shop_id,
  employee_id = excluded.employee_id,
  full_name = excluded.full_name,
  role = 'OWNER',
  is_active = true,
  phone = excluded.phone,
  username = excluded.username;

-- 5. Cek hasil akhir.
select id, full_name, role, is_active, shop_id, employee_id, username
from public.profiles
where id = 'c06fd99f-84f8-412c-9c95-49db26bacfce';
