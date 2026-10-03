# Panduan pindah dari buku manual ke Idola One

**Tanggal rencana mulai:** 1 Oktober 2026, waktu toko (WIB).  
**Tujuan:** mulai mencatat transaksi baru di aplikasi tanpa menggandakan omzet, kas, atau pesanan lama.  
**Status:** panduan kerja; angka awal dan keputusan impor harus diisi serta disetujui owner sebelum dipakai.

## Keputusan pertama: titik potong

Tetapkan satu jam mulai, misalnya **1 Oktober 2026 pukul 08.00 WIB**. Tulis jam sebenarnya di lembar serah terima. Semua transaksi **sebelum** jam itu adalah histori buku; semua transaksi **sejak** jam itu dibuat di aplikasi. Buku boleh disimpan sebagai arsip dan alat cocok silang, tetapi jangan menjadi pencatatan kedua yang kemudian dimasukkan lagi sebagai transaksi baru.

Jika aplikasi sudah berisi data uji atau transaksi sungguhan, **jangan reset massal**. Pisahkan dahulu daftar data uji, data asli, pembayaran, dan kas yang sudah masuk. Buat ekspor/backup yang dapat dibaca dan catat jumlah baris serta totalnya. Reset kontak bukan reset pesanan atau kas; penghapusan produksi hanya boleh dilakukan setelah dampak relasi, poin, dan laporan diperiksa.

## Peta data dari buku ke aplikasi

| Catatan manual | Tujuan di aplikasi | Cara memulai | Hal yang harus dijaga |
| --- | --- | --- | --- |
| Daftar harga kiloan/satuan | Layanan & Harga | Periksa kategori, satuan, varian ukuran, harga, estimasi, dan layanan aktif. | Harga di pesanan lama adalah snapshot; mengubah katalog tidak boleh dianggap mengubah tagihan lama. |
| Buku pelanggan dan nomor WA | Pelanggan | Impor dari **satu akun Google** yang telah tersinkron ke HP, atau input manual; cek duplikat nomor. | Jangan reset seluruh pelanggan bila sudah terhubung ke pesanan. Kontak sumber di Google/HP tidak terhapus oleh reset hasil sinkron aplikasi. |
| Nota yang **belum selesai/diambil** | Pesanan | Daftar per nota: pelanggan, item, berat/jumlah, total, sudah dibayar, sisa, status, tenggat, penerima, catatan. Putuskan impor terkontrol satu per satu. | Form pesanan biasa membuat nomor/tanggal baru dan dapat membuat pemasukan/poin baru. Jangan masukkan pembayaran lama sebagai uang masuk hari ini. Simpan nomor nota buku sebagai referensi migrasi. |
| Nota lama yang **sudah selesai dan lunas** | Arsip buku | Simpan buku/foto/CSV; tidak wajib dimasukkan sebagai pesanan baru. | Memasukkannya hari ini akan menggelembungkan pesanan/omzet/poin hari ini. |
| DP atau piutang lama | Daftar piutang awal | Rekap per nota pelanggan: total, DP lampau, sisa, jatuh tempo. Tentukan mekanisme migrasi sebelum input ke aplikasi. | Pelunasan yang benar-benar diterima setelah titik potong dicatat sekali; jangan mencatat DP lama sebagai penerimaan baru. |
| Kas tunai, saldo bank/QR, utang, dan pengeluaran lama | Saldo awal terpisah | Hitung fisik dan mutasi bank pada titik potong; dokumentasikan per sumber. | Buku Kas aplikasi menghitung dari `cash_transactions`; belum ada alur migrasi saldo awal lintas metode yang terbukti aman. Jangan membuat “penjualan palsu” agar saldo cocok. |
| Plastik, sabun, pewangi, gas, dan bahan lain | Stok & Pengadaan | Hitung fisik, tambah item dengan **stok awal**, satuan, harga beli, minimum, dan catatan tanggal opname. | Stok awal bukan pembelian baru; hindari mencatat pengeluaran kas untuk barang yang sudah dibayar sebelum titik potong. |
| Jadwal, karyawan, upah, absensi | Tim, Shift, Absensi, Payroll | Periksa akun aktif, akses usaha, shift dan toleransi; mulai absensi sejak titik potong. | Gaji/utang gaji periode lama direkap terpisah; jangan dibayar dua kali melalui payroll aplikasi. |
| Pengajuan/permintaan belum selesai | Pengajuan | Daftar pending dan penanggung jawab; pilih entri ulang hanya bila diperlukan. | Jangan membuat pengajuan baru untuk biaya yang sudah disetujui dan dibayar di buku. |
| Penjualan minuman, bila digunakan | POS usaha terpilih | Periksa produk, harga, assignment, lalu mulai transaksi baru setelah titik potong. | POS minuman belum punya tutup kas/pengeluaran per usaha yang lengkap; rekonsiliasi per usaha masih perlu catatan manual. |

## Persiapan sebelum transaksi pertama

1. **Tetapkan penanggung jawab.** Owner memutuskan jam mulai, saldo awal dan nota terbuka. Satu karyawan memasukkan data; satu orang lain mencocokkan dengan buku. Catat nama pemeriksa.
2. **Periksa perangkat dan akun.** Owner serta setiap karyawan login, pilih usaha Laundry yang benar, pastikan jaringan aktif, tanggal/zona waktu HP benar, dan aplikasi memakai versi yang sama/terbaru. Jangan memakai mode preview untuk data produksi.
3. **Cadangkan keadaan saat ini.** Ekspor daftar pelanggan, pesanan, pembayaran, kas, stok, dan pengajuan yang sudah ada; simpan foto/scan halaman buku per tanggal terakhir. Catat total yang dilihat sebelum mulai. Jangan menaruh password, token, atau foto identitas di folder bersama tanpa pengamanan.
4. **Cocokkan katalog.** Uji satu layanan kiloan dan beberapa satuan populer. Pastikan harga, ukuran, kategori, batas minimum berat, serta aturan pembulatan yang berlaku sama dengan kebijakan toko. Perubahan harga dilakukan sebelum pesanan baru dibuat.
5. **Siapkan pelanggan.** Pilih akun Google yang benar di pemilih kontak; impor, lalu periksa sampel nama dan nomor WA. Bila daftar sudah berisi kontak campuran, jangan menekan reset sebelum ada backup serta daftar pelanggan yang harus dipertahankan.
6. **Opname barang.** Catat kuantitas fisik dan satuan tiap item. Tambahkan sebagai stok awal; setelah itu gunakan Stok Masuk/Keluar hanya untuk pergerakan baru.
7. **Hitung posisi pembuka.** Hitung uang tunai fisik, saldo rekening/QR yang dapat diatribusikan, pengeluaran belum tercatat, DP lama, piutang lama, dan nota terbuka. Owner tanda tangani angka pembuka di lembar migrasi.
8. **Uji satu transaksi nyata.** Buat pesanan baru kecil dengan pelanggan, item, nominal, metode bayar, dan catatan yang benar. Cek nota, daftar Pesanan di perangkat owner/karyawan, dashboard, dan Buku Kas. Jangan gunakan transaksi palsu di database produksi untuk tes tanpa prosedur pembatalan/audit.

## Saat mulai beroperasi

1. Sampaikan ke seluruh petugas: **transaksi baru hanya dicatat di aplikasi** sejak jam mulai. Tulis nomor nota aplikasi pada kertas/label fisik bila masih diperlukan.
2. Untuk setiap pesanan: pilih pelanggan, jenis kiloan/satuan/gabung, layanan, berat/jumlah, tenggat, catatan, pembayaran **Belum/DP/Lunas**, metode dan petugas. Periksa total sebelum menyimpan. Status pekerjaan dan status pembayaran berbeda.
3. Cetak **nota pelanggan** dan **label cucian** secara terpisah. Kegagalan printer tidak berarti pesanan gagal tersimpan; cek detail/nomor nota sebelum mencoba simpan ulang.
4. Bila pelanggan membayar setelah pesanan dibuat, catat melalui pembayaran pesanan, lalu cek satu entri kas masuk. Pengeluaran baru dicatat sekali melalui alur Pengeluaran, bukan ditambah lagi secara manual di Buku Kas.
5. Saat cucian siap, ubah status dan kirim WhatsApp sesuai alur; saat diambil, periksa sisa bayar dan cetak bukti bila perlu. Pesanan boleh diambil meski belum lunas, tetapi sisa harus tetap tercatat.
6. Lakukan absensi serta stok masuk/keluar pada waktu kejadian. Pengajuan karyawan diproses oleh owner; keputusan dan pembayaran pengajuan adalah dua langkah berbeda.

## Penanganan nota lama yang masih berjalan

Jangan langsung memasukkan semua nota lama melalui form **Buat Pesanan Baru**. Form standar membuat nomor dan waktu baru; pembayaran awal yang diisi dapat menambah `payments`, `cash_transactions`, dan poin pelanggan. Itu akan merusak angka 1 Oktober jika DP sebenarnya diterima pada September. Mulai dengan daftar nota terbuka dan sisa bayar di spreadsheet/kertas kendali. Untuk migrasi penuh, perlu alur impor khusus yang menyimpan referensi nota lama, waktu asli, status, `paid_amount` pembuka, dan rekonsiliasi kas tanpa membuat pembayaran lama sebagai kas baru. Alur khusus ini **belum diklaim tersedia** di UI saat ini.

Pilihan aman sementara: kerjakan nota lama dengan daftar kendali terpisah sampai selesai, sambil semua pesanan **baru** masuk aplikasi. Bila owner memutuskan pencatatan nota lama secara manual di aplikasi, tandai sebagai migrasi dan lakukan hanya setelah metode rekonsiliasi DP/piutang disepakati serta diuji di staging; jangan menebak nilai nol atau membuat pembayaran fiktif.

## Pemeriksaan pada akhir hari pertama

| Cocokkan | Rumus/pemeriksaan | Bila berbeda |
| --- | --- | --- |
| Pesanan baru | Jumlah nota sejak jam mulai di aplikasi = jumlah transaksi baru di meja kasir. | Cari nota ganda atau pesanan yang gagal disimpan. |
| Nilai tagihan | Jumlah total tagihan pesanan baru, terpisah dari kas yang diterima. | Periksa item, berat desimal, harga, dan pembulatan. |
| Pembayaran | Jumlah pembayaran yang **diterima setelah titik potong**, per tunai/transfer/QR. | Cocokkan nomor nota dan bukti transfer; jangan campur DP lama. |
| Piutang akhir | Sisa nota baru + sisa nota lama yang masih dipantau terpisah. | Cari pelunasan yang belum tercatat atau dicatat dua kali. |
| Kas tunai fisik | Tunai pembuka + tunai masuk baru − tunai keluar baru. | Periksa laci kas, kembalian, dan metode bayar yang salah. |
| Bank/QR | Mutasi masuk/keluar baru yang telah benar-benar settled. | Catat transaksi pending/biaya admin terpisah. |
| Stok | Stok awal + masuk baru − keluar baru = hitung fisik. | Periksa satuan dan mutasi yang tertinggal. |
| Sinkronisasi | Sampel pesanan, pembayaran, pelanggan, dan stok tampak sama pada owner dan karyawan setelah refresh. | Catat perangkat, jam, koneksi, dan nomor nota; jangan input ulang sebelum memeriksa backend. |

**Batas laporan:** dashboard web lokal belum menjadi laporan audit final. Grafik selesai masih memakai `updated_at` terakhir, metrik order/kas dapat terpotong oleh batas query API, pagination sebagian masih di browser, dan web belum menampilkan seluruh modul Android. Untuk serah terima hari pertama, pakai nota/payment ledger dan bukti bank sebagai pembanding; jangan mengandalkan satu kartu KPI saja.

## Lembar serah terima yang perlu diisi owner

```text
Tanggal dan jam mulai (WIB) : __________________________
Owner / pemeriksa           : __________________________
Petugas input               : __________________________
Build aplikasi tiap HP      : __________________________
Jumlah pesanan asli sebelum mulai di aplikasi : _______
Jumlah pelanggan sebelum impor               : _______
Kas tunai fisik pembuka                       : Rp _____
Saldo bank/QR pembuka (per akun)              : Rp _____
Nota lama belum selesai                       : _______ nota
DP lama yang sudah diterima                   : Rp _____
Piutang lama yang masih ditagih               : Rp _____
Jumlah item stok hasil opname                 : _______
Lokasi backup buku/ekspor                     : _______
Catatan selisih dan keputusan owner           : _______
```

## Batasan yang perlu diselesaikan setelah hari pertama

- Buat importer nota aktif dan saldo pembuka yang idempoten, berizin owner, punya preview dan audit, sebelum migrasi historis penuh.
- Tambahkan rekonsiliasi kas per metode dan saldo awal resmi; jangan memalsukan order atau payment untuk mengisi saldo.
- Uji lintas perangkat nyata untuk sinkronisasi. Realtime mempercepat tampilan, tetapi refresh/query adalah cara pemulihan saat event terlewat.
- Lengkapi agregat server untuk dashboard web agar angka bulanan tidak bergantung pada jumlah baris yang sempat dimuat browser.

Rujukan teknis: [PRD](01-PRD.md), [alur aplikasi](04-APPFLOW.md), [blueprint dashboard](07-ADMIN-DASHBOARD-BLUEPRINT.md), dan [matriks sinkronisasi](../quality/02-SYNC-MATRIX.md).
