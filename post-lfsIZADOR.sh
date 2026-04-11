#!/bin/bash
####################################
#       __    ______  ______       #
#      |  |  |  ____||  ____|      #
#      |  |  | | __  | | __        #
#      |  |__| ||_ | | ||_ |       #
#      |_____|\____| |_____|       #
# -------------------------------- #
#    >> https://lucianogg.info     #
####################################
#      Script p/ LFS Project       #
####################################
# ------------------------------------------------------------------
# Description: This script finalizes the installation by setting up
#              passwords, fstab, and the Bootloader (GRUB) with
#              Dual-Boot support for the original Host.
# ------------------------------------------------------------------

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root."
  exit 1
fi

# ==================================================================
# [USER ACTION REQUIRED] CONFIGURATION VARIABLES
# ==================================================================
# Run 'blkid' and 'lsblk' in another terminal to find these values.

# 1. LFS Partition Details
# The UUID of the partition where you just built LFS (/mnt/lfs)
UUID_LFS=""
PARTICAO_LFS=""
PARTUUID_LFS=""

# 2. Disk Installation Target (For GRUB MBR)
# The physical disk device, NOT the partition (e.g., /dev/sda, /dev/nvme0n1)
DISCO_INSTALACAO=""

# 3. Host System Details (For Dual Boot & Fstab)
# The UUID of your current Linux (Ubuntu/Debian/etc) partition
UUID_HOST=""
# Filesystem type of your host (usually ext4, btrfs, or xfs)
SISTEMA_ARQUIVOS_HOST="ext4"
# ==================================================================
# --- Safety Check Extensivo ---
if [ -z "$UUID_LFS" ] || [ -z "$DISCO_INSTALACAO" ] || [ -z "$UUID_HOST" ] || [ -z "$PARTICAO_LFS" ] || [ -z "$SISTEMA_ARQUIVOS_HOST" ]; then
    echo "Error: You must edit the script and fill in all 5 UUID and DISK variables."
    echo "Run 'blkid' to get UUIDs and 'lsblk' to check the disk name."
    exit 1
fi

export LFS="/mnt/lfs"

if ! mountpoint -q "$LFS"; then
    echo "Error: LFS partition is not mounted at $LFS."
    echo "Please mount it first."
    exit 1
fi

echo "=== Starting Post-Configuration ==="

# ------------------------------------------------------------------
# 1. Re-bind API Filesystems
# ------------------------------------------------------------------
echo "-> Checking API filesystems..."
for fs in dev dev/pts proc sys run; do
    if ! mountpoint -q "$LFS/$fs"; then
        mount --bind "/$fs" "$LFS/$fs"
    fi
done

# ------------------------------------------------------------------
# 2. Configure System Keyboard Layout (Interactive)
# ------------------------------------------------------------------
echo ""
echo "-> Keyboard Layout Configuration"
echo "Common examples: us, es, br-abnt2, fr, de"
read -p "Enter the desired keyboard layout [Default: es]: " ESCOLHA_TECLADO

ESCOLHA_TECLADO=${ESCOLHA_TECLADO:-es}
echo "   -> Selected layout: $ESCOLHA_TECLADO"
echo ""

# ------------------------------------------------------------------
# 3. Auto-Detect Compiled Kernel
# ------------------------------------------------------------------
echo "-> Auto-detecting compiled LFS Kernel..."

ARQUIVO_KERNEL=$(ls "$LFS"/boot/vmlinuz-* 2>/dev/null | head -n 1)

if [ -z "$ARQUIVO_KERNEL" ]; then
    echo "   [ERROR] No kernel image found in $LFS/boot/."
    echo "   Did the kernel compilation fail in Phase 3?"
    exit 1
fi

NOME_KERNEL=$(basename "$ARQUIVO_KERNEL")
echo "   -> Kernel detected: $NOME_KERNEL"
echo ""

# ------------------------------------------------------------------
# 4. Create Internal Configuration Script
# ------------------------------------------------------------------
cat > "$LFS/source/internal_config.sh" << EOF
#!/bin/bash
set -e

echo "   [Chroot] Setting root password..."
echo "root:root" | chpasswd
echo "   -> Password set to 'root'"

echo "   [Chroot] Generating Basic Systemd Configurations..."
echo "chunguito" > /etc/hostname
echo "LANG=es_ES.UTF-8" > /etc/locale.conf
echo "KEYMAP=$ESCOLHA_TECLADO" > /etc/vconsole.conf

cat > /etc/resolv.conf << "DNS"
nameserver 8.8.8.8
nameserver 1.1.1.1
DNS

echo "   [Chroot] Configuring /etc/fstab..."
mkdir -pv /mnt/host_old

cat > /etc/fstab << "FSTAB"
# file system       mount-point    type    options             dump  fsck
UUID=$UUID_LFS      /              ext4    defaults            1     1
UUID=$UUID_HOST     /mnt/host_old  $SISTEMA_ARQUIVOS_HOST  defaults            0     0
tmpfs               /run           tmpfs   defaults            0     0
proc                /proc          proc    nosuid,noexec,nodev 0     0
sysfs               /sys           sysfs   nosuid,noexec,nodev 0     0
devpts              /dev/pts       devpts  gid=5,mode=620      0     0
FSTAB

echo "   [Chroot] Installing GRUB to $DISCO_INSTALACAO..."
grub-install $DISCO_INSTALACAO

echo "   [Chroot] Generating grub.cfg with Dual Boot..."
cat > /boot/grub/grub.cfg << "GRUB"
set default=0
set timeout=10

menuentry "LFS 12.3 (Linux From Scratch - Chunguito Version)" {
    insmod ext2
    insmod part_msdos
    insmod part_gpt

    search --no-floppy --fs-uuid --set=root $UUID_LFS
    linux /boot/vmlinuz-6.13.4-lfs root=PARTUUID=$PARTUUID_LFS ro nomodeset
}

menuentry "Original Linux Host (Chainload Config - Boring Debian)" {
    insmod ext2
    insmod part_msdos
    insmod part_gpt

    search --no-floppy --fs-uuid --set=root $UUID_HOST

    if [ -f /boot/grub/grub.cfg ]; then
        configfile /boot/grub/grub.cfg
    elif [ -f /boot/grub2/grub.cfg ]; then
        configfile /boot/grub2/grub.cfg
    else
        echo "Could not find Host GRUB config. Booting manually..."
        linux /boot/vmlinuz root=UUID=$UUID_HOST ro quiet
        initrd /boot/initrd.img
    fi
}
GRUB

echo "   [Chroot] Configuration Complete."
EOF

chmod +x "$LFS/source/internal_config.sh"

# ------------------------------------------------------------------
# 5. Execute inside Chroot
# ------------------------------------------------------------------

echo ""
echo "############################################################"
echo "# STARTING POST INSTALL PHASE  (User: Root in Chroot)      #"
echo "############################################################"

comando_chroot="cd source && ./internal_config.sh"

if chroot "$LFS" /usr/bin/env -i    \
    HOME=/root                   \
    TERM="$TERM"                 \
    PS1='(lfs chroot) \u:\w\$ '  \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin \
    DIR_LOGS=/logs               \
    DIR_SOURCES=/source          \
    /bin/bash --login -c "$comando_chroot" 2>&1 | tee "$DIR_LOGS/post_master.log"; then

    echo "   -> Chroot executed and configured successfully!"
else
    echo "   -> [ERROR] Failed to execute Chroot."
    exit 1
fi

rm -v "$LFS/source/internal_config.sh"

echo ""
echo "=== POST-INSTALLATION FINISHED ==="
echo "1. The root password is set to: root"
echo "B) Your new LFS Host OS is configured in GRUB as 'Linux From Scratch - Chunguito Version'"
echo "c. Your old Host OS is configured in GRUB as 'Chainload Config - Boring Debian'"
echo "IV. Your old Host partition will mount at /mnt/host_old"
echo ""
echo "You can now reboot into your new LFS system!"
