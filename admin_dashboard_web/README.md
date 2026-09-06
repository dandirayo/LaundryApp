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

Daftar fitur, kontrak realtime, status sinkronisasi, prioritas, dan Definition of Done tersedia di [Blueprint Website Admin](../docs/ADMIN_DASHBOARD_BLUEPRINT.md).
