#!/usr/bin/env bash
set -euo pipefail
: "${KERNEL_RELEASE:?set KERNEL_RELEASE}"
: "${KERNEL_MODULES_ARCHIVE:?set KERNEL_MODULES_ARCHIVE}"
: "${KERNEL_CONFIG_FILE:?set KERNEL_CONFIG_FILE}"
: "${KERNEL_SYSTEM_MAP_FILE:?set KERNEL_SYSTEM_MAP_FILE}"
: "${OUT_DIR:?set OUT_DIR}"
DISTRO="${DISTRO:-chimera}"
ROOTFS_LABEL="${ROOTFS_LABEL:-chimera}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK_DIR="${WORK_DIR:-$REPO_ROOT/.work}"
ROOTFS="$WORK_DIR/rootfs"
KREL="$KERNEL_RELEASE"
test -s "$KERNEL_MODULES_ARCHIVE"; test -s "$KERNEL_CONFIG_FILE"; test -s "$KERNEL_SYSTEM_MAP_FILE"
mkdir -p "$WORK_DIR" "$OUT_DIR"; sudo rm -rf "$ROOTFS"; sudo mkdir -p "$ROOTFS"

echo "::group::Bootstrap Chimera Linux ARM64 rootfs"
BASE="https://repo.chimera-linux.org/live/latest"
FILE="$(curl -fsSL "$BASE/" | grep -oE 'chimera-linux-aarch64-ROOTFS-[0-9]+-full\.tar\.gz' | sort -u | tail -n1)"
test -n "$FILE"
curl -fL --retry 3 "$BASE/$FILE" -o "$WORK_DIR/$FILE"
curl -fL --retry 3 "$BASE/sha256sums.txt" -o "$WORK_DIR/sha256sums.txt"
(cd "$WORK_DIR" && grep "  $FILE$" sha256sums.txt | sha256sum -c -)
sudo tar -xpf "$WORK_DIR/$FILE" -C "$ROOTFS"
sudo install -m 0755 /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/qemu-aarch64-static"
sudo rm -f "$ROOTFS/etc/resolv.conf"; sudo cp /etc/resolv.conf "$ROOTFS/etc/resolv.conf"
sudo chroot "$ROOTFS" /bin/sh -lc 'apk update && apk add openssh openssh-dinit networkmanager networkmanager-dinit networkmanager-udev dnsmasq iproute2 iputils kmod e2fsprogs util-linux procps nano ethtool iw wpa_supplicant ca-certificates'
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"
echo "::endgroup::"

sudo cp -a "$REPO_ROOT/chimera/rootfs/." "$ROOTFS/"
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

# Fixed SSH management service on USB RNDIS only.
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
if ! sudo grep -Fq 'Include /etc/ssh/sshd_config.d/*.conf' "$ROOTFS/etc/ssh/sshd_config"; then
  sudo sed -i '1iInclude /etc/ssh/sshd_config.d/*.conf' "$ROOTFS/etc/ssh/sshd_config"
fi

sudo ssh-keygen -A -f "$ROOTFS"

echo "::group::Configure Chimera Linux services"
sudo mkdir -p "$ROOTFS/etc/dinit.d/boot.d"
sudo tee "$ROOTFS/etc/dinit.d/channel-usb-gadget" >/dev/null <<'EOF'
type = scripted
command = /usr/local/sbin/channel-usb-gadget
before = network.target
EOF
sudo tee "$ROOTFS/etc/dinit.d/channel-dhcp" >/dev/null <<'EOF'
type = process
command = /usr/local/sbin/channel-dhcp
depends-on = channel-usb-gadget
EOF
sudo tee "$ROOTFS/etc/dinit.d/channel-wifi-firmware" >/dev/null <<'EOF'
type = scripted
command = /usr/local/sbin/channel-wifi-firmware
before = networkmanager
EOF
sudo ln -sfn ../channel-usb-gadget "$ROOTFS/etc/dinit.d/boot.d/channel-usb-gadget"
sudo ln -sfn ../channel-dhcp "$ROOTFS/etc/dinit.d/boot.d/channel-dhcp"
sudo ln -sfn ../channel-wifi-firmware "$ROOTFS/etc/dinit.d/boot.d/channel-wifi-firmware"
[ ! -f "$ROOTFS/usr/lib/dinit.d/sshd" ] || sudo ln -sfn /usr/lib/dinit.d/sshd "$ROOTFS/etc/dinit.d/boot.d/sshd"
[ ! -f "$ROOTFS/usr/lib/dinit.d/networkmanager" ] || sudo ln -sfn /usr/lib/dinit.d/networkmanager "$ROOTFS/etc/dinit.d/boot.d/networkmanager"
echo "::endgroup::"

sudo tar -I zstd -xf "$KERNEL_MODULES_ARCHIVE" -C "$ROOTFS"
test -d "$ROOTFS/lib/modules/$KREL" || test -d "$ROOTFS/usr/lib/modules/$KREL"
sudo depmod -b "$ROOTFS" "$KREL"
sudo mkdir -p "$ROOTFS/boot"; sudo cp "$KERNEL_CONFIG_FILE" "$ROOTFS/boot/config-$KREL"; sudo cp "$KERNEL_SYSTEM_MAP_FILE" "$ROOTFS/boot/System.map-$KREL"

sudo update-binfmts --enable qemu-aarch64 || true
sudo install -m 0755 /usr/bin/qemu-aarch64-static "$ROOTFS/usr/bin/qemu-aarch64-static"
sudo chroot "$ROOTFS" /bin/sh -lc 'mkdir -p /run/sshd; sshd -t'
sudo rm -f "$ROOTFS/usr/bin/qemu-aarch64-static"

USED_MB="$(sudo du -sm "$ROOTFS" | awk '{print $1}')"; IMAGE_MB=$((USED_MB + 700)); [ "$IMAGE_MB" -ge 1536 ] || IMAGE_MB=1536
ROOTFS_IMG="$OUT_DIR/chimera-channel-rootfs.ext4"
truncate -s "${IMAGE_MB}M" "$ROOTFS_IMG"
sudo mkfs.ext4 -F -m 0 -L "$ROOTFS_LABEL" -U random -d "$ROOTFS" "$ROOTFS_IMG"
ROOTFS_EXT4_UUID="$(blkid -p -o value -s UUID "$ROOTFS_IMG")"
test -n "$ROOTFS_EXT4_UUID"
sudo e2fsck -fn "$ROOTFS_IMG"
zstd -T0 -10 -f "$ROOTFS_IMG" -o "$ROOTFS_IMG.zst"; rm -f "$ROOTFS_IMG"
{
 echo "distro=$DISTRO"; echo "variant=full-dinit"; echo "architecture=arm64"; echo "kernel_release=$KREL"; echo "rootfs_label=$ROOTFS_LABEL"; echo "rootfs_uuid=$ROOTFS_EXT4_UUID";
 echo "usb_device_ip=172.16.42.1"; echo "ssh_auth=ssh"; echo "ssh_listen=172.16.42.1"; echo "network_manager=NetworkManager"; echo "wifi_firmware=stock-modem-vendor-readonly";
} > "$OUT_DIR/build-info.txt"
(cd "$OUT_DIR" && sha256sum chimera-channel-rootfs.ext4.zst build-info.txt > SHA256SUMS.chimera)
