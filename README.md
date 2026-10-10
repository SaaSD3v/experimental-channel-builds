# openSUSE Tumbleweed — Channel

Experimental openSUSE Tumbleweed ARM64 rootfs for the Motorola Moto G7 Play.

## Build

This branch uses `opensuse/build.sh` and `.github/workflows/opensuse.yml`.

The rootfs uses systemd and includes modules matching the Channel mainline kernel.

The artifact is `channel-opensuse-rootfs`.

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

## Rootfs details

- Artifact: `channel-opensuse-rootfs`
- Image: `opensuse-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `opensuse`
- UUID: `89530000-6320-4000-8000-000000000001`
