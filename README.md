# 🚀 RPi 5 NVMe LVM Migrator

**Automated script to migrate Raspberry Pi OS (Bookworm) from an SD Card to an NVMe SSD with full LVM support.**

## 📖 Overview

Running a Raspberry Pi 5 from an NVMe SSD provides a massive performance boost over standard SD cards. However, setting up **LVM (Logical Volume Manager)** on the boot drive can be tricky because the Raspberry Pi bootloader does not natively understand LVM volumes.

This script automates the entire process. It takes a vanilla Raspberry Pi OS installation running on an SD card, clones it to your NVMe drive, sets up LVM structure, and applies the necessary boot configuration fixes (`initramfs` & `config.txt`) to ensure the system boots correctly.

## ✨ Features

* **Automated Partitioning:** Wipes the NVMe drive and creates a standard Boot partition (FAT32) and an LVM Physical Volume.
* **LVM Setup:** Creates a Volume Group (`pi_vg`) and separate Logical Volumes for:
    * `root` (System)
    * `var_log` (Logs - prevents log spam from filling up root)
    * `data` (User data)
* **Smart Cloning:** Uses `rsync` to copy your running system to the new drive.
* **Bootloader Configuration:** Automatically updates the RPi EEPROM to enable PCIe Gen 3 and set the boot order to NVMe.
* **The "Boot Fix":** Automatically generates the `initramfs` image and modifies `config.txt` to force the kernel to load LVM drivers before mounting the root filesystem.

## 🛠 Prerequisites

1.  **Raspberry Pi 5**.
2.  **NVMe SSD** installed (via HAT or PCIe base).
3.  **SD Card** with a working, fresh installation of Raspberry Pi OS (Bookworm).
4.  **Internet Connection** (to install dependencies like `lvm2` and `rsync`).

## ⚙️ Configuration

Before running the script, open it and adjust the variables at the top to match your needs:

```bash
# Target Drive (Default is usually correct)
TARGET_DISK="/dev/nvme0n1"

# Volume Group Name
VG_NAME="pi_vg"

# Logical Volume Sizes
LV_ROOT_SIZE="30G"    # Size for the OS
LV_VARLOG_SIZE="5G"   # Size for /var/log
LV_DATA_SIZE="20G"    # Size for /data partition
