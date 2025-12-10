# RPi-5-NVMe-LVM-Migrator-
Automated script to migrate Raspberry Pi OS (Bookworm) from SD Card to NVMe SSD with LVM support.


This script automates the complex process of moving a running Raspberry Pi 5 system to an NVMe drive while setting up LVM (Logical Volume Manager). It handles partitioning, data migration, bootloader configuration, and—most importantly—fixes the initramfs boot issues common with RPi 5 and LVM.

🌟 Features
Full Automation: Wipes NVMe, partitions it, creates LVM, and copies the system.

LVM Support: Sets up Logical Volume Manager for flexibility.

Custom Partitioning: Creates separate volumes for / (Root), /var/log, and /data to keep your data organized and safe.

Bootloader Config: Automatically updates EEPROM (boot_order and pcie_probe).

Initramfs Fix: Handles the specific Raspberry Pi 5 requirement to manually copy initramfs to the FAT32 boot partition to allow booting from LVM.

Update Safe: Standard apt upgrade works fine (kernel updates trigger initramfs regeneration, though manual copy to boot partition might be needed for major kernel version jumps).

🛠 Prerequisites
Raspberry Pi 5.

NVMe SSD connected via a HAT or PCIe base.

SD Card with a working installation of Raspberry Pi OS (Bookworm).

Internet connection (to install lvm2, rsync, parted).

⚙️ Configuration
Open the script and adjust the variables at the top to fit your needs:

Bash

TARGET_DISK="/dev/nvme0n1" # Your NVMe device
VG_NAME="pi_vg"            # Volume Group Name

# Logical Volume Sizes
LV_ROOT_SIZE="12G"         # Size for system root
LV_VARLOG_SIZE="4G"        # Size for logs
LV_DATA_SIZE="20G"         # Size for your data (or use "100%FREE")
🚀 Usage
Boot your Raspberry Pi from the SD Card.

Download or create the script:

Bash

nano migrate.sh
# Paste the script content here
Make it executable:

Bash

chmod +x migrate.sh
Run as root:

Bash

sudo ./migrate.sh
Wait for the "SUCCESS" message.

Shutdown (sudo poweroff).

REMOVE the SD Card. (Crucial step! Do not boot with both attached initially).

Power on and enjoy your fast NVMe system!

⚠️ Disclaimer
This script wipes the target disk (/dev/nvme0n1). Make sure you don't have important data on the SSD.

Use at your own risk. Always backup your SD card before performing major system changes.
