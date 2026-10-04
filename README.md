# Fedora for Motorola Moto G7 Play (channel)

Experimental ARM64 rootfs builder using the shared Channel mainline kernel checkpoint.

- Rootfs label: `fedora`
- Rootfs UUID: `89530000-6320-4000-8000-000000000001`
- Boot locator remains the Android `userdata` PARTUUID in `boot-channel.img`.
- If no reusable kernel artifact exists, this workflow builds the kernel temporarily and uploads only the rootfs.
