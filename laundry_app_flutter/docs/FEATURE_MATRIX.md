# Feature Matrix

Sumber referensi: `https://github.com/dandirayo/laundry_app` commit `d54531f`.
Repo lama hanya dibaca sebagai referensi istilah, warna, menu, dan alur bisnis.

## Ringkasan Referensi Kotlin

| Area | Ada di Kotlin lama | Catatan rebuild Flutter |
| --- | --- | --- |
| Login role | Ada, Owner/Karyawan berbasis PIN | Diganti Supabase Auth. PIN hanya quick unlock lokal setelah login utama. |
| Dashboard | Ada untuk Owner dan Karyawan | Dipertahankan, dibuat server-authoritative dan role-aware. |
| Pesanan | Ada daftar, detail, pembuatan, print | Dibangun ulang bertahap, order number server-side `IDL-YYYYMMDD-0001`. |
| Pelanggan | Ada CRUD dasar | Tambah normalisasi nomor Indonesia, cegah duplikat per toko. |
| Layanan & Harga | Ada CRUD dasar | Tambah kategori, estimasi selesai, active flag, snapshot harga pada order item. |
| Pembayaran | Ada status dan cash transaction | Dipisah ke tabel `payments`; `cash_transactions` jadi satu-satunya sumber pergerakan kas. |
| Buku Kas/Laporan | Ada rekap lokal | Dibangun dari transaksi kas, bukan dari UI card atau status pesanan. |
| Pengeluaran | Ada | Dipertahankan dan masuk `cash_transactions` secara idempotent. |
| Stok | Ada item, riwayat, request stok | Tambah movement type, constraint stok tidak negatif, approval flow. |
| Absensi | Ada dengan foto path lokal | Foto wajib via Supabase Storage, timestamp server, RLS per karyawan. |
| Shift | Ada jadwal sederhana | Tambah validasi bentrok, libur, copy minggu berikutnya, notifikasi perubahan. |
| Gaji/Insentif | Ada | Setting nominal disimpan database, pembayaran idempotent ke Buku Kas. |
| Request karyawan | Ada beberapa request | Disatukan dalam `employee_requests` dengan tipe dan status constraint. |
| Notifikasi | Ada lokal | Supabase Realtime untuk in-app, FCM untuk push. |
| Printer | Ada manager util | Abstraksi `ReceiptPrinterService`, fallback PDF/share WhatsApp. |
| Backup | Ada util lokal | Karena Supabase source of truth, backup berupa export JSON/CSV terstruktur. |

## Masalah Yang Tidak Dibawa Dari Kotlin Lama

| Masalah lama | Bukti referensi | Keputusan rebuild |
| --- | --- | --- |
| Nama dipakai sebagai relasi bisnis | `employeeName`, `customerName`, `processedBy` di model | Semua relasi bisnis memakai UUID. Nama hanya snapshot tampilan bila diperlukan. |
| Status memakai string bebas | `status: String`, `paymentStatus: String` | Status database memakai check constraint dan enum domain. |
| PIN menjadi autentikasi utama | `PinEntryScreen`, `SecurityUtils.hashPin` | Supabase Auth menjadi autentikasi utama. PIN tidak plaintext dan bukan pengganti session server. |
| Satu ViewModel besar | `LaundryViewModel` mengelola banyak fitur | Feature-first dengan repository/provider per fitur. |
| Room/local sebagai database utama | DAO lokal di `data/local` | Supabase PostgreSQL menjadi source of truth; Drift hanya cache/offline queue. |
| Halaman placeholder bisa ditekan | Printer/Backup "Segera Hadir" di route aktif | Semua route tetap valid; fitur belum selesai tampil state jelas dan action non-destruktif. |

## Scope Phase 1

Phase 1 membuat foundation yang dapat dikembangkan:

- Flutter project `laundry_app_flutter`.
- Material 3 theme dengan warna Idola Laundry dan DM Sans asset registration.
- Feature-first folder structure.
- Supabase config via dart-define/environment placeholder.
- Riverpod Notifier/AsyncNotifier foundation.
- GoRouter dengan redirect session dan role guard.
- Auth screen, app shell, Owner/Karyawan bottom navigation.
- Halaman valid untuk semua menu yang diminta.
- Shared loading, empty, error, retry, offline banner, confirmation dialog.
- Result/Failure untuk error handling.
- Dokumentasi dan SQL awal Supabase.

## Scope Belum Selesai Setelah Phase 1

Phase 1 belum mengklaim fitur operasional selesai. Area berikut masuk Phase 2+:

- CRUD pelanggan, layanan, pesanan, pembayaran, dan struk.
- Realtime notification production.
- Upload foto Supabase Storage.
- Drift offline queue.
- FCM dan printer thermal.
- Export PDF/CSV final.
- APK debug bila toolchain Android lengkap tersedia.
