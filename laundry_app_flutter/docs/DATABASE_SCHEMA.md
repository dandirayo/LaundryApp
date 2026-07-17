# Database Schema

Supabase PostgreSQL adalah source of truth. Nominal uang disimpan sebagai integer Rupiah. Berat memakai `numeric(10,2)`. Semua data operasional memakai UUID, `shop_id`, timestamp, FK, index, RLS, dan audit log untuk perubahan penting.

## Core Identity

| Tabel | Tujuan | Catatan |
| --- | --- | --- |
| `shops` | Data toko laundry | Satu toko memiliki owner, settings, dan data operasional. |
| `profiles` | Profil Supabase Auth user | `id` sama dengan `auth.users.id`, role `OWNER` atau `EMPLOYEE`. |
| `employees` | Data karyawan | Terhubung ke profile bila karyawan sudah punya akun login. |

## Master Data

| Tabel | Tujuan | Constraint penting |
| --- | --- | --- |
| `customers` | Pelanggan | Unique `(shop_id, normalized_phone)`. |
| `laundry_services` | Layanan & harga | `active`, kategori, satuan, estimasi selesai. |
| `inventory_items` | Master stok | `current_stock >= 0`, `minimum_stock >= 0`. |
| `shop_settings` | Konfigurasi toko | Unique `shop_id`. |
| `payroll_settings` | Nominal gaji/insentif | Unique `shop_id`. |

## Transaksi

| Tabel | Tujuan | Catatan |
| --- | --- | --- |
| `orders` | Header pesanan | `order_number` unik per toko; status dan payment status via check constraint. |
| `order_items` | Item layanan | Snapshot nama, kategori, satuan, harga saat transaksi dibuat. |
| `payments` | Pembayaran pesanan | Idempotency key unik per toko, tidak boleh nol. |
| `cash_transactions` | Buku Kas | Satu-satunya sumber pergerakan uang. |
| `expenses` | Pengeluaran | Membuat cash transaction saat approved/paid. |
| `inventory_movements` | Riwayat stok | Movement type `IN`, `OUT`, `ADJUSTMENT`, `PURCHASE`, `USAGE`. |
| `supply_requests` | Request stok | Status approval/provided/completed. |
| `employee_requests` | Request lembur, izin, kasbon, insentif, tukar shift | Status `PENDING`, `APPROVED`, `REJECTED`, `PAID`, `COMPLETED`. |
| `attendance` | Absensi foto | Foto masuk dan keluar wajib sesuai aksi. |
| `shifts` | Jadwal kerja | Validasi waktu dan overlap per karyawan. |
| `payroll_periods` | Periode gaji | Unique per toko dan rentang periode. |
| `payroll_records` | Pembayaran gaji | Unique `(employee_id, payroll_period_id)`. |
| `notifications` | Notifikasi app/push | Recipient by user id atau role, action route valid. |
| `audit_logs` | Log perubahan penting | Insert dari trigger/function aplikasi. |

## Server-Side Functions

| Function | Tujuan |
| --- | --- |
| `set_updated_at()` | Trigger standar `updated_at`. |
| `current_profile_shop_id()` | Helper RLS mengambil `shop_id` user login. |
| `current_profile_role()` | Helper RLS mengambil role user login. |
| `create_order_number(shop_uuid)` | Membuat nomor `IDL-YYYYMMDD-0001` aman concurrency. |
| `recalculate_order_payment(order_uuid)` | Menghitung `paid_amount`, `remaining_amount`, dan `payment_status` dari tabel payments. |
| `record_order_payment(...)` | Insert payment + cash transaction dalam satu transaksi idempotent. |
| `record_inventory_movement(...)` | Update stok + movement dengan constraint stok tidak negatif. |

## RLS Policy

Prinsip:

1. Owner dapat membaca dan mengubah data di `shop_id` miliknya.
2. Employee hanya membaca data tokonya yang relevan dan data dirinya sendiri untuk absensi, shift, payroll, dan request.
3. Tidak ada policy berdasarkan nama.
4. Storage bucket foto dibatasi path `shop_id/...` dan metadata owner.
5. Service role hanya untuk edge function/server operation yang butuh transaksi sensitif.

Detail SQL awal ada di `supabase/migrations/001_initial_schema.sql`.
