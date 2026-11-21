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

BUILD_DIR="build/rootfs"
# Output dir: home user yang memanggil script (tetap benar walau dijalankan dengan sudo)
OWNER_HOME="$(getent passwd "${SUDO_USER:-$USER}" | cut -d: -f6)"
OUT_DIR="${OWNER_HOME:-$HOME}/koppie-arm-products"
mkdir -p "$BUILD_DIR" "$OUT_DIR"

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
sudo chroot "$BUILD_DIR" /usr/bin/qemu-aarch64-static /bin/bash -c "
    pacman-key --init
    pacman-key --populate archlinuxarm
    pacman -Syu --noconfirm
"

echo "=== ARM Rootfs Prepared Successfully in $BUILD_DIR ==="
