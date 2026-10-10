# Chimera Linux — Channel

Experimental Chimera Linux ARM64 rootfs for the Motorola Moto G7 Play.

## Build

This branch uses `chimera/build.sh` and `.github/workflows/chimera.yml`.

The rootfs runs with dinit. It uses modules from a matching mainline Channel kernel build.

The artifact is `channel-chimera-rootfs`.

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

Install on Chimera Linux before converting an image:

```sh
apk add android-tools
```

After decompressing the matching rootfs image:

```sh
img2simg chimera-channel-rootfs.ext4 rootfs-sparse.img
simg2img rootfs-sparse.img rootfs-restored.ext4
```

`img2simg` converts raw to sparse; `simg2img` converts sparse back to raw. 

## Rootfs details

- Artifact: `channel-chimera-rootfs`
- Image: `chimera-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `chimera`
- UUID: `89530000-6320-4000-8000-000000000001`
