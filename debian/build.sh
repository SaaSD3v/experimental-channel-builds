#!/usr/bin/env bash
set -euo pipefail

: "${KERNEL_RELEASE:?set KERNEL_RELEASE}"
: "${KERNEL_MODULES_ARCHIVE:?set KERNEL_MODULES_ARCHIVE}"
: "${KERNEL_CONFIG_FILE:?set KERNEL_CONFIG_FILE}"
: "${KERNEL_SYSTEM_MAP_FILE:?set KERNEL_SYSTEM_MAP_FILE}"
: "${OUT_DIR:?set OUT_DIR}"

DISTRO="${DISTRO:-debian}"
ROOTFS_LABEL="${ROOTFS_LABEL:-debian}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.work}"
ROOTFS="$WORK_DIR/rootfs"
KREL="$KERNEL_RELEASE"

test -s "$KERNEL_MODULES_ARCHIVE"
test -s "$KERNEL_CONFIG_FILE"
test -s "$KERNEL_SYSTEM_MAP_FILE"

mkdir -p "$WORK_DIR" "$OUT_DIR"
sudo rm -rf "$ROOTFS"

echo "::group::Create Debian 13 (trixie) arm64 rootfs"
sudo mmdebstrap \
  --architectures=arm64 \
  --variant=minbase \
  --components=main \
  --keyring=/usr/share/keyrings/debian-archive-keyring.gpg \
  --aptopt='Apt::Install-Recommends "false"' \
  --include=debian-archive-keyring,systemd-sysv,openssh-server,iproute2,iputils-ping,dnsmasq,ca-certificates,kmod,udev,busybox-static,e2fsprogs,util-linux,procps,less,nano,ethtool,openssh-client,iw,wpasupplicant,wireless-regdb,dbus,network-manager \
  trixie "$ROOTFS" https://deb.debian.org/debian
echo "::endgroup::"

echo "::group::Install Channel Debian configuration"
sudo cp -a "$REPO_ROOT/debian/rootfs/." "$ROOTFS/"
sudo chmod 0755 "$ROOTFS/usr/local/sbin/channel-usb-gadget"
sudo chmod 0755 "$ROOTFS/usr/local/sbin/channel-wifi-firmware"

printf '%s\n' channel | sudo tee "$ROOTFS/etc/hostname" >/dev/null
sudo tee "$ROOTFS/etc/hosts" >/dev/null <<'HOSTS'
127.0.0.1 localhost
127.0.1.1 channel
::1 localhost ip6-localhost ip6-loopback
HOSTS

sudo tee "$ROOTFS/etc/fstab" >/dev/null <<FSTAB
PARTLABEL=userdata / ext4 rw,noatime 0 1
FSTAB

# Keep local root authentication protected; SSH access is USB-only.
RANDOM_PASSWORD="$(openssl rand -hex 48)"
ROOT_HASH="$(openssl passwd -6 "$RANDOM_PASSWORD")"
sudo sed -i "s|^root:[^:]*:|root:${ROOT_HASH}:|" "$ROOTFS/etc/shadow"
unset RANDOM_PASSWORD ROOT_HASH
sudo tee "$ROOTFS/etc/pam.d/sshd" >/dev/null <<'PAM'
auth required pam_permit.so
account required pam_permit.so
session required pam_permit.so
PAM
sudo mkdir -p "$ROOTFS/etc/ssh/sshd_config.d"
sudo tee "$ROOTFS/etc/ssh/sshd_config.d/10-channel-usb.conf" >/dev/null <<'SSH'
# Fixed root SSH on the USB RNDIS management address.
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
if ! sudo grep -Fq 'Include /etc/ssh/sshd_config.d/*.conf' "$ROOTFS/etc/ssh/sshd_config"; then
  sudo sed -i '1iInclude /etc/ssh/sshd_config.d/*.conf' "$ROOTFS/etc/ssh/sshd_config"
fi

sudo ssh-keygen -A -f "$ROOTFS"

sudo systemctl --root="$ROOTFS" disable ssh.socket 2>/dev/null || true
sudo systemctl --root="$ROOTFS" disable dnsmasq.service 2>/dev/null || true
sudo systemctl --root="$ROOTFS" enable \
  channel-usb-gadget.service channel-dhcp.service \
  channel-wifi-firmware.service NetworkManager.service dbus.socket
sudo systemctl --root="$ROOTFS" enable ssh.service

sudo mkdir -p "$ROOTFS/var/log/journal"
echo "::endgroup::"

echo "::group::Install reusable mainline kernel modules"
sudo tar -I zstd -xf "$KERNEL_MODULES_ARCHIVE" -C "$ROOTFS"
test -d "$ROOTFS/lib/modules/$KREL"
sudo depmod -b "$ROOTFS" "$KREL"
sudo mkdir -p "$ROOTFS/boot"
sudo cp "$KERNEL_CONFIG_FILE" "$ROOTFS/boot/config-$KREL"
sudo cp "$KERNEL_SYSTEM_MAP_FILE" "$ROOTFS/boot/System.map-$KREL"
echo "::endgroup::"

echo "::group::Validate Debian rootfs"
sudo update-binfmts --enable qemu-aarch64 || true
if [ -x /usr/bin/qemu-aarch64-static ]; then
  sudo install -m 0755 /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/qemu-aarch64-static"
fi

cleanup_mounts() {
  sudo umount -R "$ROOTFS/dev" 2>/dev/null || true
  sudo umount "$ROOTFS/proc" 2>/dev/null || true
  sudo umount "$ROOTFS/sys" 2>/dev/null || true
}
trap cleanup_mounts EXIT

sudo mount --bind /dev "$ROOTFS/dev"
sudo mount -t proc proc "$ROOTFS/proc"
sudo mount -t sysfs sysfs "$ROOTFS/sys"
sudo install -d -m 0755 "$ROOTFS/run/sshd"
sudo chroot "$ROOTFS" /usr/sbin/sshd -t

test -L "$ROOTFS/etc/systemd/system/multi-user.target.wants/NetworkManager.service" || \
  test -L "$ROOTFS/etc/systemd/system/network-online.target.wants/NetworkManager-wait-online.service"
test -L "$ROOTFS/etc/systemd/system/multi-user.target.wants/ssh.service"

cleanup_mounts
trap - EXIT
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"
echo "::endgroup::"

echo "::group::Create Debian ext4 image"
USED_MB="$(sudo du -sm "$ROOTFS" | awk '{print $1}')"
IMAGE_MB=$((USED_MB + 700))
if [ "$IMAGE_MB" -lt 1536 ]; then IMAGE_MB=1536; fi

ROOTFS_IMG="$OUT_DIR/debian-channel-rootfs.ext4"
truncate -s "${IMAGE_MB}M" "$ROOTFS_IMG"
sudo mkfs.ext4 -F -m 0 -L "$ROOTFS_LABEL" -U random -d "$ROOTFS" "$ROOTFS_IMG"
ROOTFS_EXT4_UUID="$(blkid -p -o value -s UUID "$ROOTFS_IMG")"
test -n "$ROOTFS_EXT4_UUID"
sudo e2fsck -fn "$ROOTFS_IMG"
test "$(blkid -p -o value -s LABEL "$ROOTFS_IMG")" = "$ROOTFS_LABEL"
zstd -T0 -10 -f "$ROOTFS_IMG" -o "$ROOTFS_IMG.zst"
rm -f "$ROOTFS_IMG"
echo "::endgroup::"

{
  echo "distro=$DISTRO"
  echo "debian_suite=trixie"
  echo "architecture=arm64"
  echo "kernel_release=$KREL"
  echo "rootfs_label=$ROOTFS_LABEL"
  echo "rootfs_uuid=$ROOTFS_EXT4_UUID"
  echo "usb_device_ip=172.16.42.1"
  echo "usb_dhcp_range=172.16.42.2-172.16.42.20"
  echo "ssh_auth=ssh"
  echo "ssh_listen=172.16.42.1"
  echo "ssh_scope=usb-only"
  echo "network_manager=NetworkManager"
  echo "usb_network_manager=unmanaged"
  echo "wifi_runtime_setup=nmcli"
  echo "wifi_firmware=stock-modem-vendor-readonly"
} > "$OUT_DIR/build-info.txt"

(
  cd "$OUT_DIR"
  sha256sum debian-channel-rootfs.ext4.zst build-info.txt > SHA256SUMS.debian
)
