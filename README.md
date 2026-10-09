# Gentoo for Motorola Moto G7 Play (channel)

Experimental ARM64 rootfs builder using the shared Channel mainline kernel checkpoint.

- Rootfs label: `gentoo`
- Rootfs UUID: `89530000-6320-4000-8000-000000000001`
- Boot locator: existing Android `userdata` PARTUUID from `boot-channel.img`.
- Builds the latest kernel by default; may explicitly reuse a published artifact.

## GitHub Actions behavior

The `gentoo` rootfs workflow builds the latest kernel from
`SaaSD3v/linux:msm8953/latest` by default. The `reuse_kernel` checkbox enables
reuse of a saved artifact; `kernel_run_id` is valid only with reuse selected.
The kernel commit used is recorded in the workflow log.

For direct root login over USB with no key/password fields, use the dedicated
`Build GENTOO rootfs (USB open root)` launcher on `main`.
The standard launcher handles authenticated SSH. GitHub's manual workflow
form cannot dynamically hide fields when its choices change.
