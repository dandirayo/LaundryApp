# Android Cloud Updates

**Diverifikasi:** 11 Oktober 2026

**Rilis aktif:** 2.1.11+27

**Dipublikasikan:** 11 Oktober 2026

## Status rilis

Manifest production berada di:

```text
https://sqydcdhvsmmkvlpsjzgx.supabase.co/storage/v1/object/public/app-releases/android/latest.json
```

Manifest aktif berisi APK untuk `arm64-v8a`, `armeabi-v7a`, dan `x86_64`. Release 2.1.11+27 menampilkan nominal Tunai/Transfer di Laporan dan Buku Kas untuk setiap filter waktu, menambah filter Kemarin pada Buku Kas, dan memberi Owner serta karyawan halaman Laporan Pembayaran khusus dengan draf WhatsApp untuk Owner. Hybrid berarti nota dengan pembayaran Tunai sekaligus Transfer; nominalnya sudah termasuk pada metode tersebut dan hanya menghitung kedua metode walau nota juga memiliki QRIS. Pembayaran dan kas dibaca bertahap agar periode panjang tidak berhenti pada 500 baris. Rilis 2.1.9+25 sebelumnya menambahkan sinkron otomatis pelanggan baru dengan akun Google terpilih.

Delapan item stok yang belum ada ditambahkan ke toko produksi dengan stok awal 0. Item `Plastik 45` yang sudah ada dibiarkan pada jumlah dan satuan sebelumnya; Owner perlu memeriksa satuannya setelah opname.

Titik source release 2.1.11 disimpan pada tag Git lokal `v2.1.11-build27`. Tag source versi sebelumnya tetap `v2.1.9-build25`. Commit/tag baru belum didorong ke GitHub agar perubahan website lokal tidak ikut memicu deploy.

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
- Untuk perangkat yang sudah update, checkout source versi stabil sebelumnya, naikkan nomor build di atas versi yang terpasang, lalu publikasikan sebagai release rollback. Android tidak menerima downgrade versionCode.
- Pertahankan APK immutable yang dirujuk manifest rollback.
- Pertahankan tag `v2.1.7-build23` agar perubahan baru dapat diedit dan diterbitkan lagi setelah masalah diperbaiki.
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
