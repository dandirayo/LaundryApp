# Blueprint Website Admin Idola One

Dokumen ini memetakan aplikasi Android, website Admin Owner, dan Supabase sebagai satu sistem. Status diverifikasi dari source code dan konfigurasi database produksi pada 6 September 2026.

## 1. Prinsip sistem

- Supabase adalah sumber data utama bersama. Aplikasi Android dan website tidak memiliki database produksi terpisah.
- Setiap data operasional membawa `shop_id`. RLS membatasi pembacaan dan perubahan ke toko pengguna yang sedang login.
- Owner dapat mengelola toko. Karyawan hanya memperoleh aksi yang diizinkan untuk pekerjaan hariannya.
- Realtime dipakai sebagai pemicu untuk mengambil ulang data. Data payload realtime tidak langsung dianggap sebagai state final.
- Realtime dapat terlewat saat perangkat tidur atau jaringan berpindah. Layar penting juga melakukan rekonsiliasi setiap 15 detik, refresh saat kembali aktif, atau menyediakan refresh manual.
- Perubahan finansial memakai function/trigger database agar pembayaran, pengeluaran, payroll, dan kas tidak berbeda antar-client.

## 2. Status website Admin saat ini

| Area | Kemampuan saat ini | Status |
|---|---|---|
| Login | Login username/email, hanya profil Owner aktif yang diterima | Siap |
| Beranda | Pesanan hari ini, request pending, karyawan aktif, stok menipis, pemasukan, saldo, aktivitas pesanan | Siap untuk data saat ini; perlu agregat server untuk volume besar |
| Pengajuan | Daftar request, setujui, tolak, bayar, tandai selesai, catatan Owner | Siap |
| Pesanan | Daftar 50 terbaru, ubah status, catat pembayaran | Dasar siap; detail item dan validasi UI belum lengkap |
| Pelanggan | Cari, tambah, ubah, soft delete | Siap untuk Owner |
| Inventaris | Tambah item, stok minimum, mutasi masuk/keluar/penyesuaian, riwayat mutasi | Siap |
| Karyawan | Tambah akun melalui Edge Function, ubah profil, shift dasar, aktif/nonaktif | Siap |
| Jadwal | Tambah, ubah, hapus shift mingguan dan hari libur | Siap |
| Laporan | Buku Kas terbaru, input manual, ekspor CSV, audit aktivitas | Dasar siap |
| Pengaturan | Nama, telepon, dan alamat toko | Siap |
| Realtime web | Request, order, karyawan, pelanggan, inventaris, shift, mutasi, kas, audit | Siap + rekonsiliasi 15 detik |

## 3. Matriks fitur lintas Android, Admin, dan backend

| Modul | Android | Website Admin | Sumber data / operasi | Realtime |
|---|---|---|---|---|
| Autentikasi & profil | Owner/karyawan | Owner | Auth, `profiles`, `employees` | `employees`, `profiles` |
| Dashboard | Sesuai role | Ringkasan Owner | Agregat order, kas, request, tim, stok | Mengikuti tabel sumber |
| Pesanan | Buat, status, detail, pembayaran, nota, WhatsApp | Daftar, status, pembayaran | `orders`, `order_items`, `payments`; RPC pembuatan/pembayaran | Ya |
| Pelanggan | Daftar, tambah, ubah, impor kontak terpilih | Daftar, tambah, ubah, soft delete | `customers` | Ya |
| Layanan & harga | Kiloan/satuan/gabungan, kategori, harga | Belum tersedia | `services`, `service_categories` | Android: ya |
| Buku Kas | Transaksi dan ringkasan periode | Transaksi terbaru, manual, CSV | `cash_transactions` | Ya |
| Pengeluaran | Form dan riwayat sesuai role | Belum sebagai modul terstruktur | `expenses`; trigger ke kas | Android: ya |
| Inventaris | Item, stok, mutasi | Item, stok, mutasi | `inventory_items`, `inventory_movements`; RPC penyesuaian | Ya |
| Karyawan | Daftar dan pengelolaan Owner | Tambah/ubah/aktifkan | `employees`, `profiles`, Edge Function | Ya |
| Absensi | Masuk/keluar dengan foto, lupa absen | Belum tersedia | `attendance_records`, Storage `attendance-photos`, `employee_requests` | Android: ya |
| Shift | Jadwal mingguan | Kelola jadwal | `weekly_shifts` | Ya |
| Pengajuan | Buat dan pantau status | Review, tolak, bayar, selesai | `employee_requests`; trigger notifikasi/kas | Ya + rekonsiliasi 15 detik |
| Payroll | Bayar dan riwayat | Belum tersedia | `payroll_payments`; trigger validasi/kas | Android: ya |
| Notifikasi | Inbox, badge, tandai baca, hapus | Belum tersedia | `notifications` | Android: ya |
| Laporan | Ringkasan periode | Kas dan audit dasar | Tabel operasional dan `audit_logs` | Sebagian melalui tabel sumber |
| Backup | Ekspor dan panduan pemulihan | Belum tersedia | Data toko | Tidak perlu realtime |
| Update aplikasi | Cek versi, unduh dan pasang APK | Bukan kebutuhan dashboard | Storage `app-releases` | Polling manifest 5 menit |

## 4. Kontrak realtime

Tabel berikut berada dalam publication `supabase_realtime` setelah migration `20260906013324_complete_realtime_publication.sql` diterapkan:

`attendance_records`, `audit_logs`, `cash_closings`, `cash_transactions`, `customers`, `employee_requests`, `employees`, `expenses`, `inventory_items`, `inventory_movements`, `notifications`, `order_items`, `orders`, `payments`, `payroll_payments`, `profiles`, `services`, dan `weekly_shifts`.

Alur yang wajib dipakai setiap halaman:

1. Muat snapshot awal dengan query yang diberi filter `shop_id`.
2. Subscribe ke perubahan tabel yang relevan dengan filter toko.
3. Saat event datang, panggil query ulang; jangan menghitung saldo atau status hanya dari payload event.
4. Rekonsiliasi maksimal setiap 15 detik ketika halaman terlihat.
5. Refresh segera ketika tab/browser kembali fokus.
6. Pertahankan data terakhir jika refresh gagal dan tampilkan indikator sinkronisasi terganggu.
7. Setelah mutation, verifikasi baris hasil dengan `.select(...)`; update yang mengenai nol baris harus dianggap gagal.

Postgres Changes memadai untuk jumlah pengguna Idola Laundry saat ini. Jika kelak ada ribuan koneksi serentak, evaluasi Supabase Broadcast.

## 5. Status dan aturan yang harus sama

### Pesanan

- `received` → Diterima
- `processing` → Diproses
- `ready` → Siap Diambil
- `picked_up` → Diambil
- `cancelled` → Dibatalkan

Pesanan tidak boleh menjadi `picked_up` ketika masih ada sisa pembayaran. Status pembayaran adalah `unpaid`, `partial`, atau `paid`. Setelah status menjadi `ready`, aplikasi Android membuka WhatsApp dengan pesan siap ambil.

### Pengajuan

- `pending` → Menunggu
- `approved` → Disetujui
- `rejected` → Ditolak
- `paid` → Dibayar
- `completed` → Selesai

Kategori aktif adalah stok, izin dan jadwal, serta dana dan biaya. `Lupa Absen` dicatat sebagai pengajuan jadwal dengan alasan wajib.

### Harga dan kuantitas

- Layanan dipisahkan menjadi kelompok utama Kiloan dan Satuan, kemudian kategori, item, dan varian.
- Kuantitas kiloan mendukung desimal 0,1 kg.
- Minimum normal adalah 3 kg; override di bawah 3 kg hanya dipilih secara eksplisit untuk pelanggan setia.
- Website harus membaca harga dari `services`, bukan menyimpan daftar harga kedua di source code.

## 6. Gap yang perlu diselesaikan pada website Admin

### Prioritas 0 — integritas data

- Ubah semua update/delete agar mengembalikan baris hasil. Jangan menampilkan sukses bila RLS menyebabkan nol baris berubah.
- Gunakan RPC yang sama dengan Android untuk operasi kompleks, khususnya pembuatan order, pembayaran, dan penyesuaian stok.
- Tambahkan state `sinkron`, `menyinkronkan`, dan `gagal sinkron` yang terlihat oleh Owner.
- Ganti metrik dari array 50 data terbaru menjadi query agregat/RPC server agar total tetap benar ketika data bertambah.

### Prioritas 1 — operasional Owner

- Detail pesanan lengkap: item, kuantitas, unit, subtotal, penerima, petugas, estimasi, catatan, pembayaran, dan cetak nota.
- Master layanan dan harga: kelompok, kategori, item, varian, unit, estimasi, aktif/nonaktif, dan urutan tampil.
- Absensi: daftar harian/periode, foto bukti dengan signed URL, terlambat, keluar, dan pengajuan lupa absen.
- Filter serta pagination server untuk pesanan, pelanggan, kas, dan audit.

### Prioritas 2 — keuangan dan tim

- Pengeluaran terstruktur yang memakai tabel `expenses`, bukan hanya transaksi kas manual.
- Payroll per periode, riwayat pembayaran, metode bayar, serta pencegahan pembayaran ganda.
- Notifikasi Owner dan badge request/operasional.
- Laporan per hari, minggu, bulan, dan rentang tanggal; ekspor order, kas, payroll, serta pengeluaran.

### Prioritas 3 — pengelolaan sistem

- Pengaturan tambahan dari `shop_settings`.
- Riwayat update aplikasi Android dan release notes untuk Owner.
- Backup operasional dengan kontrol akses dan audit.
- Dashboard kesehatan sinkronisasi tanpa menampilkan credential atau service-role key.

## 7. Struktur website yang disarankan

Kode saat ini masih terpusat di `src/App.tsx`. Sebelum menambah modul besar, pecah menjadi:

- `features/dashboard/`
- `features/orders/`
- `features/customers/`
- `features/services/`
- `features/finance/`
- `features/team/`
- `features/attendance/`
- `features/requests/`
- `features/inventory/`
- `features/settings/`
- `lib/supabase/` untuk query, mutation, subscription, dan mapper bersama

Gunakan satu kamus label status, formatter uang/tanggal, serta error mapper bersama agar istilah web sama dengan Android. Jangan memakai `service_role` di browser; browser hanya menggunakan key publik dan RLS.

## 8. Definition of Done

Website Admin dapat disebut settle bila:

- Semua modul Prioritas 0 dan 1 selesai.
- Setiap mutation diuji dari Owner web dan hasilnya muncul di dua akun Android tanpa refresh manual.
- Perubahan dari Android muncul di web melalui realtime atau rekonsiliasi maksimal 15 detik.
- Metrik tidak berubah salah ketika data melewati batas 50 baris.
- Semua query terisolasi per `shop_id` dan pengujian RLS lintas toko lulus.
- Pembayaran, pengeluaran, payroll, dan request berbayar menghasilkan tepat satu transaksi kas.
- Build, lint, dan smoke test browser lulus tanpa error mentah database di UI.
