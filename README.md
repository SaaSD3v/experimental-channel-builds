# Fedora for Motorola Moto G7 Play (channel)

Experimental ARM64 rootfs builder using the shared Channel mainline kernel build/reuse flow.

- Rootfs label: `fedora`
- Rootfs UUID: `89530000-6320-4000-8000-000000000001`
- Boot locator remains the Android `userdata` PARTUUID in `boot-channel.img`.
- Builds the current kernel by default; can explicitly reuse a previous artifact and fall back to compiling if unavailable.

## GitHub Actions behavior

By default, the `fedora` rootfs workflow builds the latest kernel from
`SaaSD3v/linux:msm8953/latest`. The `reuse_kernel` checkbox enables reuse
of an available kernel artifact; `kernel_run_id` is only valid when checked.
The selected kernel commit is recorded in build logs.

For direct root login on USB without SSH key/password fields, choose the
separate `Build FEDORA rootfs (USB open root)` launcher on `main`.
The regular launcher is for authenticated SSH, because GitHub's manual
workflow form cannot hide unused fields dynamically.
