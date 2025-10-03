#!/bin/sh
#
# Copyright (C) 2025-26 https://github.com/ArKT-7/Auto-Installer-Forge
#
# Made For Processing ROMs containing payload.bin, converts them into a ready-to-flash super.img, and generates a fully automated installation package for Fastboot or Recovery, which can later be flashed using my custom flasher scripts.

# Define URLs and target paths for binaries
BASE_URL="https://raw.githubusercontent.com/arkt-7/Auto-Installer-Forge/main"
URL_BUSYBOX="$BASE_URL/bin/linux_amd64/busybox"
URL_PAYLOAD_DUMPER="$BASE_URL/bin/linux_amd64/payload-dumper-go"
URL_LPMAKE="$BASE_URL/bin/linux_amd64/lpmake"
URL_LPUNPACK="$BASE_URL/bin/linux_amd64/lpunpack"

BIN_DIR="$HOME/Auto-Installer-Forge/bin"
WORK_DIR="$HOME/Auto-Installer-Forge/out"
MAGISK_DIR="$BIN_DIR/magisk_patch"

#mkdir -p "$BIN_DIR"
mkdir -p "$MAGISK_DIR"
mkdir -p "$WORK_DIR"

log() {
    echo -e -e "\n[$(date +"%H:%M:%S")] $1"
}

# Function to download and set permissions
download_and_set_permissions() {
    local url=$1 dest_file=$2
    log "[INFO] Downloading $(basename "$dest_file")..."
    curl -L -# -o "$dest_file" "$url" || { log "[ERROR] Failed to download $(basename "$dest_file")"; exit 1; }
    chmod +x "$dest_file"
    echo -e "[SUCCESS] $(basename "$dest_file") ready."
}

# Function to download files without setting permissions
download_file() {
    local url=$1 dest_file=$2
    #echo -e "[INFO] Downloading $(basename "$dest_file")..."
    curl -L -# -o "$dest_file" "$url" || { log "[ERROR] Failed to download $(basename "$dest_file")"; }
    echo -e "[SUCCESS] $(basename "$dest_file") downloaded."
}

# Function to extract checksum from file
get_checksum() {
    local filename="$1"
    if [ "$CHECKSUM_AVAILABLE" -eq 0 ]; then
        echo -e ""
        return
    fi
    grep "^$filename=" "$CHECKSUM_FILE" | cut -d'=' -f2
}


# Function to verify checksum
verify_checksum() {
    local file="$1"
    local expected_checksum="$2"

    if [ "$CHECKSUM_AVAILABLE" -eq 0 ]; then
        #echo -e "[WARNING] Checksum verification skipped for $(basename "$file")."
        return 0
    fi

    if [ -z "$expected_checksum" ]; then
        echo -e "[WARNING] No checksum found for $(basename "$file"), skipping verification."
        return 0  # Skip verification if no checksum is available
    fi

    local actual_checksum
    actual_checksum=$($BIN_DIR/busybox sha256sum "$file" | awk '{print $1}')

    if [ "$actual_checksum" = "$expected_checksum" ]; then
        #echo -e "[SUCCESS] Checksum verified for $(basename "$file")."
        return 0
    else
        echo -e "\n[ERROR] Checksum mismatch for $(basename "$file")! Expected: $expected_checksum, Got: $actual_checksum"
        return 1
    fi
}

# Function to attempt download with checksum validation
download_with_fallback() {
    PRIMARY_URL="$1"
    FALLBACK_URL="$2"
    DEST_FILE="$3"
    FILE_KEY="$4"  # Key name in checksum file

    #echo -e "[INFO] Downloading: $(basename "$DEST_FILE")"

    EXPECTED_CHECKSUM=$(get_checksum "$FILE_KEY")

    if download_file "$PRIMARY_URL" "$DEST_FILE"; then
        if verify_checksum "$DEST_FILE" "$EXPECTED_CHECKSUM"; then
            return 0  # Download successful with valid checksum
        else
            echo -e "[WARNING] Checksum mismatch, trying fallback...\n"
            rm -f "$DEST_FILE"
        fi
    else
        echo -e "[WARNING] Primary download failed, trying fallback...\n"
    fi

    # Try downloading from fallback source
    if download_file "$FALLBACK_URL" "$DEST_FILE"; then
        if verify_checksum "$DEST_FILE" "$EXPECTED_CHECKSUM"; then
            return 0  # Fallback successful with valid checksum
        else
            echo -e "[ERROR] Fallback checksum mismatch! Continuing with warning...\n"
            return 1
        fi
    else
        echo -e "[ERROR] Failed to download $(basename "$DEST_FILE") from both sources! Continuing..."
        return 1
    fi
}

# Function to patch boot.img with magisk
patch_magisk_boot() {
    log "[INFO] Patching boot.img with Magisk..\n"

    # Unzip only assets and lib folders; if unzip fails, exit
    if ! $BIN_DIR/busybox unzip -q -o "$TARGET_DIR/ROOT_APK_INSATLL_THIS_ONLY/$1" "assets/*" "lib/*" -d "$MAGISK_DIR"; then
        log "[ERROR] Failed to unzip Magisk APK"
        return 1
    fi

    ARCH_DIR="x86_64"

    LIB_PATH="$MAGISK_DIR/lib/$ARCH_DIR"
    if [ -d "$LIB_PATH" ]; then
        for file in "$LIB_PATH"/*.so; do
            [ -f "$file" ] || continue
            new_name=$(basename "$file" | $BIN_DIR/busybox sed -E 's/^lib(.*)\.so$/\1/')
            mv "$file" "$MAGISK_DIR/assets/$new_name"
        done
    else
        log "[ERROR] Library folder not found for $ARCH_DIR"
        return 1
    fi

    chmod -R +x "$MAGISK_DIR/assets/"

    #$BIN_DIR/busybox sed -i -e 's/API=$(grep_get_prop ro.build.version.sdk)/API=33/' \
    #   -e 's/ABI=$(grep_get_prop ro.product.cpu.abi)/ABI=x86_64/' "$MAGISK_DIR/assets/util_functions.sh"

    #$BIN_DIR/busybox sed -i '1 s|^.*$|#!/bin/bash|' "$MAGISK_DIR/assets/boot_patch.sh"
    #$BIN_DIR/busybox sed -i 's/ui_print/echo -e/g' "$MAGISK_DIR/assets/boot_patch.sh"
    # Modify boot_patch.sh to hardcode "sda19" for NABU
    if ! $BIN_DIR/busybox sed -i 's/\$BOOTMODE && \[ -z "\$PREINITDEVICE" \] && PREINITDEVICE=\$(\.\/magisk --preinit-device)/PREINITDEVICE="sda19"/' "$MAGISK_DIR/assets/boot_patch.sh"; then
        log "[ERROR] Failed to modify boot_patch.sh"
        return 1
    fi

    "$MAGISK_DIR/assets/boot_patch.sh" "$TARGET_DIR/images/boot.img"

    if [ -f "$MAGISK_DIR/assets/new-boot.img" ]; then
        $BIN_DIR/busybox cp "$MAGISK_DIR/assets/new-boot.img" "$TARGET_DIR/images/magisk_boot.img"
        log "[SUCCESS] Patching successful! Magisk boot image saved at: $TARGET_DIR/images/magisk_boot.img"
    else
        log "[ERROR] Patching unsuccessful. Please patch manually and add to /images folder..."
        return 1
    fi
    return 0
}

# Function to prompt and update a single config field
update_field() {
    field="$1"
    label="$2"
    line=$(grep "^$field=" "$CONF_FILE")

    value=$(echo -e "$line" | $BIN_DIR/busybox sed -n "s/^$field=\"\([^\"]*\)\".*/\1/p")

    comment=$(echo -e "$line" | $BIN_DIR/busybox sed -n "s/^$field=\"[^\"]*\"[[:space:]]*\(.*\)/\1/p")

    echo -e "Current $label: $value"
    printf "Enter new $label (leave blank to keep current): "
    read new_value

    [ -z "$new_value" ] && new_value="$value"

    escaped_new_value=$(printf '%s\n' "$new_value" | $BIN_DIR/busybox sed 's/[&/\]/\\&/g')

    new_line="$field=\"${escaped_new_value}\""
    [ -n "$comment" ] && new_line="$new_line $comment"

    $BIN_DIR/busybox sed -i "s|^$field=.*|$new_line|" "$CONF_FILE"

    echo -e "$label updated to: $new_value\n"
}

# Start payload zip selector
get_payload_zip_path() {
    echo -e "\nPlease enter the full path to an AOSP ROM ZIP file or a folder containing multiple ROM ZIPs:\n"
    read -r INPUT_PATH
    echo -e " "

    INPUT_PATH=$(echo "$INPUT_PATH" | sed 's:^~:'"$HOME"':' | sed 's:/*$::')

    [ -z "$INPUT_PATH" ] && {
        log "[INFO] No input provided. Exiting...\n"
        exit 1
    }

    candidate_zips=()
    count=0

    if [ -d "$INPUT_PATH" ]; then
        log "[INFO] Searching for payload-containing ZIP files in the specified folder..."
        for zip in $(find "$INPUT_PATH" -type f -name "*.zip"); do
            if $BIN_DIR/busybox unzip -l "$zip" | $BIN_DIR/busybox grep -q "payload.bin"; then
                candidate_zips[count]="$zip"
                count=$((count + 1))
            fi
        done

    elif [ -f "$INPUT_PATH" ]; then
        case "$INPUT_PATH" in
            *.zip)
                log "[INFO] Checking the specified ZIP file for payload.bin..."
                if $BIN_DIR/busybox unzip -l "$INPUT_PATH" | $BIN_DIR/busybox grep -q "payload.bin"; then
                    candidate_zips[0]="$INPUT_PATH"
                    count=1
                fi
                ;;
            *)
                log "[ERROR] The specified file is not a .zip file. Please provide a valid ZIP archive."
                return 1
                ;;
        esac
    else
        log "[ERROR] The specified path is invalid. Please try again."
        return 1
    fi

    if [ "$count" -eq 0 ]; then
        log "[ERROR] No valid ZIP files containing payload.bin were found."
        return 1

    elif [ "$count" -eq 1 ]; then
        log "[SUCCESS] Matching ZIP file found."
        SELECTED_ZIP_FILE="${candidate_zips[0]}"
        return 0
    else
        echo -e "\n[INFO] Multiple ZIP files containing payload.bin were found:\n"
        for i in $(seq 0 $((count - 1))); do
            index=$((i + 1))
            echo -e "$index) ${candidate_zips[$i]}"
        done

        valid=0
        while [ "$valid" -eq 0 ]; do
            echo -e "\nPlease enter the number corresponding to the ZIP file to use (1 - $count): "
            read -r selection
            if echo "$selection" | grep -qE '^[0-9]+$'; then
                index=$((selection - 1))
                if [ "$index" -ge 0 ] && [ "$index" -lt "$count" ]; then
                    SELECTED_ZIP_FILE="${candidate_zips[$index]}"
                    valid=1
                else
                    echo -e "[ERROR] Invalid selection. Please enter a valid number between 1 and $count."
                fi
            else
                echo -e "[ERROR] Invalid selection. Please enter a valid number between 1 and $count."
            fi
        done
    fi
    return 0
}


echo -e "\nAutomating ROM conversion for easy Fastboot/Recovery flashing for Xiaomi Pad 5 (more devices planned)\n"
echo -e "This script is Written and Made By °⊥⋊ɹ∀°, Telegram - '@ArKT_7', Github - 'ArKT-7'\n"

AVAILABLE_SPACE=$(df "$WORK_DIR" | awk 'NR==2 {print $4}')
if [ "$AVAILABLE_SPACE" -lt 15000000 ]; then
    log "[ERROR] Not enough space. Need at least 15GB free!"
    exit 1
fi

# Download required binaries
download_and_set_permissions "$URL_BUSYBOX" "$BIN_DIR/busybox"
download_and_set_permissions "$URL_PAYLOAD_DUMPER" "$BIN_DIR/payload-dumper-go"
download_and_set_permissions "$URL_LPMAKE" "$BIN_DIR/lpmake"
download_and_set_permissions "$URL_LPUNPACK" "$BIN_DIR/lpunpack"
# URL to the checksum file
CHECKSUM_FILE="$BIN_DIR/checksum.arkt"
CHECKSUM_AVAILABLE=1  # Assume checksum is available

# Download checksum file
#echo -e "[INFO] Downloading checksum file..."
if ! download_file "$BASE_URL/bin/checksum.arkt" "$CHECKSUM_FILE"; then
    #echo -e "[WARNING] Failed to download checksum file. Continuing without checksum verification!"
    CHECKSUM_AVAILABLE=0  # Set flag to disable checksum verification
elif ! grep -q "=" "$CHECKSUM_FILE"; then
    #echo -e "[WARNING] Checksum file is invalid or empty. Skipping verification!"
    CHECKSUM_AVAILABLE=0  # Mark as unavailable if it's empty or corrupted
fi

if [ -d "$WORK_DIR" ]; then
    # Check if the directory contains any files or only empty folders
	if [ -n "$($BIN_DIR/busybox find "$WORK_DIR" -mindepth 1 -type f 2>/dev/null)" ]; then
        while true; do
            echo -e "\n[WARNING] Existing files found in $WORK_DIR. Choose an option:\n"
            echo -e "1) Delete all existing files from $WORK_DIR and start fresh"
            echo -e "2) Move old files to a backup folder"
            echo -e "3) Exit script"
            read -r choice

            case "$choice" in
                1)
                    log "[INFO] Deleting existing files..."
                    $BIN_DIR/busybox rm -rf "$WORK_DIR"/*
                    echo -e "[SUCCESS] Old files deleted."
                    break
                    ;;
                2)
                    TIMESTAMP=$(date +"%Y%m%d_%H%M%S")
                    BACKUP_DIR="${WORK_DIR}_backup_$TIMESTAMP"
                    log "[INFO] Moving old files to $BACKUP_DIR..."
                    $BIN_DIR/busybox mkdir -p "$BACKUP_DIR"
                    $BIN_DIR/busybox mv "$WORK_DIR"/* "$BACKUP_DIR"/
                    echo -e "[SUCCESS] Files moved to $BACKUP_DIR."
                    break
                    ;;
                3)
                    log "[INFO] Exiting script. No changes made."
                    exit 0
                    ;;
                *)
                    log "[ERROR] Invalid input. Please select a valid option (1/2/3)."
                    ;;
            esac
        done
    else
        # If only empty folders or no content exists, delete and recreate it
        # log "[INFO] Work directory is empty or contains only empty folders. Cleaning up..."
        $BIN_DIR/busybox rm -rf "$WORK_DIR"
        $BIN_DIR/busybox mkdir -p "$WORK_DIR"
        # log "[SUCCESS] Clean workspace ready."
    fi
fi

if get_payload_zip_path; then
    log "[INFO] Using payload ZIP: $SELECTED_ZIP_FILE"
    export SELECTED_PAYLOAD_ZIP="$SELECTED_ZIP_FILE"
else
    log "[ERROR] No valid payload zip selected. Exiting.\n"
    exit 1
fi

# Extract the filename (without extension) from the selected ZIP file
ZIP_NAME=$($BIN_DIR/busybox basename "$SELECTED_ZIP_FILE" .zip)
TARGET_DIR="$WORK_DIR/${ZIP_NAME}_FASTBOOT_RECOVERY"

# Create the directory
$BIN_DIR/busybox mkdir -p "$TARGET_DIR"

# Unzip only the payload.bin file into the created directory
echo -e " "
echo -e "Extracting payload.bin"
$BIN_DIR/busybox unzip -o "$SELECTED_ZIP_FILE" "payload.bin" -d "$TARGET_DIR"

# Check if extraction was successful
if [ ! -f "$TARGET_DIR/payload.bin" ]; then
    echo -e "[ERROR] payload.bin not found in the selected ZIP. Exiting."
    exit 1
fi

# Store the extracted payload.bin path in $PAYLOAD_FILE
PAYLOAD_FILE="$TARGET_DIR/payload.bin"

echo -e "payload.bin extraction complete."

log "[INFO] Extracting payload.bin..."
echo -e " "
$BIN_DIR/payload-dumper-go -o "$TARGET_DIR" "$PAYLOAD_FILE" || { log "[ERROR] Extraction failed!"; exit 1; }
log "[SUCCESS] Extraction completed."

log "[INFO] Generating original checksums..."
for img in system vendor odm system_ext product; do
    $BIN_DIR/busybox mv "$TARGET_DIR/${img}.img" "$TARGET_DIR/${img}_a.img"
done
$BIN_DIR/busybox sha256sum "$TARGET_DIR/system_a.img" "$TARGET_DIR/vendor_a.img" "$TARGET_DIR/odm_a.img" "$TARGET_DIR/system_ext_a.img" "$TARGET_DIR/product_a.img" > "$TARGET_DIR/original_checksums.txt"
echo -e "[SUCCESS] Checksums generated."

log "[INFO] Calculating total partition size with buffer..."
TOTAL_SIZE=$($BIN_DIR/busybox du -b "$TARGET_DIR/system_a.img" "$TARGET_DIR/vendor_a.img" "$TARGET_DIR/odm_a.img" "$TARGET_DIR/system_ext_a.img" "$TARGET_DIR/product_a.img" | $BIN_DIR/busybox awk '{sum += $1} END {print sum + (24 * 1024 * 1024); exit}')
echo -e "Total size (with buffer): $TOTAL_SIZE"

log "[INFO] Creating super.img..."
echo -e ""
$BIN_DIR/lpmake \
--metadata-size 65536 \
--metadata-slots 3 \
--device super:9126805504 \
--super-name super \
--group super_group_a:9126805504 \
--group super_group_b:9126805504 \
--partition odm_a:readonly:$(wc -c <"$TARGET_DIR/odm_a.img"):super_group_a --image odm_a="$TARGET_DIR/odm_a.img" \
--partition odm_b:readonly:0:super_group_b \
--partition product_a:readonly:$(wc -c <"$TARGET_DIR/product_a.img"):super_group_a --image product_a="$TARGET_DIR/product_a.img" \
--partition product_b:readonly:0:super_group_b \
--partition system_a:readonly:$(wc -c <"$TARGET_DIR/system_a.img"):super_group_a --image system_a="$TARGET_DIR/system_a.img" \
--partition system_b:readonly:0:super_group_b \
--partition system_ext_a:readonly:$(wc -c <"$TARGET_DIR/system_ext_a.img"):super_group_a --image system_ext_a="$TARGET_DIR/system_ext_a.img" \
--partition system_ext_b:readonly:0:super_group_b \
--partition vendor_a:readonly:$(wc -c <"$TARGET_DIR/vendor_a.img"):super_group_a --image vendor_a="$TARGET_DIR/vendor_a.img" \
--partition vendor_b:readonly:0:super_group_b \
--virtual-ab \
--output "$TARGET_DIR/super.img"

log "[SUCCESS] super.img created."

log "[INFO] Truncating super.img..."
$BIN_DIR/busybox truncate -s "$TOTAL_SIZE" "$TARGET_DIR/super.img"
echo -e "[SUCCESS] Truncation complete."

log "[INFO] Cleaning up payload.bin extrated img's..."
$BIN_DIR/busybox rm -f "$TARGET_DIR/system_a.img" "$TARGET_DIR/vendor_a.img" "$TARGET_DIR/odm_a.img" "$TARGET_DIR/system_ext_a.img" "$TARGET_DIR/product_a.img" "$PAYLOAD_FILE" 
echo -e "[SUCCESS] Cleanup complete."

log "[INFO] Extracting super.img..."
$BIN_DIR/busybox mkdir -p "$TARGET_DIR/super_extracted"
$BIN_DIR/lpunpack "$TARGET_DIR/super.img" "$TARGET_DIR/super_extracted" || { log "[ERROR] Extraction failed!"; exit 1; }
echo -e "[SUCCESS] super.img extracted."

log "[INFO] Generating new checksums..."
$BIN_DIR/busybox sha256sum "$TARGET_DIR/super_extracted/system_a.img" "$TARGET_DIR/super_extracted/vendor_a.img" "$TARGET_DIR/super_extracted/odm_a.img" "$TARGET_DIR/super_extracted/system_ext_a.img" "$TARGET_DIR/super_extracted/product_a.img" > "$TARGET_DIR/new_checksums.txt"
echo -e "[SUCCESS] Checksums generated."

log "[INFO] Normalizing checksums for comparison..."
$BIN_DIR/busybox sed -E "s|(_a)?\.img|.img|" "$TARGET_DIR/original_checksums.txt" | $BIN_DIR/busybox sed -E "s|$TARGET_DIR|/tmp|" > "$TARGET_DIR/original_checksums_norm.txt"
$BIN_DIR/busybox sed -E "s|(_a)?\.img|.img|" "$TARGET_DIR/new_checksums.txt" | $BIN_DIR/busybox sed -E "s|$TARGET_DIR/super_extracted|/tmp|" > "$TARGET_DIR/new_checksums_norm.txt"

log "[INFO] Comparing checksums..."
$BIN_DIR/busybox diff "$TARGET_DIR/original_checksums_norm.txt" "$TARGET_DIR/new_checksums_norm.txt" || log "[WARNING] Checksum mismatch detected!"
echo -e "[SUCCESS] Checksum comparison complete."

log "[COMPLETED] super.img prepared to use in fastboot/recovery!"

log "[INFO] Cleaning up..."
$BIN_DIR/busybox rm -rf "$TARGET_DIR/super_extracted"
$BIN_DIR/busybox rm -f "$TARGET_DIR/original_checksums.txt" "$TARGET_DIR/new_checksums.txt" "$TARGET_DIR/original_checksums_norm.txt" "$TARGET_DIR/new_checksums_norm.txt" 
echo -e "[SUCCESS] Cleanup complete."

log "[INFO] Now will contrust folder/files and Download Scripts as required for Auto Installer!\n"

$BIN_DIR/busybox mkdir -p "$TARGET_DIR/images" 
$BIN_DIR/busybox mkdir -p "$TARGET_DIR/META-INF/com/google/android" 
$BIN_DIR/busybox mkdir -p "$TARGET_DIR/META-INF/com/arkt" 
$BIN_DIR/busybox mkdir -p "$TARGET_DIR/bin/windows/platform-tools"
$BIN_DIR/busybox mkdir -p "$TARGET_DIR/bin/windows/log-tool" 
$BIN_DIR/busybox mkdir -p "$TARGET_DIR/bin/linux/platform-tools" 
$BIN_DIR/busybox mkdir -p "$TARGET_DIR/ROOT_APK_INSATLL_THIS_ONLY"
for img in boot dtbo vendor_boot vbmeta vbmeta_system super; do
    $BIN_DIR/busybox mv "$TARGET_DIR/${img}.img" "$TARGET_DIR/images/${img}.img"
done

#still gotta upload to mirror location for fallback
download_with_fallback \
    "$BASE_URL/files/userdata.img" \
    "$BASE_URL/files/userdata.img" \
    "$TARGET_DIR/images/userdata.img" \
    "userdata.img"
	
download_with_fallback \
    "$BASE_URL/files/empty_frp.img" \
    "$BASE_URL/files/empty_frp.img" \
    "$TARGET_DIR/images/empty_frp.img" \
    "empty_frp.img"

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/bin/7zzs" \
    "$BASE_URL/auto-installer-scripts/bin/7zzs" \
    "$TARGET_DIR/META-INF/com/arkt/7zzs" \
    "7zzs"

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/bin/bootctl" \
    "$BASE_URL/auto-installer-scripts/bin/bootctl" \
    "$TARGET_DIR/META-INF/com/arkt/bootctl" \
    "bootctl"

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/bin/busybox" \
    "$BASE_URL/auto-installer-scripts/bin/busybox" \
    "$TARGET_DIR/META-INF/com/arkt/busybox" \
    "busybox"

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/bin/libhidltransport.so" \
    "$BASE_URL/auto-installer-scripts/bin/libhidltransport.so" \
    "$TARGET_DIR/META-INF/com/arkt/libhidltransport.so" \
    "libhidltransport.so"

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/bin/libhwbinder.so" \
    "$BASE_URL/auto-installer-scripts/bin/libhwbinder.so" \
    "$TARGET_DIR/META-INF/com/arkt/libhwbinder.so" \
    "libhwbinder.so"

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/bin/dmsetup" \
    "$BASE_URL/auto-installer-scripts/bin/dmsetup" \
    "$TARGET_DIR/META-INF/com/arkt/dmsetup" \
    "dmsetup"
	
download_with_fallback \
    "$BASE_URL/auto-installer-scripts/bin/make_f2fs" \
    "$BASE_URL/auto-installer-scripts/bin/make_f2fs" \
    "$TARGET_DIR/META-INF/com/arkt/make_f2fs" \
    "make_f2fs"
	
download_with_fallback \
    "$BASE_URL/auto-installer-scripts/bin/mke2fs" \
    "$BASE_URL/auto-installer-scripts/bin/mke2fs" \
    "$TARGET_DIR/META-INF/com/arkt/mke2fs" \
    "mke2fs"

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/update-binary" \
    "$BASE_URL/auto-installer-scripts/update-binary" \
    "$TARGET_DIR/META-INF/com/google/android/update-binary" \
    "update-binary"
	
download_with_fallback \
    "$BASE_URL/auto-installer-scripts/updater-script" \
    "$BASE_URL/auto-installer-scripts/updater-script" \
    "$TARGET_DIR/META-INF/com/google/android/updater-script" \
    "updater-script"

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/autoinstaller.conf" \
    "$BASE_URL/auto-installer-scripts/autoinstaller.conf" \
    "$TARGET_DIR/META-INF/autoinstaller.conf" \

download_with_fallback \
    "$BASE_URL/auto-installer-scripts/install_forge_linux.sh" \
    "$BASE_URL/auto-installer-scripts/install_forge_linux.sh" \
    "$TARGET_DIR/install_forge_linux.sh" \
    "install_forge_linux.sh"
	
download_with_fallback \
    "$BASE_URL/auto-installer-scripts/install_forge_windows.bat" \
    "$BASE_URL/auto-installer-scripts/install_forge_windows.bat" \
    "$TARGET_DIR/install_forge_windows.bat" \
    "install_forge_windows.bat"
	
download_with_fallback \
    "$BASE_URL/auto-installer-scripts/update_forge_linux.sh" \
    "$BASE_URL/auto-installer-scripts/update_forge_linux.sh" \
    "$TARGET_DIR/update_forge_linux.sh" \
    "update_forge_linux.sh"
	
download_with_fallback \
    "$BASE_URL/auto-installer-scripts/update_forge_windows.bat" \
    "$BASE_URL/auto-installer-scripts/update_forge_windows.bat" \
    "$TARGET_DIR/update_forge_windows.bat" \
    "update_forge_windows.bat"

log "[INFO] Downloading Platform-tools and required tools for Auto-Installer-Forge script...\n"

download_with_fallback \
    "https://dl.google.com/android/repository/platform-tools-latest-linux.zip" \
    "$BASE_URL/files/platform-tools-latest-linux.zip" \
    "$TARGET_DIR/bin/linux/platform-tools-linux.zip" \
    "platform-tools-latest-linux.zip"
	
echo -e "[INFO] Extracting Linux platform-tools..."
$BIN_DIR/busybox unzip -q "$TARGET_DIR/bin/linux/platform-tools-linux.zip" -d "$TARGET_DIR/bin/linux/"
log "[SUCCESS] Linux platform-tools extracted.\n"

download_with_fallback \
    "$BASE_URL/files/platform-tools-latest-windows.zip" \
    "$BASE_URL/files/platform-tools-latest-windows.zip" \
    "$TARGET_DIR/bin/windows/platform-tools-windows.zip" \
    "platform-tools-latest-windows.zip"

echo -e "[INFO] Extracting Windows platform-tools..."
$BIN_DIR/busybox unzip -q "$TARGET_DIR/bin/windows/platform-tools-windows.zip" -d "$TARGET_DIR/bin/windows/"
log "[SUCCESS] Windows platform-tools extracted.\n"

download_with_fallback \
    "https://github.com/dEajL3kA/tee-win32/releases/download/1.3.3/tee-win32.2023-11-27.zip" \
    "$BASE_URL/files/tee-win32.2023-11-27.zip" \
    "$TARGET_DIR/bin/windows/tee.zip" \
    "tee-win32.2023-11-27.zip"
	
echo -e "[INFO] Extracting tee for logging in windows..."
$BIN_DIR/busybox unzip -q "$TARGET_DIR/bin/windows/tee.zip" -d "$TARGET_DIR/bin/windows/log-tool/"
log "[SUCCESS] TEE for windows extracted."

log "[INFO] Now will Download KernelSU NEXT and Magisk APK for ROOT access!\n[NOTE] Manually Add Patched ksu-n_boot.img and magisk_boot.img in /images folder and add options to autoinstaller.conf file\n"

download_with_fallback \
    "https://github.com/KernelSU-Next/KernelSU-Next/releases/download/v1.0.8/KernelSU_Next_v1.0.8_12701-release.apk" \
    "$BASE_URL/files/KernelSU_Next_v1.0.8.apk" \
    "$TARGET_DIR/ROOT_APK_INSATLL_THIS_ONLY/KernelSU_Next_v1.0.8.apk" \
    "KernelSU_Next_v1.0.8.apk"

download_with_fallback \
    "https://github.com/topjohnwu/Magisk/releases/download/v29.0/Magisk-v29.0.apk" \
    "$BASE_URL/files/Magisk_v29.0.apk" \
    "$TARGET_DIR/ROOT_APK_INSATLL_THIS_ONLY/Magisk_v29.0.apk" \
    "Magisk-v29.0.apk"

# Call the funtion with magisk apk name
#patch_magisk_boot "Magisk_v29.0.apk"

CONF_FILE="$TARGET_DIR/META-INF/autoinstaller.conf"
IMAGES_DIR="$TARGET_DIR/images"

# Generate the new HASH_PAIRS lines
tmp_hashes=$(mktemp)
for img in "$IMAGES_DIR"/*.img; do
  [ -f "$img" ] || continue
  name=$(basename "$img")

  # Skip super.img because its a big file, if verify then it will take alot of time
  [ "$name" = "super.img" ] && continue

  sha1=$($BIN_DIR/busybox sha1sum "$img" | $BIN_DIR/busybox awk '{print $1}')
  echo -e "  \"images/$name\" \"$sha1\"" >> "$tmp_hashes"
done

$BIN_DIR/busybox sed -i '/^HASH_PAIRS=(/,/^)/ {
  /^HASH_PAIRS=(/!{/^)/!d}
}' "$CONF_FILE"

# Insert new hashes
$BIN_DIR/busybox sed -i "/^HASH_PAIRS=(/r $tmp_hashes" "$CONF_FILE"

#echo -e "[INFO] HASH_PAIRS inside autoinstaller.conf block updated with current img's in images folder"

log "[SUCCESS] Auto-Installer-Forge files processing finished!\n"

log "[INFO] Now, let's update configration file for this rom!\n"

# fields to update 
#update_field "DEVICE_CODE" "DEVICE CODE"
update_field "ROM_NAME" "ROM name"
update_field "ROM_MAINTAINER" "ROM maintainer"
update_field "ANDROID_VER" "Android version"
update_field "DEVICE_NAME" "Device name"
update_field "BUILD_DATE" "Build date"
update_field "SECURITY_PATCH" "Security patch"
update_field "ROM_VERSION" "ROM Build version"

# Extract ROM_NAME line from config
line=$(grep "^ROM_NAME=" "$CONF_FILE")

# Extract value and optional comment
value=$(echo -e "$line" | $BIN_DIR/busybox sed -n 's/^ROM_NAME="\([^"]*\)".*/\1/p')
comment=$(echo -e "$line" | $BIN_DIR/busybox sed -n 's/^ROM_NAME="[^"]*"[[:space:]]*\(.*\)/\1/p')
#echo -e "Current ROM Name: $value"
#echo -e "Sanitized: $(echo -e "$value" | $BIN_DIR/busybox tr ' ' '_' | $BIN_DIR/busybox tr -cd '[:alnum:]_-')"

# Sanitize ROM name by removing non-alphanum and replace space with _ underscore
sanitized_name=$(echo -e "$value" | $BIN_DIR/busybox tr ' ' '_' | $BIN_DIR/busybox tr -cd '[:alnum:]_-')

# Rename auto-insatller scripts file with new rom name
for base in install_forge_linux.sh update_forge_linux.sh install_forge_windows.bat update_forge_windows.bat; do
  src="$TARGET_DIR/$base"
  if [ -f "$src" ]; then
    new_name=$(echo -e "$base" | $BIN_DIR/busybox sed "s/forge/$sanitized_name/")
    $BIN_DIR/busybox mv "$src" "$TARGET_DIR/$new_name"
    #echo -e "Renamed: $base → $new_name"
  fi
done

# Convert .sh and .bat files (once, after renaming)
for file in "$TARGET_DIR"/*.sh "$TARGET_DIR"/*.bat; do
  [ -f "$file" ] || continue
  case "$file" in
    *.sh)  $BIN_DIR/busybox dos2unix "$file" ;;
    *.bat) $BIN_DIR/busybox dos2unix -d "$file" ;;
  esac
done

$BIN_DIR/busybox dos2unix "$CONF_FILE"
log "[INFO] Cleaning up..."
$BIN_DIR/busybox rm -f "$tmp_hashes" "$TARGET_DIR/bin/linux/platform-tools-linux.zip" "$TARGET_DIR/bin/windows/platform-tools-windows.zip" "$TARGET_DIR/bin/windows/tee.zip"
cd
rm -rf $BIN_DIR
echo -e "[SUCCESS] Cleanup complete."

log "[NOTE] you can also change configrations in META-INF/autoinstaller.conf file anytime!"
log "[COMPLETED] Auto-Installer-Forge process finished successfully!\n"
