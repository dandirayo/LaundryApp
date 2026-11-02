# Idola One — Laundry App

Idola One adalah sistem operasional dan POS multi-usaha untuk **Idola Laundry** dan unit usaha pendukung (seperti booth minuman/Es Teh Manis). Sistem ini menghubungkan aplikasi mobile kasir/karyawan (Flutter Android), dashboard web manajemen pemilik/Owner (React Vite), serta backend database cloud (Supabase PostgreSQL & Realtime).

> **Master Blueprint & Alur Lengkap**:  
> Seluruh alur operasional, peran, skema keuangan, printer thermal, dan checklist SOP dirangkum secara ringkas dan tegas di **[`BLUEPRINT.md`](BLUEPRINT.md)**.

## Fitur Utama

- **Pesanan Fleksibel**: Kiloan (desimal 0,1 kg), satuan terkelompok, dan pesanan campuran (*mix*).
- **Pembulatan Otomatis**: Total pesanan selalu dibulatkan ke atas ke kelipatan Rp1.000 terdekat.
- **Kartu Pesanan Ringkas**: Detail *collapsible*, riwayat status proses (Cuci, Kering, Setrika, Siap Diambil, Selesai).
- **Otomasi WhatsApp**: Langsung membuka pesan WhatsApp siap ambil ke nomor pelanggan saat status pesanan menjadi **Siap Diambil**.
- **Printer Bluetooth Thermal**: Cetak modular nota pelanggan, label cucian plastik, dan bukti pengambilan (ESC/POS 58 mm & 80 mm).
- **Buku Kas Otomatis (Zero Leakage)**: Pembayaran pesanan (DP/Lunas) langsung terjurnal ke buku kas; koreksi transaksi hanya dapat dilakukan oleh Owner dengan audit trail.
- **Multi-Usaha**: Satu akun login dapat beralih antara operasional Laundry dan kasir POS Minuman harian.
- **SDM & Absensi**: Presensi selfie kamera datang/pulang, deteksi keterlambatan, pengajuan lembur/izin, dan tiket "Lupa Absen".
- **Pusat Pengajuan (Approval Center)**: Alur permohonan stok dan kasbon karyawan yang disetujui Owner sebelum mutasi dicatat.
- **Proyek Besar (B2B)**: Pengelolaan cucian borongan instansi dengan target *pieces*, sistem batch harian, dan termin pembayaran.
- **Pembaruan Mandiri (Cloud OTA Update)**: Pembaruan APK Android langsung dari aplikasi tanpa perlu uninstall manual.

## Struktur Repositori

- **[`BLUEPRINT.md`](BLUEPRINT.md)** — **Master blueprint tunggal**, mencakup seluruh flow, arsitektur peran, dan SOP operasional.
- `laundry_app_flutter/` — aplikasi Android utama berbasis Flutter.
- `admin_dashboard_web/` — dashboard web Owner berbasis React + Vite.
- `supabase/` — migrasi database, RPC, trigger, RLS, dan Edge Functions.
- `scripts/` — skrip build dan publikasi APK Android (`publish-android.ps1`).
- `docs/` — dokumentasi historis dan teknis mendalam (product, deployment, QA).

## Dokumentasi Pendukung

Bagi pengembang yang membutuhkan referensi teknis mendalam:
- **Katalog Produk & Arsitektur**: [`docs/product/README.md`](docs/product/README.md)
- **Deployment, VPS, & Rilis APK**: [`docs/deployment/README.md`](docs/deployment/README.md)
- **Quality Assurance & Sync Matrix**: [`docs/quality/README.md`](docs/quality/README.md)
- **Panduan Karyawan**: [`tutorial-karyawan/README.md`](tutorial-karyawan/README.md)
