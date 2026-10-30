# Android Cloud Updates

**Diverifikasi:** 30 Oktober 2026

**Rilis aktif:** 2.1.15+31

**Dipublikasikan:** 30 Oktober 2026

**Verifikasi source 2.1.15:** Flutter analyze bersih dan 96 tes lulus. APK arm64-v8a, armeabi-v7a, serta x86_64 diverifikasi ukuran, SHA-256, package/version, dan sertifikat penandatanganannya sebelum manifest ditayangkan.

## Status rilis

Manifest production berada di:

```text
https://sqydcdhvsmmkvlpsjzgx.supabase.co/storage/v1/object/public/app-releases/android/latest.json
```

Manifest aktif berisi APK untuk `arm64-v8a`, `armeabi-v7a`, dan `x86_64`. Release 2.1.12+28 menambahkan Proyek Laundry untuk Owner/karyawan dengan target pcs, batch harian dan tarif per kg/per pcs; pilihan insentif Rp10.000/Rp15.000/Rp20.000 untuk sepatu, helm, dan tas; hak insentif saat pesanan siap; serta pembayaran insentif oleh Owner yang baru kemudian masuk pengeluaran kas. Release 2.1.11+27 sebelumnya menampilkan nominal Tunai/Transfer di Laporan dan Buku Kas untuk semua filter waktu serta halaman Laporan Pembayaran untuk Owner/karyawan.

Release 2.1.13+29 menyatukan pembelian barang Live Stock dengan biaya pengadaan/Buku Kas dalam satu transaksi backend. Owner dan karyawan dapat mencatat pemakaian stok tanpa mencatat pengeluaran kas kedua. Riwayat Pengadaan/Pengeluaran menampilkan jumlah dan nominal sesuai periode, termasuk bulan kalender berjalan. Website Owner tetap lokal dan tidak dideploy ke VPS pada rilis ini.

Release 2.1.14+30 merapikan Laporan Owner menjadi ringkasan pesanan/keuangan dengan rincian status, layanan, volume, metode, kategori, dan transaksi yang dapat dibuka saat diperlukan. Buku Kas menonjolkan saldo akhir, uang masuk, uang keluar, serta rincian Tunai/Transfer; analisis dan Old Data dapat dibuka, sedangkan daftar transaksi awal dibatasi 10 dengan tombol **Lihat semua**. Pilihan periode lengkap, ekspor, dan seluruh hitungan tetap tersedia. Website Owner tetap lokal dan tidak dideploy ke VPS pada rilis ini.

Release 2.1.15+31 mengelompokkan menu Owner dan karyawan berdasarkan pekerjaan agar fitur lebih mudah ditemukan. `Kelola Stok` dipisahkan dari `Pembelian Stok & Pengeluaran`, sedangkan area Perangkat, Keuangan, Tim, Pelayanan, Pengajuan, serta Akun dibuat lebih jelas. Perubahan ini tidak memigrasikan atau menghitung ulang data lama. Dashboard web juga mengelompokkan sidebar, memperjelas istilah pengajuan, mendeteksi mutation nol-baris akibat RLS, dan mengambil pesanan/kas/pelanggan bertahap agar tidak terpotong batas respons API.

Delapan item stok yang belum ada ditambahkan ke toko produksi dengan stok awal 0. Item `Plastik 45` yang sudah ada dibiarkan pada jumlah dan satuan sebelumnya; Owner perlu memeriksa satuannya setelah opname.

Titik source release 2.1.15 disimpan pada tag Git `v2.1.15-build31` setelah commit rilis didorong ke GitHub. Push perubahan dashboard web memicu workflow deployment VPS dan statusnya harus diperiksa terpisah dari keberhasilan rilis APK.

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
