# Void Linux for Motorola Moto G7 Play (channel)

Experimental ARM64 rootfs branch.

- Rootfs label: `void`
- Fixed ext4 UUID: `89530000-6320-4000-8000-000000000001`
- Fresh mainline kernel by default; optional saved-kernel reuse and fallback.
- Boot remains direct to Android `userdata` by PARTUUID; no initramfs.

## GitHub Actions behavior

The `void` rootfs workflow builds the latest kernel from
`SaaSD3v/linux:msm8953/latest` by default. The `reuse_kernel` checkbox enables
reuse of a saved artifact; `kernel_run_id` is valid only with reuse selected.
The kernel commit used is recorded in the workflow log.

For direct root login over USB with no key/password fields, use the dedicated
`Build VOID rootfs (USB open root)` launcher on `main`.
The standard launcher handles authenticated SSH. GitHub's manual workflow
form cannot dynamically hide fields when its choices change.
