# 🚀 RPi 5 NVMe LVM Migrator

**Automated script to migrate Raspberry Pi OS (Bookworm/Trixie) from an SD Card to an NVMe SSD with full Logical Volume Manager (LVM) support.**

## 📖 Overview

Running a Raspberry Pi 5 from an NVMe SSD provides a massive performance boost. However, the standard Raspberry Pi bootloader has a known limitation: **it cannot boot directly from an LVM partition.** It requires the kernel and initial ramdisk (`initramfs`) to reside on a standard FAT32 partition.

This script solves that problem automatically. It:
1.  **Clones** your running system from SD to NVMe.
2.  **Sets up LVM** (splitting Root, Logs, and Data).
3.  **Applies the "Boot Fix":** It automatically generates the required `initramfs`, copies it to the FAT32 boot partition, and configures `config.txt` to load the LVM drivers before the OS starts.

## ✨ Features

* **Zero-Config Bootloader:** Automatically updates the RPi EEPROM to enable PCIe Gen 3 and set the correct boot order.
* **LVM Structure:** Creates a flexible volume group (`pi_vg`) with separate logical volumes for:
    * `root` (System files)
    * `var_log` (Prevents log spam from filling up the root partition)
    * `data` (User data)
* **Smart Mirroring:** Uses `rsync` to preserve permissions and attributes while copying data.
* **Fixed Boot Issues:** Implements the manual `initramfs` copy workaround required for RPi 5, ensuring the system boots correctly every time.

## 🛠 Prerequisites

1.  **Raspberry Pi 5**.
2.  **NVMe SSD** installed (via HAT or PCIe base).
3.  **SD Card** with a working installation of Raspberry Pi OS (Bookworm/Trixie).
4.  **Internet Connection** (to install `lvm2`, `rsync`, `parted`).

## ⚙️ Configuration

Before running the script, open it and adjust the variables at the top to match your needs:

```bash
# Target Drive (Default is usually correct)
TARGET_DISK="/dev/nvme0n1"

# Volume Group Name
VG_NAME="pi_vg"

# Logical Volume Sizes
LV_ROOT_SIZE="12G"    # Size for the OS
LV_VARLOG_SIZE="4G"   # Size for /var/log
LV_DATA_SIZE="20G"    # Size for /data partition (Set to "100%FREE" to use full disk)
```

# 🚀 Usage Guide
1. Prepare the Script
Boot your Raspberry Pi from the SD Card. Create the script file:
```
nano migrate_nvme.sh
```
Paste the script content into the file, save (Ctrl+O), and exit (Ctrl+X).

2. Make Executable
```
chmod +x migrate_nvme.sh
```
3. Run the Migration
Run the script with root privileges. ⚠️ WARNING: This will ERASE ALL DATA on the target NVMe drive.
```
sudo ./migrate_nvme.sh
```
4. Finalize
Once the script finishes and prints the SUCCESS message:

Power off the Raspberry Pi: sudo poweroff.

UNPLUG the power cable. (Important for hardware reset).

REMOVE the SD Card. (Critical Step! Do not boot with both drives attached initially).

Plug the power back in.

# 📊 Post-Installation: Managing Storage
One of the biggest advantages of using this script is LVM. Unlike standard partitions, you can resize your volumes later without reformatting.

1. Check Available Space
To see how much "unallocated" space is left in your Volume Group (e.g., if you set Data to 20G and have a 512G drive):
```
df -h
```

2. Extending Volumes (Online)
You can increase the size of a partition (even the Root / partition) while the system is running. No reboot required.

Example: Add 10GB to the Root partition:
# The -r flag automatically resizes the filesystem
sudo lvextend -r -L +10G /dev/pi_vg/root

# 🐛 Troubleshooting
System doesn't boot (Red LED / Green flashes): Ensure you removed the SD card. The bootloader gets confused if it sees two bootable partitions with similar UUIDs.

"Waiting for root device" error: This usually means the initramfs wasn't loaded.

Boot from the SD card.

Mount the NVMe boot partition (/dev/nvme0n1p1).

Check config.txt for the line: initramfs initramfs.gz followkernel.

Ensure initramfs.gz exists in that folder.

# ⚠️ Disclaimer
This script performs destructive operations on the target disk (/dev/nvme0n1). The author is not responsible for any data loss. Always backup your data before running system migration scripts.

📜 License
MIT License - feel free to modify and share!
