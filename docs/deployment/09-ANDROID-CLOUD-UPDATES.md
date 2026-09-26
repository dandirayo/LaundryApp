# Android Cloud Updates

**Diverifikasi:** 25 September 2026  
**Rilis aktif:** 2.1.3+19  
**Dipublikasikan:** 25 September 2026

## Status rilis

Manifest production berada di:

```text
https://sqydcdhvsmmkvlpsjzgx.supabase.co/storage/v1/object/public/app-releases/android/latest.json
```

Manifest aktif berisi APK untuk `arm64-v8a`, `armeabi-v7a`, dan `x86_64`. Release produksi saat ini adalah 2.1.3+19. Kandidat 2.1.4+20 merapikan fondasi UI dan navigasi, alur buat pesanan, pencarian katalog, keranjang, pembayaran, status, cetak satu per satu, daftar pesanan, serta detail pesanan tanpa mengubah harga dan aturan bisnis.

Versi bootstrap pertama yang mendukung update cloud adalah 1.0.3+4. Perangkat pada 1.0.2 atau lebih lama harus memasang bootstrap APK sekali di atas aplikasi lama.

## Perilaku aplikasi

Aplikasi memeriksa `latest.json`:

- saat widget update aktif/startup;
- saat aplikasi kembali `resumed`, dengan throttle satu menit;
- setiap lima menit selama foreground;
- ketika pengguna menekan cek manual di **Lainnya > Pembaruan aplikasi**.

Aplikasi tidak membangunkan proses yang sudah ditutup. Gangguan jaringan tidak memblokir operasional Laundry/POS.

Saat pengguna memilih update, aplikasi:

1. meminta izin instalasi aplikasi dari sumber ini bila perlu;
2. memilih APK berdasarkan ABI perangkat;
3. mengunduh ke cache privat;
4. memeriksa ukuran dan SHA-256;
5. memeriksa package ID, version code, dan signing certificate;
6. membuka layar konfirmasi installer Android.

Pembatalan instalasi tidak menghapus penawaran update. File valid dapat digunakan kembali saat retry.

## Mempublikasikan rilis berikutnya

1. Pastikan migration/backend yang dibutuhkan sudah tersedia dan backward-compatible.
2. Jalankan:

```powershell
cd laundry_app_flutter
flutter analyze
flutter test
cd ..
```

3. Naikkan `version` dan numeric build pada `laundry_app_flutter/pubspec.yaml`.
4. Kembali ke root repository dan jalankan:

```powershell
./scripts/publish-android.ps1 -ReleaseNotes 'Ringkasan perubahan untuk pengguna.'
```

Script menggunakan project Supabase yang terhubung dan Supabase CLI yang sudah login. Tahapnya:

1. build APK per ABI serta universal;
2. verifikasi package/version/signature;
3. upload APK ke path immutable `android/<build>/<abi>-<sha256>.apk`;
4. download-back dan cocokkan hash;
5. publish `latest.json` paling akhir sebagai commit point;
6. ekspor universal APK bernama `Idola One - YYYY-MM-DD.apk`.

`-SkipBuild` hanya boleh digunakan untuk artifact yang sudah dibuat dari source/build yang sama. Script tetap memvalidasi identitas dan signature.

## Keamanan Storage

- Bucket public hanya memuat APK dan metadata versi.
- Data pesanan, kontak, pembayaran, atau pelanggan tidak berada di bucket release.
- User aplikasi hanya perlu public read.
- Upload/update/delete memakai kredensial deployment terpercaya.
- Service-role tidak boleh masuk Dart define, source, APK, dokumentasi, atau log.

## Signing continuity

APK sideload yang sudah terpasang memakai certificate dengan SHA-256:

```text
ad35e77c429a49be539baf341ee18645195058abf65bbb9561e40c2b43da2794
```

Publisher menolak APK dengan certificate berbeda. Keystore harus dicadangkan di minimal dua lokasi aman di luar Git. Pergantian key memerlukan rencana migrasi perangkat; Android tidak menerima update dengan signer berbeda.

## Rollback dan hotfix

Android tidak menerima downgrade build.

- Untuk perangkat yang belum update, pulihkan manifest lama agar penawaran buruk hilang.
- Untuk perangkat yang sudah update, buat hotfix dengan build lebih tinggi.
- Pertahankan APK immutable yang dirujuk manifest rollback.
- Jangan membuat build fiktif hanya untuk menguji notifikasi production.
- Setelah hotfix, uji login, order, POS, printer, dan update dari build sebelumnya.

## Checklist ringkas

- [ ] Version dan build naik.
- [ ] Analyze/test lulus.
- [ ] Migration production siap.
- [ ] Smoke test owner/karyawan lulus.
- [ ] Package, signer, size, dan SHA-256 lulus.
- [ ] Semua ABI terunggah dan dapat diunduh.
- [ ] Manifest dipublish terakhir.
- [ ] Satu perangkat lama berhasil mendeteksi dan memasang update.
