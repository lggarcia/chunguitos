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

set -e
set -o pipefail

# [USER ACTION REQUIRED]: Fill in the UUID below (run 'blkid' to find it)
UUID_PARTICAO=""

if [ "$EUID" -ne 0 ]; then
  echo "Error: Please run as root (sudo ./lgg-lfsIZADOR.sh)"
  exit 1
fi

# ------------------------------------------------------------------
# FUNCTION: CHECKPOINTS MANAGEMENT
# ------------------------------------------------------------------
verificar_etapa() {
    if [ -f "$DIR_STATUS/$1" ]; then
        echo -e "${GREEN}>> Step '$1' already completed. Skipping...${NC}"
        return 1
    fi
    echo -e "${YELLOW}>> Executing step: $1...${NC}"
    return 0
}

confirmar_etapa() {
    mkdir -p "$DIR_STATUS"
    touch "$DIR_STATUS/$1"
    echo -e "${GREEN}>> Step '$1' marked as finished.${NC}"
}

# ------------------------------------------------------------------
# FUNCTION: HOST SYSTEM REQUIREMENTS CHECK
# ------------------------------------------------------------------
verificar_requisitos_host() {

    echo -e "${YELLOW}== Preparing stuff for start ==${NC}"

    ALVO_SH=$(readlink -f /bin/sh)
    if [ "$ALVO_SH" != "/usr/bin/bash" ] && [ "$ALVO_SH" != "/bin/bash" ]; then
        echo -e "${CYAN}>> Redirecting /bin/sh to /bin/bash (LFS strict requirement)...${NC}"
        ln -sf /bin/bash /bin/sh
    fi

    ALVO_AWK=$(readlink -f /usr/bin/awk || echo "none")
    if [ "$ALVO_AWK" != "/usr/bin/gawk" ] && [ "$ALVO_AWK" != "/bin/gawk" ]; then
        echo -e "${CYAN}>> Redirecting awk to gawk...${NC}"
        ln -sf /usr/bin/gawk /usr/bin/awk
    fi

    if ! command -v yacc &> /dev/null; then
        echo -e "${CYAN}>> Creating yacc wrapper for bison...${NC}"
        cat > /usr/bin/yacc << "EOF"
#!/bin/sh
exec /usr/bin/bison -y "$@"
EOF
        chmod +x /usr/bin/yacc
    fi

    COMANDOS_VERIFICAR=("bison" "gawk" "m4" "makeinfo" "bash" "ld" "diff" "find" "gcc" "g++" "grep" "gzip" "make" "patch" "perl" "python3" "sed" "tar" "xz")

    echo -e "${CYAN}>> Checking all required host compilation tools...${NC}"

    FALTOU_ALGO=0
    for cmd in "${COMANDOS_VERIFICAR[@]}"; do
        if ! command -v "$cmd" &> /dev/null; then
            echo -e "${RED}[MISSING] Required tool: $cmd${NC}"
            FALTOU_ALGO=1
        fi
    done

    if [ $FALTOU_ALGO -eq 1 ]; then
        echo -e "${YELLOW}Some essential build tools for Linux From Scratch are missing.${NC}"
        read -p "Do you want the script to try installing them automatically? (y/N): " RESPOSTA

        if [[ "$RESPOSTA" =~ ^[Yy]$ ]]; then
            echo -e "${CYAN}Detecting package manager...${NC}"

            if command -v apt-get &> /dev/null; then
                echo -e "${GREEN}Debian/Ubuntu base detected (APT).${NC}"
                apt-get update && apt-get install -y build-essential bison gawk m4 texinfo coreutils bash binutils diffutils findutils gcc g++ grep gzip make patch perl python3 sed tar xz-utils
            elif command -v dnf &> /dev/null; then
                echo -e "${GREEN}Fedora/RHEL base detected (DNF).${NC}"
                dnf install -y @development-tools bison gawk m4 texinfo coreutils bash binutils diffutils findutils gcc gcc-c++ grep gzip make patch perl python3 sed tar xz
            elif command -v pacman &> /dev/null; then
                echo -e "${GREEN}Arch Linux base detected (Pacman).${NC}"
                pacman -Syu --noconfirm base-devel bison gawk m4 texinfo coreutils bash binutils diffutils findutils gcc grep gzip make patch perl python3 sed tar xz
            elif command -v zypper &> /dev/null; then
                echo -e "${GREEN}openSUSE base detected (Zypper).${NC}"
                zypper install -y -t pattern devel_basis
                zypper install -y bison gawk m4 texinfo coreutils bash binutils diffutils findutils gcc gcc-c++ grep gzip make patch perl python3 sed tar xz
            else
                echo -e "${RED}[ERROR] Could not detect a supported package manager.${NC}"
                echo -e "${RED}Aborting script. Please install manually.${NC}"
                exit 1
            fi

            for cmd in "${COMANDOS_VERIFICAR[@]}"; do
                if ! command -v "$cmd" &> /dev/null; then
                    echo -e "${RED}[ERROR] Auto-installation failed for '$cmd'. Aborting.${NC}"
                    exit 1
                fi
            done
            echo -e "${GREEN}[OK] All compilation tools installed successfully.${NC}"

            ln -sf /usr/bin/gawk /usr/bin/awk

        else
            echo -e "${RED}Aborting script. Please install the required compilation tools manually before running again.${NC}"
            exit 1
        fi
    else
        echo -e "${GREEN}[OK] All build tools are already installed.${NC}"
    fi

    echo -e "${CYAN}=== Checking Host System Requirements ===${NC}"

    export LC_ALL=C

    bail() { echo -e "${RED}FATAL: $1${NC}"; exit 1; }

    grep --version > /dev/null 2> /dev/null || bail "grep does not work"
    sed '' /dev/null || bail "sed does not work"
    sort /dev/null || bail "sort does not work"

    ver_check() {
        if ! type -p $2 &>/dev/null; then
            echo -e "${RED}ERROR: Cannot find $2 ($1)${NC}"; return 1;
        fi
        v=$($2 --version 2>&1 | grep -E -o '[0-9]+\.[0-9\.]+[a-z]*' | head -n1)
        if printf '%s\n' $3 $v | sort --version-sort --check &>/dev/null; then
            printf "${GREEN}OK:${NC} %-9s %-6s >= $3\n" "$1" "$v"; return 0;
        else
            printf "${RED}ERROR:${NC} %-9s is TOO OLD ($3 or later required)\n" "$1";
            return 1;
        fi
    }

    ver_kernel() {
        kver=$(uname -r | grep -E -o '^[0-9\.]+')
        if printf '%s\n' $1 $kver | sort --version-sort --check &>/dev/null; then
            printf "${GREEN}OK:${NC} Linux Kernel $kver >= $1\n"; return 0;
        else
            printf "${RED}ERROR:${NC} Linux Kernel ($kver) is TOO OLD ($1 or later required)\n" "$kver";
            return 1;
        fi
    }

    # --- Performing Checks ---
    ver_check Coreutils sort 8.1 || bail "Coreutils too old, stop"
    ver_check Bash bash 3.2
    ver_check Binutils ld 2.13.1
    ver_check Bison bison 2.7
    ver_check Diffutils diff 2.8.1
    ver_check Findutils find 4.2.31
    ver_check Gawk gawk 4.0.1
    ver_check GCC gcc 5.2
    ver_check "GCC (C++)" g++ 5.2
    ver_check Grep grep 2.5.1a
    ver_check Gzip gzip 1.3.12
    ver_check M4 m4 1.4.10
    ver_check Make make 4.0
    ver_check Patch patch 2.5.4
    ver_check Perl perl 5.8.8
    ver_check Python python3 3.4
    ver_check Sed sed 4.1.5
    ver_check Tar tar 1.22
    ver_check Texinfo texi2any 5.0
    ver_check Xz xz 5.0.0
    ver_kernel 5.4

    if mount | grep -q 'devpts on /dev/pts' && [ -e /dev/ptmx ]; then
        echo -e "${GREEN}OK:${NC} Linux Kernel supports UNIX 98 PTY";
    else
        echo -e "${RED}ERROR:${NC} Linux Kernel does NOT support UNIX 98 PTY";
        bail "PTY support missing";
    fi

    alias_check() {
        if $1 --version 2>&1 | grep -qi $2; then
            printf "${GREEN}OK:${NC} %-4s is $2\n" "$1";
        else
            printf "${RED}ERROR:${NC} %-4s is NOT $2\n" "$1";
        fi
    }
    echo "--- Aliases ---"
    alias_check awk GNU
    alias_check yacc Bison
    alias_check sh Bash

    echo "--- Compiler Check ---"
    if printf "int main(){}" | g++ -x c++ -; then
        echo -e "${GREEN}OK:${NC} g++ works";
    else
        echo -e "${RED}ERROR:${NC} g++ does NOT work";
        bail "g++ failed to compile a simple program";
    fi
    rm -f a.out

    echo ""
    echo -e "${GREEN}System Checks Passed.${NC}"
    echo "If you see any RED errors above (except maybe aliases), press Ctrl+C to stop."
    read -p "Press ENTER to continue building LFS..."
}

# ------------------------------------------------------------------
# Function: Prepare Host Environment
# ------------------------------------------------------------------
preparar_host() {
    echo "=== [Master] Preparing Host Environment ==="

    echo "   -> Creating Directory Hierarchy..."

    mkdir -pv $LFS/{boot,home,mnt,opt,srv,etc,var,var/log,tmp} $LFS/usr/{bin,lib,sbin}

    for i in bin lib sbin; do
        ln -svf usr/$i $LFS/$i
    done

    case $(uname -m) in
      x86_64) mkdir -pv $LFS/lib64 ;;
    esac

    mkdir -pv $LFS/tools

    mkdir -pv "$DIR_SOURCES" "$DIR_LOGS"

    chmod -v a+wt "$DIR_SOURCES"

    if ! getent group "$usuario_lfs" > /dev/null; then
        groupadd "$usuario_lfs"
    fi

    if ! id -u "$usuario_lfs" > /dev/null 2>&1; then
        useradd -s /bin/bash -g "$usuario_lfs" -m -k /dev/null "$usuario_lfs"
        echo "$usuario_lfs:$senha_lfs" | chpasswd
        echo "   -> User '$usuario_lfs' created."
    fi

    echo "   -> Setting permissions (Details saved to logs/permissoes.log)..."
    > "$DIR_LOGS/permissoes.log"

    chown -v "$usuario_lfs": $LFS/{usr{,/*},var,etc,tools} >> "$DIR_LOGS/permissoes.log"

    case $(uname -m) in
      x86_64) chown -v "$usuario_lfs": $LFS/lib64 >> "$DIR_LOGS/permissoes.log" ;;
    esac

    chown -vR "$usuario_lfs": "$DIR_SOURCES" "$DIR_LOGS" >> "$DIR_LOGS/permissoes.log"

    echo "   -> Copying scripts to $DIR_SOURCES..."
    for arquivo in "${arquivos_projeto[@]}"; do
        if [ -f "$arquivo" ]; then
            cp "$arquivo" "$DIR_SOURCES/"
            chmod +x "$DIR_SOURCES/$arquivo"
            chown -R "$usuario_lfs": "$DIR_SOURCES/$arquivo"
        else
            echo "Warning: Script '$arquivo' not found in current directory."
        fi
    done
}

# ------------------------------------------------------------------
# Function: Download Packages (Extracted for Checkpointing)
# ------------------------------------------------------------------
baixar_pacotes() {
    if verificar_etapa "download_pacotes"; then
        echo "=== [Master] Downloading Packages ==="

        if [ -f "./downloadPackages.sh" ]; then
            ./downloadPackages.sh
	    read -p "IF all packages were downloaded press ENTER to continue" 
            confirmar_etapa "download_pacotes"
        else
            echo -e "${RED}Error: downloadPackages.sh not found in current directory.${NC}"
            exit 1
        fi
    fi
}
# ------------------------------------------------------------------
# Function: Setup LFS User Environment (.bashrc/.bash_profile)
# ------------------------------------------------------------------
configurar_ambiente_usuario_lfs() {
local home_usuario="/home/$usuario_lfs"

    echo "=== [Master] Configuring .bashrc for user '$usuario_lfs' ==="

    cat > "$home_usuario/.bash_profile" << "EOF"
exec env -i HOME=$HOME TERM=$TERM PS1='\u:\w\$ ' /bin/bash
EOF

    cat > "$home_usuario/.bashrc" << EOF
set +h
umask 022
LFS=$LFS
LC_ALL=POSIX
LFS_TGT=$(uname -m)-lfs-linux-gnu
PATH=/usr/bin
if [ ! -L /bin ]; then PATH=/bin:\$PATH; fi
PATH=\$LFS/tools/bin:\$PATH
CONFIG_SITE=\$LFS/usr/share/config.site
export LFS LC_ALL LFS_TGT PATH CONFIG_SITE DIR_STATUS
alias lss='ls -claksh'
EOF

    chown "$usuario_lfs": "$home_usuario/.bash_profile" "$home_usuario/.bashrc"
}

# ------------------------------------------------------------------
# Function: Phase 1 Execution (As LFS User)
# ------------------------------------------------------------------
executar_fase_1() {
    if verificar_etapa "fase_1"; then
        echo ""
        echo "############################################################"
        echo "# STARTING PHASE 1: Cross-Toolchain (User: $usuario_lfs) #"
        echo "############################################################"

        su "$usuario_lfs" -s /bin/bash -c "env -i HOME=/home/$usuario_lfs TERM=$TERM PS1='(lfs) \u:\w\$ ' /bin/bash -c 'source /home/$usuario_lfs/.bashrc && bash $DIR_SOURCES/construtor.sh 1'"

        if [ -f "$LFS/tools/bin/$LFS_TGT-gcc" ]; then
            confirmar_etapa "fase_1"
        else
            echo -e "${RED}CRITICAL: Phase 1 seemed to fail (GCC not found). Stopping.${NC}"
            exit 1
        fi
    fi
}
# ------------------------------------------------------------------
# Function: Prepare Virtual Kernel Filesystems (Bind Mounts)
# ------------------------------------------------------------------
preparar_chroot_mounts() {
    echo ""
    echo "=== [Master] Mounting Virtual Kernel Filesystems ==="

    mkdir -pv $LFS/{dev,proc,sys,run}

    if ! mountpoint -q "$LFS/dev"; then
        mount -v --bind /dev $LFS/dev
    fi
    if ! mountpoint -q "$LFS/dev/pts"; then
        mount -v --bind /dev/pts $LFS/dev/pts
    fi
    if ! mountpoint -q "$LFS/proc"; then
        mount -vt proc proc $LFS/proc
    fi
    if ! mountpoint -q "$LFS/sys"; then
        mount -vt sysfs sysfs $LFS/sys
    fi
    if ! mountpoint -q "$LFS/run"; then
        mount -vt tmpfs tmpfs $LFS/run
    fi

    if [ -h $LFS/dev/shm ]; then
        mkdir -pv $LFS/$(readlink $LFS/dev/shm)
    fi
}
# ------------------------------------------------------------------
# Function: Phase 2 Execution (As Root inside Chroot)
# ------------------------------------------------------------------
executar_fase_2() {
    if verificar_etapa "fase_2"; then
    echo ""
    echo "############################################################"
    echo "# STARTING PHASE 2: Final System (User: Root in Chroot)    #"
    echo "############################################################"

        local comando_chroot="cd source && ./construtor.sh 2"

        if chroot "$LFS" /usr/bin/env -i    \
            HOME=/root                   \
            TERM="$TERM"                 \
            PS1='(lfs chroot) \u:\w\$ '  \
            PATH=/bin:/usr/bin:/sbin:/usr/sbin \
            DIR_LOGS=/logs               \
            DIR_SOURCES=/source          \
            /bin/bash --login -c "$comando_chroot" 2>&1 | tee "$DIR_LOGS/fase2_master.log"; then

            confirmar_etapa "fase_2"
        else
            return 1
        fi
    fi
}
# ==================================================================
# MAIN FLOW
# ==================================================================

export LFS="/mnt/lfs"
usuario_lfs="lfs"
senha_lfs="lfs"
arquivos_projeto=("construtor.sh" "downloadPackages.sh" "lgg-lfsIZADOR.sh" "pacotes.csv" "post-lfsIZADOR.sh" "receitas.sh")
DIR_SOURCES="$LFS/source"
DIR_LOGS="$LFS/logs"
export LFS_TGT=$(uname -m)-lfs-linux-gnu
DIR_STATUS="$LFS/logs/status"

verificar_requisitos_host

if [ -z "$UUID_PARTICAO" ]; then
    echo "Error: Variable 'UUID_PARTICAO' is empty. Please edit the script."
    exit 1
fi

if [ ! -d "$LFS" ]; then
    mkdir -pv "$LFS"
fi

if ! grep -q "$UUID_PARTICAO" /etc/fstab; then
    echo "Adding entry to /etc/fstab..."
    echo "UUID=$UUID_PARTICAO $LFS ext4 defaults 1 1" >> /etc/fstab
else
    echo "Entry for UUID already exists in /etc/fstab."
fi

if ! mountpoint -q "$LFS"; then
    echo "Mounting $LFS..."
    mount "$LFS"
fi

# --- Sanity Checks for Directories ---
if [ ! -d "$DIR_SOURCES" ]; then
    echo "Creating directory: $DIR_SOURCES"
    mkdir -pv "$DIR_SOURCES"
fi

preparar_host

baixar_pacotes

configurar_ambiente_usuario_lfs

echo "   -> Performing deep clean of leftover source directories..."
find "$DIR_SOURCES" -mindepth 1 -maxdepth 1 -type d -exec rm -rf {} +

executar_fase_1

echo "=== [Master] Changing ownership to root ==="
chown -R root:root $LFS/{usr,lib,var,etc,bin,sbin,tools,source,logs,logs/status}
case $(uname -m) in
  x86_64) chown -R root:root $LFS/lib64 ;;
esac

preparar_chroot_mounts

if ! executar_fase_2; then
    echo ""
    echo -e "${RED}############################################################${NC}"
    echo -e "${RED} CRITICAL ERROR: Phase 2 failed! Process interrupted.       ${NC}"
    echo -e "${RED}############################################################${NC}"
    exit 1
fi

# ==================================================================
# === LFS AUTOMATION FINISHED ===
# ==================================================================

# ------------------------------------------------------------------
# Function: Weight management (you're too fat)
# ------------------------------------------------------------------
# 6. Stripping de Binários e Bibliotecas
echo "=== [Master] Stripping Binaries (Diet LFS) ==="
if chroot "$LFS" /usr/bin/env -i \
    PATH=/bin:/usr/bin:/sbin:/usr/sbin \
    /bin/bash -c "
    echo '   -> Removing debug symbols to save space...'
    #find /usr/lib -type f -name '*.so*' -exec strip --strip-unneeded {} '+' 2>/dev/null || true
    #find /usr/lib -type f -name '*.a' -exec strip --strip-debug {} '+' 2>/dev/null || true
    #find /usr/bin /usr/sbin -type f -exec sh -c 'file \"\$@\" | grep -q ELF && strip --strip-unneeded \"\$@\"' sh {>

    find /usr/lib -type f -name '*.a' -exec strip --strip-debug {} '+' 2>/dev/null || true
    find /usr/bin /usr/sbin -type f -exec sh -c 'for arquivo in \"\$@\"; do if file \"\$arquivo\" | grep -q ELF; th>
    echo '   -> Stripping complete!'
    "; then
    echo "   -> [OK] Diet LFS applied successfully."
else
    echo "   -> [WARNING] Non-fatal error during stripping phase."
fi

# ==================================================================
# RELATÓRIO FINAL E PRÓXIMOS PASSOS
# ==================================================================
echo ""
echo -e "${GREEN}============================================================${NC}"
echo -e "${GREEN}       LFS AUTOMATION FINISHED SUCCESSFULLY!                ${NC}"
echo -e "${GREEN}============================================================${NC}"
echo ""
echo -e "${YELLOW}[IMPORTANT NOTICE ABOUT THE KERNEL]${NC}"
echo "The kernel was compiled using a generic configuration ('defconfig')."
echo "It should boot on most virtual machines and standard PCs."
echo "However, if you need specific drivers (WiFi, Nvidia, Sound), you should:"
echo "  1. Enter chroot manually."
echo "  2. Go to /sources/linux-6.13.4"
echo "  3. Run 'make menuconfig' and select your drivers."
echo "  4. Run 'make && make modules_install' again."
echo "  5. Copy the new bzImage to /boot."
echo ""
echo -e "${CYAN}[NEXT STEP]${NC}"
echo "Now you MUST configure the Bootloader and Password."
echo "Please run the post-installation script:"
echo ""
echo -e "   ${WHITE}sudo ./post-lfsIZADOR.sh${NC}"
echo ""
