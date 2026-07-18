# Project Status

Tanggal update: 18 Juli 2026

## Status Saat Ini

- Phase 0 selesai: analisis fitur Kotlin lama dan dokumen rencana sudah dibuat.
- Phase 1 berjalan: foundation Flutter, theme, router, role guard, auth preview, dan shell navigasi sudah aktif.
- Phase 2 sampai Phase 4 berjalan dalam mode preview lokal: pelanggan, layanan, pesanan, pembayaran, Buku Kas, stok, absensi, shift, request, gaji, laporan, pengeluaran, profil, backup, printer fallback.

## Perubahan Terbaru

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
- `flutter test`: 4 test lulus.
- `flutter build apk --debug`: berhasil.
- APK: `build/app/outputs/flutter-apk/app-debug.apk`

## Belum Selesai

- Supabase migration, seed, RLS, dan koneksi production.
- Supabase Realtime, Storage foto, Drift offline queue, dan FCM.
- Printer Bluetooth thermal production.
- Export file CSV/PDF production.
- Importer migrasi data Kotlin lama.
- Test integrasi, test RLS, dan GitHub Actions.
