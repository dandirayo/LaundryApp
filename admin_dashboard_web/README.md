# Idola One Admin Dashboard

Website Owner untuk membaca dan mengelola data operasional yang sama dengan aplikasi Android Idola One. Dibangun dengan React, TypeScript, Vite, dan Supabase.

## Modul yang tersedia

- Ringkasan operasional Owner.
- Review pengajuan karyawan.
- Status pesanan dan pembayaran.
- Pelanggan.
- Karyawan dan jadwal mingguan.
- Inventaris dan mutasi stok.
- Buku Kas, ekspor CSV, dan audit aktivitas.
- Pengaturan profil toko.
- Realtime lintas perangkat dengan rekonsiliasi setiap 15 detik.
- Proyek laundry besar: target pcs, tarif per kg/per pcs, batch harian, dan pembayaran yang masuk Buku Kas.
- Insentif per item sepatu/helm/tas; Owner dapat mengatur sebelum selesai dan membayar setelah hak karyawan muncul.
- Katalog layanan dan harga yang dapat diedit Owner.
- Koreksi pembayaran pesanan oleh Owner: nominal, metode, dan tanggal tetap sinkron dengan tagihan, Buku Kas, dan Audit.
- Submenu Pesanan untuk daftar/status, edit detail, ganti layanan kiloan, dan koreksi pembayaran agar halaman tidak memanjang.
- Audit aktivitas dengan pencarian, filter, garis waktu, dan perbandingan data sebelum/sesudah.

## Menjalankan project

Salin konfigurasi publik Supabase ke environment lokal:

```text
VITE_SUPABASE_URL=...
VITE_SUPABASE_ANON_KEY=...
```

Jangan pernah memasukkan `service_role` key ke environment Vite karena seluruh nilai `VITE_*` dikirim ke browser.

```bash
npm install
npm run dev
npm run lint
npm run build
```

## Rencana pengembangan

Daftar fitur, kontrak realtime, status sinkronisasi, prioritas, dan Definition of Done tersedia di [Blueprint Website Admin](../docs/product/07-ADMIN-DASHBOARD-BLUEPRINT.md).

## Deployment produksi

Website saat ini **tetap lokal** sesuai permintaan Owner; build lokal tidak otomatis menerbitkan situs ke VPS. Panduan deployment dan pemulihan untuk nanti tersedia di [Deployment Website Admin ke VPS](../docs/deployment/08-ADMIN-DASHBOARD-DEPLOYMENT.md). Jika workflow GitHub Actions lama masih aktif, jangan dorong perubahan ke branch pemicu deploy sebelum VPS dan domain baru siap.
