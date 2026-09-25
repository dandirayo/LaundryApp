# Dokumentasi Deployment dan VPS

Dokumen ini menjelaskan deployment Idola One berdasarkan konfigurasi repository, GitHub Actions, Supabase, dan host yang dapat diverifikasi pada 20 September 2026.

## Daftar dokumen

1. [Arsitektur dan Environment](01-ARCHITECTURE-AND-ENVIRONMENTS.md)
2. [CI/CD dan Auto Deploy](02-CICD-AUTO-DEPLOY.md)
3. [Secrets dan Akses](03-SECRETS-AND-ACCESS.md)
4. [Inventaris VPS](04-VPS-INVENTORY.md)
5. [Runbook Operasional](05-OPERATIONS-RUNBOOK.md)
6. [Backup, Rollback, dan Disaster Recovery](06-BACKUP-ROLLBACK-DR.md)
7. [Monitoring dan Release Checklist](07-MONITORING-AND-RELEASE-CHECKLIST.md)
8. [Deployment Dashboard Admin](08-ADMIN-DASHBOARD-DEPLOYMENT.md)
9. [Android Cloud Updates](09-ANDROID-CLOUD-UPDATES.md)

## Status ringkas

| Komponen | Cara rilis | Status yang terverifikasi |
| --- | --- | --- |
| Dashboard admin | Auto deploy GitHub Actions ketika `admin_dashboard_web/**` berubah di `main` | Workflow aktif; deployment terakhir 6 September 2026 berhasil. |
| Aplikasi Android | Script release lokal ke Supabase Storage, lalu instalasi dikonfirmasi pengguna | Tersedia; belum otomatis dari GitHub Actions. |
| Database Supabase | Migration terkontrol melalui Supabase CLI/MCP | Migration tersedia; belum menjadi pipeline auto deploy. |
| VPS dashboard | Nginx/static web pada `202.10.47.56` | Teridentifikasi, tetapi HTTP/HTTPS/port 8081 timeout saat pemeriksaan 20 September 2026. |

## Batas inventaris

Inventaris hanya menyatakan host sebagai VPS aktif jika ada bukti host/IP dan pemakaian deployment. Repository lain yang hanya memiliki Dockerfile, Nginx, atau script setup tanpa host dicatat sebagai **belum terverifikasi**, bukan sebagai VPS tambahan.

Nilai rahasia tidak disimpan di dokumentasi ini. Password, token, private key, service-role key, dan isi `.env` harus tetap berada di secret manager atau penyimpanan aman.
