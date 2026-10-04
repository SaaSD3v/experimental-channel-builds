# Gentoo for Motorola Moto G7 Play (channel)

Experimental ARM64 rootfs builder using the shared Channel mainline kernel checkpoint.

- Rootfs label: `gentoo`
- Rootfs UUID: `89530000-6320-4000-8000-000000000001`
- Boot locator: existing Android `userdata` PARTUUID from `boot-channel.img`.
- Reuses a live kernel artifact when possible; otherwise builds the kernel only for this run.
