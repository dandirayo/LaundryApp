# 4. Application Flow

## 1. Masuk dan memilih usaha

```mermaid
flowchart TD
    A[Buka aplikasi] --> B{Sesi valid?}
    B -- Tidak --> C[Login]
    C --> D{Berhasil?}
    D -- Tidak --> C
    D -- Ya --> E[Muat profil dan akses usaha]
    B -- Ya --> E
    E --> F[Pilih usaha]
    F --> G{Jenis usaha}
    G -- Laundry --> H[Shell Laundry sesuai peran]
    G -- Beverage --> I[Shell POS Minuman]
    F --> J[Kelola Usaha]
    J --> K[Tambah usaha/assign karyawan]
    K --> F
```

Aturan:

- akun nonaktif tidak boleh melanjutkan;
- usaha nonaktif tidak dapat dipilih untuk transaksi baru;
- owner mengakses usaha milik tokonya;
- karyawan hanya mengakses usaha dengan membership aktif.

## 2. Membuat pesanan laundry

```mermaid
flowchart TD
    A[Pesanan Baru] --> B[Pilih/tambah pelanggan]
    B --> C[Pilih Kiloan, Satuan, atau Gabung]
    C --> D[Pilih layanan dan varian ukuran]
    D --> E[Masukkan berat/jumlah]
    E --> F[Keranjang dan total]
    F --> G[Pilih pembayaran: belum/DP/lunas/manual]
    G --> H[Metode, kasir, tenggat, catatan]
    H --> I{Valid?}
    I -- Tidak --> D
    I -- Ya --> J[RPC create_laundry_order]
    J --> K{Tersimpan?}
    K -- Tidak --> L[Tampilkan error dan retry]
    K -- Ya --> M[Pilih dokumen cetak]
    M --> N[Nota pelanggan]
    M --> O[Label cucian]
    M --> P[Tutup tanpa cetak]
    N --> Q[Detail pesanan]
    O --> Q
    P --> Q
```

Nota dan label merupakan job yang berbeda. Pengguna dapat kembali ke detail untuk mencetak ulang.

## 3. Proses, pembayaran, dan pengambilan

```mermaid
stateDiagram-v2
    [*] --> Diterima
    Diterima --> Diproses
    Diproses --> SiapDiambil
    SiapDiambil --> Diambil
    Diterima --> Dibatalkan
    Diproses --> Dibatalkan

    state "Belum Bayar" as Belum
    state "DP" as DP
    state "Lunas" as Lunas
    Belum --> DP: pembayaran sebagian
    Belum --> Lunas: pembayaran penuh
    DP --> Lunas: pelunasan
```

Status pekerjaan dan pembayaran disimpan terpisah. Saat diambil:

1. kasir memeriksa status dan sisa;
2. pembayaran dapat ditambahkan, atau pengambilan tetap dilanjutkan sesuai kebijakan;
3. penerima dan waktu tersimpan;
4. bukti lunas/pengambilan dapat dicetak terpisah;
5. bila pelanggan bayar nanti, kasir dapat membagikan instruksi transfer/QR melalui WhatsApp dan bukti pengambilan tetap mencerminkan sisa.

## 4. Pengajuan karyawan

```mermaid
flowchart LR
    A[Karyawan buka Pengajuan Saya] --> B[Pilih jenis]
    B --> C[Isi field dinamis]
    C --> D[Kirim ke owner]
    D --> E[Status Menunggu]
    E --> F{Keputusan owner}
    F -- Setujui --> G[Disetujui + catatan]
    F -- Tolak --> H[Ditolak + alasan]
    G --> I{Berdampak kas?}
    I -- Ya --> J[Cash transaction otomatis]
    I -- Tidak --> K[Selesai alur]
    J --> K
    H --> K
```

Jenis pengajuan aktif: kebutuhan stok, lembur, tukar shift, izin, insentif, dan kasbon.

## 5. Pelanggan, kontak, dan poin

```mermaid
flowchart TD
    A[Daftar pelanggan] --> B[Sinkron kontak perangkat]
    B --> C[Normalisasi nomor]
    C --> D{Sudah ada?}
    D -- Ya --> E[Gabung/perbarui kandidat]
    D -- Tidak --> F[Tambah pelanggan]
    A --> G[Hapus kontak non-CS]
    G --> H[Hapus dari data aplikasi saja]
    F --> I[Pesanan pelanggan]
    E --> I
    I --> J{Pesanan lunas?}
    J -- Ya --> K[1 poin per Rp10.000]
    K --> L[Event + saldo poin]
```

Penghapusan hasil sinkron tidak menghapus kontak asli dari perangkat/akun Google.

## 6. Stok dan pengeluaran

```mermaid
flowchart TD
    A[Stok & Pengeluaran] --> B[Pilih Hari ini/Kemarin/Seminggu/Lainnya]
    B --> C{Jenis aksi}
    C -- Pengadaan --> D[Pilih/tambah barang]
    D --> E[Jumlah, harga, catatan]
    E --> F[Mutasi stok masuk]
    C -- Pengeluaran --> G[Deskripsi, kategori, nominal, metode]
    G --> H[Expense]
    H --> I[Cash transaction keluar]
```

## 7. POS minuman

```mermaid
flowchart TD
    A[Pilih Es Teh Manis] --> B[Ringkasan hari ini]
    B --> C{Hari ini berjualan?}
    C -- Belum --> D[Aktifkan jualan]
    D --> E[Kasir]
    C -- Ya --> E
    E --> F[Pilih produk]
    F --> G[Atur jumlah]
    G --> H[Checkout]
    H --> I[Pilih Tunai/Transfer/QRIS]
    I --> J[RPC create_pos_sale]
    J --> K{Berhasil?}
    K -- Tidak --> H
    K -- Ya --> L[Nomor transaksi + keranjang kosong]
    L --> B
```

Jika diperlukan ukuran atau topping sebelum fitur modifier tersedia, owner membuatnya sebagai produk tersendiri.

## 8. Pengelolaan usaha dan karyawan

```mermaid
flowchart TD
    A[Owner - Kelola Usaha] --> B[Tambah usaha minuman]
    A --> C[Pilih usaha]
    C --> D[Daftar karyawan toko]
    D --> E[Aktif/nonaktifkan assignment]
    E --> F[business_members diperbarui]
    F --> G[Karyawan melihat usaha pada login/pemilih berikutnya]
```

## 9. Navigasi per peran

| Area | Owner laundry | Karyawan laundry | Anggota POS |
| --- | --- | --- | --- |
| Dashboard/ringkasan | Ya | Ya | Ya, khusus POS |
| Pesanan laundry | Semua | Pesanan saya/operasional | Tidak |
| Pelanggan | Ya | Sesuai UI operasional | Tidak |
| Layanan/stok/pegawai/payroll/laporan | Ya | Tidak | Tidak |
| Absensi/jadwal | Seluruh karyawan | Milik sendiri | Belum menjadi modul khusus POS |
| Review pengajuan | Ya | Tidak | Tidak |
| Buat pengajuan | Tidak | Ya | Mengikuti akun karyawan laundry saat masuk modul laundry |
| Kasir POS | Jika membuka usaha | Jika di-assign | Ya |
| Kelola produk POS | Ya | Baca produk aktif | Baca produk aktif |
| Kelola usaha/assignment | Ya | Tidak | Tidak |

## 10. Update aplikasi

```mermaid
flowchart LR
    A[Aplikasi aktif] --> B[Cek metadata rilis]
    B --> C{Build lebih baru?}
    C -- Tidak --> D[Lanjut aplikasi]
    C -- Ya --> E[Tampilkan update]
    E --> F[Unduh APK]
    F --> G[Verifikasi file]
    G --> H[Installer Android]
```

Kegagalan cek update tidak boleh memblokir operasi kecuali rilis secara eksplisit ditandai wajib.

