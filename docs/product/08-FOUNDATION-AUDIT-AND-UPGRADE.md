# 8. Audit dan Upgrade Aplikasi Tahap 1–12

**Baseline:** Idola One 2.1.3+19  
**Tanggal audit:** 26 September 2026  
**Ruang lingkup:** fondasi, navigasi, dan alur operasional utama Laundry  
**Batasan:** tidak mengubah fitur utama, aturan bisnis, harga, perhitungan, atau schema produksi

## 1. Ringkasan audit

Aplikasi memiliki 40 route, dua workspace (Laundry dan POS minuman), dua role akun utama (owner dan karyawan), serta pembatasan tambahan melalui membership usaha. Fondasi tema, responsive layout, dan histori navigasi sudah tersedia sebelum tahap ini, tetapi pemakaiannya belum seluruhnya konsisten.

Temuan utama:

1. Komponen utama telah memakai Material 3, tetapi beberapa default global seperti dialog, bottom sheet, snackbar, icon button, list tile, dan floating action button belum memiliki standar bersama.
2. Nilai jarak sudah tersedia, tetapi halaman masih perlu alias semantik agar padding halaman dan jarak form tidak ditulis berulang.
3. Banyak menu sekunder dibuka dengan `go`, yang mengganti lokasi route. Akibatnya AppBar tidak selalu mendapat stack untuk menampilkan tombol kembali otomatis.
4. Histori route buatan sudah menangani tombol Android, tetapi fallback induk halaman sebelumnya berada di widget dan belum menjadi kontrak route yang dapat diuji terpisah.
5. Route owner dan karyawan sudah dibatasi; backend tetap menjadi sumber kebenaran untuk akses data.

## 2. Inventaris area dan akses

| Area | Halaman utama | Owner | Karyawan Laundry | Anggota POS |
|---|---|---:|---:|---:|
| Sesi | Splash, login, pilih usaha | Ya | Ya | Ya |
| Kelola usaha | Usaha dan assignment karyawan | Ya | Tidak | Tidak |
| Beranda Laundry | Ringkasan operasional | Ya | Ya | Tidak |
| Pesanan | Daftar, pesanan saya, buat, detail | Semua | Operasional/milik sendiri | Tidak |
| Pelanggan | Daftar, tambah, kontak, riwayat | Ya | Ya | Tidak |
| Layanan | Katalog dan harga | Ya | Tidak | Tidak |
| Stok dan biaya | Inventaris serta pengeluaran | Ya | Pengeluaran sesuai UI | Tidak |
| Tim | Karyawan, shift, absensi, payroll | Semua | Milik sendiri | Belum khusus POS |
| Pengajuan | Review owner dan pengajuan saya | Review | Buat/pantau | Tidak |
| Keuangan | Buku Kas dan laporan | Ya | Tidak | Ringkasan POS terpisah |
| Perangkat | Printer, backup, pengaturan | Ya | Terbatas | Terbatas |
| POS minuman | Beranda, kasir, menu, lainnya | Ya | Jika di-assign | Ya |

## 3. Kontrak design system

### Warna

- Navy dan blue: identitas, aksi primer, dan navigasi aktif.
- Gold: indikator pilihan aktif.
- Green: berhasil atau status aman.
- Orange: peringatan atau pekerjaan yang membutuhkan perhatian.
- Red: aksi destruktif dan error.
- Surface/background/outline: pemisahan lapisan tanpa bayangan berat.

### Jarak dan radius

- Skala jarak tetap 4, 8, 12, 16, 20, 24, dan 32.
- Alias semantik: padding halaman, jarak bagian, padding kartu, dan jarak field.
- Radius standar: 10, 14, 16, 20, dan pill.

### Komponen global

Komponen berikut harus mengambil gaya dari `AppTheme`:

- AppBar;
- card;
- filled, outlined, text, dan icon button;
- input;
- navigation bar;
- chip;
- floating action button;
- dialog dan bottom sheet;
- list tile dan divider;
- snackbar dan progress indicator.

Halaman boleh membuat variasi hanya jika kebutuhan operasionalnya berbeda, bukan karena gaya lokal yang duplikatif.

## 4. Kontrak navigasi

1. Bottom navigation dan pergantian workspace memakai **replace** karena merupakan tujuan utama.
2. Detail, form, pengaturan, dan menu sekunder memakai **push** agar AppBar serta tombol Android kembali ke halaman pembuka.
3. Setelah membuat data yang tidak boleh diedit ulang melalui back, aplikasi boleh mengganti lokasi dengan halaman hasil/detail.
4. Deep link dan restored route menggunakan fallback `AppRoutes.parentFor()` jika tidak memiliki Navigator stack.
5. Modal, dialog, dan bottom sheet tetap memakai `Navigator.pop()` karena bukan route aplikasi.
6. Login baru menghapus histori pengguna sebelumnya.

### Fallback penting

| Halaman | Fallback tanpa stack |
|---|---|
| Detail/buat pesanan owner | Pesanan |
| Detail/buat pesanan karyawan | Pesanan Saya |
| Form pengajuan | Pengajuan Saya |
| Kasir/Menu/Lainnya POS | Beranda POS |
| Halaman sekunder Laundry | Lainnya |
| Tab utama Laundry | Beranda |
| Kelola usaha | Pilih Usaha |

## 5. Perubahan Tahap 1–3

### Tahap 1 — Audit

- Inventaris 40 route dan pembagian akses.
- Audit komponen tema, pola layout, dan penggunaan navigasi.
- Dokumentasi kontrak desain dan navigasi pada dokumen ini.

### Tahap 2 — Design system

- Menambahkan token radius bersama.
- Menambahkan alias jarak semantik.
- Menstandarkan tipografi dan komponen Material global.
- Menyamakan padding default `ResponsivePage`.
- Menjaga warna merek dan struktur halaman yang sudah dipakai.

### Tahap 3 — Navigasi

- Menambahkan helper `AppNavigation` untuk membedakan push dan replace.
- Halaman sekunder dari Beranda, Lainnya, daftar Pesanan, Notifikasi, Pengeluaran, Payroll, POS, dan pemilih usaha dibuka dengan stack.
- `AppBackGuard` mengizinkan pop native ketika stack tersedia dan memakai histori/fallback hanya jika diperlukan.
- Parent route dipusatkan pada `AppRoutes.parentFor()` dan diuji berdasarkan role.

## 6. Perubahan Tahap 4–12

| Tahap | Area | Hasil upgrade |
|---:|---|---|
| 4 | Beranda | Ringkasan owner dan karyawan diberi judul serta konteks yang lebih jelas tanpa mengubah isi metrik dan aksi cepat. |
| 5 | Buat Pesanan | Menambahkan indikator kelengkapan pelanggan, layanan, dan pembayaran agar urutan kerja kasir mudah dipahami. |
| 6 | Katalog layanan | Menambahkan pencarian nama layanan, kelompok, kategori, barang, varian, dan satuan; hierarki katalog lama tetap tersedia. |
| 7 | Keranjang | Menampilkan jumlah item dan aksi hapus semua yang ringkas; kontrol jumlah serta aturan minimum tetap sama. |
| 8 | Pembayaran | Menampilkan metode bayar aktif dan rincian subtotal serta nilai pembulatan ke atas secara eksplisit. Pilihan Belum, DP 50%, Lunas, dan nominal manual tetap tersedia. |
| 9 | Status | Menambahkan progres visual Diterima → Diproses → Siap ambil → Diambil serta keadaan khusus Dibatalkan. |
| 10 | Pencetakan | Setiap pilihan cetak menjelaskan tujuan Nota Pelanggan, Label Cucian, atau Bukti Pengambilan. Cetak tetap dilakukan satu per satu untuk printer 58/80 mm. |
| 11 | Daftar Pesanan | Filter menampilkan jumlah data Semua, Belum selesai, dan Selesai sehingga antrean lebih cepat dipindai tanpa menambah panel tinggi. |
| 12 | Detail Pesanan | Menambahkan progres status di atas rincian item, pembayaran, catatan, WhatsApp, dan preview cetak. |

Semua perubahan di atas mempertahankan struktur data, harga, perhitungan, hak akses, status backend, dan aturan transaksi yang sudah ada.

## 7. Acceptance criteria

- [x] Tidak ada route atau fitur utama yang dihapus.
- [x] Owner dan karyawan tetap hanya melihat halaman yang diizinkan.
- [x] Bottom navigation tidak membentuk stack berulang.
- [x] Membuka halaman sekunder lalu menekan back kembali ke halaman pembuka.
- [x] Deep link tanpa stack kembali ke induk yang benar.
- [x] Login baru tidak memakai histori akun sebelumnya.
- [x] Dialog dan bottom sheet tetap menutup modal, bukan berpindah halaman.
- [x] Katalog tetap dapat dipakai secara hierarkis dan kini dapat dicari.
- [x] Pembulatan, pembayaran, dan cetak terpisah tetap mengikuti aturan lama.
- [x] Layar 390 × 844 tidak mengalami overflow pada alur tambah item.
- [x] `flutter analyze` dan seluruh automated test lulus.

## 8. Batas implementasi

Tahap 1–12 selesai pada source aplikasi dan belum mengubah schema produksi. Publikasi APK atau deployment dilakukan sebagai pekerjaan rilis terpisah agar hasil build dapat diberi versi dan diuji pada perangkat tujuan.
