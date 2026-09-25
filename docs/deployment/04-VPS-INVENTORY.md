# 4. Inventaris VPS

**Tanggal inventaris:** 20 September 2026

## 1. VPS yang terverifikasi

| ID internal | Host/IP | Peran | Project aktif | Status terakhir |
| --- | --- | --- | --- | --- |
| `vps-prod-01` | `202.10.47.56` | Static web host/Nginx | Dashboard admin LaundryApp | Host dikenal dan deployment terakhir sukses; endpoint sedang timeout saat pemeriksaan terbaru. |

### Detail `vps-prod-01`

| Field | Nilai |
| --- | --- |
| Nama operasional | DandiVPS Production 01 |
| Public IPv4 | `202.10.47.56` |
| Provider | Belum terdokumentasi |
| Region | Belum terdokumentasi |
| OS/version | Belum diverifikasi |
| CPU/RAM/disk | Belum diverifikasi |
| SSH port | Disimpan sebagai GitHub secret `VPS_PORT` |
| Deployment user | `dandivps-deploy` menurut runbook repository |
| Host key ED25519 | `SHA256:UUg4tWDLjq/RwXde+Tha7KBPH8LUQdiZCNzOwvf+mzA` |
| Service | Nginx static site |
| Verify URL | `http://202.10.47.56:8081/` |
| Webroot | `/var/www/apps/dandivps-deploy` |
| Staging | `/home/dandivps-deploy/deploy-staging/dandivps-deploy` |
| Backup aktif | `/home/dandivps-deploy/backups/dandivps-deploy/previous.tar.gz` |
| Domain/HTTPS | Belum ditemukan pada konfigurasi LaundryApp |
| Repository | `dandirayo/LaundryApp` |
| Pipeline | `.github/workflows/deploy-admin.yml` |

### Bukti status

- GitHub workflow aktif.
- Deployment sukses terakhir yang terlihat: 6 September 2026, run `34026106625`.
- `known_hosts` lokal memiliki RSA, ECDSA, dan ED25519 untuk IP yang sama.
- Pemeriksaan 20 September 2026 ke port 80, 443, dan 8081 semuanya timeout. Penyebab belum dapat ditentukan tanpa akses console/SSH: VPS mati, firewall, jaringan/provider, perubahan IP, atau service tidak tersedia.

## 2. Project dengan konfigurasi VPS/container tetapi host belum terverifikasi

Project berikut ditemukan pada workspace, tetapi **tidak dihitung sebagai VPS aktif** karena tidak ada host/IP yang cukup:

| Project | Bukti konfigurasi | Status inventaris |
| --- | --- | --- |
| MalaysiaCollegeReg | `scripts/vps-setup.sh`, Nginx, `/var/www/topalumniglobal` | Kandidat deployment; host belum diketahui. |
| peduli-donasi | Docker Compose, Nginx, backup script | Kandidat deployment; host belum diketahui. |
| Quizzy | Dockerfile Nginx | Container-ready; belum membuktikan VPS. |
| Parafrasa | Dockerfile dengan `/var/www/html` | Container-ready; belum membuktikan VPS. |
| Digital-Web-Wedding | Roadmap HTTPS/Nginx | Masih dokumentasi/rencana berdasarkan bukti lokal. |

## 3. Data yang perlu dilengkapi

- provider dan paket VPS;
- lokasi/region;
- OS, versi kernel, CPU, RAM, disk;
- tanggal mulai dan masa berlaku/tagihan;
- domain dan DNS record;
- kontak pemilik teknis;
- metode akses console darurat;
- firewall ports;
- status backup di luar VPS;
- daftar service/container lain pada host;
- target RTO dan RPO.

## 4. Aturan pemeliharaan inventaris

Perbarui dokumen ini saat:

- VPS dibuat, dipindahkan, direbuild, atau dihapus;
- IP/domain/host key berubah;
- project baru ditempatkan pada VPS;
- akses admin/deploy dirotasi;
- kapasitas atau kebijakan backup berubah.

Jangan menambahkan password, private key, API token, recovery code, atau nilai `.env`.

