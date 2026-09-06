# Matriks Sinkronisasi Idola One

Status terakhir: 6 September 2026. `CODE PASS` berarti jalur query, mutation, subscription, dan pengujian otomatis tersedia. `DEVICE TEST` berarti tetap perlu pembuktian dua perangkat pada jaringan nyata.

| Fitur | Sumber utama | Android realtime | Web realtime | Recovery | Status |
|---|---|---:|---:|---|---|
| Pesanan | `orders`, `order_items` | Ya | Ya, ringkasan order | Refresh + rekonsiliasi | CODE PASS; DEVICE TEST |
| Pembayaran | `payments`, `orders`, `cash_transactions` | Ya | Ya melalui order/kas | Refresh + rekonsiliasi | CODE PASS; DEVICE TEST |
| Pelanggan | `customers` | Ya | Ya | Refresh + rekonsiliasi web | CODE PASS; DEVICE TEST |
| Layanan/harga | `services`, `service_categories` | Ya | Belum ada modul | Refresh Android | ANDROID READY; WEB TODO |
| Buku Kas | `cash_transactions` | Ya | Ya | Polling web/Android 15 detik | CODE PASS; DEVICE TEST |
| Pengeluaran | `expenses`, `cash_transactions` | Ya | Belum ada modul terstruktur | Refresh Android | ANDROID READY; WEB TODO |
| Inventaris | `inventory_items`, `inventory_movements` | Ya | Ya | Refresh + rekonsiliasi web | CODE PASS; DEVICE TEST |
| Karyawan/profil | `employees`, `profiles` | Ya | Ya untuk karyawan | Refresh + rekonsiliasi web | CODE PASS; DEVICE TEST |
| Absensi | `attendance_records`, Storage | Ya | Belum ada modul | Refresh Android | ANDROID READY; WEB TODO |
| Shift | `weekly_shifts` | Ya | Ya | Refresh + rekonsiliasi web | CODE PASS; DEVICE TEST |
| Pengajuan | `employee_requests` | Ya | Ya | Polling Android/web 15 detik | CODE PASS; status approved produksi terverifikasi |
| Payroll | `payroll_payments`, `cash_transactions` | Ya | Belum ada modul | Refresh Android | ANDROID READY; WEB TODO |
| Notifikasi | `notifications` | Ya | Belum ada modul | Refresh Android | ANDROID READY; WEB TODO |
| Audit | `audit_logs` | Tidak ditampilkan | Ya | Rekonsiliasi web 15 detik | WEB READY |
| Pengaturan toko | `shops`, `shop_settings` | Sebagian | `shops` | Refresh/focus | PARTIAL |
| Update Android | Storage `app-releases` | Polling 5 menit | Tidak relevan | Cek manual | READY |

## Publication realtime produksi

Migration `20260906013324_complete_realtime_publication.sql` melengkapi tabel yang sudah memiliki subscriber di source code: `attendance_records`, `order_items`, `payments`, dan `profiles`.

Seluruh tabel operasional yang dipublikasikan tetap dilindungi RLS. Event realtime hanya diterima jika session pengguna juga boleh membaca row tersebut.

## Aturan recovery

- Realtime mempercepat tampilan, tetapi query ulang tetap menjadi sumber state.
- Android melakukan refresh ketika halaman dibuka atau kembali aktif; order, kas, dan pengajuan memiliki rekonsiliasi berkala.
- Website Admin melakukan query ulang saat event diterima, setiap 15 detik ketika terlihat, ketika tab kembali terlihat, dan ketika window kembali fokus.
- Tombol refresh manual tetap dipertahankan untuk diagnosis jaringan.

Rincian fitur dan backlog website tersedia di [Blueprint Website Admin](ADMIN_DASHBOARD_BLUEPRINT.md).
