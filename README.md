# CRUX-ARM 3.8 — Channel

Experimental CRUX-ARM 3.8 ARM64 rootfs for the Motorola Moto G7 Play.

## Build

This branch uses `crux/build.sh` and `.github/workflows/crux.yml`.

The rootfs runs with BSD-style init. It uses modules from a matching mainline Channel kernel build.

The artifact is `channel-crux-rootfs`.

## Image

Download `crux-channel-rootfs.ext4.zst` and extract the raw ext4 image:

```sh
zstd -d -k crux-channel-rootfs.ext4.zst
```

Deployment follows the existing Channel boot setup. No separate flashing instructions are needed here.

After boot, check root space with `df -h /`. If necessary, confirm the ext4 root device with `findmnt -n -o SOURCE,FSTYPE /` before using `resize2fs`.

## Network

The CRUX image includes the USB gadget and dnsmasq, but does not install NetworkManager.

Check available interfaces with `ip -br link`. Install and configure Wi-Fi tools separately if needed.

## Time

If the device clock needs correction, set the actual UTC time:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```
