# Matriks Sinkronisasi Idola One

**Status:** 25 September 2026  
**Baseline:** Android 2.1.3+19, dashboard web saat ini, schema Supabase production

## 1. Arti status

- **READY:** jalur query/mutation dan recovery tersedia.
- **PARTIAL:** sebagian client atau realtime belum tersedia.
- **DEVICE TEST:** tetap perlu pembuktian lintas perangkat/jaringan nyata.
- **PLANNED:** belum diimplementasikan.

## 2. Matriks sumber data dan client

| Fitur | Sumber utama | Android | Web admin | Realtime/recovery | Status |
| --- | --- | --- | --- | --- | --- |
| Profil/peran | `profiles`, `employees` | Owner/karyawan | Owner | Publication + refresh | READY; DEVICE TEST |
| Pemilih usaha | `businesses`, `business_members` | Ya | Belum | Query/refresh; belum publication | PARTIAL |
| Order Laundry | `orders`, `order_items` | Lengkap | List/status/payment | Realtime + refresh | READY; web detail PARTIAL |
| Pembayaran | `payments`, `orders`, `cash_transactions` | Ya | Ya via RPC | Realtime + rekonsiliasi | READY; DEVICE TEST |
| Pelanggan | `customers` | CRUD + kontak | CRUD dasar | Realtime + refresh | READY; web pagination PARTIAL |
| Poin pelanggan | `customer_point_events`, `customer_point_balances` | Saldo | Belum | Balance realtime; event query | PARTIAL; DEVICE TEST |
| Layanan/harga | `services`, `service_categories` | CRUD/pemilih | Belum | `services` realtime, refresh | ANDROID READY; WEB PLANNED |
| Cetak thermal | Data order/payment + device | Nota/label/bukti | Belum | Retry lokal | ANDROID READY; PHYSICAL TEST |
| Buku kas | `cash_transactions` | Ya | Ya, 50 terbaru | Realtime + polling/refresh | READY; skala web PARTIAL |
| Pengeluaran | `expenses`, `cash_transactions` | Ya | Belum terstruktur | Realtime + refresh | ANDROID READY; WEB PLANNED |
| Inventaris | `inventory_items`, `inventory_movements` | Ya | Ya | Realtime + refresh | READY; DEVICE TEST |
| Absensi | `attendance_records`, Storage | Ya | Belum | Realtime + refresh | ANDROID READY; WEB PLANNED |
| Shift | `weekly_shifts` | Ya | Ya | Realtime + refresh | READY; DEVICE TEST |
| Pengajuan | `employee_requests` | Buat/review | Review dasar | Realtime + polling | READY; label web PARTIAL |
| Payroll | `payroll_payments`, `cash_transactions` | Ya | Belum | Realtime + refresh | ANDROID READY; WEB PLANNED |
| Notifikasi | `notifications` | Ya | Belum | Realtime + refresh | ANDROID READY; WEB PLANNED |
| Audit | `audit_logs` | Tidak menjadi layar | Ya | Realtime + polling web | WEB READY |
| Pengaturan toko | `shops`, `shop_settings` | Ya | Profil toko dasar | Refresh/focus | PARTIAL |
| Produk POS | `pos_products` | Ya | Belum | Query/refresh; belum publication | ANDROID READY; WEB PLANNED |
| Sale POS | `pos_sales`, `pos_sale_items` | Ya | Belum | Query/refresh; belum publication | ANDROID READY; DEVICE TEST |
| Buka harian POS | `business_daily_operations` | Ya | Belum | Query/refresh; belum publication | ANDROID READY; DEVICE TEST |
| Update Android | Storage `app-releases` | Polling 5 menit/focus/manual | Tidak relevan | Retry dan cache download | READY |

## 3. Publication realtime production

Tabel yang terverifikasi berada dalam `supabase_realtime`:

```text
attendance_records
audit_logs
cash_closings
cash_transactions
customer_point_balances
customers
employee_requests
employees
expenses
inventory_items
inventory_movements
notifications
order_items
orders
payments
payroll_payments
profiles
services
weekly_shifts
```

Tabel multi-business/POS belum dipublikasikan. Event realtime tetap tunduk pada RLS; publication tidak memberikan hak baca tambahan.

## 4. Aturan recovery

- Query snapshot adalah sumber state; realtime mempercepat refresh.
- Android refresh saat controller dimuat, setelah mutation, dan saat pengguna melakukan retry/refresh.
- Pelanggan dan saldo poin mempunyai channel realtime terpisah.
- Dashboard query ulang ketika event diterima, setiap 15 detik saat terlihat, saat tab kembali terlihat, dan saat window fokus.
- POS saat ini mengandalkan query/refresh controller setelah aksi, bukan subscription realtime.
- Data lama boleh tetap terlihat ketika refresh gagal, tetapi UI harus menandai gangguan.
- Listener/subscription dibatalkan ketika scope/widget berhenti.

## 5. Gap sinkronisasi yang aktif

1. Dashboard belum memahami active business, assignment, POS, atau poin.
2. Dashboard memakai batas 50 untuk order, kas, dan pelanggan sehingga agregat dapat tidak lengkap.
3. Tabel POS belum berada dalam publication; perubahan dari perangkat kedua memerlukan refresh.
4. Label workflow pengajuan dashboard belum sepenuhnya sama dengan Android.
5. Detail order/item serta dokumen cetak belum tersedia di web.
6. Tutup kas dan expense per business POS belum tersedia.

Rincian backlog dashboard tersedia di [Blueprint Dashboard Admin](../product/07-ADMIN-DASHBOARD-BLUEPRINT.md). Skenario verifikasi tersedia di [Smoke Test](01-SMOKE-TEST-OWNER-EMPLOYEE-SYNC.md).

