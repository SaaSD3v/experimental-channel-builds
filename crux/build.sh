#!/usr/bin/env bash
set -euo pipefail
: "${KERNEL_RELEASE:?set KERNEL_RELEASE}"
: "${KERNEL_MODULES_ARCHIVE:?set KERNEL_MODULES_ARCHIVE}"
: "${KERNEL_CONFIG_FILE:?set KERNEL_CONFIG_FILE}"
: "${KERNEL_SYSTEM_MAP_FILE:?set KERNEL_SYSTEM_MAP_FILE}"
: "${OUT_DIR:?set OUT_DIR}"
DISTRO="${DISTRO:-crux}"
ROOTFS_LABEL="${ROOTFS_LABEL:-crux}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.work}"
ROOTFS="$WORK_DIR/rootfs"
KREL="$KERNEL_RELEASE"
test -s "$KERNEL_MODULES_ARCHIVE"; test -s "$KERNEL_CONFIG_FILE"; test -s "$KERNEL_SYSTEM_MAP_FILE"
mkdir -p "$WORK_DIR" "$OUT_DIR"; sudo rm -rf "$ROOTFS"; sudo mkdir -p "$ROOTFS"

echo "::group::Bootstrap CRUX ARM64 rootfs"
URL="https://git.crux.nu/system/crux-rootfs/releases/download/3.8/crux-3.8-arm64.rootfs.tar.xz"
curl -fL --retry 3 "$URL" -o "$WORK_DIR/crux-3.8-arm64.rootfs.tar.xz"
sudo tar -xpf "$WORK_DIR/crux-3.8-arm64.rootfs.tar.xz" -C "$ROOTFS"
test -x "$ROOTFS/usr/sbin/sshd" || test -x "$ROOTFS/usr/bin/sshd"
test -f "$ROOTFS/etc/rc.conf"
echo "::endgroup::"

sudo cp -a "$REPO_ROOT/crux/rootfs/." "$ROOTFS/"
sudo chmod 0755 "$ROOTFS/usr/local/sbin/"channel-*
printf '%s\n' channel | sudo tee "$ROOTFS/etc/hostname" >/dev/null
sudo tee "$ROOTFS/etc/hosts" >/dev/null <<'HOSTS'
127.0.0.1 localhost
127.0.1.1 channel
::1 localhost ip6-localhost ip6-loopback
HOSTS
sudo tee "$ROOTFS/etc/fstab" >/dev/null <<FSTAB
PARTLABEL=userdata / ext4 rw,noatime 0 1
FSTAB

# USB RNDIS is the only SSH management endpoint.
RANDOM_PASSWORD="$(openssl rand -hex 48)"
ROOT_HASH="$(openssl passwd -6 "$RANDOM_PASSWORD")"
sudo sed -i "s|^root:[^:]*:|root:${ROOT_HASH}:|" "$ROOTFS/etc/shadow"
unset RANDOM_PASSWORD ROOT_HASH
sudo mkdir -p "$ROOTFS/etc/pam.d" "$ROOTFS/etc/ssh/sshd_config.d"
sudo tee "$ROOTFS/etc/pam.d/sshd" >/dev/null <<'PAM'
auth required pam_permit.so
account required pam_permit.so
session required pam_permit.so
PAM
sudo tee "$ROOTFS/etc/ssh/sshd_config.d/10-channel-usb.conf" >/dev/null <<'SSH'
ListenAddress 172.16.42.1
AllowUsers root
PermitRootLogin yes
PubkeyAuthentication no
PasswordAuthentication yes
KbdInteractiveAuthentication no
PermitEmptyPasswords yes
UsePAM yes
UseDNS no
SSH
if ! sudo head -n 1 "$ROOTFS/etc/ssh/sshd_config" | grep -Fqx 'Include /etc/ssh/sshd_config.d/*.conf'; then
  sudo sed -i '1iInclude /etc/ssh/sshd_config.d/*.conf' "$ROOTFS/etc/ssh/sshd_config"
fi
sudo ssh-keygen -A -f "$ROOTFS"

echo "::group::Configure CRUX services"
sudo mkdir -p "$ROOTFS/etc/rc.d"
sudo tee "$ROOTFS/etc/rc.d/channel-usb" >/dev/null <<'EOF'
#!/bin/sh
case "$1" in
  start) /usr/local/sbin/channel-usb-gadget ;;
  stop) : ;;
  restart) "$0" stop; "$0" start ;;
  *) echo "usage: $0 {start|stop|restart}" >&2; exit 1 ;;
esac
EOF
sudo tee "$ROOTFS/etc/rc.d/channel-wifi" >/dev/null <<'EOF'
#!/bin/sh
case "$1" in
  start) /usr/local/sbin/channel-wifi-firmware ;;
  stop) : ;;
  restart) "$0" stop; "$0" start ;;
  *) echo "usage: $0 {start|stop|restart}" >&2; exit 1 ;;
esac
EOF
sudo chmod 0755 "$ROOTFS/etc/rc.d/channel-usb" "$ROOTFS/etc/rc.d/channel-wifi"
if grep -q '^SERVICES=(' "$ROOTFS/etc/rc.conf"; then
  sudo sed -i '/^SERVICES=(/ s/)/ channel-usb sshd dnsmasq channel-wifi)/' "$ROOTFS/etc/rc.conf"
else
  echo 'SERVICES=(channel-usb sshd dnsmasq channel-wifi)' | sudo tee -a "$ROOTFS/etc/rc.conf" >/dev/null
fi
echo "::endgroup::"

sudo tar -I zstd -xf "$KERNEL_MODULES_ARCHIVE" -C "$ROOTFS"
test -d "$ROOTFS/lib/modules/$KREL" || test -d "$ROOTFS/usr/lib/modules/$KREL"
sudo depmod -b "$ROOTFS" "$KREL"
sudo mkdir -p "$ROOTFS/boot"; sudo cp "$KERNEL_CONFIG_FILE" "$ROOTFS/boot/config-$KREL"; sudo cp "$KERNEL_SYSTEM_MAP_FILE" "$ROOTFS/boot/System.map-$KREL"

# CRUX's rootfs tarball does not include /dev/null. OpenSSH needs it
# when validating sshd inside the ARM64 chroot, even though devtmpfs
# will later provide /dev on the running device.
sudo install -d -m 0755 "$ROOTFS/dev"
if [ ! -c "$ROOTFS/dev/null" ] || [ -L "$ROOTFS/dev/null" ]; then
  sudo rm -f "$ROOTFS/dev/null"
  sudo mknod -m 0666 "$ROOTFS/dev/null" c 1 3
fi
sudo test -c "$ROOTFS/dev/null"

# Cross-build dnsmasq for CRUX ARM64 on the x86 runner. The stock CRUX port
# enables DNSSEC and pulls in nettle; DHCP-only doesn't need those libraries.
# Native ARM64 port compilation under qemu-user exhausted memory in CI.
echo "::group::Build CRUX ARM64 USB DHCP package"
DNSMASQ_VERSION=2.93
DNSMASQ_TARBALL="$WORK_DIR/dnsmasq-$DNSMASQ_VERSION.tar.xz"
DNSMASQ_SRC="$WORK_DIR/dnsmasq-$DNSMASQ_VERSION"
DNSMASQ_PKG_DIR="$WORK_DIR/dnsmasq-package"
DNSMASQ_PKG="dnsmasq#${DNSMASQ_VERSION}-1.pkg.tar.gz"
curl -fsSL --retry 3 "https://dnsmasq.org/dnsmasq-$DNSMASQ_VERSION.tar.xz" -o "$DNSMASQ_TARBALL"
echo "0c00d4e5c97c8306e5fb932b348b34269c9c29a0e7df0e8e82958b407092bc19  $DNSMASQ_TARBALL" | sha256sum -c -
tar -xJf "$DNSMASQ_TARBALL" -C "$WORK_DIR"
make -C "$DNSMASQ_SRC" -j2 CC=aarch64-linux-gnu-gcc COPTS='-DNO_TFTP'
sudo rm -rf "$DNSMASQ_PKG_DIR"
mkdir -p "$DNSMASQ_PKG_DIR/usr/sbin" "$DNSMASQ_PKG_DIR/etc/rc.d" "$DNSMASQ_PKG_DIR/etc"
install -m 0755 "$DNSMASQ_SRC/src/dnsmasq" "$DNSMASQ_PKG_DIR/usr/sbin/dnsmasq"
test "$(aarch64-linux-gnu-readelf -h "$DNSMASQ_PKG_DIR/usr/sbin/dnsmasq" | awk '/Machine:/{print $2}')" = AArch64
if aarch64-linux-gnu-readelf -d "$DNSMASQ_PKG_DIR/usr/sbin/dnsmasq" | grep -E 'NEEDED.*(nettle|hogweed|gmp)'; then
  echo "DHCP build unexpectedly links external DNSSEC libraries" >&2
  exit 1
fi

# Use the CRUX BSD-style start-stop-daemon convention.
cat > "$DNSMASQ_PKG_DIR/etc/rc.d/dnsmasq" <<'SERVICE'
#!/bin/sh
SSD=/sbin/start-stop-daemon
PROG=/usr/sbin/dnsmasq
PID=/run/dnsmasq.pid
case "$1" in
  start) "$SSD" --start --pidfile "$PID" --exec "$PROG" ;;
  stop) "$SSD" --stop --remove-pidfile --retry 10 --pidfile "$PID" --name dnsmasq ;;
  restart) "$0" stop && "$0" start ;;
  *) echo "usage: $0 {start|stop|restart}" >&2; exit 1 ;;
esac
SERVICE
chmod 0755 "$DNSMASQ_PKG_DIR/etc/rc.d/dnsmasq"

# DHCP serves only the RNDIS management interface. Empty options 3 and 6
# prevent Windows from treating this USB link as its default route or DNS.
cat > "$DNSMASQ_PKG_DIR/etc/dnsmasq.conf" <<'DNSMASQ'
port=0
interface=usb0
bind-dynamic
dhcp-range=172.16.42.2,172.16.42.20,255.255.255.0,12h
dhcp-authoritative
dhcp-option=3
dhcp-option=6
DNSMASQ
(
  cd "$DNSMASQ_PKG_DIR"
  tar -czf "$WORK_DIR/$DNSMASQ_PKG" etc usr
)
sudo install -m 0644 "$WORK_DIR/$DNSMASQ_PKG" "$ROOTFS/tmp/$DNSMASQ_PKG"

# Let CRUX pkgadd record the native ARM64 binary and rc files in its own
# package database. No port sources or host build dependencies reach the image.
# The CRUX rootfs has no /dev/urandom before boot. dnsmasq --test needs
# it inside the chroot. Bind host /dev only for validation; unmount before
# packing the final filesystem so no host device nodes are shipped.
cleanup_crux_dev() {
  sudo umount "$ROOTFS/dev" 2>/dev/null || true
}
trap cleanup_crux_dev EXIT
sudo mount --bind /dev "$ROOTFS/dev"
sudo test -c "$ROOTFS/dev/urandom"
sudo update-binfmts --enable qemu-aarch64 || true
sudo install -m 0755 /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/qemu-aarch64-static"
sudo chroot "$ROOTFS" /bin/sh -ec '
  test -c /dev/urandom
  pkgadd "/tmp/'"$DNSMASQ_PKG"'"
  test -x /usr/sbin/dnsmasq
  test -x /etc/rc.d/dnsmasq
  /usr/sbin/dnsmasq --test
  mkdir -p /run/sshd
  sshd -t
'

# Check what sshd will actually use, not only whether the file parses.
SSHD_EFFECTIVE="$(sudo chroot "$ROOTFS" /usr/sbin/sshd -T -C user=root,host=channel,addr=172.16.42.2,laddr=172.16.42.1,lport=22)"
grep -Fqx "permitrootlogin yes" <<< "$SSHD_EFFECTIVE"
grep -Fqx "pubkeyauthentication no" <<< "$SSHD_EFFECTIVE"
grep -Fqx "passwordauthentication yes" <<< "$SSHD_EFFECTIVE"
grep -Fqx "permitemptypasswords yes" <<< "$SSHD_EFFECTIVE"
grep -Fqx "usepam yes" <<< "$SSHD_EFFECTIVE"
grep -Eq '^listenaddress 172[.]16[.]42[.]1(:22)?$' <<< "$SSHD_EFFECTIVE"
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static" "$ROOTFS/tmp/$DNSMASQ_PKG"
# Success path must fail the build if the host /dev cannot be detached.
# Otherwise mkfs.ext4 -d could include the host's device tree by accident.
sudo umount "$ROOTFS/dev"
trap - EXIT
test -c "$ROOTFS/dev/null"
if mountpoint -q "$ROOTFS/dev"; then
  echo "CRUX /dev is still bind-mounted; refusing to create the ext4 image" >&2
  exit 1
fi
echo "::endgroup::"

USED_MB="$(sudo du -sm "$ROOTFS" | awk '{print $1}')"; IMAGE_MB=$((USED_MB + 200)); [ "$IMAGE_MB" -ge 1536 ] || IMAGE_MB=1536
ROOTFS_IMG="$OUT_DIR/crux-channel-rootfs.ext4"
truncate -s "${IMAGE_MB}M" "$ROOTFS_IMG"
sudo mkfs.ext4 -F -m 0 -L "$ROOTFS_LABEL" -U random -d "$ROOTFS" "$ROOTFS_IMG"
ROOTFS_EXT4_UUID="$(blkid -p -o value -s UUID "$ROOTFS_IMG")"
test -n "$ROOTFS_EXT4_UUID"
sudo e2fsck -fn "$ROOTFS_IMG"
zstd -T0 -10 -f "$ROOTFS_IMG" -o "$ROOTFS_IMG.zst"; rm -f "$ROOTFS_IMG"
{
 echo "distro=$DISTRO"; echo "release=3.8-arm64"; echo "architecture=arm64"; echo "kernel_release=$KREL"; echo "rootfs_label=$ROOTFS_LABEL"; echo "rootfs_uuid=$ROOTFS_EXT4_UUID";
 echo "usb_device_ip=172.16.42.1"; echo "ssh_auth=ssh"; echo "ssh_listen=172.16.42.1"; echo "network_manager=none"; echo "usb_dhcp=dnsmasq"; echo "usb_dhcp_range=172.16.42.2-172.16.42.20"; echo "wifi_firmware=stock-modem-vendor-readonly";
} > "$OUT_DIR/build-info.txt"
(cd "$OUT_DIR" && sha256sum crux-channel-rootfs.ext4.zst build-info.txt > SHA256SUMS.crux)
