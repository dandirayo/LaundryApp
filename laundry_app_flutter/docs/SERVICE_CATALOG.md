# Katalog layanan Idola Laundry

Kategori utama selalu diturunkan dari unit tagihan: KG = Kiloan; unit lainnya = Satuan. Sepatu dan Helm merupakan subkategori Satuan. Mode Gabung di pesanan hanya menggabungkan isi keranjang, bukan kategori ketiga.

## Sumber harga

- 9 varian kiloan: dipertahankan dari database sebelumnya; foto kiloan tidak diterapkan sesuai permintaan.
- 96 varian satuan dari lima foto pengguna (dua foto merupakan duplikat). Nama dengan slash yang berbagi harga dipisah menjadi barang masing-masing, misalnya Jaket, Hoodie, Sweater.
- 17 varian satuan yang tidak terbaca/tercakup di foto: memakai harga database yang sudah aktif; belum terverifikasi dengan foto.
- 4 layanan dari aplikasi sebelumnya (Sepatu, Helm, Express tambahan, Noda Berat) dipertahankan dan disamakan di database; belum terverifikasi dengan foto.
- Estimasi pengerjaan satuan tetap 72 jam sebagai nilai aplikasi sebelumnya; foto tidak mencantumkan durasi. Express tambahan tetap 24 jam.
- Tidak menambahkan harga setrika untuk Baju Damkar, Blazer, atau Jaket Kulit yang tidak tercantum.

## Menunggu konfirmasi

1. Jaket/Hoodie/Sweater Rp5.000 “sudah ditimbang”: belum dimasukkan sampai jelas apakah ini tambahan setelah kiloan.
2. Kain >3 m Rp3.000: belum dimasukkan sampai unit meter panjang atau m² dikonfirmasi.
3. Foto lengkap untuk harga yang terpotong (termasuk bedcover, boneka, karpet). Harga lama dipertahankan sementara; bukan harga terverifikasi.

## Sinkronisasi

- Fallback: `lib/shared/default_service_catalog.dart`.
- Hierarki formulir: `lib/shared/service_categories.dart`.
- Database aktif: `services.category_id` menunjuk Kiloan/Satuan; `category_name` menyimpan subkategori.
- Seed dan migrasi memuat identitas, varian, unit, harga, dan urutan yang sama dengan fallback. Test katalog memeriksa kesamaannya.
- Migrasi hanya menargetkan toko Idola Laundry 00000000-0000-0000-0000-000000000001; layanan khusus toko lain tidak berubah.
- ID layanan sebelumnya dipertahankan bila dapat dipetakan. Duplikat dinonaktifkan, tidak dihapus. Snapshot harga pesanan lama tidak diubah.
- Daftar harga dan buat pesanan hanya menampilkan layanan aktif. Tambahan layanan lokal langsung memperbarui provider katalog; online menggunakan realtime services yang sudah ada.
- Jumlah meter/m² dapat diedit dengan mengetuk jumlah di keranjang, maksimal dua angka desimal. Nota dan laporan memakai format jumlah yang sama.

## Verifikasi penerapan

- Migrasi 20260831080857 diterapkan ke database aktif pada 31 Agustus 2026.
- Hasil baca ulang: 126 layanan aktif (9 kiloan, 117 satuan), dua kategori utama, nol selisih harga/varian/unit dengan fallback.
- Harga, ID, varian, dan estimasi sembilan paket kiloan tetap sama.
- Uji transaksi yang dibatalkan membuktikan snapshot pesanan/item tidak berubah; dua kali menjalankan migrasi tidak menggandakan layanan.
- Publication realtime `services` aktif. Pengujian dua HP secara langsung masih perlu dilakukan.
- Verifikasi Flutter: 42 tes lolos, termasuk navigasi subkategori, tambah layanan lokal, insentif sepatu, kesamaan seed, dan input 2,25 m²; analisis kode bersih.

## Harga lama yang belum terverifikasi

| Subkategori | Barang | Varian | Harga | Unit |
|---|---|---|---:|---|
| Pakaian | Kaos | Sedang Normal | 5000 | PIECE |
| Pakaian | Kaos | Sedang Bagus | 7000 | PIECE |
| Pakaian | Kaos | Besar Normal | 6000 | PIECE |
| Pakaian | Celana Panjang | Normal | 20000 | PIECE |
| Jas dan Jaket | Jaket | Tebal/Bulu | 35000 | PIECE |
| Perlengkapan Tidur | Sprei | Small | 10000 | PIECE |
| Perlengkapan Tidur | Sprei | Medium | 13000 | PIECE |
| Perlengkapan Tidur | Bed Cover | Sedang Katun | 35000 | PIECE |
| Perlengkapan Tidur | Bed Cover | Besar Katun | 50000 | PIECE |
| Perlengkapan Tidur | Bed Cover | Besar Bulu Angsa | 130000 | PIECE |
| Perlengkapan Tidur | Selimut | Tebal | 15000 | PIECE |
| Perlengkapan Rumah | Karpet | per m2 | 47000 | M2 |
| Boneka | Boneka | XS | 38000 | PIECE |
| Boneka | Boneka | S | 45000 | PIECE |
| Boneka | Boneka | M | 53000 | PIECE |
| Boneka | Boneka | L | 67000 | PIECE |
| Boneka | Boneka | XL | 158000 | PIECE |
| Sepatu | Cuci Sepatu | Reguler | 25000 | PAIR |
| Helm | Cuci Helm | Reguler | 20000 | ITEM |
| Layanan Tambahan | Express | Tambahan | 5000 | ITEM |
| Layanan Tambahan | Noda Berat | Tambahan | 5000 | ITEM |
