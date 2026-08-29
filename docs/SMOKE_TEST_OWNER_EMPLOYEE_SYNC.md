# Manual Smoke Test — Owner ↔ Employee Sync

## Setup

- Dua perangkat/session terpisah: akun Owner dan Employee pada shop yang sama.
- Supabase production sudah menerima seluruh migration, termasuk migration notification reference Chat 3.
- APK debug/release yang menunjuk project production; internet aktif.
- Android memiliki beberapa system contacts (termasuk multi-number dan name-only). Google Contacts hanya akan muncul bila sudah tersinkron ke system contacts Android.

Catat `Pass/Fail` dan bukti/waktu di kolom Notes. Untuk test realtime, jangan refresh lebih dulu; bila gagal, lanjutkan dengan pull refresh untuk menguji recovery.

| # | Test / Steps | Expected result | Pass/Fail | Notes |
|---:|---|---|---|---|
| 1 | Login Owner pada perangkat A. | Dashboard Owner tampil tanpa raw DB error. | | |
| 2 | Login Employee pada perangkat B. | Dashboard Employee hanya menampilkan data yang diizinkan. | | |
| 3 | Employee → Pelanggan → tambah customer (boleh tanpa nomor). | Row customer tersimpan satu kali. | | |
| 4 | Amati perangkat Owner tanpa refresh. | Customer dan count muncul; bila tidak, pull refresh memulihkan. | | |
| 5 | Owner edit nama/alamat customer. | Save sukses tanpa duplicate. | | |
| 6 | Amati Employee. | Perubahan customer tampil realtime/refresh. | | |
| 7 | Employee buat order lalu tap submit berulang cepat. | Hanya satu order dibuat, loading/disabled jelas. | | |
| 8 | Amati Owner. | Order dan item lengkap muncul; summary dashboard berubah. | | |
| 9 | Owner ubah status order ke Processing/Ready. | Status tersimpan dan notification penting dibuat bila rule aktif. | | |
| 10 | Amati Employee. | Status terbaru terlihat; tap notification membuka halaman aman. | | |
| 11 | Owner tambah payment, tap tombol cepat dua kali. | Payment tidak duplikat; paid amount/status konsisten. | | |
| 12 | Amati Employee dan cashbook Owner. | Order ter-refresh; satu ledger income dibuat oleh trigger. | | |
| 13 | Owner tambah expense. | Expense tersimpan; Employee tidak punya aksi pengelolaan. | | |
| 14 | Buka Cashbook/dashboard. | Tepat satu ledger OUT dan summary berubah. | | |
| 15 | Owner bayar payroll untuk satu periode. | Payment sukses; pembayaran kedua periode sama ditolak aman. | | |
| 16 | Periksa payroll history/cashbook. | History berubah dan tepat satu ledger OUT. | | |
| 17 | Employee buat request. | Request pending tampil satu kali. | | |
| 18 | Amati Owner. | Request dan badge durable notification muncul. | | |
| 19 | Owner approve request dengan note yang diperlukan. | Transition valid tersimpan. | | |
| 20 | Amati Employee. | Status dan notification approval muncul; unread count berubah. | | |
| 21 | Employee check-in dengan foto valid. Ulangi dengan permission camera denied. | Check-in tersimpan; denied/storage failure tidak crash dan tidak bocor raw error. | | |
| 22 | Amati attendance Owner. | Check-in tampil realtime; summary berubah. | | |
| 23 | Owner ubah weekly shift/day off Employee. | Shift tersimpan. | | |
| 24 | Amati Employee. | Shift/day off benar dan notification durable muncul. | | |
| 25 | Owner adjust inventory; bila Employee diizinkan, lakukan movement dari session Employee. | Stock/movement konsisten, tidak negatif. | | |
| 26 | Turunkan stock melewati threshold. | Low-stock notification Owner muncul satu kali. | | |
| 27 | Pelanggan → ikon Kontak; pilih system contact, multi-number, lalu konfirmasi preview. | Hanya kontak terpilih di-upload; nomor Indonesia normalized; realtime ke session lain. | | |
| 28 | Cabut READ_CONTACTS lalu ulangi import. | Pesan izin tampil dengan Buka Pengaturan/Batal; tidak crash. | | |
| 29 | Tap notification unread dan Tandai semua. | Row menjadi read, badge berkurang, navigasi/fallback aman. | | |
| 30 | Putus network, buka halaman penting, sambungkan lagi lalu pull refresh/retry. | Data lama tidak crash; pesan aman; refresh memuat data terbaru tanpa listener ganda. | | |

## Pemeriksaan isolasi/RLS tambahan

- Ulangi query dengan akun dari shop lain: data shop pertama tidak boleh terlihat.
- Employee tidak boleh approve request sendiri, membayar payroll, atau mengelola expense.
- Employee payroll (jika UI tersedia) hanya menampilkan miliknya; notifications hanya recipient tersebut.
- Cek Supabase table editor/log: setiap payment/expense/payroll/request payout memiliki maksimal satu `cash_transactions` dengan reference yang sama.
