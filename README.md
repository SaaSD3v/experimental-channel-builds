# Alpine — Channel

Experimental Alpine ARM64 rootfs for the Motorola Moto G7 Play.

## Build

This branch uses `alpine/build.sh` and `.github/workflows/alpine.yml`.

The rootfs runs with OpenRC. It uses modules from a matching mainline Channel kernel build.

The artifact is `channel-alpine-rootfs`.

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

## Alpine utilities

Without `findmnt`, inspect the root mount using `grep ' / ' /proc/mounts`.

Optional packages:

```sh
apk add e2fsprogs-extra          # resize2fs
apk add android-tools-img2simg  # Android sparse converter (community)
```

The build outputs raw ext4, without sparse conversion.

## Rootfs details

- Artifact: `channel-alpine-rootfs`
- Image: `alpine-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `alpine`
- UUID: `89530000-6320-4000-8000-000000000001`
