# 3. Secrets dan Akses

## 1. Prinsip

- Dokumentasi hanya memuat **nama secret**, pemilik, fungsi, dan prosedur rotasi.
- Nilai secret tidak disimpan di Git, issue, log, screenshot, atau chat.
- Akses diberikan sekecil mungkin dan dipisahkan per environment.
- Service-role Supabase tidak pernah masuk ke Vite, Flutter, APK, atau browser.
- Private key deploy berbeda dari key pribadi administrator.

## 2. GitHub Actions secrets saat ini

| Secret | Fungsi | Paparan |
| --- | --- | --- |
| `VPS_HOST` | Alamat tujuan SSH | Runner GitHub Actions |
| `VPS_PORT` | Port SSH | Runner GitHub Actions |
| `VPS_USER` | Akun deployment terbatas | Runner GitHub Actions |
| `VPS_SSH_KEY` | Private key deployment | Runner GitHub Actions, file sementara mode 600 |
| `VITE_SUPABASE_URL` | URL project Supabase | Ditanam ke bundle browser; bukan rahasia |
| `VITE_SUPABASE_ANON_KEY` | Publishable/anon key | Ditanam ke bundle browser; keamanan bergantung pada RLS |

Keenam nama secret terdaftar pada repository per 20 September 2026. Nilainya tidak diverifikasi atau ditampilkan.

## 3. Matriks akses

| Aktor | GitHub | VPS | Supabase | Release Android |
| --- | --- | --- | --- | --- |
| Owner teknis | Admin sesuai kebutuhan | Akses administrasi terpisah | Owner/project admin | Menjaga signing/release authority |
| GitHub Actions | Read repository dan environment secret | SSH sebagai `dandivps-deploy` | Anon key untuk build web | Belum dipakai untuk publish Android |
| Akun deploy VPS | Tidak ada | Tulis hanya staging, backup project, dan webroot terkait | Tidak ada | Tidak ada |
| Dashboard browser | Public static asset | HTTP read | Anon/publishable + user JWT/RLS | Tidak ada |
| Aplikasi Android | Source/build config | Tidak ada | Anon/publishable + user JWT/RLS | Membaca manifest dan APK public |

## 4. SSH trust

Host `202.10.47.56` memiliki ED25519 fingerprint yang terverifikasi secara lokal:

```text
SHA256:UUg4tWDLjq/RwXde+Tha7KBPH8LUQdiZCNzOwvf+mzA
```

Workflow mem-pin public host key ED25519. Jika VPS direbuild atau host key berubah:

1. jangan langsung mengganti key karena error;
2. verifikasi perubahan melalui console provider atau kanal administratif terpisah;
3. ambil fingerprint baru dari console terpercaya;
4. bandingkan dan dokumentasikan alasan;
5. baru perbarui workflow/known_hosts.

## 5. Rotasi

### Key deployment VPS

1. Buat key baru khusus GitHub Actions.
2. Tambahkan public key ke `authorized_keys` akun deploy.
3. Uji koneksi dengan key baru.
4. Perbarui `VPS_SSH_KEY`.
5. Jalankan workflow manual dan verifikasi.
6. Hapus public key lama.
7. Catat tanggal rotasi dan pemilik.

### Supabase keys

- Rotasi publishable/anon key harus diikuti build ulang dashboard dan APK.
- Bila service-role diduga bocor, rotasi segera dan audit penggunaan; jangan menunggu jadwal rutin.
- Pastikan RLS tetap aktif karena anon key memang dapat terlihat di client.

## 6. Data yang masih perlu dicatat di secret manager

- akun/provider VPS dan recovery console;
- akun administrator VPS;
- port SSH aktual;
- private key deployment dan tanggal rotasi;
- backup signing keystore Android dan recovery procedure;
- akses GitHub owner;
- akses Supabase owner dan recovery codes;
- domain registrar/DNS apabila domain dipasang.

