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

## Expand the root filesystem

After boot, run as root and identify the partition mounted at `/`:

```sh
lsblk -o NAME,SIZE,FSTYPE,MOUNTPOINTS
grep ' / ' /proc/mounts
command -v resize2fs
```

For Alpine, install the missing tool:

```sh
apk add e2fsprogs-extra
```

If the root filesystem is ext4, use its **confirmed device path**:

```sh
resize2fs /dev/ROOT_PARTITION
df -h /
```

This grows ext4 to the available space in its existing partition. Do not guess the root device.

## Rootfs details

- Artifact: `channel-alpine-rootfs`
- Image: `alpine-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `alpine`
- UUID: `89530000-6320-4000-8000-000000000001`
