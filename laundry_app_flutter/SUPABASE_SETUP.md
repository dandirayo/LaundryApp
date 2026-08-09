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

Untuk project yang schema awalnya sudah pernah dijalankan manual, buka SQL
Editor lalu jalankan isi file berikut agar error `stack depth limit exceeded`
hilang:

`supabase/migrations/202608090002_fix_profile_rls_and_employee_accounts.sql`

Setelah itu jalankan juga migration pelengkap schema online:

`supabase/migrations/202608090003_complete_online_schema.sql`

Migration ini menambahkan tabel operasional seperti `cashbook_entries`,
`inventory_items`, `inventory_movements`, `notifications`, dan
`shop_settings`, sekaligus melengkapi shift/toleransi karyawan.

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

## 7. Pasang Fungsi Pembuatan Akun Karyawan

Owner membuat akun karyawan melalui Edge Function supaya secret key Supabase
tidak pernah masuk ke APK.

```powershell
supabase.cmd functions deploy create-employee-user
```

Kode fungsi berada di:

`supabase/functions/create-employee-user/index.ts`

Setelah fungsi terpasang, buka `Lainnya > Data Karyawan > Tambah Karyawan`.
Owner dapat mengisi nama, telepon, posisi, username, dan password awal.
Karyawan kemudian login menggunakan username tersebut atau email internalnya.

Jika Supabase CLI di Windows diblokir, deploy function dari mesin lain atau
lewat workflow/server yang mengizinkan binary Supabase CLI. Aplikasi Flutter
tidak boleh menyimpan `service_role_key`, jadi pembuatan user karyawan tetap
harus lewat Edge Function.

## 8. Build APK Kecil

Untuk APK production kecil, gunakan release split per ABI:

```powershell
C:\Users\ASUS\dev\flutter_sdk\bin\flutter.bat build apk --release --split-per-abi `
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=ANON_PUBLIC_KEY
```

Jika muncul `Application Control policy has blocked this file` untuk
`gen_snapshot.EXE` atau `font-subset.exe`, berarti Windows memblokir proses
AOT Flutter. Build release harus dijalankan setelah policy Windows tersebut
diizinkan, atau dari komputer/CI lain yang tidak memblokir Flutter engine.

## Status Saat Ini

- Supabase Auth sudah dibaca oleh app lewat tabel `profiles`.
- Login menerima email Owner atau username karyawan.
- Data dan akun login karyawan sudah menggunakan Supabase.
- Schema database bisnis sudah disiapkan dan migration pelengkap tersedia.
- Owner dapat menyimpan shift dan toleransi telat karyawan.
- Repository data bisnis masih memakai preview/offline data dan akan dipindahkan bertahap:
  1. Services/katalog
  2. Customers
  3. Orders + items + payments
  4. Cashbook
  5. Attendance dan request karyawan
