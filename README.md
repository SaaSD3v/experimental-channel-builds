# Arch Linux ARM — Channel

Experimental Arch Linux ARM ARM64 rootfs for the Motorola Moto G7 Play.

## Build

This branch uses `arch/build.sh` and `.github/workflows/arch.yml`.

The rootfs runs with systemd. It uses modules from a matching mainline Channel kernel build.

The artifact is `channel-arch-rootfs`.

## Network

SSH access is available through the USB gadget at `172.16.42.1`:

```sh
ssh root@172.16.42.1
```

With a working Wi-Fi interface, NetworkManager provides:

```sh
nmcli device wifi list
nmcli --ask device wifi connect "SSID" ifname wlan0
```

## Time

If the device clock needs correction, set the actual UTC time:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```

## Optional Android sparse tools

These builds output raw ext4. Sparse conversion is optional and does not replace the existing Channel boot process.

Install on Arch Linux ARM before converting an image:

```sh
sudo pacman -S android-tools
```

After decompressing the matching rootfs image:

```sh
img2simg arch-channel-rootfs.ext4 rootfs-sparse.img
simg2img rootfs-sparse.img rootfs-restored.ext4
```

`img2simg` converts raw to sparse; `simg2img` converts sparse back to raw. 

## Rootfs details

- Artifact: `channel-arch-rootfs`
- Image: `arch-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `arch`
- UUID: `89530000-6320-4000-8000-000000000001`
