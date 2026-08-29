# Supabase Setup Idola Laundry

## Canonical Supabase Source

Satu-satunya source migration production adalah:

`/supabase/migrations`

Semua perintah CLI di dokumen ini dijalankan dari root repository
`C:\Users\ASUS\Documents\GitHub\LaundryApp`. Folder lama
`/laundry_app_flutter/supabase` tidak boleh dibuat kembali.

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
Set-Location C:\Users\ASUS\Documents\GitHub\LaundryApp
supabase.cmd login
supabase.cmd link --project-ref sqydcdhvsmmkvlpsjzgx
```

## 3. Repair Database Production Saat Ini

Migration history remote saat audit masih kosong walaupun schema lama sudah
ada. Karena itu **jangan langsung menjalankan `supabase db push`**: CLI akan
mencoba mengulang seluruh baseline migration.

Untuk repair production pertama kali, buka Supabase Dashboard > project
`Idola Laundry` > SQL Editor > New Query, paste seluruh isi file:

`/supabase/migrations/20260829051637_repair_database_consistency.sql`

Klik Run. Setelah berhasil, paste dan Run seluruh isi:

`/supabase/verification/20260829_verify_database_repair.sql`

Semua baris pada result set pertama harus berstatus `PASS`.

Alternatif CLI PowerShell yang menjalankan dua file yang sama:

```powershell
Set-Location C:\Users\ASUS\Documents\GitHub\LaundryApp
supabase.cmd login
supabase.cmd link --project-ref sqydcdhvsmmkvlpsjzgx
supabase.cmd db query --linked --file ".\supabase\migrations\20260829051637_repair_database_consistency.sql"
supabase.cmd db query --linked --file ".\supabase\verification\20260829_verify_database_repair.sql"
```

Perintah verification harus menampilkan `PASS` untuk setiap check. Jangan
menjalankan `migration repair` bila query repair gagal atau masih ada hasil
`FAIL`.

Sesudah SQL dan verifikasi berhasil, sinkronkan migration history:

```powershell
Set-Location C:\Users\ASUS\Documents\GitHub\LaundryApp
supabase.cmd migration repair --linked --status applied `
  202607260001 202608090002 202608090003 202608140001 `
  202608170001 202608170002 202608280001 202608280003 `
  20260829051637
supabase.cmd migration list --linked
```

Kolom Local dan Remote harus berisi versi yang sama. Mulai sesudah rekonsiliasi
ini, migration baru dapat dikirim dengan alur aman berikut:

```powershell
supabase.cmd db push --dry-run
supabase.cmd db push
```

`db push --dry-run` harus ditinjau lebih dahulu dan hanya boleh menampilkan
migration baru yang memang belum applied.

### Schema cache PostgREST

Migration repair sudah menjalankan `NOTIFY pgrst, 'reload schema'`. Jika APK
masih menampilkan `PGRST205` setelah SQL sukses, jalankan sekali lagi di SQL
Editor:

```sql
NOTIFY pgrst, 'reload schema';
```

Lalu tutup dan buka ulang APK.

## 4. Baseline Schema untuk Project Baru

Untuk project baru yang benar-benar kosong, jalankan dari root repository:

```powershell
supabase.cmd link --project-ref PROJECT_REF_BARU
supabase.cmd db push --dry-run
supabase.cmd db push
```

## 5. Masukkan Seed Katalog Awal

Seed opsional berisi toko Idola Laundry dan contoh katalog bertingkat.

```powershell
supabase.cmd db seed
```

## 6. Buat User Login Pertama

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

## 7. Run Flutter Dengan Supabase

```powershell
C:\Users\ASUS\dev\flutter_sdk\bin\flutter.bat run -d RRCT2017K6N `
  --dart-define=SUPABASE_URL=https://PROJECT_REF.supabase.co `
  --dart-define=SUPABASE_ANON_KEY=ANON_PUBLIC_KEY
```

Kalau `SUPABASE_URL` dan `SUPABASE_ANON_KEY` kosong, app tetap masuk mode preview/offline.

## 8. Pasang Fungsi Pembuatan Akun Karyawan

Owner membuat akun karyawan melalui Edge Function supaya secret key Supabase
tidak pernah masuk ke APK.

```powershell
supabase.cmd functions deploy create-employee-user
```

Kode fungsi berada di:

`/supabase/functions/create-employee-user/index.ts`

Password awal hanya dikirim ke Supabase Auth oleh Edge Function. Jangan
menambahkan atau memakai kolom `employees.pin`; dashboard dan APK tidak boleh
membaca kredensial plaintext dari tabel bisnis.

Setelah fungsi terpasang, buka `Lainnya > Data Karyawan > Tambah Karyawan`.
Owner dapat mengisi nama, telepon, posisi, username, dan password awal.
Karyawan kemudian login menggunakan username tersebut atau email internalnya.

Jika Supabase CLI di Windows diblokir, deploy function dari mesin lain atau
lewat workflow/server yang mengizinkan binary Supabase CLI. Aplikasi Flutter
tidak boleh menyimpan `service_role_key`, jadi pembuatan user karyawan tetap
harus lewat Edge Function.

## 9. Build APK Kecil

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
- `cash_transactions` adalah satu-satunya ledger kas yang dipakai aplikasi.
  `cashbook_entries` hanya dipertahankan sebagai data legacy dan tidak boleh
  menerima write baru dari role aplikasi.
