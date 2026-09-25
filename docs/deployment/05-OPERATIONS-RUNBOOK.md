# 5. Runbook Operasional

## 1. Pemeriksaan harian ringan

1. Buka URL produksi dan pastikan halaman awal termuat.
2. Periksa run GitHub Actions terbaru bila ada perubahan web.
3. Pastikan tidak ada laporan login, data realtime, atau update APK gagal.
4. Bila ada incident, catat waktu, komponen, pengguna terdampak, dan perubahan terakhir.

## 2. Menjalankan deployment dashboard

### Otomatis

Merge perubahan `admin_dashboard_web/**` ke `main`. Workflow akan berjalan karena path filter.

### Manual

1. Buka repository GitHub.
2. Pilih **Actions**.
3. Pilih **Deploy Admin Dashboard**.
4. Pilih **Run workflow** pada `main`.
5. Pantau setiap step sampai verification selesai.

## 3. Diagnosis deployment gagal

| Step gagal | Pemeriksaan |
| --- | --- |
| `npm ci` | Lockfile sinkron, registry tersedia, Node 22 kompatibel. |
| `npm run lint` | Buka annotation/log dan perbaiki source. |
| `npm run build` | Periksa TypeScript serta keberadaan dua secret `VITE_*`. |
| Configure SSH | Format private key dan secret tidak kosong. |
| Upload staging | Host/port/user, network VPS, public key di `authorized_keys`, dan `rsync`. |
| Publish release | Webroot ada, writable, staging punya `index.html`, disk tidak penuh. |
| Verify response | Nginx, port/firewall, URL, dan isi webroot. |

Jangan menjalankan ulang berkali-kali sebelum memahami step yang gagal.

## 4. Incident: endpoint timeout

Kondisi ini terjadi pada pemeriksaan 20 September 2026.

Urutan pemeriksaan:

1. Buka console provider VPS dan lihat power/status network.
2. Pastikan public IP masih `202.10.47.56`.
3. Periksa security group/firewall provider.
4. Masuk melalui SSH/console administratif.
5. Periksa `systemctl status nginx` dan `nginx -t`.
6. Periksa listener dengan `ss -lntp`.
7. Periksa UFW/firewall untuk SSH, 80/443, dan 8081 sesuai desain.
8. Periksa disk dan inode dengan `df -h` dan `df -i`.
9. Periksa log Nginx dan system journal pada rentang incident.
10. Setelah perbaikan, jalankan health check dari luar VPS dan workflow manual.

Perintah diagnosis harus dijalankan oleh administrator yang memiliki akses console/SSH. Catat hasilnya pada incident log tanpa menyalin secret.

## 5. Incident: dashboard tampil tetapi data gagal

1. Pastikan bundle terbaru benar-benar terpasang.
2. Periksa browser Network/Console untuk error Supabase.
3. Pastikan `VITE_SUPABASE_URL` menunjuk project production yang benar.
4. Pastikan anon key aktif.
5. Uji login dan periksa JWT/profile.
6. Periksa RLS/grant/function yang baru berubah.
7. Cocokkan migration produksi dengan repository.
8. Rollback web bila kontrak backend ternyata belum tersedia.

## 6. Incident: Android update gagal

1. Pastikan `latest.json` dapat diakses.
2. Periksa build baru lebih tinggi dari versi terpasang.
3. Cocokkan package ID dan signing certificate.
4. Periksa asset ABI, size, dan SHA-256 dalam manifest.
5. Pastikan izin install unknown apps diberikan untuk aplikasi.
6. Jika manifest buruk, pulihkan manifest sebelumnya; pengguna yang sudah memasang build bermasalah memerlukan build perbaikan dengan nomor lebih tinggi.

## 7. Incident log minimum

```text
Waktu mulai:
Waktu pulih:
Komponen:
Dampak:
Gejala:
Perubahan terakhir:
Akar masalah:
Tindakan pemulihan:
Pencegahan:
PIC:
```

