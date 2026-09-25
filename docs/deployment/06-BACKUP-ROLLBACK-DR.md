# 6. Backup, Rollback, dan Disaster Recovery

## 1. Kondisi saat ini

Dashboard membuat satu backup rilis sebelumnya:

```text
/home/dandivps-deploy/backups/dandivps-deploy/previous.tar.gz
```

APK disimpan pada path immutable berbasis build/ABI/hash di Supabase Storage. Database dikelola oleh Supabase dan perlu mengikuti fasilitas backup project serta ekspor tambahan sesuai kebutuhan bisnis.

## 2. Kelemahan yang perlu diperbaiki

- Backup dashboard hanya satu generasi dan berada di VPS yang sama.
- Belum ada bukti backup terenkripsi di lokasi lain.
- Belum ada uji restore berkala yang terdokumentasi.
- RTO/RPO belum ditentukan.
- Endpoint produksi belum memakai domain/HTTPS yang terdokumentasi.

## 3. Target backup

| Aset | Frekuensi | Retensi minimum | Lokasi |
| --- | --- | --- | --- |
| Artifact dashboard | Setiap deploy | 10 rilis atau 30 hari | GitHub artifact/object storage |
| Webroot snapshot | Setiap deploy | 7–14 versi | VPS + offsite |
| Database Supabase | Sesuai paket + ekspor terjadwal | 30 hari atau kebutuhan hukum | Provider + offsite terenkripsi |
| Storage penting | Harian/berkala | 30 hari | Offsite terenkripsi |
| APK immutable dan manifest | Setiap release | Selama build masih dapat dipasang | Supabase Storage + salinan release |
| Android signing material | Saat berubah | Permanen | Dua lokasi aman di luar Git |
| Konfigurasi Nginx/firewall | Setiap perubahan | Versi terakhir + histori | Repository privat/backup config |

## 4. Rollback dashboard

Prosedur saat ini:

1. hentikan deployment baru;
2. verifikasi `previous.tar.gz` tersedia dan tidak korup;
3. buat snapshot webroot yang bermasalah untuk forensik;
4. ekstrak backup ke staging sementara;
5. periksa `index.html`;
6. `rsync --archive --delete` staging rollback ke webroot;
7. cek URL dari jaringan luar;
8. catat commit yang di-rollback dan akar masalah.

Target pipeline berikutnya harus melakukan rollback otomatis bila post-deploy health check gagal.

## 5. Rollback Android

Android menolak downgrade build. Pilihan aman:

- tarik penawaran bermasalah dengan memulihkan `latest.json` sebelumnya untuk pengguna yang belum update;
- buat build perbaikan dengan nomor build lebih tinggi untuk pengguna yang sudah update;
- jangan menghapus APK immutable yang masih dirujuk manifest;
- jangan mengganti signing certificate secara mendadak.

## 6. Rollback database

Migration destructive tidak boleh mengandalkan rollback otomatis. Gunakan pola:

1. **expand:** tambah kolom/table/function kompatibel;
2. deploy backend/client yang dapat membaca dua bentuk;
3. migrasikan data;
4. amati;
5. **contract:** hapus bentuk lama pada rilis terpisah.

Untuk incident, prioritaskan forward fix. Restore database penuh hanya dilakukan ketika dampak dan kehilangan data sudah dinilai serta backup telah diuji.

## 7. Disaster recovery

Skenario kehilangan VPS:

1. buat VPS pengganti dari akun provider;
2. pasang Nginx, rsync, firewall, dan akun deploy terbatas;
3. pulihkan konfigurasi Nginx;
4. pulihkan artifact dashboard terakhir;
5. verifikasi dari IP sementara;
6. ubah DNS/secret host jika diperlukan;
7. verifikasi host key baru melalui console provider;
8. perbarui pinned key workflow;
9. jalankan deployment manual dan smoke test;
10. dokumentasikan RTO aktual.

## 8. Target RTO/RPO awal

Sebelum angka bisnis disepakati, target sementara yang realistis:

- dashboard statis: RTO 4 jam, RPO satu release;
- Android distribution: RTO 4 jam, RPO satu release;
- database transaksi: RTO mengikuti Supabase plan, target RPO maksimum 24 jam dan harus diperketat bila volume meningkat.

