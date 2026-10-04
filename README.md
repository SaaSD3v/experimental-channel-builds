# CRUX-ARM for Motorola Moto G7 Play (channel)

Experimental CRUX-ARM 3.8 AArch64 rootfs builder.

- Official CRUX-ARM 3.8 AArch64 rootfs bootstrap.
- BSD-style init via `/etc/rc.d` and `SERVICES=(...)`.
- USB RNDIS device address remains `172.16.42.1/24`.
- This first CRUX branch does not build the optional NetworkManager/dnsmasq ports; configure the USB host with a static address such as `172.16.42.2/24`.
- Fixed ext4 UUID: `89530000-6320-4000-8000-000000000001`.
- Uses the same reusable Channel mainline kernel/fallback model and no initramfs.
