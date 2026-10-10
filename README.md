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

## Expand the root filesystem

After boot, run as root and identify the partition mounted at `/`:

```sh
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
grep ' / ' /proc/mounts
command -v resize2fs
```

If `resize2fs` is unavailable on CRUX, provide `e2fsprogs` through its supported package/ports setup or resize the filesystem from recovery. Do not assume a package command that has not been verified.

If the root filesystem is ext4, use its **confirmed device path**:

```sh
resize2fs /dev/ROOT_PARTITION
df -h /
```

This grows ext4 to the available space in its existing partition. Do not guess the root device.

## Rootfs details

- Artifact: `channel-crux-rootfs`
- Image: `crux-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `crux`
- UUID: `89530000-6320-4000-8000-000000000001`
