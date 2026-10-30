# Upgrade UI, UX, Sistem, dan Fitur — 30 Oktober 2026

Dokumen ini mencatat pelaksanaan upgrade setelah audit aplikasi. Prinsip utama:
data produksi lama tidak diubah massal, transaksi historis tetap menjadi sumber
kebenaran, dan perubahan database berikutnya harus bersifat additive serta dapat
diuji pada staging sebelum produksi.

## Baseline dan backup

- Baseline source: commit `69c6252e14d63077bae15cd93184faa736e60411`.
- Tag rollback: `backup/pre-ui-ux-system-2026-10-30`.
- Backup source dan database berada di
  `backups/upgrade-2026-10-30-pre-ui-ux-system/`.
- Snapshot database valid mencakup 35 tabel `public` dan 5.725 baris.
- Snapshot dibuat dalam transaksi `READ ONLY, REPEATABLE READ` dan jumlah baris
  diverifikasi kembali terhadap produksi.

## Selesai pada tahap awal

### Navigasi mobile

- Menu Owner dipisahkan menjadi Usaha, Operasional, Tim, Keuangan, Perangkat,
  serta Akun & Usaha.
- `Kelola Stok` dipisahkan dari `Pembelian Stok & Pengeluaran`.
- Menu Karyawan dikelompokkan menjadi Pekerjaan, Pelayanan, Pengajuan, dan Akun.
- Navigasi bawah dan seluruh route lama tetap dipertahankan.

### Navigasi web Owner

- Sidebar dikelompokkan menjadi Ringkasan, Operasional, Tim, Keuangan, dan
  Kontrol.
- Istilah `Approval Center` diganti menjadi `Pusat Pengajuan`.
- Status non-uang `completed` ditampilkan sebagai `Dilaksanakan`.
- Aksi ambigu `Selesaikan` diganti menjadi `Tandai Dilaksanakan` tanpa mengubah
  nilai status yang tersimpan di database.

### Integritas dan skala web

- Insert, update, upsert, dan delete penting meminta kembali `id` baris yang
  berubah. Nol baris akibat RLS tidak lagi dianggap sukses.
- Pesanan, transaksi kas, dan pelanggan dimuat bertahap per 500 baris sampai
  selesai, bukan berhenti pada satu query maksimal 5.000 baris.
- Tidak ada perubahan schema atau data produksi pada tahap ini.

## Validasi

- Flutter analyzer: lulus tanpa temuan.
- Flutter tests: 96 lulus.
- Web lint: lulus.
- Web production build: lulus.
- Preview desktop: struktur sidebar baru diperiksa secara visual.

## Rilis

- Android `2.1.15+31` dipublikasikan melalui Supabase Storage pada 30 Oktober
  2026.
- APK arm64-v8a, armeabi-v7a, dan x86_64 lolos pemeriksaan package, version,
  signer, ukuran, serta verifikasi download-back SHA-256.
- Source rilis dipersiapkan untuk commit dan tag `v2.1.15-build31` di GitHub.

## Tahap lanjutan

1. Metrik dashboard berbasis aggregate/RPC server.
2. Pagination dan pencarian server untuk tabel yang sangat panjang.
3. Histori transisi status pesanan yang append-only.
4. Detail pesanan, cetak, absensi, payroll, notifikasi, dan poin pada web.
5. Pemecahan `App.tsx` serta halaman Flutter besar menjadi modul feature-first.
6. Uji Owner–Karyawan pada dua perangkat nyata sebelum rilis APK/web.

Setiap tahap lanjutan yang membutuhkan schema baru wajib memakai migration baru,
RLS, audit, verifikasi advisor, dan uji restore/staging. Tidak boleh mengubah ID,
snapshot harga, pembayaran, atau tanggal transaksi historis yang sudah ada.
