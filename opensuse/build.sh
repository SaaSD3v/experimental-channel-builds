#!/usr/bin/env bash
set -euo pipefail

: "${KERNEL_RELEASE:?set KERNEL_RELEASE}"
: "${KERNEL_MODULES_ARCHIVE:?set KERNEL_MODULES_ARCHIVE}"
: "${KERNEL_CONFIG_FILE:?set KERNEL_CONFIG_FILE}"
: "${KERNEL_SYSTEM_MAP_FILE:?set KERNEL_SYSTEM_MAP_FILE}"
: "${OUT_DIR:?set OUT_DIR}"

DISTRO="${DISTRO:-opensuse}"
ROOTFS_LABEL="${ROOTFS_LABEL:-opensuse}"
CHANNEL_ROOT_UUID="${ROOTFS_UUID:-89530000-6320-4000-8000-000000000001}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.work}"
ROOTFS="$WORK_DIR/rootfs"
KREL="$KERNEL_RELEASE"

test -s "$KERNEL_MODULES_ARCHIVE"
test -s "$KERNEL_CONFIG_FILE"
test -s "$KERNEL_SYSTEM_MAP_FILE"
mkdir -p "$WORK_DIR" "$OUT_DIR"
sudo rm -rf "$ROOTFS"
sudo mkdir -p "$ROOTFS"

echo "::group::Bootstrap openSUSE Tumbleweed ARM64 rootfs"
docker pull --platform linux/arm64 opensuse/tumbleweed
CID="$(docker create --platform linux/arm64 opensuse/tumbleweed /bin/true)"
trap 'docker rm -f "$CID" >/dev/null 2>&1 || true' RETURN
docker export "$CID" | sudo tar -xpf - -C "$ROOTFS"
docker rm "$CID" >/dev/null
trap - RETURN
sudo install -m 0755 /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/qemu-aarch64-static"
sudo rm -f "$ROOTFS/etc/resolv.conf"; sudo cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
sudo chroot "$ROOTFS" /bin/bash -lc 'zypper --non-interactive refresh && zypper --non-interactive install systemd shadow openssh NetworkManager dnsmasq iproute2 iputils kmod e2fsprogs util-linux procps nano ethtool iw wpa_supplicant ca-certificates dbus-1 && zypper clean -a'
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"
echo "::endgroup::"

echo "::group::Install Channel configuration"
sudo cp -a "$REPO_ROOT/opensuse/rootfs/." "$ROOTFS/"
sudo chmod 0755 "$ROOTFS/usr/local/sbin/channel-usb-gadget" "$ROOTFS/usr/local/sbin/channel-wifi-firmware" "$ROOTFS/usr/local/sbin/channel-dhcp"
printf '%s\n' channel | sudo tee "$ROOTFS/etc/hostname" >/dev/null
sudo tee "$ROOTFS/etc/hosts" >/dev/null <<'HOSTS'
127.0.0.1 localhost
127.0.1.1 channel
::1 localhost ip6-localhost ip6-loopback
HOSTS
sudo tee "$ROOTFS/etc/fstab" >/dev/null <<FSTAB
UUID=$CHANNEL_ROOT_UUID / ext4 rw,noatime 0 1
FSTAB

SSH_AUTH_MODE="${SSH_AUTH_MODE:-generated-key}"
SSH_PUBLIC_KEY_INPUT="${SSH_PUBLIC_KEY_INPUT:-}"
SSH_PUBLIC_KEY="${SSH_PUBLIC_KEY:-}"
SSH_PASSWORD="${SSH_PASSWORD:-}"
rm -f "$OUT_DIR/channel_test_ed25519" "$OUT_DIR/channel_test_ed25519.pub" "$OUT_DIR/channel_ssh_password.txt"
sudo mkdir -p "$ROOTFS/root/.ssh"
sudo chmod 0700 "$ROOTFS/root/.ssh"
KEYFILE="$WORK_DIR/authorized_key"
rm -f "$KEYFILE"
ALLOW_KEY=0
ALLOW_PASSWORD=0
ALLOW_EMPTY_SSH=0
ROOT_PASSWORD=""

install_public_key() {
  printf '%s\n' "$1" | tr -d '\r' > "$KEYFILE"
  ssh-keygen -l -f "$KEYFILE" >/dev/null
  sudo install -m 0600 -o root -g root "$KEYFILE" "$ROOTFS/root/.ssh/authorized_keys"
  ALLOW_KEY=1
}
generate_public_key() {
  ssh-keygen -q -t ed25519 -N "" -C "channel-opensuse-ci" -f "$OUT_DIR/channel_test_ed25519"
  install_public_key "$(cat "$OUT_DIR/channel_test_ed25519.pub")"
}
generate_password() {
  ROOT_PASSWORD="$(openssl rand -hex 24)"
  printf '%s\n' "$ROOT_PASSWORD" > "$OUT_DIR/channel_ssh_password.txt"
  chmod 0600 "$OUT_DIR/channel_ssh_password.txt"
  ALLOW_PASSWORD=1
}
case "$SSH_AUTH_MODE" in
  auto|generated-key) generate_public_key; SSH_AUTH_MODE=generated-key ;;
  public-key-input) [ -n "$SSH_PUBLIC_KEY_INPUT" ] || exit 2; install_public_key "$SSH_PUBLIC_KEY_INPUT" ;;
  public-key-secret) [ -n "$SSH_PUBLIC_KEY" ] || exit 2; install_public_key "$SSH_PUBLIC_KEY" ;;
  generated-password) generate_password ;;
  password-secret) [ -n "$SSH_PASSWORD" ] || exit 2; ROOT_PASSWORD="$SSH_PASSWORD"; ALLOW_PASSWORD=1 ;;
  generated-key+generated-password) generate_public_key; generate_password ;;
  public-key-input+password-secret) [ -n "$SSH_PUBLIC_KEY_INPUT" ] && [ -n "$SSH_PASSWORD" ] || exit 2; install_public_key "$SSH_PUBLIC_KEY_INPUT"; ROOT_PASSWORD="$SSH_PASSWORD"; ALLOW_PASSWORD=1 ;;
  public-key-secret+password-secret) [ -n "$SSH_PUBLIC_KEY" ] && [ -n "$SSH_PASSWORD" ] || exit 2; install_public_key "$SSH_PUBLIC_KEY"; ROOT_PASSWORD="$SSH_PASSWORD"; ALLOW_PASSWORD=1 ;;
  open-root-usb) ALLOW_EMPTY_SSH=1 ;;
  *) echo "Unsupported SSH_AUTH_MODE: $SSH_AUTH_MODE" >&2; exit 2 ;;
esac

if [ "$ALLOW_PASSWORD" -eq 1 ]; then
  ROOT_HASH="$(openssl passwd -6 "$ROOT_PASSWORD")"
  sudo sed -i "s|^root:[^:]*:|root:${ROOT_HASH}:|" "$ROOTFS/etc/shadow"
  unset ROOT_HASH ROOT_PASSWORD
else
  RANDOM_PASSWORD="$(openssl rand -hex 48)"
  ROOT_HASH="$(openssl passwd -6 "$RANDOM_PASSWORD")"
  sudo sed -i "s|^root:[^:]*:|root:${ROOT_HASH}:|" "$ROOTFS/etc/shadow"
  unset RANDOM_PASSWORD ROOT_HASH
fi

if [ "$ALLOW_EMPTY_SSH" -eq 1 ]; then
  sudo mkdir -p "$ROOTFS/etc/pam.d"
  sudo tee "$ROOTFS/etc/pam.d/sshd" >/dev/null <<'PAM'
auth required pam_permit.so
account required pam_permit.so
session required pam_permit.so
PAM
  SSH_ROOT_LOGIN=yes; SSH_PUBKEY=no; SSH_PASSWORD_AUTH=yes; SSH_EMPTY_PASSWORDS=yes
elif [ "$ALLOW_PASSWORD" -eq 1 ]; then
  SSH_ROOT_LOGIN=yes; SSH_PUBKEY=$([ "$ALLOW_KEY" -eq 1 ] && echo yes || echo no); SSH_PASSWORD_AUTH=yes; SSH_EMPTY_PASSWORDS=no
else
  SSH_ROOT_LOGIN=prohibit-password; SSH_PUBKEY=yes; SSH_PASSWORD_AUTH=no; SSH_EMPTY_PASSWORDS=no
fi

sudo mkdir -p "$ROOTFS/etc/ssh/sshd_config.d"
sudo tee "$ROOTFS/etc/ssh/sshd_config.d/10-channel-usb.conf" >/dev/null <<EOF
ListenAddress 172.16.42.1
AllowUsers root
PermitRootLogin $SSH_ROOT_LOGIN
PubkeyAuthentication $SSH_PUBKEY
PasswordAuthentication $SSH_PASSWORD_AUTH
KbdInteractiveAuthentication no
PermitEmptyPasswords $SSH_EMPTY_PASSWORDS
UsePAM yes
UseDNS no
EOF
sudo ssh-keygen -A -f "$ROOTFS"

sudo systemctl --root="$ROOTFS" disable ssh.socket sshd.socket dnsmasq.service 2>/dev/null || true
sudo systemctl --root="$ROOTFS" enable channel-usb-gadget.service channel-dhcp.service channel-wifi-firmware.service NetworkManager.service
if [ -f "$ROOTFS/usr/lib/systemd/system/sshd.service" ] || [ -f "$ROOTFS/lib/systemd/system/sshd.service" ]; then
  sudo systemctl --root="$ROOTFS" enable sshd.service
  SSH_SERVICE=sshd.service
else
  sudo systemctl --root="$ROOTFS" enable ssh.service
  SSH_SERVICE=ssh.service
fi
echo "::endgroup::"

echo "::group::Install reusable mainline kernel modules"
sudo tar -I zstd -xf "$KERNEL_MODULES_ARCHIVE" -C "$ROOTFS"
test -d "$ROOTFS/lib/modules/$KREL" || test -d "$ROOTFS/usr/lib/modules/$KREL"
sudo depmod -b "$ROOTFS" "$KREL"
sudo mkdir -p "$ROOTFS/boot"
sudo cp "$KERNEL_CONFIG_FILE" "$ROOTFS/boot/config-$KREL"
sudo cp "$KERNEL_SYSTEM_MAP_FILE" "$ROOTFS/boot/System.map-$KREL"
echo "::endgroup::"

echo "::group::Validate openSUSE Tumbleweed rootfs"
sudo update-binfmts --enable qemu-aarch64 || true
if [ -x /usr/bin/qemu-aarch64-static ]; then sudo install -m 0755 /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/qemu-aarch64-static"; fi
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
cleanup_mounts
trap - EXIT
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"
echo "::endgroup::"

echo "::group::Create openSUSE Tumbleweed ext4 image"
USED_MB="$(sudo du -sm "$ROOTFS" | awk '{print $1}')"
IMAGE_MB=$((USED_MB + 700)); if [ "$IMAGE_MB" -lt 1536 ]; then IMAGE_MB=1536; fi
ROOTFS_IMG="$OUT_DIR/opensuse-channel-rootfs.ext4"
truncate -s "${IMAGE_MB}M" "$ROOTFS_IMG"
sudo mkfs.ext4 -F -m 0 -L "$ROOTFS_LABEL" -U "$CHANNEL_ROOT_UUID" -d "$ROOTFS" "$ROOTFS_IMG"
sudo e2fsck -fn "$ROOTFS_IMG"
test "$(blkid -p -o value -s UUID "$ROOTFS_IMG")" = "$CHANNEL_ROOT_UUID"
test "$(blkid -p -o value -s LABEL "$ROOTFS_IMG")" = "$ROOTFS_LABEL"
zstd -T0 -10 -f "$ROOTFS_IMG" -o "$ROOTFS_IMG.zst"
rm -f "$ROOTFS_IMG"
echo "::endgroup::"

{
  echo "distro=$DISTRO"
  echo "release=tumbleweed"
  echo "architecture=arm64"
  echo "kernel_release=$KREL"
  echo "rootfs_label=$ROOTFS_LABEL"
  echo "rootfs_uuid=$CHANNEL_ROOT_UUID"
  echo "usb_device_ip=172.16.42.1"
  echo "usb_dhcp_range=172.16.42.2-172.16.42.20"
  echo "ssh_auth=$SSH_AUTH_MODE"
  echo "ssh_listen=172.16.42.1"
  echo "ssh_scope=usb-only"
  echo "network_manager=NetworkManager"
  echo "wifi_firmware=stock-modem-vendor-readonly"
} > "$OUT_DIR/build-info.txt"
(cd "$OUT_DIR" && sha256sum opensuse-channel-rootfs.ext4.zst build-info.txt > SHA256SUMS.opensuse)
