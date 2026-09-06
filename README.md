# Idola One — Laundry App

Idola One adalah aplikasi operasional Idola Laundry untuk mengelola pesanan, pelanggan, layanan, pembayaran, kas, karyawan, dan laporan harian dalam satu tempat. Aplikasi Android dibangun dengan Flutter dan memakai backend bersama agar data Owner dan karyawan tetap sinkron.

## Fitur Utama

- Pesanan **kiloan**, **satuan**, dan **gabungan** dengan katalog serta harga yang terkelompok.
- Input berat desimal per 0,1 kg dan opsi khusus pelanggan setia untuk pesanan di bawah 3 kg.
- Kartu pesanan ringkas dengan detail yang dapat dibuka dan status proses sampai siap diambil.
- Data pesanan dan angka dashboard tersinkron untuk Owner dan seluruh pengguna toko.
- Nama penerima pesanan tersimpan dan ditampilkan di bawah nomor nota.
- Pembayaran belum bayar, DP, lunas, nominal manual, serta metode pembayaran.
- Buku Kas otomatis mengikuti pembayaran pesanan dan mencatat pemasukan maupun pengeluaran.
- Pesan WhatsApp siap ambil dengan nomor dan template pelanggan; WhatsApp terbuka setelah status **Siap Diambil** dipilih.
- Data pelanggan, riwayat pesanan, dan impor kontak dari akun Google yang dipilih.
- Absensi masuk/keluar dengan foto, shift, keterlambatan, dan fitur **Lupa Absen** dengan alasan.
- Pengajuan karyawan untuk stok, izin dan jadwal, serta dana dan biaya dengan persetujuan Owner.
- Sinkronisasi realtime dengan penarikan data berkala sebagai cadangan ketika event realtime terlewat.
- Pembaruan aplikasi Android melalui pemberitahuan di dalam aplikasi tanpa perlu uninstall.
- Laporan operasional, payroll, inventaris, pengeluaran, dan notifikasi.

## Struktur Repositori

- `laundry_app_flutter/` — aplikasi Android utama berbasis Flutter.
- `admin_dashboard_web/` — dashboard administrasi web.
- `supabase/` — migration, function, seed, dan skrip verifikasi backend.
- `scripts/` — alat build serta publikasi rilis Android.
- `docs/` — dokumentasi operasional internal.

Rincian kesiapan fitur website, sumber data, kontrak realtime, gap, dan urutan pengembangan tersedia di [`docs/ADMIN_DASHBOARD_BLUEPRINT.md`](docs/ADMIN_DASHBOARD_BLUEPRINT.md).

## Rilis Android

Pembaruan cloud tersedia mulai versi `1.0.3+4`. Proses rilis membuat APK untuk beberapa arsitektur perangkat, memverifikasi package, versi, signature, ukuran, dan hash, lalu menerbitkan manifest pembaruan setelah seluruh APK lolos pemeriksaan.

Panduan internal tersedia di [`docs/android-cloud-updates.md`](docs/android-cloud-updates.md). Kredensial dan konfigurasi produksi tidak disimpan di README.

## Kualitas

Project menggunakan analisis statis Flutter dan pengujian otomatis untuk alur penting seperti sinkronisasi pesanan dan kas, kontak, pengajuan karyawan, pembaruan aplikasi, pembayaran, katalog layanan, serta layout perangkat kecil.

## Status

Aplikasi aktif dikembangkan dan diuji untuk penggunaan operasional Idola Laundry. Fitur dapat berubah mengikuti kebutuhan toko dan hasil pengujian lapangan.

## Catatan Publik

README ini hanya menampilkan gambaran umum project. Dokumentasi setup, akses sistem, konfigurasi layanan, dan catatan produksi disimpan terpisah untuk penggunaan internal.
