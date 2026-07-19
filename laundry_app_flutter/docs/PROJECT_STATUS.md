# Project Status

Tanggal update: 19 Juli 2026

## Status Saat Ini

- Phase 0 selesai: analisis fitur Kotlin lama dan dokumen rencana sudah dibuat.
- Phase 1 berjalan: foundation Flutter, theme, router, role guard, auth preview, dan shell navigasi sudah aktif.
- Phase 2 sampai Phase 4 berjalan dalam mode preview lokal: pelanggan, layanan, pesanan, pembayaran, Buku Kas, stok, absensi, shift, request, gaji, laporan, pengeluaran, profil, backup, printer fallback.

## Perubahan Terbaru

- Fase offline-stability dimulai dengan `docs/OFFLINE_UI_AUDIT.md`.
- Empty state dibuat scroll-safe untuk layar pendek dan text scale besar.
- Halaman Pesanan Karyawan diperbaiki agar daftar kosong tidak overflow dan FAB tidak bertabrakan dengan tombol empty state.
- Bottom sheet form utama memakai wrapper `AppBottomSheetBody` dengan `SafeArea`, scroll, dan padding keyboard.
- Banner "Mode online siap" dihapus selama tahap offline-first.
- Beberapa halaman daftar memakai `provider.select(...)` untuk mengurangi rebuild dari `previewDataProvider`.
- Test layout ditambahkan untuk layar 320x568 dengan text scale 1.5.
- Fix assertion Flutter `_dependents.isEmpty` pada aksi setelah bottom sheet/dialog dengan menunda mutasi provider sampai route transien selesai dibongkar.
- Form pelanggan, layanan, stok, shift, karyawan, pembayaran, request, pengeluaran, profil, backup, payroll, dan absensi memakai pola aksi aman setelah modal/dialog tertutup.
- Fix crash pembayaran dengan menutup bottom sheet lebih dulu sebelum update provider.
- Pembayaran pesanan otomatis memperbarui status tagihan dan masuk Buku Kas.
- Owner mendapat halaman Review Request untuk menyetujui, menolak, membayar, dan menyelesaikan request karyawan.
- Gaji mingguan per karyawan bisa dibayar dari halaman Gaji & Insentif dan tercatat idempotent di Buku Kas.
- Profil bisa diedit pada session preview.
- Export laporan/backup preview mencatat waktu backup terakhir dan membuat notifikasi lokal.
- Test preview ditambahkan untuk pembayaran, request berbayar, dan gaji mingguan.

## Verifikasi Terakhir

- `dart format lib test`: lulus.
- `flutter analyze`: No issues found.
- `flutter test`: diblokir Windows Application Control pada `flutter_tester.exe` di SDK temp; sebelumnya 6 test lulus sebelum policy ini aktif.
- `flutter build apk --debug`: berhasil.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`
- Smoke test HP `RRCT2017K6N`: APK berhasil di-install dan launch; tidak ada log assertion saat smoke awal.

## Belum Selesai

- Drift database offline permanen dan repository per fitur.
- Supabase migration, seed, RLS, dan koneksi production.
- Supabase Realtime, Storage foto, Drift offline queue, dan FCM.
- Printer Bluetooth thermal production.
- Export file CSV/PDF production.
- Importer migrasi data Kotlin lama.
- Test integrasi, test RLS, dan GitHub Actions.
