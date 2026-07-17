# Routes

Routing memakai GoRouter. Route path tidak memakai label menu sehingga aman untuk perubahan teks UI.

## Public

| Name | Path | Akses | Keterangan |
| --- | --- | --- | --- |
| splash | `/splash` | Publik | Bootstrap session dan config. |
| signIn | `/sign-in` | Publik | Login Supabase Auth. |

## Shared Authenticated

| Name | Path | Owner | Employee | Keterangan |
| --- | --- | --- | --- | --- |
| dashboard | `/dashboard` | Ya | Ya | Landing setelah login. |
| orders | `/orders` | Ya | Ya | Daftar pesanan. Employee difilter miliknya. |
| orderCreate | `/orders/new` | Ya | Ya | Flow bertahap tambah pesanan. |
| orderDetail | `/orders/:orderId` | Ya | Ya | Detail pesanan sesuai akses. |
| notifications | `/notifications` | Ya | Ya | Notifikasi dan badge. |
| profile | `/profile` | Ya | Ya | Profil user. |
| more | `/more` | Ya | Ya | Menu lainnya sesuai role. |

## Owner

| Name | Path | Keterangan |
| --- | --- | --- |
| customers | `/customers` | Pelanggan. |
| services | `/services` | Layanan & harga. |
| inventory | `/inventory` | Stok & pengadaan. |
| shifts | `/shifts` | Jadwal shift semua karyawan. |
| employees | `/employees` | Data karyawan. |
| attendance | `/attendance` | Absensi semua karyawan. |
| payroll | `/payroll` | Gaji & insentif. |
| reports | `/reports` | Buku Pesanan dan Buku Kas. |
| cashbook | `/cashbook` | Buku Kas fokus transaksi. |
| expenses | `/expenses` | Pengeluaran. |
| printer | `/printer` | Pengaturan printer dan fallback struk. |
| backup | `/backup` | Export data. |
| shopSettings | `/settings/shop` | Pengaturan toko. |

## Employee

| Name | Path | Keterangan |
| --- | --- | --- |
| attendanceSelf | `/attendance/me` | Absen masuk/keluar dengan foto. |
| scheduleSelf | `/shifts/me` | Jadwal saya. |
| assignedOrders | `/orders/me` | Pesanan saya. |
| stockRequest | `/requests/stock` | Request stok. |
| overtimeRequest | `/requests/overtime` | Request lembur. |
| shiftSwapRequest | `/requests/shift-swap` | Request tukar shift. |
| leaveRequest | `/requests/leave` | Request izin. |
| incentiveRequest | `/requests/incentive` | Request insentif. |
| cashAdvanceRequest | `/requests/cash-advance` | Request kasbon. |
| changePin | `/account/change-pin` | Ganti PIN quick unlock lokal. |

## Redirect Rules

1. User tanpa session diarahkan ke `/sign-in`.
2. User dengan session tetapi profile belum lengkap diarahkan ke halaman error setup.
3. User login yang membuka `/sign-in` diarahkan ke `/dashboard`.
4. Employee yang membuka route Owner diarahkan ke `/dashboard` dengan pesan akses ditolak.
5. Route unknown diarahkan ke halaman "Halaman tidak ditemukan" dengan aksi kembali.
6. Logout membersihkan Supabase session, provider sensitif, realtime subscription, dan local cache sensitif.

## Menu Mapping

Owner bottom navigation:

- Beranda -> `/dashboard`
- Pesanan -> `/orders`
- Pelanggan -> `/customers`
- Lainnya -> `/more`

Karyawan bottom navigation:

- Beranda -> `/dashboard`
- Pesanan -> `/orders/me`
- Absensi -> `/attendance/me`
- Lainnya -> `/more`
