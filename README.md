# Experimental Channel Builds

Experimental ARM64 rootfs matrix for the Motorola Moto G7 Play (`channel`), based on the same kernel/boot architecture as `SaaSD3v/channel-rootfs-builder`.

## Shared boot/kernel model

- Kernel source: `SaaSD3v/linux`, branch `msm8953/latest`
- Architecture: `arm64`
- Boot image has **no initramfs**
- Android `userdata` is mounted directly using:
  `root=PARTUUID=76dbdefa-f243-cd22-5da5-9374e6ad318b rootfstype=ext4 rootwait rw`
- Every distro rootfs uses the fixed ext4 UUID:
  `89530000-6320-4000-8000-000000000001`
- Each distro has its own filesystem label.
- Rootfs workflows compile the latest kernel source by default, and upload **only** the rootfs.
- Reuse of an existing `channel-mainline-kernel-*` artifact is optional via `reuse_kernel` (unchecked by default); `kernel_run_id` requires reuse. When the requested cache is unavailable, the kernel is compiled temporarily.
- The selected kernel source revision is recorded and the reused commit is shown in the workflow logs.

## Manual workflows and SSH options

- For passwordless USB access, choose `Build <distro> rootfs (USB open root)`. This separate launcher has no SSH key/password fields; `reuse_kernel` is its only option.
- For generated key, supplied public key, password or secret-based login, use the regular `Build <distro> rootfs` launcher.
- In the regular SSH workflow, `ssh_public_key` is valid only for `public-key-input` modes; `kernel_run_id` is valid only when `reuse_kernel` is checked. Invalid combinations fail early.
- GitHub Actions does not dynamically hide `workflow_dispatch` inputs; the two-workflow approach avoids an irrelevant form for USB-only bring-up.
- The `main` branch exposes the UI launchers. Each workflow checks out its own distro branch for scripts and overlays.

## Branches

| Branch | Userspace / init | Status |
| --- | --- | --- |
| `debian` | Debian 13 / systemd | mirrored baseline |
| `ubuntu` | Ubuntu / systemd | mirrored baseline |
| `alpine` | Alpine / OpenRC | mirrored baseline |
| `fedora` | Fedora 44 / systemd | experimental |
| `arch` | Arch Linux ARM / systemd | experimental |
| `gentoo` | Gentoo ARM64 stage3 / systemd | experimental, long build |
| `opensuse` | openSUSE Tumbleweed / systemd | experimental |
| `void` | Void Linux AArch64 / runit | experimental |
| `chimera` | Chimera Linux AArch64 / dinit | experimental |
| `crux` | CRUX-ARM 3.8 / BSD-style rc | experimental |

Each distro branch is intentionally clean: its own workflow, README and distro directory only. The copies of distro workflows on `main` exist solely so GitHub exposes their manual **Run workflow** controls.

## CRUX note

The initial CRUX branch keeps the official CRUX-ARM base minimal and does not compile optional NetworkManager/dnsmasq ports. USB RNDIS still configures the device as `172.16.42.1/24`; configure the host statically (for example `172.16.42.2/24`) for the first bring-up.

## Flash model

Typical use remains:

```sh
fastboot flash boot boot-channel.img
fastboot flash userdata <distro>-channel-rootfs.ext4
```

The `userdata` GPT PARTUUID is not replaced by flashing the ext4 filesystem image.
