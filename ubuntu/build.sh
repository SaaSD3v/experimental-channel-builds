#!/usr/bin/env bash
set -euo pipefail

: "${KERNEL_RELEASE:?set KERNEL_RELEASE}"
: "${OUT_DIR:?set OUT_DIR}"

DISTRO="${DISTRO:-ubuntu}"
ROOTFS_LABEL="${ROOTFS_LABEL:-ubuntu}"
CHANNEL_ROOT_UUID="${ROOTFS_UUID:-89530000-6320-4000-8000-000000000001}"

: "${KERNEL_MODULES_ARCHIVE:?set KERNEL_MODULES_ARCHIVE}"
: "${KERNEL_CONFIG_FILE:?set KERNEL_CONFIG_FILE}"
: "${KERNEL_SYSTEM_MAP_FILE:?set KERNEL_SYSTEM_MAP_FILE}"
UBUNTU_VERSION="${UBUNTU_VERSION:-26.04.1}"
UBUNTU_CODENAME="${UBUNTU_CODENAME:-resolute}"
UBUNTU_ARCH="${UBUNTU_ARCH:-arm64}"
UBUNTU_BASE_URL="${UBUNTU_BASE_URL:-https://cdimage.ubuntu.com/ubuntu-base/releases/26.04/release}"
UBUNTU_BASE_TARBALL="ubuntu-base-${UBUNTU_VERSION}-base-${UBUNTU_ARCH}.tar.gz"
UBUNTU_BASE_SHA256="${UBUNTU_BASE_SHA256:-5a1906794ced63a71a8119c3f211ef5f0bbe0a243001b4bbd41fdf80c5b219fd}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.work}"
ROOTFS="$WORK_DIR/rootfs"
KREL="$KERNEL_RELEASE"

mkdir -p "$WORK_DIR" "$OUT_DIR"
sudo rm -rf "$ROOTFS"

echo "::group::Create Ubuntu Base ${UBUNTU_VERSION} ${UBUNTU_ARCH} rootfs"
UBUNTU_BASE_PATH="$WORK_DIR/$UBUNTU_BASE_TARBALL"
curl -fsSL --retry 3 "$UBUNTU_BASE_URL/$UBUNTU_BASE_TARBALL" -o "$UBUNTU_BASE_PATH"
printf '%s  %s\n' "$UBUNTU_BASE_SHA256" "$UBUNTU_BASE_PATH" | sha256sum -c -

sudo mkdir -p "$ROOTFS"
sudo tar --numeric-owner -xzf "$UBUNTU_BASE_PATH" -C "$ROOTFS"

# Ubuntu Base is intentionally tiny. Configure the official ARM ports archive,
# then install only the runtime required by this headless Channel image.
sudo tee "$ROOTFS/etc/apt/sources.list" >/dev/null <<EOF
deb http://ports.ubuntu.com/ubuntu-ports $UBUNTU_CODENAME main universe
deb http://ports.ubuntu.com/ubuntu-ports $UBUNTU_CODENAME-updates main universe
deb http://ports.ubuntu.com/ubuntu-ports $UBUNTU_CODENAME-security main universe
EOF
sudo rm -f "$ROOTFS/etc/apt/sources.list.d/ubuntu.sources" 2>/dev/null || true

sudo cp -L /etc/resolv.conf "$ROOTFS/etc/resolv.conf"

# systemd's package setup expects a normal Linux userspace view even in a
# chroot. Seed machine-id on the host and provide proc/sys/dev while apt/dpkg
# configures the Ubuntu packages.
if [ ! -s "$ROOTFS/etc/machine-id" ]; then
  openssl rand -hex 16 | sudo tee "$ROOTFS/etc/machine-id" >/dev/null
fi

sudo update-binfmts --enable qemu-aarch64 || true
if [ -x /usr/bin/qemu-aarch64-static ]; then
  sudo install -m 0755 /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/qemu-aarch64-static"
fi

bootstrap_cleanup_mounts() {
  sudo umount -R "$ROOTFS/dev" 2>/dev/null || true
  sudo umount "$ROOTFS/proc" 2>/dev/null || true
  sudo umount "$ROOTFS/sys" 2>/dev/null || true
}
trap bootstrap_cleanup_mounts EXIT
sudo mount --rbind /dev "$ROOTFS/dev"
sudo mount --make-rslave "$ROOTFS/dev"
sudo mount -t proc proc "$ROOTFS/proc"
sudo mount -t sysfs sysfs "$ROOTFS/sys"

# Prevent package postinst scripts from trying to start services inside the
# build chroot. Services are enabled explicitly after the rootfs is configured.
sudo tee "$ROOTFS/usr/sbin/policy-rc.d" >/dev/null <<'EOF'
#!/bin/sh
exit 101
EOF
sudo chmod 0755 "$ROOTFS/usr/sbin/policy-rc.d"

sudo chroot "$ROOTFS" /bin/sh -ec '
  export DEBIAN_FRONTEND=noninteractive
  apt-get update
  apt-get install -y --no-install-recommends \
    systemd-sysv udev dbus network-manager \
    openssh-server openssh-client \
    iproute2 iputils-ping \
    dnsmasq \
    ca-certificates \
    kmod busybox-static \
    e2fsprogs util-linux procps \
    less nano ethtool iw \
    wpasupplicant wireless-regdb \
    systemd-timesyncd
  apt-get clean
  rm -rf /var/lib/apt/lists/*
'
sudo rm -f "$ROOTFS/usr/sbin/policy-rc.d"
bootstrap_cleanup_mounts
trap - EXIT
echo "::endgroup::"

echo "::group::Install channel headless configuration"
sudo cp -a "$REPO_ROOT/ubuntu/rootfs/." "$ROOTFS/"
sudo chmod 0755 "$ROOTFS/usr/local/sbin/channel-usb-gadget"
sudo chmod 0755 "$ROOTFS/usr/local/sbin/channel-wifi-firmware"

if [ ! -s "$ROOTFS/etc/machine-id" ]; then
  openssl rand -hex 16 | sudo tee "$ROOTFS/etc/machine-id" >/dev/null
fi

printf '%s\n' channel | sudo tee "$ROOTFS/etc/hostname" >/dev/null
sudo tee "$ROOTFS/etc/hosts" >/dev/null <<'EOF'
127.0.0.1 localhost
127.0.1.1 channel
::1 localhost ip6-localhost ip6-loopback
EOF

sudo tee "$ROOTFS/etc/fstab" >/dev/null <<EOF
UUID=$CHANNEL_ROOT_UUID / ext4 rw,noatime 0 1
EOF

SSH_AUTH_MODE="${SSH_AUTH_MODE:-auto}"
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
  ssh-keygen -q -t ed25519 -N "" -C "channel-bringup-ci" -f "$OUT_DIR/channel_test_ed25519"
  install_public_key "$(cat "$OUT_DIR/channel_test_ed25519.pub")"
}

generate_password() {
  ROOT_PASSWORD="$(openssl rand -hex 24)"
  printf '%s\n' "$ROOT_PASSWORD" > "$OUT_DIR/channel_ssh_password.txt"
  chmod 0600 "$OUT_DIR/channel_ssh_password.txt"
  ALLOW_PASSWORD=1
}

case "$SSH_AUTH_MODE" in
  auto)
    if [ -n "$SSH_PUBLIC_KEY" ]; then
      install_public_key "$SSH_PUBLIC_KEY"
      SSH_AUTH_MODE="public-key-secret"
    else
      generate_public_key
      SSH_AUTH_MODE="generated-key"
    fi
    ;;
  generated-key)
    generate_public_key
    ;;
  public-key-input)
    [ -n "$SSH_PUBLIC_KEY_INPUT" ] || { echo "ssh_public_key input is required for public-key-input" >&2; exit 2; }
    install_public_key "$SSH_PUBLIC_KEY_INPUT"
    ;;
  public-key-secret)
    [ -n "$SSH_PUBLIC_KEY" ] || { echo "SSH_PUBLIC_KEY secret is required for public-key-secret" >&2; exit 2; }
    install_public_key "$SSH_PUBLIC_KEY"
    ;;
  generated-password)
    generate_password
    ;;
  password-secret)
    [ -n "$SSH_PASSWORD" ] || { echo "SSH_PASSWORD secret is required for password-secret" >&2; exit 2; }
    ROOT_PASSWORD="$SSH_PASSWORD"
    ALLOW_PASSWORD=1
    ;;
  generated-key+generated-password)
    generate_public_key
    generate_password
    ;;
  public-key-input+password-secret)
    [ -n "$SSH_PUBLIC_KEY_INPUT" ] || { echo "ssh_public_key input is required" >&2; exit 2; }
    [ -n "$SSH_PASSWORD" ] || { echo "SSH_PASSWORD secret is required" >&2; exit 2; }
    install_public_key "$SSH_PUBLIC_KEY_INPUT"
    ROOT_PASSWORD="$SSH_PASSWORD"
    ALLOW_PASSWORD=1
    ;;
  public-key-secret+password-secret)
    [ -n "$SSH_PUBLIC_KEY" ] || { echo "SSH_PUBLIC_KEY secret is required" >&2; exit 2; }
    [ -n "$SSH_PASSWORD" ] || { echo "SSH_PASSWORD secret is required" >&2; exit 2; }
    install_public_key "$SSH_PUBLIC_KEY"
    ROOT_PASSWORD="$SSH_PASSWORD"
    ALLOW_PASSWORD=1
    ;;
  open-root-usb)
    ALLOW_EMPTY_SSH=1
    ;;
  disabled)
    echo "SSH mode 'disabled' was removed; use open-root-usb for direct USB root login" >&2
    exit 2
    ;;
  *)
    echo "Unsupported SSH_AUTH_MODE: $SSH_AUTH_MODE" >&2
    exit 2
    ;;
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
  # Keep the Unix root password non-empty so local/serial login is not opened.
  # The USB-only sshd accepts its initial empty "none" authentication through
  # a dedicated PAM policy instead.
  sudo tee "$ROOTFS/etc/pam.d/sshd" >/dev/null <<'EOF'
# Channel USB-only open-root SSH mode.
auth required pam_permit.so
account required pam_permit.so
session required pam_permit.so
EOF
fi

if [ "$ALLOW_EMPTY_SSH" -eq 1 ]; then
  SSH_ROOT_LOGIN=yes
  SSH_PUBKEY=no
  SSH_PASSWORD_AUTH=yes
  SSH_EMPTY_PASSWORDS=yes
elif [ "$ALLOW_PASSWORD" -eq 1 ]; then
  SSH_ROOT_LOGIN=yes
  SSH_PUBKEY=$([ "$ALLOW_KEY" -eq 1 ] && echo yes || echo no)
  SSH_PASSWORD_AUTH=yes
  SSH_EMPTY_PASSWORDS=no
elif [ "$ALLOW_KEY" -eq 1 ]; then
  SSH_ROOT_LOGIN=prohibit-password
  SSH_PUBKEY=yes
  SSH_PASSWORD_AUTH=no
  SSH_EMPTY_PASSWORDS=no
else
  echo "No usable SSH authentication method selected" >&2
  exit 2
fi

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

# Keep SSH under ssh.service control. Ubuntu also ships ssh.socket, which
# listens independently from sshd's ListenAddress when explicitly enabled.
sudo systemctl --root="$ROOTFS" disable ssh.socket 2>/dev/null || true
sudo systemctl --root="$ROOTFS" disable dnsmasq.service 2>/dev/null || true
sudo systemctl --root="$ROOTFS" enable \
  channel-usb-gadget.service channel-dhcp.service \
  channel-wifi-firmware.service NetworkManager.service dbus.socket systemd-timesyncd.service

sudo systemctl --root="$ROOTFS" enable ssh.service

# Keep a persistent time floor. systemd-timesyncd advances this after a
# successful sync, preventing the broken device RTC from dropping back to 1970.
sudo install -d -m 0755 "$ROOTFS/var/lib/systemd/timesync"
sudo touch "$ROOTFS/var/lib/systemd/timesync/clock"

# This device is intentionally headless. Persist the journal so boot/USB
# failures can be inspected by mounting the microSD on another machine.
sudo mkdir -p "$ROOTFS/var/log/journal"
echo "::endgroup::"

echo "::group::Install reusable mainline kernel modules"
test -s "$KERNEL_MODULES_ARCHIVE"
sudo tar -I zstd -xf "$KERNEL_MODULES_ARCHIVE" -C "$ROOTFS"
test -d "$ROOTFS/lib/modules/$KREL"
sudo depmod -b "$ROOTFS" "$KREL"
sudo mkdir -p "$ROOTFS/boot"
sudo cp "$KERNEL_CONFIG_FILE" "$ROOTFS/boot/config-$KREL"
sudo cp "$KERNEL_SYSTEM_MAP_FILE" "$ROOTFS/boot/System.map-$KREL"
echo "::endgroup::"

echo "::group::Finalize Ubuntu rootfs"
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

cleanup_mounts
trap - EXIT

# qemu-aarch64-static is a host-side helper and must not ship in the target image.
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"
echo "::endgroup::"

echo "::group::Create ext4 rootfs image"
USED_MB="$(sudo du -sm "$ROOTFS" | awk '{print $1}')"
IMAGE_MB=$((USED_MB + 700))
if [ "$IMAGE_MB" -lt 1536 ]; then IMAGE_MB=1536; fi

ROOTFS_IMG="$OUT_DIR/ubuntu-channel-rootfs.ext4"
truncate -s "${IMAGE_MB}M" "$ROOTFS_IMG"
sudo mkfs.ext4 -F -m 0 -L "$ROOTFS_LABEL" -U "$CHANNEL_ROOT_UUID" -d "$ROOTFS" "$ROOTFS_IMG"
sudo e2fsck -fn "$ROOTFS_IMG"
test "$(blkid -p -o value -s UUID "$ROOTFS_IMG")" = "$CHANNEL_ROOT_UUID"
test "$(blkid -p -o value -s LABEL "$ROOTFS_IMG")" = "$ROOTFS_LABEL"
zstd -T0 -10 -f "$ROOTFS_IMG" -o "$ROOTFS_IMG.zst"
rm -f "$ROOTFS_IMG"
echo "::endgroup::"

{
  echo "distribution=ubuntu"
  echo "ubuntu_version=$UBUNTU_VERSION"
  echo "ubuntu_codename=$UBUNTU_CODENAME"
  echo "kernel_release=$KREL"
  echo "rootfs_label=$ROOTFS_LABEL"
  echo "rootfs_uuid=$CHANNEL_ROOT_UUID"
  echo "usb_device_ip=172.16.42.1"
  echo "usb_dhcp_range=172.16.42.2-172.16.42.20"
  echo "ssh_auth=$SSH_AUTH_MODE"
  echo "ssh_listen=172.16.42.1"
  echo "ssh_scope=usb-only"
  echo "wifi_manager=NetworkManager"
  echo "usb_network_manager=unmanaged"
  echo "wifi_runtime_setup=nmcli"
  echo "wifi_firmware=stock-modem-vendor-readonly"
  echo "time_sync=systemd-timesyncd"
} > "$OUT_DIR/build-info.txt"

(
  cd "$OUT_DIR"
  sha256sum ubuntu-channel-rootfs.ext4.zst build-info.txt > SHA256SUMS.ubuntu
)
