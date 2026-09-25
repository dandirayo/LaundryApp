# Manual Smoke Test — Owner, Karyawan, Multi-Usaha, dan POS

**Baseline:** Idola One 2.1.2+18  
**Diperbarui:** 20 September 2026

## 1. Persiapan

- Dua perangkat atau session terpisah: satu owner dan satu karyawan pada shop yang sama.
- Karyawan di-assign ke usaha Laundry dan Es Teh Manis.
- Supabase production/staging memiliki seluruh migration sampai poin pelanggan dan multi-business POS.
- Printer Bluetooth tersedia untuk uji fisik 58 dan 80 mm.
- Kontak Android memiliki contoh: nama mengandung `CS`, nama non-CS, multi-number, dan kontak tanpa nomor.
- Internet aktif; siapkan juga skenario putus-sambung jaringan.

Catat `Pass/Fail`, waktu, perangkat, build, dan bukti. Untuk uji realtime, amati dulu tanpa refresh; jika belum berubah, lakukan refresh untuk membedakan kegagalan realtime dari kegagalan query.

## 2. Login, peran, dan pemilih usaha

| # | Langkah | Hasil yang diharapkan | Hasil | Catatan |
| ---: | --- | --- | --- | --- |
| 1 | Login owner. | Profil aktif dimuat dan pemilih usaha tampil. | | |
| 2 | Login karyawan pada perangkat lain. | Hanya usaha dengan membership aktif yang tampil. | | |
| 3 | Owner nonaktifkan assignment POS karyawan, lalu karyawan refresh/login ulang. | Usaha POS hilang; query POS langsung ditolak RLS. | | |
| 4 | Owner aktifkan kembali assignment. | Usaha kembali setelah refresh tanpa duplikasi membership. | | |
| 5 | Tekan back dari halaman detail/form pada beberapa menu. | Kembali ke halaman asal, bukan tiba-tiba ke Beranda. Pastikan tombol Pelanggan tersedia pada beranda karyawan. | | |

## 3. Pelanggan, kontak, dan poin

| # | Langkah | Hasil yang diharapkan | Hasil | Catatan |
| ---: | --- | --- | --- | --- |
| 6 | Tambah pelanggan dari karyawan. | Satu row tersimpan dan terlihat owner melalui realtime/refresh. | | |
| 7 | Owner edit nama/alamat pelanggan. | Perubahan terlihat di session karyawan tanpa duplikasi. | | |
| 8 | Sinkron kontak perangkat dengan multi-number. | Nomor dinormalisasi dan kandidat dapat dipilih dengan jelas. | | |
| 9 | Gunakan **Hapus kontak non-CS**. | Hanya data hasil sinkron di aplikasi yang tidak memiliki penanda CS yang dihapus; kontak perangkat tetap ada. | | |
| 10 | Cabut izin kontak lalu coba sinkron. | Pesan izin tampil dan aplikasi tidak crash. | | |
| 11 | Catat saldo poin awal pelanggan. | Saldo sama pada owner dan karyawan. | | |

## 4. Order, pembayaran, poin, dan cetak

| # | Langkah | Hasil yang diharapkan | Hasil | Catatan |
| ---: | --- | --- | --- | --- |
| 12 | Buat order dengan Sprei Besar ukuran 160. | Layanan dan harga ukuran 160 tampil sebagai item terpisah. | | |
| 13 | Buat order lain ukuran 180/200. | Nama dan harga mengikuti ukuran yang dipilih, tidak memakai harga gabungan lama. | | |
| 14 | Tambahkan kiloan + satuan dalam mode Gabung. | Quantity, unit, dan subtotal benar; Rp32.000 tetap Rp32.000, sedangkan Rp32.001-Rp32.999 menjadi Rp33.000. | | |
| 15 | Isi catatan dan pembayaran awal, lalu tekan simpan berulang cepat. | Hanya satu order dan satu pembayaran awal dibuat. | | |
| 16 | Amati owner. | Order, item, penerima, note, total, dan status lengkap muncul. | | |
| 17 | Cetak **Nota Pelanggan**. | Hanya nota tercetak sebagai satu job. | | |
| 18 | Cetak **Label Cucian**. | Hanya label tercetak; teks besar memuat nomor, nama, berat/jumlah, layanan, status bayar, dan note. | | |
| 19 | Ulangi pada lebar 58 dan 80 mm. | Teks tidak terpotong dan logo tidak memiliki margin berlebihan. | | |
| 20 | Tambah pembayaran dari owner dua kali dengan tap cepat. | Tidak ada nilai melebihi sisa; status dan satu ledger per payment konsisten. | | |
| 21 | Lunasi order pelanggan dengan total minimal Rp10.000. | Point event tunggal terbentuk dan saldo naik `floor(total/10.000)`. | | |
| 22 | Ubah/refresh status order lunas berulang. | Poin tidak bertambah dua kali untuk order yang sama. | | |
| 23 | Tandai order belum lunas sebagai diambil. | Transisi diizinkan, sisa bayar tetap terlihat. | | |
| 24 | Cetak **Bukti Pengambilan**. | Bukti terpisah menunjukkan lunas atau sisa secara benar. | | |
| 25 | Putus printer lalu cetak ulang dari detail. | Order tetap tersimpan; error printer jelas; retry tidak membuat order/payment baru. | | |

## 5. Pengajuan, absensi, shift, dan payroll

| # | Langkah | Hasil yang diharapkan | Hasil | Catatan |
| ---: | --- | --- | --- | --- |
| 26 | Karyawan membuat pengajuan stok. | Field stok relevan tampil dan status Menunggu terlihat owner. | | |
| 27 | Buat izin/lembur/kasbon. | Form dinamis sesuai jenis; field yang tidak relevan tidak ditampilkan. | | |
| 28 | Owner setujui dan beri catatan. | Karyawan melihat **Disetujui**, bukan label ambigu “Selesai”. | | |
| 29 | Owner tolak pengajuan dengan alasan. | Alasan wajib dan terlihat oleh karyawan. | | |
| 30 | Bayar pengajuan uang. | Status paid dan tepat satu cash transaction OUT terbentuk. | | |
| 31 | Karyawan check-in/out dengan foto. | Attendance dan foto tersimpan; owner melihat data yang sama. | | |
| 32 | Tolak izin kamera/storage. | Aplikasi tidak crash dan menampilkan tindakan pemulihan. | | |
| 33 | Owner ubah shift/hari libur. | Perubahan terlihat karyawan dan tidak membuat shift ganda. | | |
| 34 | Owner bayar payroll periode tertentu dua kali. | Pembayaran pertama sukses, duplikasi periode ditolak aman. | | |

## 6. Stok, pengadaan, dan pengeluaran

| # | Langkah | Hasil yang diharapkan | Hasil | Catatan |
| ---: | --- | --- | --- | --- |
| 35 | Pilih filter Hari ini, Kemarin, Seminggu. | Daftar mengikuti rentang yang benar dan pilihan tetap saat refresh. | | |
| 36 | Tambah pengadaan stok. | Item/mutasi masuk dan saldo stok konsisten. | | |
| 37 | Tambah pengeluaran dari role yang diizinkan. | Expense dan satu cash transaction OUT terbentuk. | | |
| 38 | Turunkan stok melewati minimum. | Peringatan/indikator stok menipis muncul tanpa notifikasi ganda. | | |

## 7. POS Es Teh Manis

| # | Langkah | Hasil yang diharapkan | Hasil | Catatan |
| ---: | --- | --- | --- | --- |
| 39 | Pilih Es Teh Manis. | Shell POS tampil dan data Laundry tidak bercampur. | | |
| 40 | Ubah **Hari ini berjualan**. | Satu daily operation tersimpan untuk business/tanggal. | | |
| 41 | Owner tambah/edit/nonaktifkan produk. | Produk aktif tampil di kasir; produk nonaktif tidak dapat dijual baru. | | |
| 42 | Karyawan tambah beberapa produk dan quantity. | Keranjang dan total benar. | | |
| 43 | Checkout Tunai, Transfer, lalu QRIS pada transaksi terpisah. | Sale number unik, sale/items atomik, seller dan metode tersimpan. | | |
| 44 | Tekan checkout berulang cepat. | Tidak ada sale ganda dan loading/disabled jelas. | | |
| 45 | Amati ringkasan hari ini. | Omzet, jumlah transaksi, dan transaksi terbaru sesuai business aktif. | | |
| 46 | Pindah kembali ke Laundry. | Context dan navbar berganti; data POS tidak masuk ke laporan Laundry. | | |

## 8. Notifikasi, recovery, dan update

| # | Langkah | Hasil yang diharapkan | Hasil | Catatan |
| ---: | --- | --- | --- | --- |
| 47 | Ubah status kerja/pembayaran pesanan, lalu buka notifikasi unread dan tandai semua. | Penerima yang relevan mendapat notifikasi; badge dan row read berubah tanpa reload penuh; deep link membuka route aman. | | |
| 48 | Putus jaringan, buka halaman data, sambungkan, lalu retry/refresh. | Data lama tidak crash dan data terbaru kembali tanpa listener ganda. | | |
| 49 | Cek update dari build lebih lama. | Rilis 2.1.2+18 atau rilis lebih baru terdeteksi sesuai manifest. | | |
| 50 | Instal update. | Package/signature valid dan data aplikasi tidak terhapus. | | |

## 9. Pemeriksaan database/RLS

- Akun shop lain tidak dapat membaca data shop pertama.
- Karyawan tidak dapat approve request sendiri, membayar payroll, atau mengubah katalog owner-only.
- Karyawan tanpa membership tidak dapat membaca/menulis business POS.
- Setiap payment, expense, payroll, dan request payout memiliki maksimal satu cash transaction untuk reference yang sama.
- Satu order memiliki maksimal satu `customer_point_events`.
- `customer_point_balances.points` sama dengan ledger event aktif.
- Satu POS checkout selalu memiliki header dan seluruh item, tidak setengah tersimpan.
