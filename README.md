# Experimental Channel Builds

Experimental ARM64 rootfs builds for the Motorola Moto G7 Play (`channel`).

## Workflows

The `main` branch provides the kernel build and rootfs workflow launchers.

The available distributions are Debian, Ubuntu, Alpine, Arch Linux ARM, Fedora, Gentoo, openSUSE, Void Linux, Chimera Linux and CRUX-ARM.

Choose a workflow under **Actions**. Each distribution uses its own branch and can reuse matching mainline kernel modules.

## Network

The USB gadget uses `172.16.42.1` for SSH.

Most distributions install NetworkManager. With working Wi-Fi, use `nmcli device wifi list` and `nmcli --ask device wifi connect "SSID" ifname wlan0`.

CRUX uses its own init scripts and does not include NetworkManager by default.

## Time

If the clock is incorrect, set the current UTC time manually:

```sh
date -u -s "YYYY-MM-DD HH:MM:SS"
date
```

## Rootfs details

| Distribution | Artifact | Image | Label |
| --- | --- | --- | --- |
| debian | `channel-debian-rootfs` | `debian-channel-rootfs.ext4.zst` | `debian` |
| ubuntu | `channel-ubuntu-rootfs` | `ubuntu-channel-rootfs.ext4.zst` | `ubuntu` |
| alpine | `channel-alpine-rootfs` | `alpine-channel-rootfs.ext4.zst` | `alpine` |
| arch | `channel-arch-rootfs` | `arch-channel-rootfs.ext4.zst` | `arch` |
| fedora | `channel-fedora-rootfs` | `fedora-channel-rootfs.ext4.zst` | `fedora` |
| gentoo | `channel-gentoo-rootfs` | `gentoo-channel-rootfs.ext4.zst` | `gentoo` |
| opensuse | `channel-opensuse-rootfs` | `opensuse-channel-rootfs.ext4.zst` | `opensuse` |
| void | `channel-void-rootfs` | `void-channel-rootfs.ext4.zst` | `void` |
| chimera | `channel-chimera-rootfs` | `chimera-channel-rootfs.ext4.zst` | `chimera` |
| crux | `channel-crux-rootfs` | `crux-channel-rootfs.ext4.zst` | `crux` |

- Format: ext4 (raw, zstd-compressed)
- Ext4 UUID: `89530000-6320-4000-8000-000000000001`
