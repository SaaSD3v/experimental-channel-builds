# CRUX-ARM for Motorola Moto G7 Play (channel)

Experimental CRUX-ARM 3.8 AArch64 rootfs builder.

- Official CRUX-ARM 3.8 AArch64 rootfs bootstrap.
- BSD-style init via `/etc/rc.d` and `SERVICES=(...)`.
- USB RNDIS device address remains `172.16.42.1/24`.
- This first CRUX branch does not build the optional NetworkManager/dnsmasq ports; configure the USB host with a static address such as `172.16.42.2/24`.
- Fixed ext4 UUID: `89530000-6320-4000-8000-000000000001`.
- Builds the latest Channel mainline kernel by default, optionally reuses artifacts, and uses no initramfs.

## GitHub Actions behavior

The `crux` rootfs workflow builds the latest kernel from
`SaaSD3v/linux:msm8953/latest` by default. The `reuse_kernel` checkbox enables
reuse of a saved artifact; `kernel_run_id` is valid only with reuse selected.
The kernel commit used is recorded in the workflow log.

For direct root login over USB with no key/password fields, use the dedicated
`Build CRUX rootfs (USB open root)` launcher on `main`.
The standard launcher handles authenticated SSH. GitHub's manual workflow
form cannot dynamically hide fields when its choices change.
