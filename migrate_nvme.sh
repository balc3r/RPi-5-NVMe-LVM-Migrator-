#!/bin/bash
set -e

# === SETTINGS ===
TARGET_DISK="/dev/nvme0n1"
VG_NAME="pi_vg"

# === PARTITION SIZES ===
# Change these values to whatever you need.
# The remaining space on NVMe will be left unallocated (Free PE)
LV_ROOT_SIZE="30G"
LV_VARLOG_SIZE="5G"
LV_DATA_SIZE="30G"   # <--- FIXED SIZE (Not 100%) OR - "100%FREE")

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}=== RPi 5 NVMe LVM Migrator (English & Fixed Data Size) ===${NC}"

if [[ $EUID -ne 0 ]]; then
   echo -e "${RED}ERROR: Please run as root (sudo).${NC}"
   exit 1
fi

# 1. CLEANUP
echo -e "${RED}[0/8] Cleaning up previous installations...${NC}"
umount -R /mnt/nvme_final 2>/dev/null || true
vgchange -an $VG_NAME 2>/dev/null || true
vgremove -ff $VG_NAME 2>/dev/null || true
wipefs -a -f $TARGET_DISK
udevadm settle
sleep 1

# 2. EEPROM SETUP
echo -e "${GREEN}[1/8] Configuring EEPROM (PCIe + Boot Order)...${NC}"
rpi-eeprom-config > /tmp/boot_conf.txt
sed -i '/BOOT_ORDER=/d' /tmp/boot_conf.txt
sed -i '/PCIE_PROBE=/d' /tmp/boot_conf.txt
echo "PCIE_PROBE=1" >> /tmp/boot_conf.txt
echo "BOOT_ORDER=0xf416" >> /tmp/boot_conf.txt
rpi-eeprom-config --apply /tmp/boot_conf.txt
rm /tmp/boot_conf.txt

# 3. PARTITIONING
echo -e "${GREEN}[2/8] Partitioning NVMe disk...${NC}"
apt install -y lvm2 rsync parted

parted -s $TARGET_DISK mklabel msdos
# Partition 1: Boot (FAT32) - 512MB
parted -s $TARGET_DISK mkpart primary fat32 1MiB 513MiB
parted -s $TARGET_DISK set 1 lba on
# Partition 2: LVM (Ext4) - Rest of the disk
parted -s $TARGET_DISK mkpart primary 513MiB 100%
parted -s $TARGET_DISK set 2 lvm on

udevadm settle
partprobe $TARGET_DISK
sleep 3

PART_BOOT="${TARGET_DISK}p1"
PART_LVM="${TARGET_DISK}p2"

# 4. LVM SETUP
echo -e "${GREEN}[3/8] Setting up LVM and Formatting...${NC}"
mkfs.vfat -F 32 -n BOOTFS $PART_BOOT
pvcreate -ff -y $PART_LVM
vgcreate -f $VG_NAME $PART_LVM

# Creating Logical Volumes with FIXED sizes
echo "Creating Logical Volumes..."
lvcreate -y -L $LV_ROOT_SIZE -n root $VG_NAME
lvcreate -y -L $LV_VARLOG_SIZE -n var_log $VG_NAME
lvcreate -y -L $LV_DATA_SIZE -n data $VG_NAME # Fixed size here

echo "Activating Volume Group..."
vgchange -ay $VG_NAME
sleep 1

echo "Formatting filesystems (ext4)..."
mkfs.ext4 -F -L rootfs /dev/$VG_NAME/root
mkfs.ext4 -F -L logs /dev/$VG_NAME/var_log
mkfs.ext4 -F -L data /dev/$VG_NAME/data

# 5. MOUNT & COPY
echo -e "${GREEN}[4/8] Copying System Files...${NC}"
MOUNT_POINT="/mnt/nvme_final"
mkdir -p $MOUNT_POINT
mount /dev/$VG_NAME/root $MOUNT_POINT

mkdir -p $MOUNT_POINT/boot/firmware
mount $PART_BOOT $MOUNT_POINT/boot/firmware
mkdir -p $MOUNT_POINT/var/log
mount /dev/$VG_NAME/var_log $MOUNT_POINT/var/log
mkdir -p $MOUNT_POINT/data
mount /dev/$VG_NAME/data $MOUNT_POINT/data

echo "Rsyncing RootFS (This may take a while)..."
rsync -axHAWX --info=progress2 --exclude={"/mnt","/proc","/sys","/tmp","/run","/dev","/lost+found","/media"} / $MOUNT_POINT/

echo "Copying Bootloader files (Crucial Step)..."
cp -r /boot/firmware/* $MOUNT_POINT/boot/firmware/

# Creating empty system directories
mkdir -p $MOUNT_POINT/{dev,proc,sys,run,tmp,mnt,media}
chmod 1777 $MOUNT_POINT/tmp

# 6. CONFIGURATION
echo -e "${GREEN}[5/8] Updating Configuration Files (fstab/cmdline)...${NC}"
NEW_BOOT_UUID=$(blkid -s UUID -o value $PART_BOOT)

# FSTAB
cat > $MOUNT_POINT/etc/fstab <<EOF
proc            /proc           proc    defaults          0       0
UUID=$NEW_BOOT_UUID  /boot/firmware  vfat    defaults          0       2
/dev/mapper/$VG_NAME-root    /               ext4    defaults,noatime  0       1
/dev/mapper/$VG_NAME-var_log /var/log        ext4    defaults,noatime  0       2
/dev/mapper/$VG_NAME-data    /data           ext4    defaults,noatime  0       2
EOF

# CMDLINE - Pointing root to LVM
CURRENT_CMDLINE=$(cat /boot/firmware/cmdline.txt)
CLEAN_CMDLINE=$(echo $CURRENT_CMDLINE | sed -E 's/root=[^ ]* //')
CLEAN_CMDLINE=$(echo $CLEAN_CMDLINE | sed -E 's/initrd=[^ ]* //')
echo "root=/dev/mapper/$VG_NAME-root $CLEAN_CMDLINE" > $MOUNT_POINT/boot/firmware/cmdline.txt

# 7. INITRAMFS GENERATION
echo -e "${GREEN}[6/8] Generating Initramfs inside Chroot...${NC}"
mount --bind /dev $MOUNT_POINT/dev
mount --bind /dev/pts $MOUNT_POINT/dev/pts
mount --bind /proc $MOUNT_POINT/proc
mount --bind /sys $MOUNT_POINT/sys
mount --bind /run $MOUNT_POINT/run

chroot $MOUNT_POINT /bin/bash <<EOF
apt update
apt install -y lvm2
grep -qxF "dm-mod" /etc/initramfs-tools/modules || echo "dm-mod" >> /etc/initramfs-tools/modules
grep -qxF "lvm2" /etc/initramfs-tools/modules || echo "lvm2" >> /etc/initramfs-tools/modules
update-initramfs -u -k all
EOF

# 8. COPY INITRAMFS TO FAT32
echo -e "${GREEN}[7/8] Deploying Initramfs to Boot Partition...${NC}"
LATEST_INITRD=$(ls -t $MOUNT_POINT/boot/initrd.img* | head -n1)
if [[ -z "$LATEST_INITRD" ]]; then
    echo "ERROR: Initrd file not found!"
    exit 1
fi
echo "Found: $LATEST_INITRD"
cp $LATEST_INITRD $MOUNT_POINT/boot/firmware/initramfs.gz

# 9. CONFIG.TXT UPDATE
echo -e "${GREEN}[8/8] Updating config.txt to load initramfs...${NC}"
CONFIG_FILE="$MOUNT_POINT/boot/firmware/config.txt"

if [[ ! -f "$CONFIG_FILE" ]]; then
    echo "CRITICAL ERROR: config.txt does not exist on target!"
    exit 1
fi

# Clean old entries and add new one
sed -i '/auto_initramfs/d' $CONFIG_FILE
sed -i '/initramfs /d' $CONFIG_FILE
echo "initramfs initramfs.gz followkernel" >> $CONFIG_FILE

echo -e "${GREEN}=== SUCCESS! ===${NC}"
echo "1. Run: sudo poweroff"
echo "2. UNPLUG POWER CABLE"
echo "3. REMOVE SD CARD"
echo "4. PLUG POWER BACK IN"
