# Dokumentasi Quality Assurance

Folder ini memuat prosedur verifikasi dan matriks konsistensi lintas aplikasi Android, dashboard admin, dan Supabase.

## Dokumen

1. [Smoke Test Owner dan Karyawan](01-SMOKE-TEST-OWNER-EMPLOYEE-SYNC.md)
2. [Matriks Sinkronisasi](02-SYNC-MATRIX.md)

## Kapan diperbarui

- Saat alur owner atau karyawan berubah.
- Saat tabel, realtime publication, notifikasi, atau aturan RLS berubah.
- Saat dashboard dan Android menambah sumber data atau mutation baru.
- Sebelum rilis yang mengubah pesanan, pembayaran, kas, pengajuan, absensi, atau stok.

Dokumen product menjelaskan **apa** yang dibangun, deployment menjelaskan **bagaimana** sistem dirilis dan dioperasikan, sedangkan folder ini menjelaskan **bagaimana konsistensi dan perilakunya diverifikasi**.
