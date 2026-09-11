# laundry_app_flutter

Flutter app for Idola One.

## Printer Bluetooth (Android)

Pasangkan printer struk Bluetooth ESC/POS (misalnya RPP02N) melalui pengaturan
Bluetooth HP. Di aplikasi, buka **Lainnya > Printer > Pilih Printer**, izinkan
**Perangkat di sekitar**, lalu pilih nama printer dan tekan **Cetak Tes**.
Printer yang berhasil dipilih disimpan pada HP dan disambungkan kembali saat
mencetak. Dari preview struk, pilihan awal adalah 80 mm; ukuran 58 mm tetap
tersedia. Tekan **Cetak ke Printer Thermal** untuk mengirim nota.

Total pesanan dibulatkan ke ribuan untuk semua metode dan status pembayaran.
Sisa Rp500 dibulatkan ke bawah, sedangkan Rp501 dibulatkan ke atas. Nota
menampilkan subtotal, penyesuaian pembulatan, status lunas, dan logo toko.

Daftar pesanan memakai kartu dropdown untuk membuka ringkasan tanpa memenuhi layar.
Filter Express dan Kilat tersedia di atas filter status. Alur utama menampilkan
**Pesanan Selesai**, kemudian membuka WhatsApp siap diambil. Dashboard karyawan
menampilkan ringkasan pesanan, layanan, nominal, dan catatan hari ini.

Menu **Stok & Pengeluaran** memiliki tab Pengadaan dan Pengeluaran. Live Stock
ditampilkan di bagian atas Pengadaan. Pengadaan menyediakan pilihan Gas, Plastik
(ukuran 30-55 serta jenis Biasa/Jinjing/Plastik Satuan), Sabun, dan Pewangi. Data
tersimpan di Supabase dan tersinkron untuk Owner maupun karyawan.

Jika izin ditolak permanen, aktifkan izin Perangkat di sekitar melalui pengaturan
aplikasi Android. Jika koneksi gagal, periksa daya, jarak, dan aplikasi/HP lain
yang sedang memakai printer. Status pengiriman bukan konfirmasi kertas tercetak;
periksa hasil fisik sebelum mengulang. Cetak teks memakai karakter ASCII.
USB, BLE-only, dan protokol printer selain ESC/POS belum didukung.

Integrasi memerlukan pemasangan APK baru; APK lama yang menampilkan pesan plugin
belum dipasang tidak dapat mengaktifkannya hanya dengan pairing Bluetooth.

## Android releases

Cloud updates are available from version 1.0.3+4. For a user-facing release,
increase `version` in `pubspec.yaml`, run analysis/tests, then run
`../scripts/publish-android.ps1 -ReleaseNotes 'Ringkasan perubahan'` from PowerShell.
This builds and verifies APKs and publishes the cloud version feed last.
Running `flutter build apk` alone does not notify installed apps.
See [the update runbook](../docs/android-cloud-updates.md) for signing continuity,
publishing, verification, and rollback details.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.
