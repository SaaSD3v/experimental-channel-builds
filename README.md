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

## Rootfs details

- Artifact: `channel-chimera-rootfs`
- Image: `chimera-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `chimera`
- UUID: `89530000-6320-4000-8000-000000000001`
