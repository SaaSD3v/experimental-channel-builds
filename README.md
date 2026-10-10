# CRUX-ARM 3.8 — Channel

Experimental CRUX-ARM 3.8 ARM64 rootfs for the Motorola Moto G7 Play.

## Build

This branch uses `crux/build.sh` and `.github/workflows/crux.yml`.

The rootfs runs with BSD-style init. It uses modules from a matching mainline Channel kernel build.

The artifact is `channel-crux-rootfs`.

## Network

The CRUX image includes the USB gadget and dnsmasq, but does not install NetworkManager.

Check available interfaces with `ip -br link`. Install and configure Wi-Fi tools separately if needed.

## Time

If the device clock needs correction, set the actual UTC time:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```

## Optional Android sparse tools

These builds output raw ext4. Sparse conversion is optional and does not replace the existing Channel boot process.

A sparse-tool package for the CRUX base was not verified. Use a Debian/Ubuntu computer to handle the image:

```sh
sudo apt install android-sdk-libsparse-utils
```

After decompressing the matching rootfs image:

```sh
img2simg crux-channel-rootfs.ext4 rootfs-sparse.img
simg2img rootfs-sparse.img rootfs-restored.ext4
```

`img2simg` converts raw to sparse; `simg2img` converts sparse back to raw. 

## Rootfs details

- Artifact: `channel-crux-rootfs`
- Image: `crux-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `crux`
- UUID: `89530000-6320-4000-8000-000000000001`
