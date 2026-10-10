# Ubuntu — Channel

Experimental Ubuntu ARM64 rootfs for the Motorola Moto G7 Play.

## Build

This branch uses `ubuntu/build.sh` and `.github/workflows/ubuntu.yml`.

The rootfs uses systemd and includes modules matching the Channel mainline kernel.

The artifact is `channel-ubuntu-rootfs`.

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

## Optional Android sparse tools

The image is raw ext4. Install these tools on a Ubuntu system only if sparse conversion is needed:

```sh
sudo apt install android-sdk-libsparse-utils
```

After decompressing `ubuntu-channel-rootfs.ext4.zst`:

```sh
img2simg ubuntu-channel-rootfs.ext4 rootfs-sparse.img
simg2img rootfs-sparse.img rootfs-restored.ext4
```

The first command makes an Android sparse image; the second restores raw ext4. Neither command flashes a device.

## Rootfs details

- Artifact: `channel-ubuntu-rootfs`
- Image: `ubuntu-channel-rootfs.ext4.zst`
- Format: ext4 (raw, zstd-compressed)
- Label: `ubuntu`
- UUID: `89530000-6320-4000-8000-000000000001`
