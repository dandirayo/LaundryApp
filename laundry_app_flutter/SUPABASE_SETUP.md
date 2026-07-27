# Supabase Setup Idola Laundry

## 1. Buat Project Supabase

1. Buka Supabase Dashboard.
2. Buat project baru, misalnya `idola-laundry`.
3. Simpan:
   - Project URL
   - anon public key

Ambil keduanya dari `Project Settings > API`.

## 2. Login dan Link CLI

Di terminal PowerShell, gunakan `supabase.cmd` agar tidak kena blokir `supabase.ps1`.

```powershell
supabase.cmd login
supabase.cmd link --project-ref PROJECT_REF_KAMU
```

`PROJECT_REF_KAMU` adalah kode di URL project Supabase, misalnya:
`https://abcxyz.supabase.co` berarti project ref `abcxyz`.

## 3. Push Schema

```powershell
supabase.cmd db push
```

Ini menjalankan migration di folder `supabase/migrations`.

## 4. Masukkan Seed Katalog Awal

Seed opsional berisi toko Idola Laundry dan contoh katalog bertingkat.

```powershell
supabase.cmd db seed
```

## 5. Buat User Login Pertama

Di Supabase Dashboard:

1. Buka `Authentication > Users`.
2. Klik `Add user`.
3. Buat email dan password owner.
4. Copy `User UID`.

Lalu buka `SQL Editor`, jalankan SQL ini. Ganti `USER_UID_DARI_SUPABASE`.

```sql
insert into public.employees (
  id, shop_id, name, phone, role, shift_start, shift_end, weekly_salary
) values (
  '20000000-0000-0000-0000-000000000001',
  '00000000-0000-0000-0000-000000000001',
  'Owner Idola',
  '0812-2000-3075',
  'OWNER',
  '06:00',
  '20:00',
  0
) on conflict (id) do nothing;

insert into public.profiles (
  id, shop_id, employee_id, full_name, role, is_active, phone
) values (
  'USER_UID_DARI_SUPABASE',
  '00000000-0000-0000-0000-000000000001',
  '20000000-0000-0000-0000-000000000001',
  'Owner Idola',
  'OWNER',
  true,
  '0812-2000-3075'
) on conflict (id) do update set
  full_name = excluded.full_name,
  role = excluded.role,
  is_active = excluded.is_active,
  phone = excluded.phone;
```

## 6. Run Flutter Dengan Supabase

```powershell
C:\Users\ASUS\dev\flutter_sdk\bin\flutter.bat run -d RRCT2017K6N `
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=ANON_PUBLIC_KEY
```

Kalau `SUPABASE_URL` dan `SUPABASE_ANON_KEY` kosong, app tetap masuk mode preview/offline.

## Status Saat Ini

- Supabase Auth sudah dibaca oleh app lewat tabel `profiles`.
- Schema database bisnis sudah disiapkan.
- Repository data bisnis masih memakai preview/offline data dan akan dipindahkan bertahap:
  1. Services/katalog
  2. Customers
  3. Orders + items + payments
  4. Cashbook
  5. Attendance dan request karyawan
