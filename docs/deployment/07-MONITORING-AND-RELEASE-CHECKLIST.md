# 7. Monitoring dan Release Checklist

## 1. Monitoring minimum

| Komponen | Sinyal | Alert awal |
| --- | --- | --- |
| Dashboard VPS | HTTP status dan latency | Gagal 3 kali berturut-turut atau latency tinggi. |
| GitHub Actions | Conclusion workflow | Setiap deployment gagal. |
| Supabase | Error Auth/API/Database, quota, storage | Error spike, quota mendekati batas, koneksi gagal. |
| Android update | Manifest dan asset dapat diunduh | Manifest invalid, hash/size mismatch, download gagal. |
| Aplikasi | Crash dan RPC failure | Peningkatan error setelah release. |
| Disk VPS | Pemakaian disk/inode | Warning 75%, critical 90%. |
| TLS/domain | Masa berlaku certificate | 30, 14, dan 7 hari sebelum habis. |
| Backup | Job dan restore test | Backup gagal atau restore test terlambat. |

Karena URL produksi yang terdokumentasi masih raw HTTP/IP, prioritas pertama adalah memulihkan konektivitas lalu memasang domain HTTPS sebelum mengandalkan monitoring publik jangka panjang.

## 2. Checklist dashboard admin

### Sebelum merge

- [ ] Perubahan telah direview.
- [ ] `npm ci`, `npm run lint`, dan `npm run build` lulus.
- [ ] Perubahan backend yang dibutuhkan sudah tersedia dan kompatibel.
- [ ] Tidak ada secret/service-role di bundle atau log.
- [ ] Empty/error/loading state sudah diuji.

### Setelah deploy

- [ ] Workflow selesai sukses.
- [ ] URL dapat diakses dari luar jaringan VPS.
- [ ] Login owner berhasil.
- [ ] Dashboard dapat membaca data Supabase.
- [ ] Satu mutation aman diuji bila rilis menyentuh write flow.
- [ ] Realtime/refresh tetap bekerja.
- [ ] Backup rilis sebelumnya tersedia.

## 3. Checklist Android

### Sebelum publish

- [ ] `pubspec.yaml` memiliki version dan build lebih tinggi.
- [ ] `flutter analyze` lulus.
- [ ] `flutter test` lulus.
- [ ] Migration production yang diperlukan sudah diterapkan.
- [ ] Smoke test owner dan karyawan lulus.
- [ ] Printer 58/80 mm diuji bila layout cetak berubah.
- [ ] Release notes ringkas dan dipahami pengguna.

### Saat publish

- [ ] Script memverifikasi package ID, build, dan certificate.
- [ ] Semua ABI dan universal APK berhasil dibuat.
- [ ] Upload serta download-back SHA-256 lulus.
- [ ] `latest.json` dipublish paling akhir.
- [ ] Bootstrap APK disimpan di lokasi yang jelas.

### Setelah publish

- [ ] Perangkat lama mendeteksi update.
- [ ] Instalasi tidak menghapus sesi/data aplikasi.
- [ ] Login dan satu alur utama berhasil.
- [ ] Manifest dan asset tetap dapat diakses.
- [ ] Build bermasalah dapat ditarik atau diperbaiki dengan build lebih tinggi.

## 4. Checklist migration Supabase

- [ ] Migration baru, tidak mengubah file yang sudah diterapkan.
- [ ] DDL, constraint, index, grant, dan RLS direview.
- [ ] Fungsi `SECURITY DEFINER` memiliki `search_path` dan execute grant yang tepat.
- [ ] Owner, employee, anggota business, dan nonanggota diuji.
- [ ] Backward compatibility dengan APK lama diperiksa.
- [ ] Backup tersedia.
- [ ] Schema produksi diverifikasi setelah apply.
- [ ] Dashboard dan Android smoke test lulus.

## 5. Catatan pemeriksaan 20 September 2026

- GitHub workflow: aktif.
- GitHub secrets: enam nama secret yang diwajibkan terdaftar.
- Run deployment terakhir yang terlihat: sukses pada 6 September 2026.
- `http://202.10.47.56/`: timeout.
- `https://202.10.47.56/`: timeout.
- `http://202.10.47.56:8081/`: timeout.

Status tersebut adalah snapshot pemeriksaan, bukan diagnosis akar masalah.

