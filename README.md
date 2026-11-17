# Koppie Linux ARM - Build Profile (aarch64)

The official build repository for generating **Koppie Linux ARM (aarch64)** images and installers, designed for **Apple Silicon (MacBook M1/M2/M3/M-series)** and generic UEFI ARM64 devices, featuring a minimal KDE Plasma desktop and an offline Calamares installer.

---

## 🛠️ Prerequisites

You can build this on **any Linux laptop or PC** (both x86_64 Intel/AMD and native aarch64 systems).

Install the required build and cross-architecture emulation tools:

```bash
sudo pacman -Syu --needed base-devel git wget bsdtar qemu-user-static qemu-user-static-binfmt binfmt-qemu-static
```

> **Note:** Sudo privileges are required for preparing the rootfs, mounting filesystems, and setting up permissions. Ensure your user has working `sudo` access and at least **15 GB** of free disk space.

---

## 🚀 Setup & Build Instructions

Follow these steps to set up and build Koppie Linux ARM:

### 1. Clone the Repository
Clone this repository directly into your `~/Projects/koppie-arch-arm` folder:

```bash
mkdir -p ~/Projects
git clone https://github.com/KoppieLinux/koppie-build-arm.git ~/Projects/koppie-arch-arm
cd ~/Projects/koppie-arch-arm
```

### 2. Verify Repository Configuration
The build script automatically utilizes the official **Koppie Linux ARM repository** (`https://raw.githubusercontent.com/KoppieLinux/koppie-repo/master/aarch64`) for custom packages (`koppie-software-centre`, `koppie-driver-manager-arm`, `koppie-update-manager-arm`, `calamares`, `yay`).

If you have built local packages in `~/koppie-arm-products/koppie-repo/aarch64`, the local repo path in `configs/pacman-arm.conf` can also be used.

### 3. Build the ARM System Image
Execute the build script with sudo permissions:

```bash
sudo ./build-arm.sh
```

> **What the script does automatically:**
> - Verifies QEMU aarch64 emulation for building on x86 machines.
> - Downloads the clean Arch Linux ARM (ALARM) rootfs tarball.
> - Injects the Koppie Linux custom desktop layout, themes (Orchis-dark, Papirus-Dark, Bibata cursor), and offline configurations.
> - Compiles and outputs the ready-to-flash ARM products into `~/koppie-arm-products/`.

---

## 💾 Installation & Usage

- **Apple Silicon (MacBook M1/M2/M3)**: Flash the resulting image to an external USB/NVMe drive or follow the Asahi dual-boot chain.
- **Generic ARM64 / Virtual Machines (UTM / Parallels / QEMU)**: Boot directly using the UEFI ARM64 kernel image and run the offline Calamares installer from the live desktop.
