# Experimental Channel Builds

Experimental ARM64 rootfs builds for the Motorola Moto G7 Play (`channel`).

## Workflows

The `main` branch provides the kernel build and rootfs workflow launchers.

The available distributions are Debian, Ubuntu, Alpine, Arch Linux ARM, Fedora, Gentoo, openSUSE, Void Linux, Chimera Linux and CRUX-ARM.

Choose a workflow under **Actions**. Each distribution uses its own branch and can reuse matching mainline kernel modules.

## Images

Each rootfs workflow publishes `<distribution>-channel-rootfs.ext4.zst`, a compressed raw ext4 filesystem, with build metadata.

Extract an image on the host, for example:

```sh
zstd -d -k crux-channel-rootfs.ext4.zst
```

Deployment follows the existing Channel boot setup. The kernel and boot image are built separately; these rootfs workflows do not install the image onto a device.

## Network

The USB gadget uses `172.16.42.1` for SSH.

Most distributions install NetworkManager. With working Wi-Fi, use `nmcli device wifi list` and `nmcli --ask device wifi connect "SSID" ifname wlan0`.

CRUX uses its own init scripts and does not include NetworkManager by default.

## Root filesystem

After boot, check `df -h /`. Confirm the mounted ext4 device using `findmnt -n -o SOURCE,FSTYPE /` before using `resize2fs` to grow the filesystem.

## Time

If the clock is incorrect, set the current UTC time manually:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```
