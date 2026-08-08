# CloakBrowser Installer

Installer sederhana untuk Ubuntu 24.04.

Alur:

1. Update Ubuntu
2. Install Docker
3. Clone CloakBrowser Manager
4. Build dan start Manager
5. Membuka port `8080`
6. Berhenti dan meminta user upload PIA VPN
7. User upload PIA melalui WinSCP/SFTP
8. User mengetik `YES`
9. Installer mengecek `manifest.json`
10. Menampilkan status akhir

## Upload ke GitHub

Buat repository baru, misalnya:

`cloakbrowser-installer`

Upload:

- `install.sh`
- `README.md`

Lalu di VPS jalankan:

```bash
curl -fsSL https://raw.githubusercontent.com/USERNAME/cloakbrowser-installer/main/install.sh -o install.sh
chmod +x install.sh
sudo ./install.sh
```

Atau:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/USERNAME/cloakbrowser-installer/main/install.sh)
```

Ganti `USERNAME` dengan username GitHub.

## PIA

Jangan upload extension PIA ke repository GitHub jika lisensinya tidak mengizinkan redistribusi.

Installer sengaja berhenti dan meminta upload manual ke:

```text
/opt/CloakBrowser-Manager/extensions/pia/
```

Setelah upload selesai:

```text
Ketik YES
```

Installer akan melanjutkan.

## Catatan

Installer ini menyiapkan extension dan memvalidasi `manifest.json`.
Pemuatan extension ke profile harus dikonfigurasi melalui `launch_args`
CloakBrowser Manager yang sesuai dengan versi source yang digunakan.
