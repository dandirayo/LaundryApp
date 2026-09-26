# Dokumentasi Produk Idola One

Dokumen ini merangkum produk dan implementasi **Idola One 2.1.3+19** per 26 September 2026. Isinya disusun dari kode aplikasi, migrasi dan schema Supabase produksi, histori Git, dokumentasi repository, serta task Codex yang relevan dengan LaundryApp.

## Cara membaca status

- **Selesai**: tersedia di aplikasi dan didukung kode/schema saat ini.
- **Sebagian**: alur utama tersedia, tetapi masih ada batasan yang dicatat.
- **Rencana**: belum menjadi kemampuan produksi.

## Dokumen

1. [Product Requirements Document](01-PRD.md)
2. [Technical Requirements Document](02-TRD.md)
3. [UI/UX Design Specification](03-UI-UX-DESIGN.md)
4. [Application Flow](04-APPFLOW.md)
5. [Backend Schema](05-BACKEND-SCHEMA.md)
6. [Implementation Plan](06-IMPLEMENTATION-PLAN.md)
7. [Admin Dashboard Blueprint](07-ADMIN-DASHBOARD-BLUEPRINT.md)
8. [Audit dan Upgrade Aplikasi Tahap 1–12](08-FOUNDATION-AUDIT-AND-UPGRADE.md)

Dokumentasi operasional terpisah tersedia di [Deployment dan VPS](../deployment/README.md).

Dokumentasi pengujian dan sinkronisasi tersedia di [Quality Assurance](../quality/README.md).

## Sumber kebenaran

Jika ada perbedaan, urutan sumber kebenaran adalah:

1. schema Supabase produksi dan kebijakan RLS aktif;
2. kode pada `laundry_app_flutter/lib`;
3. migrasi pada `supabase/migrations`;
4. dokumen ini;
5. percakapan dan dokumen lama.

Percakapan dipakai untuk menjelaskan tujuan produk. Status implementasi selalu diverifikasi terhadap kode dan database agar rencana lama tidak keliru dianggap sudah selesai.
