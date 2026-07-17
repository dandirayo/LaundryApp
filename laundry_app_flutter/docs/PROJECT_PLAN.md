# Project Plan

## Phase 0 - Analisis dan Perencanaan

Status: selesai pada dokumen ini.

Output:

- `docs/FEATURE_MATRIX.md`
- `docs/ROUTES.md`
- `docs/DATABASE_SCHEMA.md`
- `docs/PROJECT_PLAN.md`

Keputusan utama:

- Rebuild memakai Flutter, bukan port struktur Kotlin lama.
- Supabase Auth/PostgreSQL/Realtime/Storage menjadi backend utama.
- Drift ditunda sampai alur online stabil.
- Semua relasi bisnis memakai UUID.
- Status bisnis diproteksi oleh enum domain dan check constraint.

## Phase 1 - Foundation

Target:

- Flutter project Android/iOS-ready.
- Theme Material 3, DM Sans, warna Idola Laundry.
- Feature-first folder structure.
- Config Supabase tanpa secret di Git.
- Result/Failure, logger sederhana, formatter Indonesia.
- Riverpod auth/session bootstrap.
- GoRouter role guard.
- Shell navigation Owner/Karyawan.
- Halaman valid untuk seluruh menu Phase 1.
- Shared state widgets: loading, empty, error, retry, offline banner.
- SQL migration, seed, README setup, GitHub Actions, test foundation.

Exit criteria:

- `dart format` bersih.
- `flutter analyze` tanpa error.
- `flutter test` lulus.
- `docs/PROJECT_STATUS.md` terupdate.
- Commit lokal Phase 1 dibuat.

## Phase 2 - Core Transaction

Target:

- Pelanggan CRUD dengan normalisasi telepon.
- Layanan & harga CRUD.
- Flow pesanan bertahap.
- Order item snapshot.
- Pembayaran DP/pelunasan idempotent.
- Receipt preview/PDF fallback.
- Daftar/detail pesanan dengan filter, search, empty/error/retry.

## Phase 3 - Operasional

Target:

- Data karyawan.
- Absensi foto.
- Jadwal shift dengan validasi bentrok.
- Stok dan pengadaan.
- Request karyawan.
- Notifikasi realtime dasar.

## Phase 4 - Keuangan

Target:

- Buku Pesanan.
- Buku Kas.
- Pengeluaran.
- Gaji, insentif, kasbon.
- Export CSV/PDF.

## Phase 5 - Integrasi

Target:

- Supabase Realtime production subscription.
- FCM.
- Supabase Storage upload/retry.
- Bluetooth printer Android.
- Backup/export.
- Importer migrasi data Kotlin lama via CSV/JSON.

## Phase 6 - Offline

Target:

- Drift cache.
- Draft pesanan.
- Offline operation queue.
- Retry idempotent.
- Conflict handling terdokumentasi.

## Phase 7 - UI Polish

Target:

- Responsive check 320, 360, 390, 412, 480 px.
- Text scaling.
- Skeleton loading.
- Accessibility.
- Micro-animation hemat.
- Performance pass.

## Phase 8 - QA

Target:

- Unit test.
- Repository/provider/widget/router/integration test.
- Database function test.
- RLS policy test.
- Build APK debug.
- Dokumentasi final.
