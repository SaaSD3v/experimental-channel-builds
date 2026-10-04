# Channel RootFS Builder

Reusable mainline kernel and rootfs builders for the Motorola Moto G7 Play (channel).

- Kernel source: `SaaSD3v/linux`, branch `msm8953/latest`
- Kernel architecture: `arm64`
- Root partition: Android `userdata`
- Root partition PARTUUID used by `boot-channel.img`: `76dbdefa-f243-cd22-5da5-9374e6ad318b`
- Fixed ext4 filesystem UUID used by distro images: `89530000-6320-4000-8000-000000000001`
- Rootfs labels are distro-specific: `debian`, `ubuntu`, `alpine`.

## Boot model

`boot-channel.img` contains the kernel plus the Channel DTB and has no initramfs.
The kernel mounts the existing Android `userdata` partition directly using:

`root=PARTUUID=76dbdefa-f243-cd22-5da5-9374e6ad318b rootfstype=ext4 rootwait rw`

Flashing a distro with `fastboot flash userdata <rootfs.ext4>` replaces the filesystem
inside `userdata` but does not recreate the GPT entry, so the partition PARTUUID stays
the boot locator. The ext4 UUID and distro label belong to the filesystem itself and are
kept separate from the GPT PARTUUID.

## Kernel reuse and rootfs fallback

`build-mainline.yml` is the only workflow that publishes the reusable kernel checkpoint.
Debian, Ubuntu, and Alpine first look for a successful `build-mainline.yml` run with a
live `channel-mainline-kernel-*` artifact. If none exists, the selected rootfs workflow
builds `SaaSD3v/linux:msm8953/latest` locally with the same `mainline/build.sh` and
configuration, uses those modules/config/System.map for that rootfs, and does not upload
the temporary kernel.

The distro workflow files are mirrored on the default branch only so GitHub exposes their
manual **Run workflow** controls. Their SSH inputs belong to the rootfs workflows; the
`Build mainline kernel` workflow itself has no SSH inputs and builds no userspace.
