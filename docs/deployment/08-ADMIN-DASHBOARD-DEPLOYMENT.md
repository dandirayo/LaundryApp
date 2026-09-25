# Deployment Dashboard Admin ke VPS

**Diverifikasi:** 20 September 2026

Dashboard admin dibangun oleh GitHub Actions dan diterbitkan sebagai file statis ke VPS `202.10.47.56`. Nginx membaca hasil deployment dari `/var/www/apps/dandivps-deploy` dan workflow memeriksa `http://202.10.47.56:8081/`.

## Status saat ini

| Item | Status |
| --- | --- |
| Workflow `Deploy Admin Dashboard` | Aktif |
| Trigger otomatis | Push ke `main` untuk `admin_dashboard_web/**` atau file workflow |
| Trigger manual | `workflow_dispatch` |
| GitHub secrets | Enam nama secret yang diwajibkan terdaftar |
| Deploy sukses terakhir yang terlihat | 6 September 2026, run `34026106625` |
| Pemeriksaan host 20 September 2026 | Port 80, 443, dan 8081 timeout; perlu pemeriksaan VPS/firewall/provider |

## Alur deployment

1. Perubahan dashboard masuk ke `main`.
2. Runner memakai Node 22 dan menjalankan `npm ci`.
3. `npm run lint` dan `npm run build` harus lulus.
4. `dist/` dikirim melalui SSH/rsync ke staging.
5. VPS mengarsipkan webroot lama sebagai `previous.tar.gz`.
6. Staging disinkronkan ke webroot dengan `rsync --delete`.
7. Workflow memastikan `index.html` tersedia.
8. Runner melakukan HTTP health check dengan retry.

Deployment serial memakai concurrency group `dandivps-deploy-production` dan tidak membatalkan deployment aktif.

## Folder VPS

| Fungsi | Lokasi |
| --- | --- |
| Webroot | `/var/www/apps/dandivps-deploy` |
| Staging | `/home/dandivps-deploy/deploy-staging/dandivps-deploy` |
| Backup sebelumnya | `/home/dandivps-deploy/backups/dandivps-deploy/previous.tar.gz` |

## GitHub Actions secrets

| Secret | Fungsi |
| --- | --- |
| `VPS_HOST` | Host/IP tujuan |
| `VPS_PORT` | Port SSH |
| `VPS_USER` | Akun deploy terbatas |
| `VPS_SSH_KEY` | Private key deployment |
| `VITE_SUPABASE_URL` | URL Supabase production |
| `VITE_SUPABASE_ANON_KEY` | Publishable/anon key untuk browser |

Nilai `VITE_*` masuk ke bundle browser dan harus dilindungi oleh RLS. `service_role`, password, private key, dan nilai secret tidak boleh disimpan di Git atau log.

## Kontrol keamanan

- Akun `dandivps-deploy` hanya memerlukan akses staging, backup project, dan webroot.
- Workflow mem-pin host key ED25519; pemeriksaan identitas server tidak dinonaktifkan.
- Perubahan host key harus diverifikasi melalui console/provider sebelum workflow diperbarui.
- Target path dibandingkan dengan nilai tetap sebelum rsync.
- Deployment berhenti jika webroot/staging/index/rsync tidak valid.
- Nginx tidak perlu restart untuk penggantian static asset.

## Pemeriksaan endpoint yang timeout

1. Periksa power dan IP dari console provider.
2. Periksa firewall/security group provider.
3. Periksa listener `80`, `443`, dan `8081` dengan `ss -lntp`.
4. Jalankan `nginx -t` dan periksa `systemctl status nginx`.
5. Periksa UFW, disk, inode, serta log Nginx.
6. Setelah pulih, jalankan workflow manual dan health check dari jaringan luar.

## Rollback

Backup saat ini hanya satu generasi. Untuk rollback:

1. simpan snapshot webroot yang bermasalah;
2. ekstrak `previous.tar.gz` ke staging rollback;
3. pastikan `index.html` valid;
4. rsync staging rollback ke webroot;
5. verifikasi URL dan login/data dasar;
6. catat commit serta penyebab rollback.

Peningkatan yang masih diperlukan: backup bertimestamp, retensi beberapa rilis, artifact CI, HTTPS/domain, timeout job, dan auto rollback jika health check gagal. Rincian operasional ada di [CI/CD](02-CICD-AUTO-DEPLOY.md), [Runbook](05-OPERATIONS-RUNBOOK.md), dan [Backup/DR](06-BACKUP-ROLLBACK-DR.md).

