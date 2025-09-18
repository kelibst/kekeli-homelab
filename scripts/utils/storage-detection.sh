#!/bin/bash
# storage-detection.sh - Storage detection utilities for Kekeli-HomeCloud
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# STORAGE DETECTION FUNCTIONS
# =============================================================================

# Function to detect all available storage devices
detect_storage_devices() {
    print_subsection "Detecting Storage Devices"

    local devices=()

    # Get all block devices with filesystem information
    if command_exists lsblk; then
        while IFS= read -r line; do
            # Parse lsblk output: NAME SIZE TYPE MOUNTPOINT FSTYPE UUID
            local name=$(echo "$line" | awk '{print $1}')
            local size=$(echo "$line" | awk '{print $2}')
            local type=$(echo "$line" | awk '{print $3}')
            local mountpoint=$(echo "$line" | awk '{print $4}')
            local fstype=$(echo "$line" | awk '{print $5}')
            local uuid=$(echo "$line" | awk '{print $6}')

            # Skip loop devices, ram, and system partitions
            if [[ "$name" =~ ^(loop|ram|sr) ]] || [[ "$type" =~ ^(rom|ram)$ ]]; then
                continue
            fi

            # Only include devices with filesystems or that are partitions
            if [ -n "$fstype" ] || [[ "$type" == "part" ]]; then
                devices+=("$name|$size|$type|$mountpoint|$fstype|$uuid")
                print_status "info" "Found device: $name ($size, $fstype, mounted: ${mountpoint:-unmounted})"
            fi
        done < <(lsblk -n -o NAME,SIZE,TYPE,MOUNTPOINT,FSTYPE,UUID | grep -v "^$")
    else
        print_status "warn" "lsblk not available, using fallback detection"
        # Fallback using /proc/mounts and /proc/partitions
        while IFS= read -r line; do
            local device=$(echo "$line" | awk '{print $1}')
            local mountpoint=$(echo "$line" | awk '{print $2}')
            local fstype=$(echo "$line" | awk '{print $3}')

            if [[ "$device" =~ ^/dev/(sd|hd|nvme|mmcblk) ]]; then
                local name=$(basename "$device")
                local size="unknown"
                devices+=("$name|$size|part|$mountpoint|$fstype|unknown")
                print_status "info" "Found mounted device: $name (mounted at $mountpoint)"
            fi
        done < /proc/mounts
    fi

    # Return devices as array
    printf '%s\n' "${devices[@]}"
}

# Function to detect external storage (USB drives, external HDDs)
detect_external_storage() {
    print_subsection "Detecting External Storage"

    local external_devices=()

    # Check for USB devices
    if [ -d /sys/bus/usb/devices ]; then
        for usb_device in /sys/bus/usb/devices/*; do
            if [ -f "$usb_device/bDeviceClass" ]; then
                local device_class=$(cat "$usb_device/bDeviceClass" 2>/dev/null)
                # Class 08 is Mass Storage
                if [ "$device_class" = "08" ]; then
                    local vendor=$(cat "$usb_device/manufacturer" 2>/dev/null || echo "Unknown")
                    local product=$(cat "$usb_device/product" 2>/dev/null || echo "Unknown")
                    print_status "info" "Found USB storage: $vendor $product"

                    # Try to find associated block device
                    local usb_id=$(basename "$usb_device")
                    for block_device in /sys/block/*; do
                        if [ -L "$block_device" ]; then
                            local device_path=$(readlink -f "$block_device")
                            if [[ "$device_path" =~ $usb_id ]]; then
                                local device_name=$(basename "$block_device")
                                external_devices+=("$device_name")
                                print_status "pass" "USB device maps to: /dev/$device_name"
                            fi
                        fi
                    done
                fi
            fi
        done
    fi

    # Check for removable devices
    for block_device in /sys/block/*; do
        if [ -f "$block_device/removable" ]; then
            local removable=$(cat "$block_device/removable" 2>/dev/null)
            if [ "$removable" = "1" ]; then
                local device_name=$(basename "$block_device")
                local size=$(cat "$block_device/size" 2>/dev/null || echo "0")
                # Convert 512-byte sectors to MB
                local size_mb=$((size * 512 / 1024 / 1024))

                if [ "$size_mb" -gt 100 ]; then  # Only devices larger than 100MB
                    external_devices+=("$device_name")
                    print_status "pass" "Found removable device: /dev/$device_name (${size_mb}MB)"
                fi
            fi
        fi
    done

    printf '%s\n' "${external_devices[@]}"
}

# Function to get device UUID
get_device_uuid() {
    local device=$1

    if command_exists blkid; then
        blkid -s UUID -o value "/dev/$device" 2>/dev/null
    else
        # Fallback using /dev/disk/by-uuid
        for uuid_link in /dev/disk/by-uuid/*; do
            if [ -L "$uuid_link" ]; then
                local target=$(readlink -f "$uuid_link")
                if [ "$target" = "/dev/$device" ]; then
                    basename "$uuid_link"
                    return 0
                fi
            fi
        done
    fi
}

# Function to get device filesystem type
get_device_fstype() {
    local device=$1

    if command_exists blkid; then
        blkid -s TYPE -o value "/dev/$device" 2>/dev/null
    else
        # Fallback using /proc/mounts
        grep "^/dev/$device " /proc/mounts | awk '{print $3}' | head -1
    fi
}

# Function to get device size in bytes
get_device_size() {
    local device=$1

    if [ -f "/sys/block/$device/size" ]; then
        local sectors=$(cat "/sys/block/$device/size")
        echo $((sectors * 512))
    elif command_exists blockdev; then
        blockdev --getsize64 "/dev/$device" 2>/dev/null
    else
        echo "0"
    fi
}

# Function to check if device is mounted
is_device_mounted() {
    local device=$1
    grep -q "^/dev/$device " /proc/mounts
}

# Function to get device mount point
get_device_mountpoint() {
    local device=$1
    grep "^/dev/$device " /proc/mounts | awk '{print $2}' | head -1
}

# Function to detect suggested mount points
suggest_mount_points() {
    local device=$1
    local mount_points=()

    # Common mount point patterns
    mount_points+=(
        "/mnt/nextcloud-data"
        "/mnt/kekeli-storage"
        "/mnt/$device"
        "/media/$USER/kekeli-storage"
        "/media/kekeli-storage"
        "/opt/nextcloud-data"
    )

    printf '%s\n' "${mount_points[@]}"
}

# Function to validate mount point
validate_mount_point() {
    local mount_point=$1

    # Check if mount point is already in use
    if grep -q " $mount_point " /proc/mounts; then
        print_status "error" "Mount point already in use: $mount_point"
        return 1
    fi

    # Check if directory exists and is empty
    if [ -d "$mount_point" ]; then
        if [ -n "$(ls -A "$mount_point" 2>/dev/null)" ]; then
            print_status "warn" "Mount point not empty: $mount_point"
            return 2  # Warning, but not a hard failure
        fi
    fi

    # Check if parent directory is writable
    local parent_dir=$(dirname "$mount_point")
    if [ ! -w "$parent_dir" ]; then
        print_status "error" "Parent directory not writable: $parent_dir"
        return 1
    fi

    return 0
}

# Function to format device (with confirmation)
format_device() {
    local device=$1
    local fstype=${2:-ext4}

    print_status "warn" "This will FORMAT /dev/$device and ERASE ALL DATA!"
    echo -e "${RED}  Device: /dev/$device${NC}"
    echo -e "${RED}  Filesystem: $fstype${NC}"
    echo ""

    if ! ask_yes_no "Are you absolutely sure you want to continue?"; then
        print_status "info" "Format operation cancelled"
        return 1
    fi

    print_status "progress" "Formatting /dev/$device as $fstype..."

    case $fstype in
        ext4)
            if mkfs.ext4 -F "/dev/$device" >/dev/null 2>&1; then
                print_status "pass" "Device formatted successfully"
                return 0
            fi
            ;;
        ext3)
            if mkfs.ext3 -F "/dev/$device" >/dev/null 2>&1; then
                print_status "pass" "Device formatted successfully"
                return 0
            fi
            ;;
        ntfs)
            if command_exists mkfs.ntfs && mkfs.ntfs -f "/dev/$device" >/dev/null 2>&1; then
                print_status "pass" "Device formatted successfully"
                return 0
            fi
            ;;
        *)
            print_status "error" "Unsupported filesystem type: $fstype"
            return 1
            ;;
    esac

    print_status "error" "Failed to format device"
    return 1
}

# Function to mount device
mount_device() {
    local device=$1
    local mount_point=$2
    local fstype=$3
    local options=${4:-"defaults"}

    # Create mount point if it doesn't exist
    if ! create_directory "$mount_point"; then
        print_status "error" "Failed to create mount point: $mount_point"
        return 1
    fi

    # Mount the device
    print_status "progress" "Mounting /dev/$device to $mount_point..."

    if [ -n "$fstype" ]; then
        mount_cmd="mount -t $fstype -o $options /dev/$device $mount_point"
    else
        mount_cmd="mount -o $options /dev/$device $mount_point"
    fi

    if eval "$mount_cmd" 2>/dev/null; then
        print_status "pass" "Device mounted successfully"

        # Set appropriate permissions
        if [ -d "$mount_point" ]; then
            chmod 755 "$mount_point" 2>/dev/null
            chown "$USER:$USER" "$mount_point" 2>/dev/null || sudo chown "$USER:$USER" "$mount_point" 2>/dev/null
        fi

        return 0
    else
        print_status "error" "Failed to mount device"
        return 1
    fi
}

# Function to add to fstab for persistent mounting
add_to_fstab() {
    local device=$1
    local mount_point=$2
    local fstype=$3
    local options=${4:-"defaults"}
    local uuid

    # Get device UUID for reliable mounting
    uuid=$(get_device_uuid "$device")
    if [ -z "$uuid" ]; then
        print_status "warn" "Could not get UUID for /dev/$device, using device path"
        local device_path="/dev/$device"
    else
        local device_path="UUID=$uuid"
    fi

    # Check if entry already exists
    if grep -q "$mount_point" /etc/fstab 2>/dev/null; then
        print_status "warn" "Mount point already in /etc/fstab: $mount_point"
        return 1
    fi

    # Backup fstab
    if backup_file "/etc/fstab"; then
        print_status "info" "Created fstab backup"
    fi

    # Add entry to fstab
    local fstab_entry="$device_path $mount_point $fstype $options 0 2"
    print_status "progress" "Adding to /etc/fstab: $fstab_entry"

    if echo "$fstab_entry" | sudo tee -a /etc/fstab >/dev/null 2>&1; then
        print_status "pass" "Added persistent mount to /etc/fstab"

        # Test the fstab entry
        if sudo mount -a 2>/dev/null; then
            print_status "pass" "fstab entry validated successfully"
            return 0
        else
            print_status "error" "fstab entry validation failed"
            # Remove the bad entry
            sudo sed -i "\|$mount_point|d" /etc/fstab 2>/dev/null
            return 1
        fi
    else
        print_status "error" "Failed to add entry to /etc/fstab"
        return 1
    fi
}

# Function to detect optimal storage for Nextcloud
detect_optimal_storage() {
    print_section "🔍" "Detecting Optimal Storage Configuration"

    local all_devices
    local external_devices
    local recommended_device=""
    local recommended_size=0

    # Get all available devices
    all_devices=$(detect_storage_devices)
    external_devices=$(detect_external_storage)

    # Analyze devices for best fit
    while IFS= read -r device_info; do
        if [ -z "$device_info" ]; then continue; fi

        local name=$(echo "$device_info" | cut -d'|' -f1)
        local size_str=$(echo "$device_info" | cut -d'|' -f2)
        local type=$(echo "$device_info" | cut -d'|' -f3)
        local mountpoint=$(echo "$device_info" | cut -d'|' -f4)
        local fstype=$(echo "$device_info" | cut -d'|' -f5)

        # Skip already mounted system partitions
        if [[ "$mountpoint" =~ ^(/|/boot|/home|/usr|/var)$ ]]; then
            continue
        fi

        # Get actual size in bytes
        local size_bytes=$(get_device_size "$name")
        local size_gb=$((size_bytes / 1024 / 1024 / 1024))

        # Prefer external devices
        local is_external=false
        while IFS= read -r ext_device; do
            if [ "$ext_device" = "$name" ]; then
                is_external=true
                break
            fi
        done <<< "$external_devices"

        # Score devices based on preferences
        local score=0

        # Size scoring (minimum 10GB, optimal 100GB+)
        if [ $size_gb -ge 100 ]; then
            score=$((score + 50))
        elif [ $size_gb -ge 50 ]; then
            score=$((score + 30))
        elif [ $size_gb -ge 10 ]; then
            score=$((score + 10))
        else
            continue  # Too small
        fi

        # External device bonus
        if [ "$is_external" = true ]; then
            score=$((score + 30))
        fi

        # Unmounted device bonus
        if [ -z "$mountpoint" ] || [ "$mountpoint" = "-" ]; then
            score=$((score + 20))
        fi

        # Compatible filesystem bonus
        if [[ "$fstype" =~ ^(ext4|ext3|ntfs|exfat)$ ]]; then
            score=$((score + 10))
        fi

        print_status "info" "Device /dev/$name: ${size_gb}GB, score: $score (external: $is_external, mounted: ${mountpoint:-no})"

        # Check if this is the best device so far
        if [ $score -gt $recommended_size ]; then
            recommended_device="$name"
            recommended_size=$score
        fi
    done <<< "$all_devices"

    if [ -n "$recommended_device" ]; then
        print_status "pass" "Recommended storage device: /dev/$recommended_device"
        echo "$recommended_device"
        return 0
    else
        print_status "warn" "No suitable storage device found"
        return 1
    fi
}

# Function to setup storage for Nextcloud
setup_nextcloud_storage() {
    local device=$1
    local mount_point=$2
    local format_device=${3:-false}

    print_section "💾" "Setting Up Nextcloud Storage"

    # Validate device
    if [ ! -b "/dev/$device" ]; then
        print_status "error" "Device does not exist: /dev/$device"
        return 1
    fi

    # Check if device is mounted elsewhere
    local current_mount=$(get_device_mountpoint "$device")
    if [ -n "$current_mount" ] && [ "$current_mount" != "$mount_point" ]; then
        print_status "warn" "Device is currently mounted at: $current_mount"
        if ask_yes_no "Unmount device before proceeding?"; then
            if sudo umount "/dev/$device" 2>/dev/null; then
                print_status "pass" "Device unmounted successfully"
            else
                print_status "error" "Failed to unmount device"
                return 1
            fi
        else
            return 1
        fi
    fi

    # Format device if requested
    if [ "$format_device" = true ]; then
        if ! format_device "$device" "ext4"; then
            return 1
        fi
    fi

    # Validate mount point
    if ! validate_mount_point "$mount_point"; then
        return 1
    fi

    # Get filesystem type
    local fstype=$(get_device_fstype "$device")
    if [ -z "$fstype" ]; then
        print_status "error" "Could not determine filesystem type for /dev/$device"
        print_status "info" "Device may need to be formatted first"
        return 1
    fi

    # Mount device
    if ! mount_device "$device" "$mount_point" "$fstype"; then
        return 1
    fi

    # Add to fstab for persistence
    if ! add_to_fstab "$device" "$mount_point" "$fstype"; then
        print_status "warn" "Device mounted but not added to fstab (will not persist after reboot)"
    fi

    # Create Nextcloud data directory
    local nextcloud_data="$mount_point/nextcloud-data"
    if create_directory "$nextcloud_data" 755 "$USER"; then
        print_status "pass" "Created Nextcloud data directory: $nextcloud_data"
    else
        print_status "error" "Failed to create Nextcloud data directory"
        return 1
    fi

    # Set up proper permissions for Docker
    if sudo chown -R "$USER:$USER" "$mount_point" 2>/dev/null; then
        print_status "pass" "Set proper ownership for mount point"
    else
        print_status "warn" "Could not set ownership for mount point"
    fi

    print_status "pass" "Storage setup completed successfully"
    return 0
}

# =============================================================================
# INTERACTIVE STORAGE SELECTION
# =============================================================================

# Function for interactive storage device selection
interactive_storage_selection() {
    print_section "📁" "Storage Configuration"

    local devices
    local device_list=()
    local choice

    # Get all available devices
    devices=$(detect_storage_devices)
    if [ -z "$devices" ]; then
        print_status "error" "No storage devices detected"
        return 1
    fi

    # Build device selection menu
    echo -e "${CYAN}Available storage devices:${NC}"
    local index=1
    while IFS= read -r device_info; do
        if [ -z "$device_info" ]; then continue; fi

        local name=$(echo "$device_info" | cut -d'|' -f1)
        local size_str=$(echo "$device_info" | cut -d'|' -f2)
        local type=$(echo "$device_info" | cut -d'|' -f3)
        local mountpoint=$(echo "$device_info" | cut -d'|' -f4)
        local fstype=$(echo "$device_info" | cut -d'|' -f5)

        local size_bytes=$(get_device_size "$name")
        local size_gb=$((size_bytes / 1024 / 1024 / 1024))

        if [ $size_gb -ge 5 ]; then  # Only show devices with at least 5GB
            echo -e "  ${index}. /dev/$name - ${size_gb}GB ($fstype) ${mountpoint:+- mounted at $mountpoint}"
            device_list+=("$name")
            index=$((index + 1))
        fi
    done <<< "$devices"

    if [ ${#device_list[@]} -eq 0 ]; then
        print_status "error" "No suitable storage devices found (minimum 5GB required)"
        return 1
    fi

    echo -e "  $index. Skip storage setup (use local storage)"
    echo ""

    # Get user choice
    while true; do
        choice=$(get_user_input "Select storage device (1-$index)" "1")
        if [[ "$choice" =~ ^[0-9]+$ ]] && [ "$choice" -ge 1 ] && [ "$choice" -le $index ]; then
            break
        fi
        print_status "error" "Invalid choice. Please enter a number between 1 and $index."
    done

    # Handle choice
    if [ "$choice" -eq $index ]; then
        print_status "info" "Skipping external storage setup"
        return 2  # Special return code for skipped
    fi

    local selected_device="${device_list[$((choice - 1))]}"
    print_status "info" "Selected device: /dev/$selected_device"

    # Get mount point
    local default_mount="/mnt/nextcloud-data"
    local mount_point=$(get_user_input "Mount point" "$default_mount")

    # Check if device needs formatting
    local fstype=$(get_device_fstype "$selected_device")
    local format_needed=false

    if [ -z "$fstype" ]; then
        print_status "warn" "Device has no filesystem"
        if ask_yes_no "Format device with ext4 filesystem?"; then
            format_needed=true
        else
            print_status "error" "Cannot proceed without filesystem"
            return 1
        fi
    elif [[ ! "$fstype" =~ ^(ext4|ext3|ntfs|exfat)$ ]]; then
        print_status "warn" "Device has unsupported filesystem: $fstype"
        if ask_yes_no "Reformat device with ext4 filesystem?"; then
            format_needed=true
        else
            print_status "error" "Unsupported filesystem type"
            return 1
        fi
    fi

    # Setup storage
    if setup_nextcloud_storage "$selected_device" "$mount_point" "$format_needed"; then
        # Save configuration
        save_config "STORAGE_DEVICE" "$selected_device"
        save_config "STORAGE_MOUNT_POINT" "$mount_point"
        save_config "STORAGE_DATA_DIR" "$mount_point/nextcloud-data"
        return 0
    else
        return 1
    fi
}

# =============================================================================
# INITIALIZATION
# =============================================================================

log_message "INIT" "Storage detection utilities loaded"