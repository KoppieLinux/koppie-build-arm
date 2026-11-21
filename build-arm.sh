#!/bin/bash
# Koppie Linux ARM64 (aarch64) Image & Rootfs Builder
# Designed for Apple Silicon (M1/M2/M3) and generic aarch64 UEFI systems.
# Requires: qemu-user-static, qemu-user-static-binfmt, tar, wget, libarchive (bsdtar)

set -e
set -o pipefail

echo "=== [1/5] Checking Prerequisites ==="
sudo -n true || { echo "ERROR: sudo password required"; exit 1; }

# Ensure qemu binfmt is ready for aarch64
if [ ! -f /usr/bin/qemu-aarch64-static ]; then
    echo "Installing qemu-user-static for ARM64 emulation..."
    sudo pacman -S --needed --noconfirm qemu-user-static qemu-user-static-binfmt
fi

# binfmt yang baru diinstall belum tentu sudah kebaca kernel — restart dulu,
# lalu verifikasi. Tanpa ini chroot gagal dengan "exec format error".
if ! ls /proc/sys/fs/binfmt_misc/ 2>/dev/null | grep -q aarch64; then
    echo "Registering aarch64 binfmt..."
    sudo systemctl restart systemd-binfmt 2>/dev/null || true
fi
if ! ls /proc/sys/fs/binfmt_misc/ 2>/dev/null | grep -q aarch64; then
    echo "ERROR: binfmt untuk aarch64 tidak terdaftar, chroot tidak akan jalan."
    echo "       Jalankan: sudo systemctl restart systemd-binfmt   (atau reboot)"
    exit 1
fi

BUILD_DIR="build/rootfs"
# Output dir: home user yang memanggil script (tetap benar walau dijalankan dengan sudo)
OWNER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
OUT_DIR="${OWNER_HOME:-$HOME}/koppie-arm-products"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

# Lepas bind-mount chroot yang mungkin masih tersisa (run sebelumnya mati di
# tengah jalan) SEBELUM rm -rf — kalau tidak, rm -rf akan ikut masuk ke
# /proc, /sys, /dev milik host yang masih ke-mount.
unmount_chroot() {
    for m in run dev sys proc; do
        if mountpoint -q "$BUILD_DIR/$m"; then
            sudo umount -l "$BUILD_DIR/$m"
        fi
    done
}
unmount_chroot

echo "=== [2/5] Fetching Arch Linux ARM Base Tarball ==="
TARBALL="ArchLinuxARM-aarch64-latest.tar.gz"
if [ ! -f "build/$TARBALL" ]; then
    echo "Downloading Arch Linux ARM rootfs..."
    wget -c "http://os.archlinuxarm.org/os/$TARBALL" -O "build/$TARBALL"
fi

echo "=== [3/5] Extracting Rootfs ==="
sudo rm -rf "$BUILD_DIR"/*
sudo bsdtar -xpf "build/$TARBALL" -C "$BUILD_DIR"

# Copy QEMU binary into chroot
sudo cp /usr/bin/qemu-aarch64-static "$BUILD_DIR/usr/bin/"

# Copy pacman config and DNS
sudo cp configs/pacman-arm.conf "$BUILD_DIR/etc/pacman.conf"
sudo cp /etc/resolv.conf "$BUILD_DIR/etc/resolv.conf"

echo "=== [4/5] Injecting Koppie Linux Overlay ==="
sudo cp -a airootfs/. "$BUILD_DIR/"

echo "=== [5/5] Chrooting to Setup Base Packages & Users ==="

# /proc, /sys, /dev dan /run wajib ke-mount di chroot: mkinitcpio (dijalankan
# saat package linux-aarch64 terpasang) dan hook systemd butuh semuanya.
# Tanpa mount ini install kernel gagal walau qemu-nya jalan.
trap unmount_chroot EXIT
for m in proc sys dev run; do
    sudo mkdir -p "$BUILD_DIR/$m"
    sudo mount --bind "/$m" "$BUILD_DIR/$m"
done

# pacman -S - membaca target dari stdin, jadi komentar/baris kosong dibuang dulu.
# '|| true' supaya pipefail tidak mematikan script kalau grep tidak menemukan baris.
if [ ! -f packages.aarch64 ]; then
    echo "ERROR: packages.aarch64 tidak ditemukan"; exit 1
fi
{ grep -vE '^[[:space:]]*(#|$)' packages.aarch64 || true; } \
    | sudo tee "$BUILD_DIR/root/koppie-packages.list" >/dev/null

sudo chroot "$BUILD_DIR" /usr/bin/qemu-aarch64-static /bin/bash -c "
    set -e
    pacman-key --init
    pacman-key --populate archlinuxarm
    pacman -Syu --noconfirm
    echo '--- Installing Koppie package set ---'
    pacman -S --needed --noconfirm - < /root/koppie-packages.list
"

unmount_chroot
trap - EXIT
sudo rm -f "$BUILD_DIR/root/koppie-packages.list"

echo "=== ARM Rootfs Prepared Successfully in $BUILD_DIR ==="
