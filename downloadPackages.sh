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

echo "=== LFS Package Downloader ==="
echo "Reading URLs from pacotes.csv and downloading missing files..."
echo ""

DIR_SOURCES="${LFS:-/mnt/lfs}/source"
CSV_FILE="pacotes.csv"

if [ ! -f "$CSV_FILE" ]; then
    echo -e "\e[31m[ERROR] Database '$CSV_FILE' not found!\e[0m"
    exit 1
fi

if [ ! -d "$DIR_SOURCES" ]; then
    echo "Creating directory $DIR_SOURCES..."
    mkdir -p "$DIR_SOURCES"
fi

# ==============================================================================
# SMART CSV PARSING
# ==============================================================================

mapfile -t URLS < <(awk -F',' '!/^#/ && NF>=6 {print $6}' "$CSV_FILE" | tr -d '\r' | sort -u)

EXPECTED_COUNT=${#URLS[@]}

echo "CSV Parsed Successfully. Found $EXPECTED_COUNT files to process."
echo ""

echo "-----------------------------------------------------"
echo "Starting processing of $EXPECTED_COUNT files..."
echo "-----------------------------------------------------"

for url in "${URLS[@]}"; do
    filename=$(basename "$url")
    filepath="$DIR_SOURCES/$filename"

    if [ -s "$filepath" ]; then
        echo -e "\e[32m[SKIP]\e[0m $filename already exists and is valid."
        continue
    fi

    if [ -f "$filepath" ]; then
        echo -e "\e[33m[WARNING]\e[0m Corrupted file detected: $filename. Removing..."
        rm -f "$filepath"
    fi

    echo -e "\e[34m[DOWNLOADING]\e[0m $filename..."
    wget -c -q --show-progress -P "$DIR_SOURCES" "$url"
    WGET_STATUS=$?

    if [ $WGET_STATUS -eq 0 ] && [ -s "$filepath" ]; then
        continue
    fi

    rm -f "$filepath"

    if [ $WGET_STATUS -eq 5 ]; then
        echo -e "\e[33m[WARNING]\e[0m SSL Certificate Error. \e[34m[RETRYING]\e[0m $filename (Insecure Mode)..."
        wget -c -q --show-progress --no-check-certificate -P "$DIR_SOURCES" "$url"

        if [ $? -ne 0 ] || [ ! -s "$filepath" ]; then
            echo -e "\e[31m[ERROR]\e[0m Failed even in insecure mode: $url"
            rm -f "$filepath"
        fi
    elif [ $WGET_STATUS -eq 8 ]; then
        echo -e "\e[31m[ERROR]\e[0m HTTP Error 404/403 (Broken Link or Not Found): $url"
    elif [ $WGET_STATUS -eq 4 ]; then
        echo -e "\e[31m[ERROR]\e[0m Network/DNS Error (Host down): $url"
    else
        echo -e "\e[31m[ERROR]\e[0m Download failed (Wget Code: $WGET_STATUS). URL: $url"
    fi
done

chown -R root: "$DIR_SOURCES"

echo ""
echo "-----------------------------------------------------"
echo "PACKAGE VERIFICATION"
echo "-----------------------------------------------------"

while true; do
    TOTAL_FOUND=$(find "$DIR_SOURCES" -maxdepth 1 -type f \( -name "*.tar.*" -o -name "*.patch" -o -name "*.tgz" \) | wc -l)

    if [ "$TOTAL_FOUND" -eq "$EXPECTED_COUNT" ]; then
        echo -e "\e[32m[OK] File count correct: $TOTAL_FOUND packages found.\e[0m"
        break
    else
        echo -e "\e[31m[ERROR] Incorrect count! Found $TOTAL_FOUND packages, expected $EXPECTED_COUNT.\e[0m"
        echo "Please check the logs above to see which links failed."
        echo -e "\e[33m[ACTION REQUIRED]\e[0m You can manually download the missing files to $DIR_SOURCES from another terminal."
        echo -e "\e[33m[ACTION REQUIRED].\e[0m DON'T forget to set permissions properly"

        read -p "Fix the issue and press ENTER to verify again (or Ctrl+C to abort)..."

        echo "Re-checking..."
    fi
done

echo ""
echo "Process finished."
