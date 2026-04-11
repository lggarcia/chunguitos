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
# ------------------------------------------------------------------
# File: construtor.sh
# Description: The main engine script. It parses the CSV, handles
#              source extraction, and dispatches the build to the
#              specific recipe function cleanly.
# ------------------------------------------------------------------

set -e

FASE_ALVO="$1"

if [ -z "$FASE_ALVO" ]; then
    echo "Error: Target phase not specified. Usage: $0 <phase_number>"
    exit 1
fi

arquivo_dados="pacotes.csv"
arquivo_receitas="receitas.sh"

if [ "$FASE_ALVO" = "1" ]; then
    diretorio_fontes="${LFS:-/mnt/lfs}/source"
    diretorio_logs="${LFS:-/mnt/lfs}/logs"
elif [ "$FASE_ALVO" = "2" ]; then
    diretorio_fontes="/source"
    diretorio_logs="/logs"
else
    echo "Error: Invalid phase. Must be 1 or 2."
    exit 1
fi

# ------------------------------------------------------------------
# Prepare some excencial files for building phase
# ------------------------------------------------------------------
mkdir -p "$diretorio_logs"

if [ ! -f "$arquivo_dados" ]; then
    echo "Error: Source file $arquivo_dados not found."
    exit 1
fi

if [ ! -f "$arquivo_receitas" ]; then
    echo "Error: Source file $arquivo_receitas not found."
    exit 1
fi

source "$arquivo_receitas"

# ------------------------------------------------------------------
# Prepare some excencial files for CHROOT environment (Phase 2)
# ------------------------------------------------------------------
preparar_arquivos_essenciais() {
    echo "=== Creating undamental User and Group files ==="

    cat > /etc/passwd << "EOF"
root:x:0:0:root:/root:/bin/bash
bin:x:1:1:bin:/dev/null:/usr/bin/false
daemon:x:6:6:Daemon User:/dev/null:/usr/bin/false
messagebus:x:18:18:D-Bus Message Daemon User:/run/dbus:/usr/bin/false
uuidd:x:80:80:UUID Generation Daemon User:/dev/null:/usr/bin/false
nobody:x:65534:65534:Unprivileged User:/dev/null:/usr/bin/false
EOF

    cat > /etc/group << "EOF"
root:x:0:
bin:x:1:daemon
sys:x:2:
kmem:x:3:
tape:x:4:
tty:x:5:
daemon:x:6:
floppy:x:7:
disk:x:8:
lp:x:9:
dialout:x:10:
audio:x:11:
video:x:12:
utmp:x:13:
usb:x:14:
cdrom:x:15:
adm:x:16:
messagebus:x:18:
input:x:24:
mail:x:34:
kvm:x:61:
uuidd:x:80:
wheel:x:97:
users:x:999:
nogroup:x:65534:
EOF

    echo "=== Inicializing Log Files ==="
    touch /var/log/{btmp,lastlog,faillog,wtmp}
    chgrp -v utmp /var/log/lastlog
    chmod -v 664  /var/log/lastlog
    chmod -v 600  /var/log/btmp
}

if [ "$FASE_ALVO" = "2" ]; then
    preparar_arquivos_essenciais
fi

# ------------------------------------------------------------------
# Function to extract source and remove previous dirty folders
# ------------------------------------------------------------------
preparar_e_extrair() {
    local nome_arquivo="$1"
    pasta_para_remover=$(tar -tf "$nome_arquivo" | head -1 | cut -f1 -d"/")

    if [ -n "$pasta_para_remover" ] && [ -d "$pasta_para_remover" ]; then
        echo "   [Engine] Removing old dirty directory: $pasta_para_remover"
	chmod -R u+rwx "$pasta_para_remover" 2>/dev/null || true
        rm -rf "$pasta_para_remover"
    fi

    echo "   [Engine] Extracting $nome_arquivo..."
    tar -xf "$nome_arquivo"
    cd "$pasta_para_remover"
    echo "   [Engine] Entering directory: $pasta_para_remover"
}

# ------------------------------------------------------------------
# Read CSV and compile loop
# ------------------------------------------------------------------
while IFS=',' read -r fase_instalacao id_receita nome_pacote versao_pacote arquivo_tarball _; do

    if [ -z "$fase_instalacao" ] || [[ "$fase_instalacao" == \#* ]]; then
        continue
    fi

    if [ "$fase_instalacao" != "$FASE_ALVO" ]; then
        continue
    fi

    echo ""
    echo "------------------------------------------------------------"
    echo "Processing: $nome_pacote $versao_pacote (Recipe: $id_receita)"
    echo "------------------------------------------------------------"

    cd "$diretorio_fontes"

    if [ ! -f "$arquivo_tarball" ]; then
        echo "Error: Source file $arquivo_tarball not found in $diretorio_fontes"
        exit 1
    fi

    preparar_e_extrair "$arquivo_tarball"

    LOG_FILE="$diretorio_logs/fase${FASE_ALVO}-${id_receita}.log"
    echo -n "   [Engine] Executing recipe: $id_receita... "

    if declare -f "$id_receita" > /dev/null; then
        if "$id_receita" > "$LOG_FILE" 2>&1; then
            echo -e "\e[32m[SUCCESS]\e[0m"
        else
            echo -e "\e[31m[FAILED]\e[0m"
            echo "      -> CRITICAL: Build failed for $nome_pacote."
            echo "      -> Read the log for details: $LOG_FILE"
            exit 1
        fi
    else
        echo -n "(Using generic fallback)... "
        if receita_generica > "$LOG_FILE" 2>&1; then
            echo -e "\e[32m[SUCCESS]\e[0m"
        else
            echo -e "\e[31m[FAILED]\e[0m"
            echo "      -> CRITICAL: Build failed for $nome_pacote."
            echo "      -> Read the log for details: $LOG_FILE"
            exit 1
        fi
    fi

    echo "   [Engine] Cleaning up build directory..."
    cd "$diretorio_fontes"

    pasta_para_remover=$(tar -tf "$arquivo_tarball" | head -1 | cut -f1 -d"/")

    if [ -n "$pasta_para_remover" ] && [ -d "$pasta_para_remover" ]; then
	chmod -R u+rwx "$pasta_para_remover" 2>/dev/null || true
        rm -rf "$pasta_para_remover"
    fi

done < "$arquivo_dados"
