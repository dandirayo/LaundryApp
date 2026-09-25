# 1. Product Requirements Document

**Produk:** Idola One  
**Versi acuan:** 2.1.2+18  
**Tanggal:** 20 September 2026  
**Platform utama:** Android

## 1. Ringkasan produk

Idola One adalah aplikasi operasional dan POS multi-usaha untuk pemilik usaha kecil beserta karyawannya. Satu akun owner dapat mengelola beberapa usaha, menentukan karyawan yang boleh masuk ke tiap usaha, lalu memakai modul yang sesuai dengan jenis usaha tersebut.

Jenis usaha yang tersedia saat ini:

- **Laundry — aktif:** alur operasional lengkap dari pesanan sampai pengambilan, pelanggan, layanan, kas, stok, pegawai, pengajuan, laporan, dan printer thermal.
- **Es Teh Manis/minuman kecil — aktif:** buka/tutup jualan harian, katalog produk, kasir sederhana, pembayaran, dan ringkasan transaksi hari ini.

## 2. Masalah yang diselesaikan

Pemilik sebelumnya harus memisahkan pencatatan pesanan, pembayaran, stok, absensi, permintaan karyawan, dan usaha minuman. Dampaknya adalah status pekerjaan mudah tertukar, pembayaran sulit ditelusuri, nota dan label cucian tidak konsisten, serta akses karyawan tidak terkontrol per usaha.

Idola One menyatukan pencatatan tersebut dalam satu akun dan tetap memberi alur yang lebih sederhana untuk usaha minuman.

## 3. Pengguna

| Pengguna | Kebutuhan utama |
| --- | --- |
| Owner | Melihat seluruh usaha, mengatur karyawan dan akses, memantau operasional, menyetujui pengajuan, mengelola harga, stok, kas, dan laporan. |
| Karyawan laundry | Membuat dan memperbarui pesanan, menerima pembayaran, mencetak bukti, melihat jadwal/absensi, dan membuat pengajuan. |
| Karyawan minuman | Menandai hari berjualan, menjalankan kasir, dan melihat transaksi hari ini tanpa menu operasional laundry. |
| Pelanggan | Saat ini menerima nota/label/bukti melalui kasir. Portal web pelanggan dan penukaran poin berada pada tahap rencana. |

## 4. Sasaran produk

1. Mengurangi kesalahan status cucian dan pembayaran.
2. Memisahkan nota pelanggan, label cucian, dan bukti pengambilan agar dapat dicetak satu per satu.
3. Memberi owner gambaran operasional dan keuangan tanpa rekap manual.
4. Menjadikan satu aplikasi sebagai pintu masuk beberapa usaha.
5. Menjaga POS minuman cepat dipelajari dan cukup sederhana untuk transaksi harian.
6. Menyediakan fondasi loyalty pelanggan yang dapat dipakai aplikasi web pelanggan di masa depan.

## 5. Ruang lingkup dan status

### 5.1 Akun dan multi-usaha

| Kebutuhan | Status | Perilaku saat ini |
| --- | --- | --- |
| Login owner dan karyawan | Selesai | Autentikasi memakai Supabase Auth; peran dan toko berasal dari profil. |
| Pilihan usaha setelah login | Selesai | Pengguna memilih kartu usaha yang aktif. |
| Tambah usaha oleh owner | Selesai | Owner dapat menambah usaha jenis minuman. |
| Assign karyawan ke usaha | Selesai | Owner mengaktifkan atau menonaktifkan membership karyawan per usaha. |
| Status usaha aktif/nonaktif | Selesai | Hanya usaha yang dapat diakses pengguna ditampilkan sebagai tujuan aktif. |
| Jenis usaha selain laundry dan minuman | Rencana | Struktur data mendukung perluasan, UI dan alur bisnis belum dibuat. |

### 5.2 Laundry

| Area | Status | Cakupan |
| --- | --- | --- |
| Pesanan | Selesai | Kiloan, satuan, atau gabung; pelanggan; penerima; tenggat; catatan; subtotal dan pembulatan total selalu naik ke kelipatan Rp1.000 berikutnya. |
| Harga layanan | Selesai | Katalog per toko, kategori, unit, express, estimasi, ukuran dan material. Sprei 160/180/200 merupakan pilihan terpisah dengan harga berbeda. |
| Pembayaran | Selesai | Belum bayar, DP, lunas, nominal manual; metode tunai/transfer/QR; pembayaran tambahan tercatat sebagai payment. |
| Status kerja | Selesai | Status pesanan, status pembayaran, pengambilan walau belum lunas, dan pencatatan penerima pesanan. |
| Nota dan label | Selesai | Nota pelanggan, label cucian, dan bukti lunas/pengambilan dipilih serta dicetak satu per satu pada printer 58/80 mm. |
| Pelanggan dan kontak | Selesai | Tambah/cari pelanggan, akses cepat dari beranda karyawan, sinkron kontak perangkat/Google, reset hasil sinkron, dan hapus kontak yang tidak mengandung penanda CS. |
| Poin pelanggan | Sebagian | Saldo otomatis bertambah 1 poin per Rp10.000 untuk pesanan laundry yang lunas. Penukaran dan portal pelanggan belum ada. |
| Stok/pengadaan | Selesai | Barang stok, mutasi, batas minimum, harga beli, serta pengadaan/pengeluaran dalam tampilan ringkas. |
| Filter pengeluaran | Selesai | Pilihan Hari ini, Kemarin, Seminggu, dan rentang lain melalui dropdown/filter. |
| Pegawai | Selesai | Akun/PIN, posisi, gaji mingguan, jadwal, absensi, payroll, dan status aktif. |
| Pengajuan karyawan | Selesai | Stok, lembur, tukar shift, izin, insentif, kasbon; owner meninjau dengan keputusan dan catatan yang jelas. |
| Keuangan | Selesai | Pengeluaran, buku kas, transaksi kas hasil sinkron, laporan, dan fondasi tutup kas. |
| Notifikasi | Selesai | Notifikasi in-app/realtime untuk pengajuan serta perubahan status pekerjaan dan pembayaran pesanan; aksi baca/hapus langsung memperbarui tampilan dan deep link dibatasi ke route aplikasi. |
| Backup/pengaturan/update | Selesai | Backup, pengaturan toko, profil/PIN, update APK dari cloud, dan konfigurasi printer. |

### 5.3 POS Es Teh Manis dan minuman kecil

POS saat ini **cukup untuk berjualan es teh manis dan minuman kecil dengan menu serta harga tetap**.

| Kebutuhan | Status | Perilaku saat ini |
| --- | --- | --- |
| Menandai hari ini berjualan | Selesai | Satu toggle harian dengan catatan opsional. |
| Katalog produk | Selesai | Owner dapat menambah, mengubah, mengurutkan, mengaktifkan, dan menonaktifkan produk. |
| Keranjang kasir | Selesai | Tambah/kurangi jumlah produk dan hitung total. |
| Checkout | Selesai | Tunai, transfer, QRIS, dan catatan transaksi. |
| Nomor transaksi | Selesai | Dibuat atomik oleh backend. |
| Ringkasan hari ini | Selesai | Omzet dan daftar transaksi terbaru pada usaha terpilih. |
| Varian ukuran/gula/es/topping | Rencana | Saat ini harus dibuat sebagai produk terpisah. |
| Resep dan pengurangan stok bahan | Rencana | Belum mengurangi teh, gula, es, cup, atau topping otomatis. |
| Pengeluaran khusus POS | Rencana | Belum dipisahkan berdasarkan business pada modul POS. |
| Diskon, pembatalan, refund | Rencana | Belum tersedia. |
| Cetak struk POS | Rencana | Printer saat ini berfokus pada dokumen laundry. |
| Tutup kas per usaha | Rencana | Tabel tutup kas laundry tersedia, alur khusus POS belum dibuat. |
| Loyalty POS | Rencana | Poin saat ini hanya berasal dari pesanan laundry lunas. |

## 6. Persyaratan fungsional utama

### FR-01 — Pemilihan usaha

Setelah autentikasi berhasil, sistem harus menampilkan usaha aktif yang boleh diakses pengguna. Pilihan disimpan sebagai konteks sesi dan menentukan shell navigasi serta data yang dimuat.

### FR-02 — Akses berdasarkan peran

Owner dapat membuka fungsi administrasi. Karyawan hanya dapat membuka alur operasional yang ditetapkan. Backend harus tetap memeriksa toko, usaha, keanggotaan, dan peran melalui RLS walaupun route UI disembunyikan.

### FR-03 — Pesanan laundry

Sistem harus membuat header pesanan dan item secara atomik, menyimpan snapshot nama pelanggan/layanan/harga, menghitung total, mencatat pembayaran awal, dan menghasilkan nomor nota.

### FR-04 — Dokumen thermal

Kasir harus dapat memilih secara terpisah:

1. nota pelanggan saat pesanan dibuat;
2. label cucian berhuruf besar berisi nomor, pelanggan, berat/jumlah, layanan, status bayar, dan catatan;
3. bukti lunas/pengambilan ketika pekerjaan selesai atau diambil.

Setiap aksi menghasilkan satu dokumen agar kertas dapat dipotong dan dibagikan secara mandiri.

### FR-05 — Pembayaran dan pengambilan

Sistem harus menyimpan setiap pembayaran, menjaga `paid_amount` dan `payment_status`, serta mendukung tanda terima pengambilan. Pesanan boleh diambil dalam kondisi belum lunas sesuai kebijakan toko dan sisa bayar tetap terlihat.

### FR-06 — Pengajuan karyawan

Karyawan harus memilih jenis pengajuan dan mengisi detail yang sesuai. Owner memberi keputusan dan catatan. Label keputusan harus menggambarkan hasil seperti Menunggu, Disetujui, atau Ditolak; istilah “Selesai” tidak dipakai sebagai pengganti keputusan.

### FR-07 — Transaksi minuman

Karyawan yang menjadi anggota usaha harus dapat melakukan checkout hanya pada usaha aktif yang dipilih. Harga dan nama item disalin ke item transaksi agar histori tidak berubah saat katalog diedit.

### FR-08 — Poin pelanggan

Sistem memberikan `floor(total_price / 10.000)` poin untuk pesanan yang memiliki pelanggan dan berubah menjadi lunas. Perhitungan harus idempoten per order.

## 7. Persyaratan nonfungsional

| Area | Persyaratan |
| --- | --- |
| Keamanan | Semua tabel publik memakai RLS; service-role tidak berada di aplikasi; akses dibatasi berdasarkan shop/business membership. |
| Integritas | Pembuatan order, pembayaran, stok, dan penjualan POS memakai RPC/transaksi database untuk mencegah data setengah tersimpan. |
| Kinerja | Daftar difilter berdasarkan toko/usaha dan rentang waktu; kolom foreign key/filter utama harus terindeks. |
| Keandalan | Aksi simpan memiliki loading, error, dan retry; printer yang putus tidak boleh membatalkan transaksi yang sudah tersimpan. |
| Keterbacaan | Teks utama, nilai uang, status, dan aksi utama harus terbaca pada layar ponsel serta kertas 58/80 mm. |
| Navigasi | Tombol kembali mengarah ke halaman sebelumnya dalam konteks pengguna, bukan tiba-tiba ke Beranda. |
| Audit | Perubahan penting dapat ditelusuri melalui payment, cash transaction, point event, notification, dan audit log. |

## 8. Indikator keberhasilan

- Seluruh pesanan memiliki pelanggan/snapshot, item, total, dan status yang konsisten.
- Tidak ada pembayaran yang tersimpan tanpa referensi pesanan dan pencatatan kas terkait.
- Waktu membuat transaksi minuman sederhana maksimal sekitar 30 detik setelah produk tersedia.
- Owner dapat mengetahui omzet harian masing-masing usaha tanpa rekap manual.
- Karyawan dapat membedakan dengan jelas nota pelanggan, label cucian, dan bukti pengambilan.
- Pengajuan yang menunggu keputusan tidak tampil sebagai selesai.
- Tidak ada akses lintas toko atau lintas usaha dalam pengujian RLS.

## 9. Batasan rilis saat ini

- Aplikasi utama berorientasi Android; implementasi iOS belum menjadi target rilis.
- Mode preview membantu demo, tetapi bukan sinkronisasi offline penuh.
- POS minuman belum cocok untuk usaha dengan resep bahan kompleks, modifier banyak, refund, atau tutup kas ketat.
- Aplikasi pelanggan berbasis web dan penukaran poin belum dibuat.
