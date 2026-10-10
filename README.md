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

## Rootfs details

- Artifact: `channel-crux-rootfs`
- Image: `crux-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `crux`
- UUID: `89530000-6320-4000-8000-000000000001`
