# Channel RootFS Builder

Reusable mainline kernel and rootfs builders for the Motorola Moto G7 Play (channel).

- Kernel source: `SaaSD3v/linux`, branch `msm8953/latest`
- Kernel architecture: `arm64`
- Fixed root filesystem UUID: `89530000-6320-4000-8000-000000000001`
- Rootfs labels are distro-specific (for example `debian`).

## GitHub Actions behavior

By default, the `debian` rootfs workflow builds the latest kernel from
`SaaSD3v/linux:msm8953/latest`. The `reuse_kernel` checkbox enables reuse
of an available kernel artifact; `kernel_run_id` is only valid when checked.
The selected kernel commit is recorded in build logs.

For direct root login on USB without SSH key/password fields, choose the
separate `Build DEBIAN rootfs (USB open root)` launcher on `main`.
The regular launcher is for authenticated SSH, because GitHub's manual
workflow form cannot hide unused fields dynamically.
