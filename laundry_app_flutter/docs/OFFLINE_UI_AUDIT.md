# Offline UI Audit

Tanggal audit: 19 Juli 2026

Scope tahap ini: Fase 0 audit, Fase 1 overflow global awal, dan Fase 6 pemeriksaan performa awal. Aplikasi tetap offline/preview lokal; Supabase operasional, Realtime, FCM, Storage online, dan sinkronisasi cloud tidak disentuh.

| Masalah | Lokasi file | Prioritas | Penyebab | Rencana perbaikan | Status |
| --- | --- | --- | --- | --- | --- |
| Empty state bisa overflow pada layar pendek atau text scale besar | `lib/core/widgets/app_state_view.dart` | P0 | `Center` + `Column(mainAxisSize: min)` tidak bisa scroll saat ruang vertikal lebih kecil dari isi | Buat empty/error state scroll-safe dengan `LayoutBuilder`, `SingleChildScrollView`, dan `ConstrainedBox` | Selesai |
| Halaman Pesanan Karyawan berisiko `BOTTOM OVERFLOWED` saat daftar kosong | `lib/features/orders/presentation/orders_page.dart` | P0 | Search, filter fixed height, empty state, FAB, dan bottom navigation berbagi ruang sempit | Hapus tinggi statis filter, sembunyikan FAB saat empty state punya tombol, tambah padding bawah list, tambah widget test 320x568 text scale 1.5 | Selesai |
| Filter status dapat terpotong pada text scale besar | `orders_page.dart`, `request_review_page.dart` | P1 | `SizedBox(height: 42)` membatasi tinggi chip | Ganti dengan horizontal `SingleChildScrollView` + `Row` tanpa tinggi statis | Selesai |
| Bottom sheet form rawan tertutup keyboard atau overflow | `orders_page.dart`, `customers_page.dart`, `services_page.dart`, `inventory_page.dart`, `shifts_page.dart`, `employees_page.dart`, `request_page.dart`, `request_review_page.dart`, `expenses_page.dart`, `profile_page.dart`, `payroll_page.dart`, `backup_page.dart` | P0 | Banyak sheet memakai `Padding` + `Column(mainAxisSize: min)` tanpa scroll wrapper dan `SafeArea` konsisten | Tambah `AppBottomSheetBody` berisi `SafeArea`, `SingleChildScrollView`, dan padding `viewInsets.bottom`; migrasikan sheet utama | Selesai |
| Assertion `_dependents.isEmpty` setelah aksi sukses | `orders_page.dart`, `customers_page.dart`, `services_page.dart`, `inventory_page.dart`, `shifts_page.dart`, `employees_page.dart`, `request_page.dart`, `request_review_page.dart`, `expenses_page.dart`, `profile_page.dart`, `payroll_page.dart`, `backup_page.dart`, `attendance_page.dart`, `confirmation_dialog.dart` | P0 | Mutasi provider atau snackbar dipanggil ketika bottom sheet/dialog masih dalam proses deactivation | Tambah `waitForTransientUiDismissal()` dan ubah aksi agar sheet/dialog mengembalikan input dulu, lalu provider di-update setelah route transien selesai | Selesai |
| Banner "Mode online siap" tidak sesuai tahap offline-first dan memakan ruang vertikal | `lib/app/app_shell.dart` | P1 | Banner dibuat untuk fase online/cache, tetapi sekarang target offline UI stability | Hapus banner dari shell agar layar pendek lebih lega dan tidak memberi klaim online | Selesai |
| FAB menutupi empty state atau menduplikasi tombol aksi | `orders_page.dart`, `customers_page.dart`, `services_page.dart`, `inventory_page.dart`, `employees_page.dart`, `expenses_page.dart`, `request_page.dart`, `shifts_page.dart` | P1 | FAB tetap tampil walau empty state sudah punya tombol aksi | Sembunyikan FAB saat daftar kosong, sesuaikan padding bawah body | Selesai |
| Controller bottom sheet tidak selalu di-dispose | `shifts_page.dart`, `employees_page.dart`, `inventory_page.dart` | P1 | Controller dibuat di method sheet tanpa cleanup setelah sheet ditutup | Dispose controller setelah `showModalBottomSheet` selesai | Selesai |
| Label stok "Plus" dan "Minus" kurang konsisten dengan istilah bisnis | `inventory_page.dart` | P2 | Label teknis tidak menjelaskan pergerakan stok | Ganti menjadi "Stok Masuk" dan "Stok Keluar" | Selesai |
| Dashboard card menampilkan nilai panjang terpotong | `lib/core/widgets/summary_card.dart` | P2 | Nilai memakai `maxLines: 1` dan ellipsis | Gunakan `FittedBox(scaleDown)` untuk nilai ringkas seperti jam shift | Selesai |
| Rebuild terlalu luas dari `previewDataProvider` | Banyak halaman fitur | P1 | Halaman melakukan `ref.watch(previewDataProvider)` walau hanya perlu satu list | Ganti ke `select(...)` pada halaman daftar dan laporan yang sederhana | Sebagian selesai |
| Dashboard masih watch seluruh preview state | `dashboard_page.dart` | P2 | Dashboard memang menghitung banyak agregasi dari seluruh data preview | Pindahkan agregasi ke repository/DAO setelah Drift masuk | Belum selesai |
| Data belum permanen setelah aplikasi ditutup | `lib/shared/preview_data.dart` | P0 untuk fase Drift | Preview state masih in-memory/session | Lanjut Fase 2: Drift database lokal dan repository per fitur setelah overflow dasar stabil | Belum selesai |
| Query/sorting/agregasi masih dilakukan di widget build | `dashboard_page.dart`, `reports_page.dart`, sebagian halaman daftar | P2 | Belum ada DAO/repository agregasi offline | Pindahkan agregasi ke DAO/repository, gunakan stream/query agregat lokal saat Drift | Belum selesai |
| Responsive matrix semua route belum lengkap | `test/` | P1 | Test layout baru baru mencakup empty state dan Pesanan Karyawan | Tambah helper route matrix Owner/Karyawan pada ukuran 320, 360, 390, 412, 480 dan text scale 1.0/1.3/1.5 | Belum selesai |

## Catatan Performa Awal

- `previewDataProvider` masih file besar dan menjadi penyimpanan utama sementara.
- Rebuild global sudah dikurangi pada halaman daftar sederhana memakai `provider.select(...)`.
- Potensi freeze yang tersisa paling mungkin berasal dari kombinasi emulator low RAM, dashboard agregasi di build, dan belum adanya database lokal/pagination.
- Tidak ada operasi file I/O besar atau export production yang dijalankan di method `build` pada tahap ini.
- Drift belum dieksekusi pada perubahan ini agar Fase 1 overflow/stabilitas dasar tetap kecil dan mudah diverifikasi.
