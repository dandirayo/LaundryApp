# Pengajuan karyawan

Menu Pengajuan Saya dan Review Pengajuan memakai tiga kategori yang sama.

| Kategori | Jenis | Detail wajib |
| --- | --- | --- |
| Kebutuhan Stok | Stok | Nama barang, jumlah bulat positif, satuan |
| Izin & Jadwal | Izin (pilihan awal) | Jenis izin, tanggal mulai dan selesai |
| Izin & Jadwal | Tukar Shift (pilihan tambahan) | Tanggal, shift asal, shift tujuan, rekan pengganti |
| Izin & Jadwal | Lembur (pilihan tambahan) | Tanggal, jam mulai/selesai, pekerjaan |
| Dana & Biaya | Kasbon | Nominal positif |
| Dana & Biaya | Biaya Operasional | Dana operasional/reimbursement, nominal positif, tujuan |

Catatan tambahan selalu opsional. Penjelasan pribadi untuk izin/kasbon tidak
diwajibkan. Tanggal selesai izin tidak boleh mendahului tanggal mulai. Lembur
mendukung selesai esok hari dengan durasi lebih dari nol sampai 24 jam.

Jenis insentif tidak ditawarkan untuk pengajuan baru. Riwayat insentif lama tetap
terlihat dalam Dana & Biaya dan masih dapat diproses Owner. Tautan pengajuan lama
tetap valid. Tukar shift/lembur berada di pilihan tambahan, bukan menu tersendiri;
belum ada pengaturan toko untuk mengaktifkan/menonaktifkan kedua jenis ini.

## Kompatibilitas penyimpanan

Nilai `type` yang sudah ada tetap digunakan, termasuk `Request Stok`,
`Request Izin`, dan `Request Pengeluaran`. `amount` tetap berupa integer untuk
jumlah stok atau nominal uang. Tidak ada migrasi database untuk perubahan ini.

Detail form dirangkum menjadi teks berlabel dalam kolom `reason` yang sudah ada.
Catatan opsional ditambahkan hanya jika diisi. Ringkasan ini dapat dibaca client
lama, notifikasi, halaman review, dan Buku Kas tanpa parser atau kolom baru.
Detail tanggal/barang belum berupa kolom terstruktur yang dapat dipakai untuk
otomatisasi jadwal, penambahan stok, atau pelaporan per barang.

Persetujuan tidak otomatis mengubah stok, jadwal, atau absensi. Pembayaran tetap
menggunakan alur status yang ada; tombol pembayaran mencatat uang keluar dan
bukan transfer bank. Biaya yang sudah dicatat/diganti tidak perlu diajukan ulang.

## Verifikasi

`flutter test test/request_form_test.dart` memeriksa kolom wajib, catatan opsional,
pergantian kategori tanpa membawa data pribadi sebelumnya, tanggal/jam, layout
layar kecil, dan kompatibilitas riwayat insentif. Uji sinkronisasi dua akun pada
Supabase tetap mengikuti `docs/SMOKE_TEST_OWNER_EMPLOYEE_SYNC.md` di root repo.
