# Blueprint Dashboard Admin Idola One

**Status diverifikasi:** 20 September 2026  
**Aplikasi Android:** 2.1.2+18  
**Backend:** Supabase production `sqydcdhvsmmkvlpsjzgx`

## 1. Posisi dashboard dalam produk

Dashboard web adalah alat kerja owner untuk data operasional Laundry. Dashboard memakai Supabase production yang sama dengan Android; tidak memiliki database terpisah. Aplikasi Android telah berkembang menjadi aplikasi multi-usaha dengan Laundry dan POS minuman, sedangkan dashboard web saat ini masih berfokus pada satu `shop_id` dan modul Laundry.

```mermaid
flowchart LR
    A[Owner Web] --> S[Supabase]
    B[Owner Android] --> S
    C[Karyawan Android] --> S
    S --> D[Data Laundry per shop_id]
    S --> E[Data POS per business_id]
    A -. belum memiliki UI .-> E
```

## 2. Prinsip sistem

- Supabase adalah sumber kebenaran bersama.
- Data Laundry diisolasi dengan `shop_id`; data POS diisolasi dengan `business_id` dan membership.
- Browser hanya memakai publishable/anon key serta JWT pengguna; `service_role` tidak boleh masuk ke bundle Vite.
- RLS tetap memeriksa akses walaupun menu disembunyikan di UI.
- Realtime hanya memicu query ulang. Payload event tidak dipakai sebagai saldo/status final.
- Operasi finansial dan operasi atomik memakai RPC/trigger yang sama dengan Android.
- Snapshot nama pelanggan, layanan, produk, dan harga harus dipertahankan untuk histori.

## 3. Implementasi dashboard saat ini

Source dashboard masih terpusat pada `admin_dashboard_web/src/App.tsx` dengan React, TypeScript, Vite, Supabase JS, dan Lucide.

| Area | Kemampuan aktual | Status |
| --- | --- | --- |
| Login | Email/username, hanya profil owner aktif | Selesai |
| Beranda | Pesanan hari ini, request pending, karyawan aktif, pelanggan, stok menipis, pemasukan, pengeluaran, saldo | Selesai untuk dataset kecil |
| Pengajuan | Filter status, setujui, tolak, bayar, selesaikan, catatan owner | Sebagian; istilah/status web perlu disamakan dengan Android |
| Pesanan | Maksimal 50 terbaru, ubah status, catat pembayaran | Sebagian; belum ada detail item lengkap/cetak |
| Pelanggan | Cari lokal dari 50 terbaru, tambah, ubah, soft delete | Sebagian; belum ada poin dan pagination server |
| Inventaris | Item, stok minimum, tambah item, adjustment, riwayat mutasi | Selesai untuk kebutuhan dasar |
| Karyawan | Tambah akun melalui Edge Function, ubah profil, aktif/nonaktif | Selesai untuk Laundry |
| Shift | CRUD jadwal mingguan dan hari libur | Selesai |
| Laporan | 50 transaksi kas terbaru, input manual, ekspor CSV, 15 audit log | Sebagian; belum agregat periode/pagination |
| Pengaturan | Nama, telepon, dan alamat toko | Selesai |
| Realtime | Request, order, employee, customer, inventory, shift, movement, cash, audit | Selesai dengan rekonsiliasi berkala |
| Multi-usaha | Belum ada pemilih/kelola usaha atau assignment | Belum |
| POS minuman | Belum ada produk, transaksi, status buka, laporan, dan kas | Belum |
| Poin pelanggan | Belum menampilkan saldo/event | Belum |

## 4. Matriks Android, web, dan backend

| Modul | Android | Dashboard web | Sumber utama |
| --- | --- | --- | --- |
| Auth/profil | Owner dan karyawan | Owner | Auth, `profiles`, `employees` |
| Pemilih usaha | Ya | Belum | `businesses`, `business_members` |
| Pesanan Laundry | Buat, detail, status, pembayaran, cetak | List, status, pembayaran | `orders`, `order_items`, `payments` dan RPC |
| Layanan/harga | CRUD owner, pemilih varian | Belum | `service_categories`, `services` |
| Pelanggan/kontak | CRUD, sinkron/reset/filter kontak | CRUD dasar | `customers` |
| Poin pelanggan | Saldo realtime | Belum | `customer_point_events`, `customer_point_balances` |
| Printer | Nota, label, bukti pengambilan terpisah | Belum | Device Bluetooth, data order |
| Stok | Item dan mutasi | Item dan mutasi | `inventory_items`, `inventory_movements` |
| Pengeluaran/kas | Riwayat dan filter periode | Kas manual/dasar | `expenses`, `cash_transactions` |
| Karyawan/shift | Lengkap sesuai role | CRUD owner | `employees`, `profiles`, `weekly_shifts` |
| Absensi | Check-in/out dan foto | Belum | `attendance_records`, Storage |
| Pengajuan | Buat/pantau/review | Review dasar | `employee_requests` |
| Payroll | Bayar dan histori | Belum | `payroll_payments`, cash trigger |
| Notifikasi | Inbox/badge/deep link | Belum | `notifications` |
| POS minuman | Produk, kasir, sale, status buka | Belum | `pos_*`, `business_daily_operations` |
| Audit | Tidak menjadi layar utama | 15 aktivitas terbaru | `audit_logs` |
| Update Android | Cek dan instal APK | Tidak relevan | Storage `app-releases` |

## 5. Kontrak realtime produksi

Tabel dalam publication `supabase_realtime` per 20 September 2026:

`attendance_records`, `audit_logs`, `cash_closings`, `cash_transactions`, `customer_point_balances`, `customers`, `employee_requests`, `employees`, `expenses`, `inventory_items`, `inventory_movements`, `notifications`, `order_items`, `orders`, `payments`, `payroll_payments`, `profiles`, `services`, dan `weekly_shifts`.

`businesses`, `business_members`, `pos_products`, `pos_sales`, `pos_sale_items`, dan `business_daily_operations` belum berada dalam publication. Android POS saat ini memuat ulang data melalui controller/query setelah aksi; jika dashboard POS ditambahkan, gunakan publication dengan RLS/filter yang benar atau polling/focus refresh yang terdokumentasi.

Pola halaman realtime:

1. query snapshot awal dengan filter tenant;
2. subscribe hanya ke tabel relevan;
3. query ulang ketika event diterima;
4. refresh saat tab kembali fokus;
5. rekonsiliasi berkala ketika halaman terlihat;
6. pertahankan data lama dan tampilkan gangguan sinkronisasi saat refresh gagal;
7. mutation harus mengembalikan row/RPC result dan tidak boleh menampilkan sukses jika nol row berubah.

## 6. Aturan bisnis yang harus sama

### Pesanan dan pembayaran

- Status order: `received`, `processing`, `ready`, `picked_up`, `cancelled`.
- Status pembayaran: `unpaid`, `partial`, `paid`.
- Pesanan boleh menjadi `picked_up` walaupun belum lunas sesuai migration `20260913034252_allow_unpaid_order_pickup.sql`; sisa harus tetap terlihat dan dapat ditagih kemudian.
- Pembayaran tambahan wajib memakai `record_order_payment`.
- Total order mengikuti pembulatan backend dan tidak dihitung berbeda di web.
- Sprei 160, 180, dan 200 adalah layanan/harga terpisah.

### Pengajuan

Status storage: `pending`, `approved`, `rejected`, `paid`, `completed`.

Android menampilkan `completed` non-uang sebagai **Disetujui** agar owner tidak terlihat sekadar “menandai selesai”. Dashboard masih memiliki tombol **Selesaikan** untuk request non-uang; ini merupakan gap UI yang perlu diperbaiki menjadi istilah keputusan/penyelesaian yang jelas.

### Poin pelanggan

- Satu event per order melalui `app_private.sync_customer_points()`.
- Poin diberikan ketika pesanan berpelanggan menjadi lunas.
- Formula aktif: `floor(total_price / 10.000)`.
- Dashboard hanya membaca saldo/event; perubahan tidak dilakukan dengan edit balance langsung.

### POS minuman

- Akses berdasarkan owner atau `business_members` aktif.
- Sale dan item harus dibuat melalui `create_pos_sale`.
- Nama dan harga produk disalin ke item sale.
- Status buka harian unik per business dan tanggal.

## 7. Gap dan prioritas dashboard

### P0 — integritas dan konsistensi

- Gunakan `.select()` atau RPC result pada seluruh update/delete agar nol-row akibat RLS dianggap gagal.
- Ganti metrik berbasis array 50 terbaru dengan aggregate/RPC server.
- Samakan label pengajuan dengan Android dan hilangkan tombol “Selesaikan” yang ambigu.
- Pastikan transisi `picked_up` belum lunas ditampilkan dengan sisa bayar, bukan ditolak oleh validasi web lama.
- Tambah pagination/filter server untuk order, customer, kas, dan audit.

### P1 — parity Laundry

- Detail order lengkap: item, penerima, petugas, tenggat, note, pembayaran, poin, dan cetak/export.
- Master layanan/harga dengan ukuran dan varian.
- Pengeluaran terstruktur dari `expenses`.
- Absensi/foto, payroll, notifikasi, dan laporan periode.
- Saldo serta histori poin pada detail pelanggan.

### P1 — multi-usaha dan POS owner

- Pemilih usaha setelah login.
- CRUD usaha dan assignment karyawan.
- Ringkasan POS: buka hari ini, omzet, jumlah transaksi.
- Produk POS dan histori sale/item.
- Laporan per `business_id`; jangan mencampurkan omzet POS dengan Laundry.

### P2 — operasional dan skala

- Tutup kas POS, void/refund dengan audit, dan pengeluaran per usaha setelah backend tersedia.
- Monitoring sync dan health tanpa credential.
- Backup/export owner dengan kontrol akses.
- Pemecahan `App.tsx` menjadi module feature-first.

## 8. Struktur target dashboard

```text
src/
├── app/                 # auth gate, layout, router, active business
├── features/
│   ├── dashboard/
│   ├── businesses/
│   ├── laundry-orders/
│   ├── customers/
│   ├── services/
│   ├── finance/
│   ├── inventory/
│   ├── team/
│   ├── attendance/
│   ├── requests/
│   └── pos/
├── lib/supabase/        # query, mutation, subscription, mapper
└── shared/              # status labels, formatter, UI components
```

## 9. Definition of done

Dashboard dianggap sinkron dengan project saat ini bila:

- P0 selesai dan semua mutation mendeteksi nol-row;
- metrik tidak bergantung pada batas 50 baris;
- order belum lunas dapat diambil dengan sisa yang tetap konsisten;
- perubahan web muncul di Android dan sebaliknya melalui realtime/recovery;
- multi-usaha menggunakan `business_id` dan membership, bukan hanya `shop_id`;
- laporan Laundry dan POS dapat dipisahkan;
- owner dapat melihat poin tanpa dapat memalsukan saldo;
- RLS lintas shop/business diuji;
- lint, build, dan smoke test browser lulus.

