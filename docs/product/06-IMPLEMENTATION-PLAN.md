# 6. Implementation Plan

**Baseline:** Idola One 2.1.2+18, 20 September 2026

## 1. Posisi saat ini

Fondasi laundry sudah luas dan dipakai sebagai modul operasional utama. Multi-usaha, POS minuman sederhana, pemisahan cetak nota/label, harga sprei per ukuran, history back, dan poin pelanggan sudah terdapat pada working tree/schema produksi. POS dapat dipakai untuk es teh manis dan minuman kecil dengan harga tetap, tetapi belum setara dengan POS F&B lengkap.

## 2. Prinsip pelaksanaan

- Selesaikan stabilisasi perubahan yang ada sebelum menambah modul besar.
- Satu fase harus memiliki acceptance test yang dapat dijalankan owner dan karyawan.
- Perubahan database selalu melalui migration, RLS, index, dan verifikasi produksi.
- Pisahkan commit berdasarkan fungsi agar regresi dapat dilacak.
- Fitur POS tetap sederhana sampai kebutuhan lapangan membuktikan perlunya kompleksitas tambahan.

## 3. Status pekerjaan dari pengembangan Codex

| Paket | Status | Hasil |
| --- | --- | --- |
| Printer Bluetooth thermal | Selesai | Koneksi RPP02N/ESC-POS, 58/80 mm, test print, layout nota. |
| Pemisahan dokumen cetak | Selesai di working tree | Nota, label, dan bukti pengambilan dipilih/cetak satu per satu. |
| Perapihan buat pesanan | Selesai di working tree | Bagian lanjutan dapat dibuka, form lebih hemat ruang. |
| Harga sprei per ukuran | Selesai di schema/working tree | 160, 180, dan 200 menjadi layanan/harga terpisah. |
| Pengajuan karyawan | Selesai | Form dinamis dan review owner dengan status keputusan. |
| Filter stok/pengeluaran | Selesai | Hari ini, Kemarin, Seminggu, serta detail ringkas. |
| Kontak CS | Selesai di working tree | Sinkron/reset dan penghapusan data aplikasi untuk kontak non-CS. |
| Navigasi kembali | Selesai di working tree | History route mengembalikan ke halaman sebelumnya. |
| Multi-usaha | Selesai di schema/working tree | Pemilih usaha, status aktif, tambah usaha, assignment karyawan. |
| POS Es Teh Manis | MVP selesai di schema/working tree | Buka harian, produk, kasir, checkout, transaksi dan omzet hari ini. |
| Poin pelanggan | Fondasi selesai | Earn dan saldo otomatis dari laundry lunas; redeem/web belum ada. |
| Pembulatan total | Selesai | Nilai di atas kelipatan Rp1.000 selalu naik ke ribuan berikutnya pada aplikasi dan database. |
| Notifikasi pesanan | Selesai | Perubahan status kerja/pembayaran membuat notifikasi tertarget; baca, hapus, dan navigasi ditangani tanpa reload penuh. |
| Ringkasan Buku Kas | Selesai | Label dan keterangan panjang membungkus pada ruang terkontrol tanpa membuat teks vertikal. |

Keterangan “working tree” berarti implementasi tersedia secara lokal tetapi perlu dibaseline, diuji ulang, dan disusun dalam commit/release yang jelas.

## 4. Fase 0 — Baseline dan stabilisasi

**Prioritas:** P0  
**Tujuan:** menjadikan kondisi saat ini aman untuk dirilis dan mudah direview.

Pekerjaan:

1. Kelompokkan perubahan lokal menjadi commit: navigation, print, UI laundry, multi-business/POS, loyalty, migration/seed, dan docs.
2. Jalankan `flutter analyze`, seluruh test, dan release build.
3. Jalankan smoke test owner/karyawan pada backend produksi/staging.
4. Uji fisik printer 58 dan 80 mm untuk ketiga dokumen secara terpisah.
5. Rekonsiliasi satu order: total → payment → cash transaction → point event.
6. Rekonsiliasi satu POS sale: header → items → total → ringkasan hari ini.
7. Pastikan migrasi lokal sama dengan schema produksi dan buat backup sebelum rilis.

Acceptance criteria:

- analyzer dan test hijau;
- APK release dapat dipasang/update;
- tidak ada akses lintas peran/usaha;
- tidak ada duplikasi transaksi saat tombol checkout ditekan ulang;
- hasil cetak dapat dipotong dan dipakai secara mandiri;
- route kembali lolos dari semua halaman detail/form.

## 5. Fase 1 — POS minuman operasional

**Prioritas:** P1  
**Tujuan:** cukup kuat untuk jualan harian tanpa membuat UI rumit.

### 5.1 Struk POS

- Builder thermal khusus POS.
- Nama usaha, nomor sale, item, total, metode, waktu, kasir.
- Cetak ulang dari histori.

### 5.2 Histori dan pembatalan aman

- Filter Hari ini/Kemarin/Seminggu.
- Detail transaksi.
- Void hanya oleh owner dengan alasan dan audit; jangan hard delete.
- Reversal kas bila jurnal POS sudah ditambahkan.

### 5.3 Tutup kas sederhana

- Saldo awal, tunai sistem, tunai aktual, selisih, catatan.
- Satu closing per business/date.
- Transfer/QRIS terlihat terpisah dari tunai.

### 5.4 Pengeluaran per usaha

- Tambah `business_id` nullable pada expense/cash transaction atau ledger POS khusus.
- UI pengeluaran ringkas pada POS.
- Laporan harian menghitung penjualan dikurangi pengeluaran usaha.

Acceptance criteria:

- owner dapat mencocokkan tunai kasir dengan transaksi harian;
- transaksi batal meninggalkan audit lengkap;
- laporan laundry dan minuman tidak bercampur.

## 6. Fase 2 — Produk, varian, dan stok bahan

**Prioritas:** P1 setelah data penggunaan MVP tersedia.

Bangun hanya bila menu mulai memiliki banyak ukuran/topping:

1. `pos_product_variants` untuk ukuran dan harga.
2. `modifier_groups` dan `modifiers` untuk gula/es/topping bila benar-benar perlu.
3. `ingredients` dan `product_recipes` untuk teh, gula, cup, es, dan topping.
4. Pengurangan stok atomik saat sale dibuat.
5. Reversal stok saat void.
6. Peringatan stok minimum dan daftar belanja.

UI kasir tetap satu layar: pilih produk → pilih varian yang wajib → modifier opsional → tambah.

Acceptance criteria:

- sale tidak dapat menghasilkan stok negatif jika kebijakan melarang;
- snapshot harga/modifier tetap utuh setelah katalog diubah;
- void mengembalikan bahan dengan nilai yang sama.

## 7. Fase 3 — Loyalty dan web pelanggan

**Prioritas:** P2  
**Tujuan:** pelanggan dapat melihat transaksi/poin dan memakai reward.

Pekerjaan backend:

- ledger point bertipe earn/redeem/adjust/expire;
- katalog reward dan aturan minimum;
- kode/OTP aman untuk menautkan nomor pelanggan ke akun;
- API/RPC redeem atomik dengan validasi saldo;
- policy customer hanya melihat datanya sendiri.

Pekerjaan web:

- login/OTP;
- saldo dan histori poin;
- status laundry dan riwayat nota;
- katalog reward serta konfirmasi redeem;
- kanal kontak/WhatsApp toko.

Acceptance criteria:

- saldo sama dengan jumlah ledger;
- redeem idempoten dan tidak dapat membuat saldo negatif;
- akun pelanggan tidak dapat membaca pelanggan lain atau data internal pegawai.

## 8. Fase 4 — Keandalan dan skala

**Prioritas:** P2

- Monitoring crash dan kegagalan RPC.
- Dashboard metrik per usaha.
- Pengujian RLS otomatis menggunakan role matrix.
- Outbox transaksi offline idempoten bila koneksi lapangan memang sering putus.
- Pagination dan pencarian server-side untuk pelanggan/order besar.
- Retensi audit, backup terjadwal, dan prosedur restore yang diuji.

## 9. Backlog prioritas

| Prioritas | Item | Alasan |
| --- | --- | --- |
| P0 | Commit/baseline seluruh perubahan dan test release | Mengurangi risiko regresi dari perubahan lintas fitur. |
| P0 | Uji printer fisik 58/80 untuk dokumen terpisah | Kebutuhan operasional langsung. |
| P0 | RLS test multi-business | Mencegah akses silang usaha. |
| P1 | Struk dan histori POS | Dibutuhkan saat POS mulai dipakai rutin. |
| P1 | Tutup kas dan pengeluaran POS | Agar omzet dapat direkonsiliasi. |
| P1 | Void/refund dengan audit | Koreksi kasir tanpa merusak histori. |
| P1 | Varian ukuran sederhana | Menghindari duplikasi produk jika menu berkembang. |
| P2 | Resep/stok bahan | Berguna setelah volume dan menu meningkat. |
| P2 | Loyalty redeem dan web pelanggan | Fondasi earn sudah tersedia. |
| P2 | Offline outbox | Dikerjakan berdasarkan bukti masalah koneksi. |

## 10. Rencana rilis

1. **Internal:** owner + satu karyawan, data uji, dua ukuran printer.
2. **Pilot:** satu lokasi selama beberapa hari; cocokkan transaksi, tunai, stok, dan kertas.
3. **Release:** naikkan version/build, publish APK, verifikasi update dari build sebelumnya.
4. **Observasi:** cek error, duplikasi, selisih kas, dan feedback UI.
5. **Rollback:** simpan APK stabil sebelumnya; perubahan schema harus backward-compatible atau memiliki migration pemulihan yang aman.

## 11. Definition of done

Sebuah fitur dianggap selesai ketika:

- kebutuhan dan akses peran terdokumentasi;
- schema/migration, RLS, index, dan audit tersedia jika dibutuhkan;
- loading, empty, error, dan retry ditangani;
- unit/widget test yang bernilai dan smoke test peran lulus;
- tidak merusak back navigation, update APK, atau printer;
- dokumentasi PRD, TRD, flow, dan schema diperbarui bila kontrak berubah;
- artefak release dapat dipasang dan diuji pada perangkat target.
