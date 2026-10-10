# Ubuntu — Channel

Experimental Ubuntu ARM64 rootfs for the Motorola Moto G7 Play.

## Build

This branch uses `ubuntu/build.sh` and `.github/workflows/ubuntu.yml`.

The rootfs uses systemd and includes modules matching the Channel mainline kernel.

The artifact is `channel-ubuntu-rootfs`.

## Image

Download `ubuntu-channel-rootfs.ext4.zst` and extract the raw ext4 image:

```sh
zstd -d -k ubuntu-channel-rootfs.ext4.zst
```

Use the existing Channel boot setup to deploy the rootfs.

After boot, `df -h /` shows available space. Confirm the root partition with `findmnt -n -o SOURCE,FSTYPE /` before using `resize2fs` if expansion is needed.

## Network

Connect over the USB gadget at `172.16.42.1`:

```sh
ssh root@172.16.42.1
```

With working Wi-Fi, NetworkManager provides:

```sh
nmcli device wifi list
nmcli --ask device wifi connect "SSID" ifname wlan0
```

## Time

To correct an incorrect clock, enter the actual UTC time:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```
