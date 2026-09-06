# Deployment Website Admin ke VPS

Website admin dibangun oleh GitHub Actions dan diterbitkan sebagai file statis ke VPS. Nginx membaca hasil deployment dari `/var/www/apps/idola-admin`.

## Alur deployment

1. Perubahan pada `admin_dashboard_web/**` masuk ke branch `main`.
2. GitHub Actions menjalankan `npm ci`, lint, dan build produksi.
3. Hasil `dist/` dikirim melalui SSH ke folder staging milik `idola-deploy`.
4. VPS membuat cadangan rilis sebelumnya di `/home/idola-deploy/idola-admin-previous.tar.gz`.
5. File staging disinkronkan ke `/var/www/apps/idola-admin`.
6. Workflow memeriksa bahwa website dapat diakses melalui HTTP di port `8081`.

Deployment juga dapat dijalankan manual dari tab **Actions**, workflow **Deploy Admin Dashboard**, lalu **Run workflow**.

## GitHub Actions secrets

Repository memerlukan GitHub Actions secrets berikut:

| Secret | Isi |
| --- | --- |
| `VPS_HOST` | IP atau domain VPS |
| `VPS_PORT` | Port SSH, biasanya `22` |
| `VPS_USER` | User deployment terbatas, yaitu `idola-deploy` |
| `VPS_SSH_KEY` | Private key khusus deployment |
| `VITE_SUPABASE_URL` | URL project Supabase yang digunakan aplikasi |
| `VITE_SUPABASE_ANON_KEY` | Publishable/anon key Supabase |

Jangan menyimpan password VPS, private key, atau nilai environment produksi di Git. Nilai `VITE_*` ikut dikirim ke browser; gunakan anon/publishable key dan jangan pernah memakai `service_role` key.

## Keamanan dan pemulihan

- Akun `idola-deploy` hanya membutuhkan akses tulis ke `/var/www/apps/idola-admin` dan tidak memerlukan `sudo`.
- SSH memeriksa host key VPS yang sudah diverifikasi di workflow; workflow tidak menonaktifkan pemeriksaan identitas server.
- Deployment berhenti jika target, staging, izin, atau `index.html` tidak valid.
- Untuk memulihkan rilis sebelumnya, ekstrak `/home/idola-deploy/idola-admin-previous.tar.gz` ke webroot menggunakan akun yang berwenang.
- Nginx tidak perlu direstart karena deployment hanya mengganti file statis.

## Pemeriksaan ketika deployment gagal

- Buka detail run pada tab **Actions** dan lihat langkah pertama yang gagal.
- Pastikan public key yang berpasangan dengan `VPS_SSH_KEY` masih berada di `/home/idola-deploy/.ssh/authorized_keys`.
- Pastikan `idola-deploy` dapat menulis ke `/var/www/apps/idola-admin`.
- Pastikan `rsync` tersedia di VPS.
- Pastikan kedua environment Supabase terisi dan berasal dari project yang sama dengan aplikasi Android.
