#!/bin/bash
####################################
#       __    ______  ______       #
#      |  |  |  ____||  ____|      #
#      |  |  | | __  | | __        #
#      |  |__| ||_ | | ||_ |       #
#      |_____|\____| |_____|       #
# -------------------------------- #
#   >> https://lucianogg.info      #
####################################
#     Script p/ LFS Project        #
####################################

BLACK='\033[0;30m'
WHITE='\033[1;37m'
RED='\033[0;31m'
RED_LIGHT='\033[1;31m'
GREEN='\033[0;32m'
GREEN_LIGHT='\033[1;32m'
ORANGE='\033[0;33m'
BLUE='\033[0;34m'
BLUE_LIGHT='\033[1;34m'
CYAN='\033[0;36m'
CYAN_LIGHT='\033[1;36m'
YELLOW='\033[1;33m'
PURPLE='\033[0;35m'
PURPLE_LIGHT='\033[1;35m'
GRAY_LIGHT='\033[0;37m'
GRAY_DARK='\033[1;30m'
NC='\033[0m' # No Color

echo ""
echo -e "${GREEN}###############################${GRAY_DARK}#${NC}"
echo -e "${GREEN}# ${YELLOW}LL${GRAY_DARK}L           ${BLUE}GGGGGGG${GRAY_DARK}G     ${GREEN} #${GRAY_DARK}##${NC}"
echo -e "${GREEN}# ${YELLOW}LL${GRAY_DARK}L           ${BLUE}GG${GRAY_DARK}G          ${GREEN} #${GRAY_DARK}###${NC}"
echo -e "${GREEN}# ${YELLOW}LL${GRAY_DARK}L           ${BLUE}GG${GRAY_DARK}G ${BLUE}GGGG${GRAY_DARK}G     ${GREEN}#${GRAY_DARK}###${NC}"
echo -e "${GREEN}# ${YELLOW}LL${GRAY_DARK}L           ${BLUE}GG${GRAY_DARK}G   ${BLUE}GG${GRAY_DARK}G     ${GREEN}#${GRAY_DARK}###${NC}"
echo -e "${GREEN}# ${YELLOW}LLLLLLL${GRAY_DARK}L ${WHITE} X${GRAY_DARK}X  ${BLUE}GGGGGGGG${GRAY_DARK}G  ${WHITE}X${GRAY_DARK}X ${GREEN}#${GRAY_DARK}###${NC}"
echo -e "${GREEN}###############################${GRAY_DARK}###${NC}"
echo -e "${GREEN}#       ${WHITE}LUCIANOGG.INFO        ${GREEN}#${GRAY_DARK}###${NC}"
echo -e "${GREEN}###############################${GRAY_DARK}###${NC}"
echo -e "${GRAY_DARK}##################################${NC}"
echo -e "${GRAY_DARK} #################################${NC}"
echo ""

if [ "$EUID" -ne 0 ]; then
  echo -e "${RED}Error: Please run as root (sudo ./arrastao.sh)${NC}"
  exit 1
fi

# ==============================
#  HOST DEPENDENCY VERIFICATION 
# ==============================
DEPENDENCIAS=("wget" "parted" "lsblk" "blkid" "mkfs.ext4")
PACOTES_INSTALAR="wget parted util-linux e2fsprogs"
FALTOU_ALGO=0

for cmd in "${DEPENDENCIAS[@]}"; do
    if ! command -v "$cmd" &> /dev/null; then
        echo -e "${RED}[ERROR] Required command '$cmd' not found in the system.${NC}"
        FALTOU_ALGO=1
    fi
done

if [ $FALTOU_ALGO -eq 1 ]; then
    echo ""
    echo -e "${YELLOW}Some required base tools are missing.${NC}"
    read -p "Do you want the script to try installing them automatically? (y/N): " RESPOSTA

    if [[ "$RESPOSTA" =~ ^[Yy]$ ]]; then
        echo -e "${CYAN}Detecting package manager...${NC}"

        if command -v apt-get &> /dev/null; then
            echo -e "${GREEN}Debian/Ubuntu base detected (APT).${NC}"
            apt-get update && apt-get install -y $PACOTES_INSTALAR
        elif command -v dnf &> /dev/null; then
            echo -e "${GREEN}Fedora/RHEL base detected (DNF).${NC}"
            dnf install -y $PACOTES_INSTALAR
        elif command -v pacman &> /dev/null; then
            echo -e "${GREEN}Arch Linux base detected (Pacman).${NC}"
            pacman -Syu --noconfirm $PACOTES_INSTALAR
        elif command -v zypper &> /dev/null; then
            echo -e "${GREEN}openSUSE base detected (Zypper).${NC}"
            zypper install -y $PACOTES_INSTALAR
        else
            echo -e "${RED}[ERROR] Could not detect a supported package manager. Please install manually: $PACOTES_INSTALAR${NC}"
            exit 1
        fi

        for cmd in "${DEPENDENCIAS[@]}"; do
            if ! command -v "$cmd" &> /dev/null; then
                echo -e "${RED}[ERROR] Auto-installation failed for '$cmd'. Aborting.${NC}"
                exit 1
            fi
        done
        echo -e "${GREEN}[OK] All base tools installed successfully.${NC}"
    else
        echo -e "${RED}Aborting script. Please install the following packages manually:${NC} ${PACOTES_INSTALAR}"
        exit 1
    fi
else
    echo -e "${GREEN}[OK] All base tools detected.${NC}"
fi
# ==============================

#URL_BASE="DEPRECATED"

#FILES=(
#    "construtor.sh"
#    "downloadPackages.sh"
#    "lgg-lfsIZADOR.sh"
#    "pacotes.csv"
#    "post-lfsIZADOR.sh"
#    "receitas.sh"
#)

ARQUIVO_1="lgg-lfsIZADOR.sh"
ARQUIVO_2="post-lfsIZADOR.sh"

echo "-----------------------------------------------------"
echo "Starting download of LFS project scripts..."
echo "Source: $URL_BASE"
echo "-----------------------------------------------------"

#for file in "${FILES[@]}"; do
#    echo ">> Downloading: $file"

#    wget -q --show-progress "$URL_BASE/$file" -O "$file"

#    if [ $? -eq 0 ]; then
#        echo -e "\e[32m[Success]\e[0m $file downloaded."
#    else
#        echo -e "\e[31m[Error]\e[0m Failed to download $file. Check the URL."
#        rm -f "$file"
#    fi
#done

echo ""
echo "-----------------------------------------------------"
echo "Applying execution permissions (+x)..."
chmod +x *.sh
echo "Done."
ls -lh --color=auto

echo "-----------------------------------------------------"
echo " LFS DISK PREPARATION & CONFIGURATION"
echo "-----------------------------------------------------"

echo "Current Disks:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINT
echo "-----------------------------------------------------"

echo "STEP 1: Format LFS Target Disk"
read -p "Which physical device do you want to use for LFS? (e.g., /dev/sdb): " DISCO_ALVO

# SAFETY CHECK
echo -e "${RED}WARNING: This will ERASE ALL DATA on $DISCO_ALVO.${NC}"
echo -e "${ORANGE}IF YOU TRUST MY POOR SCRIPTING ABILITIES, GO AHEAD. YOU'VE BEEN WARNED!!!${NC}"
echo -e "${ORANGE}ELSE, just edit $ARQUIVO_1 and $ARQUIVO_2 then run $ARQUIVO_1 yourself.${NC}"
echo -ne "${RED}Are you sure you want to proceed? (${GREEN}yes${RED}/no): ${NC}"
read CONFIRMACAO
echo -ne "${RED}SURE? (${GREEN}yes${RED}/no): ${NC}"
read CONFIRMACAO2

if [ "$CONFIRMACAO" != "yes" ] || [ "$CONFIRMACAO2" != "yes" ]; then
    echo "Aborting operation. Both confirmations must be 'yes'."
    exit 1
fi

echo "-----------------------------------------------------"
echo "Creating GPT Partition Table on $DISCO_ALVO..."

parted -s "$DISCO_ALVO" mklabel gpt

echo "Creating BIOS Boot Partition for GRUB..."
parted -s "$DISCO_ALVO" mkpart primary 1MiB 3MiB
parted -s "$DISCO_ALVO" set 1 bios_grub on

echo "Creating Main LFS Partition..."
parted -s "$DISCO_ALVO" mkpart primary ext4 3MiB 100%

sleep 2

if [[ "$DISCO_ALVO" =~ [0-9]$ ]]; then
    PARTICAO_LFS="${DISCO_ALVO}p2"
else
    PARTICAO_LFS="${DISCO_ALVO}2"
fi

echo "Formatting $PARTICAO_LFS to ext4..."
mkfs.ext4 -F -q "$PARTICAO_LFS"

if [ $? -eq 0 ]; then
    echo "Format successful!"

    DADO_UUID_LFS=$(blkid -s UUID -o value "$PARTICAO_LFS")
    DADO_PARTUUID_LFS=$(blkid -s PARTUUID -o value "$PARTICAO_LFS")
    echo " > Detected new LFS UUID: $DADO_UUID_LFS"
    echo " > Detected new LFS PARTUUID: $DADO_PARTUUID_LFS"

    DADO_DISCO="$DISCO_ALVO"
    echo " > Target disk for GRUB installation: $DADO_DISCO"
else
    echo "ERROR: Formatting failed. Please check the device name."
    exit 1
fi

echo "-----------------------------------------------------"
echo "STEP 2: Host Configuration"
echo "-----------------------------------------------------"

echo ""
echo "Current Disks:"
lsblk -o NAME,SIZE,TYPE,FSTYPE,UUID,MOUNTPOINT
echo "-----------------------------------------------------"

read -p "Paste here the HOST System PARTITION (current Linux, e.g., /dev/sda1) for dual-boot entry: " DADOS_UUID_PART

DADO_UUID_HOST=$(blkid -s UUID -o value "$DADOS_UUID_PART")
DADO_FS_HOST=$(blkid -s TYPE -o value "$DADOS_UUID_PART")

if [ -z "$DADO_UUID_HOST" ]; then
    echo -e "${RED}[ERROR] Invalid partition or no UUID found on '$DADOS_UUID_PART'. Aborting.${NC}"
    exit 1
fi

echo " > Host UUID detected: $DADO_UUID_HOST"
echo " > Host Filesystem detected: $DADO_FS_HOST"

echo "-----------------------------------------------------"

if [ -f "$ARQUIVO_1" ]; then
    echo "Configuring $ARQUIVO_1..."
    sed -i "s|^UUID_PARTICAO=.*|UUID_PARTICAO=\"$DADO_UUID_LFS\"|" "$ARQUIVO_1"
else
    echo "WARNING: $ARQUIVO_1 not found."
fi

if [ -f "$ARQUIVO_2" ]; then
    echo "Configuring $ARQUIVO_2..."
    sed -i "s|^UUID_LFS=.*|UUID_LFS=\"$DADO_UUID_LFS\"|" "$ARQUIVO_2"
    sed -i "s|^PARTUUID_LFS=.*|PARTUUID_LFS=\"$DADO_PARTUUID_LFS\"|" "$ARQUIVO_2"
    sed -i "s|^PARTICAO_LFS=.*|PARTICAO_LFS=\"$PARTICAO_LFS\"|" "$ARQUIVO_2"
    sed -i "s|^DISCO_INSTALACAO=.*|DISCO_INSTALACAO=\"$DADO_DISCO\"|" "$ARQUIVO_2"
    sed -i "s|^UUID_HOST=.*|UUID_HOST=\"$DADO_UUID_HOST\"|" "$ARQUIVO_2"
    sed -i "s|^SISTEMA_ARQUIVOS_HOST=.*|SISTEMA_ARQUIVOS_HOST=\"$DADO_FS_HOST\"|" "$ARQUIVO_2"
else
    echo "WARNING: $ARQUIVO_2 not found."
fi

echo "-----------------------------------------------------"
echo "All done. Drive formatted, partitioned and scripts configured."
echo "-----------------------------------------------------"

echo ""
echo -e "\e[1;32m"
echo "##########################################################"
echo "#                                                        #"
echo "#   DOWNLOAD & PREPARATION COMPLETE!                     #"
echo "#                                                        #"
echo "#   IMPORTANT:                                           #"
echo "#   To start the installation, you MUST run as ROOT:     #"
echo "#                                                        #"
echo "#   ./lgg-lfsIZADOR.sh                                   #"
echo "#                                                        #"
echo "##########################################################"
echo -e "\e[0m"
