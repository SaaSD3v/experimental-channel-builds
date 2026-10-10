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

## Optional Android sparse tools

These builds output raw ext4. Sparse conversion is optional and does not replace the existing Channel boot process.

| Linux environment | Install sparse tools |
| --- | --- |
| Debian | `sudo apt install android-sdk-libsparse-utils` |
| Ubuntu | `sudo apt install android-sdk-libsparse-utils` |
| Alpine (community) | `apk add android-tools-img2simg android-tools-simg2img` |
| Arch Linux ARM | `sudo pacman -S android-tools` |
| Fedora | `sudo dnf install android-tools` |
| Gentoo | `emerge --ask dev-util/android-tools` |
| openSUSE | `sudo zypper install android-tools` |
| Void Linux | `sudo xbps-install -S android-tools` |
| Chimera Linux | `apk add android-tools` |
| CRUX (use a Debian/Ubuntu host) | `sudo apt install android-sdk-libsparse-utils` |

After decompressing the matching rootfs image:

```sh
img2simg crux-channel-rootfs.ext4 rootfs-sparse.img
simg2img rootfs-sparse.img rootfs-restored.ext4
```

`img2simg` converts raw to sparse; `simg2img` converts sparse back to raw. For CRUX, the installation command above is for a Debian/Ubuntu host, not for CRUX.

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
