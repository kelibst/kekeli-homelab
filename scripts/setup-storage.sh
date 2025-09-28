#!/bin/bash
# setup-storage.sh - Storage detection and setup for Kekeli-HomeCloud
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/error-handling.sh"
source "$UTILS_DIR/storage-detection.sh"

# =============================================================================
# STORAGE SETUP CONFIGURATION
# =============================================================================

readonly DEFAULT_MOUNT_POINT="/mnt/nextcloud-data"
readonly DEFAULT_DATA_DIR="nextcloud-data"
readonly MIN_STORAGE_SIZE_GB=5
readonly RECOMMENDED_STORAGE_SIZE_GB=20

# =============================================================================
# MAIN STORAGE SETUP FUNCTIONS
# =============================================================================

# Function to perform interactive storage setup
interactive_storage_setup() {
    print_section "💾" "Kekeli-HomeCloud Storage Setup"

    print_status "info" "Setting up storage for your Nextcloud instance"
    echo -e "${CYAN}This will configure where Nextcloud stores your files and data.${NC}"
    echo ""

    print_status "progress" "Initializing storage setup process..."
    print_status "info" "Checking system requirements and available storage options"

    set_operation "Interactive Storage Setup"

    # Check for existing configuration
    print_status "progress" "Checking for existing storage configuration..."
    print_status "info" "Loading configuration from: $KEKELI_CONFIG_FILE"
    local existing_storage_device=$(load_config "STORAGE_DEVICE")
    local existing_mount_point=$(load_config "STORAGE_MOUNT_POINT")
    print_status "info" "Existing device: ${existing_storage_device:-none}, mount point: ${existing_mount_point:-none}"

    if [ -n "$existing_storage_device" ] && [ -n "$existing_mount_point" ]; then
        print_status "pass" "Found existing storage configuration!"
        echo -e "  Device: ${CYAN}/dev/$existing_storage_device${NC}"
        echo -e "  Mount Point: ${CYAN}$existing_mount_point${NC}"
        echo ""
        print_status "info" "Validating existing configuration before proceeding..."

        if ask_yes_no "Use existing storage configuration?" "y"; then
            if validate_existing_storage "$existing_storage_device" "$existing_mount_point"; then
                complete_operation "success"
                return 0
            else
                print_status "warn" "Existing configuration is invalid, setting up new storage"
            fi
        fi
    fi

    # Offer storage options
    print_status "info" "Presenting storage configuration options..."
    echo -e "${CYAN}Storage Options:${NC}"
    echo -e "  ${GREEN}1.${NC} Auto-detect and setup external storage (recommended)"
    echo -e "  ${GREEN}2.${NC} Use existing directory on current drive"
    echo -e "  ${GREEN}3.${NC} Manual storage device selection"
    echo -e "  ${GREEN}4.${NC} Skip storage setup (use Docker volumes)"
    echo ""

    local choice=$(get_user_input "Select storage option (1-4)" "1")

    case $choice in
        1)
            print_status "progress" "Starting auto-detection of optimal storage..."
            if setup_auto_detected_storage; then
                complete_operation "success"
                return 0
            else
                print_status "warn" "Auto-detection failed, falling back to manual selection"
                print_status "progress" "Attempting manual storage selection as fallback..."
                if setup_manual_storage_selection; then
                    complete_operation "success"
                    return 0
                else
                    print_status "warn" "Manual selection failed, falling back to local directory storage"
                    print_status "progress" "Attempting local directory storage as final fallback..."
                    if setup_local_directory_storage; then
                        complete_operation "success"
                        return 0
                    fi
                fi
            fi
            ;;
        2)
            print_status "progress" "Starting local directory storage setup..."
            if setup_local_directory_storage; then
                complete_operation "success"
                return 0
            fi
            ;;
        3)
            print_status "progress" "Starting manual storage device selection..."
            if setup_manual_storage_selection; then
                complete_operation "success"
                return 0
            fi
            ;;
        4)
            print_status "progress" "Setting up Docker volume storage..."
            if setup_docker_volume_storage; then
                complete_operation "success"
                return 0
            fi
            ;;
        *)
            handle_recoverable_error "Invalid choice: $choice"
            complete_operation "failed"
            return 1
            ;;
    esac

    complete_operation "failed"
    return 1
}

# Function to setup auto-detected storage
setup_auto_detected_storage() {
    print_subsection "Auto-Detecting Optimal Storage"

    print_status "progress" "Scanning system for available storage devices..."
    print_status "info" "Looking for external drives, USB devices, and additional storage"

    local recommended_device
    recommended_device=$(detect_optimal_storage)

    if [ $? -ne 0 ] || [ -z "$recommended_device" ]; then
        print_status "warn" "No suitable external storage detected"
        print_status "info" "Auto-detection requires external storage devices with sufficient space"
        print_status "info" "Consider connecting a USB drive or external hard drive"
        return 1
    fi

    print_status "progress" "Analyzing recommended device: /dev/$recommended_device"

    local device_size_bytes=$(get_device_size "$recommended_device")
    local device_size_gb=$((device_size_bytes / 1024 / 1024 / 1024))
    local device_fstype=$(get_device_fstype "$recommended_device")
    local device_mount=$(get_device_mountpoint "$recommended_device")

    print_status "info" "Device analysis complete - gathering details..."

    print_status "pass" "Recommended device: /dev/$recommended_device"
    print_status "info" "Size: ${device_size_gb}GB"
    print_status "info" "Filesystem: ${device_fstype:-unknown}"
    print_status "info" "Currently mounted: ${device_mount:-no}"

    if [ $device_size_gb -lt $MIN_STORAGE_SIZE_GB ]; then
        print_status "error" "Device too small (${device_size_gb}GB < ${MIN_STORAGE_SIZE_GB}GB minimum)"
        print_status "info" "Nextcloud requires at least ${MIN_STORAGE_SIZE_GB}GB for basic operation"
        print_status "info" "Recommended minimum: ${RECOMMENDED_STORAGE_SIZE_GB}GB for better performance"
        return 1
    fi

    echo ""
    print_status "info" "Device meets requirements - ready for setup"
    if ask_yes_no "Use /dev/$recommended_device for Nextcloud data storage?" "y"; then
        print_status "progress" "User confirmed - proceeding with device setup..."
        return setup_device_storage "$recommended_device"
    else
        print_status "info" "User declined recommended device - setup cancelled"
    fi

    return 1
}

# Function to setup storage on a specific device
setup_device_storage() {
    local device=$1
    local mount_point=${2:-"$DEFAULT_MOUNT_POINT"}
    local format_device=false

    print_subsection "Setting Up Device Storage: /dev/$device"
    print_status "progress" "Initializing device storage setup process..."
    print_status "info" "This will prepare /dev/$device for Nextcloud data storage"

    # Validate device exists
    print_status "progress" "Validating device accessibility..."
    if [ ! -b "/dev/$device" ]; then
        handle_critical_error "Device does not exist: /dev/$device"
        return 1
    fi
    print_status "pass" "Device /dev/$device found and accessible"

    # Check filesystem
    print_status "progress" "Analyzing device filesystem..."
    local fstype=$(get_device_fstype "$device")
    if [ -z "$fstype" ]; then
        print_status "warn" "Device /dev/$device has no filesystem"
        print_status "info" "Device appears to be unformatted or has corrupted filesystem"
        if ask_yes_no "Format device with ext4 filesystem? (THIS WILL ERASE ALL DATA)" "n"; then
            format_device=true
            print_status "progress" "User confirmed formatting - will create ext4 filesystem"
        else
            print_status "error" "Cannot proceed without filesystem"
            return 1
        fi
    elif [[ ! "$fstype" =~ ^(ext4|ext3|ntfs|exfat)$ ]]; then
        print_status "warn" "Device has unsupported filesystem: $fstype"
        print_status "info" "Supported filesystems: ext4, ext3, ntfs, exfat"
        if ask_yes_no "Reformat device with ext4? (THIS WILL ERASE ALL DATA)" "n"; then
            format_device=true
            print_status "progress" "User confirmed reformatting - will create ext4 filesystem"
        else
            print_status "error" "Unsupported filesystem type"
            return 1
        fi
    else
        print_status "pass" "Device filesystem ($fstype) is compatible"
    fi

    # Get mount point preference
    echo ""
    print_status "progress" "Configuring mount point for device..."
    mount_point=$(get_user_input "Mount point for storage" "$mount_point")
    print_status "info" "Selected mount point: $mount_point"

    # Validate mount point
    print_status "progress" "Validating mount point location..."
    validate_mount_point "$mount_point"
    local validate_result=$?
    if [ $validate_result -eq 1 ]; then
        print_status "error" "Mount point validation failed"
        return 1
    elif [ $validate_result -eq 2 ]; then
        print_status "warn" "Mount point contains existing files"
        if ! ask_yes_no "Mount point not empty. Continue anyway?"; then
            print_status "info" "User cancelled due to non-empty mount point"
            return 1
        fi
        print_status "progress" "User confirmed - proceeding with non-empty mount point"
    else
        print_status "pass" "Mount point validation successful"
    fi

    # Unmount if currently mounted elsewhere
    print_status "progress" "Checking current mount status..."
    local current_mount=$(get_device_mountpoint "$device")
    if [ -n "$current_mount" ] && [ "$current_mount" != "$mount_point" ]; then
        print_status "info" "Device currently mounted at: $current_mount"
        print_status "progress" "Unmounting /dev/$device from $current_mount..."
        if safe_execute "sudo umount /dev/$device" "Unmount device" false; then
            print_status "pass" "Device unmounted successfully"
        else
            handle_recoverable_error "Could not unmount device"
            return 1
        fi
    elif [ -n "$current_mount" ] && [ "$current_mount" = "$mount_point" ]; then
        print_status "info" "Device already mounted at target location: $mount_point"
    else
        print_status "info" "Device not currently mounted"
    fi

    # Format if requested
    if [ "$format_device" = true ]; then
        print_status "progress" "Formatting device with ext4 filesystem..."
        print_status "warn" "This will permanently erase all data on /dev/$device"
        if ! format_device "$device" "ext4"; then
            print_status "error" "Device formatting failed"
            return 1
        fi
        fstype="ext4"
        print_status "pass" "Device formatted successfully with ext4"
    fi

    # Create mount point
    print_status "progress" "Creating mount point directory..."
    if ! create_directory "$mount_point" 755; then
        handle_critical_error "Failed to create mount point: $mount_point"
        return 1
    fi
    print_status "pass" "Mount point created: $mount_point"

    # Mount device
    print_status "progress" "Mounting /dev/$device to $mount_point..."
    print_status "info" "Filesystem type: $fstype"
    local mount_options="defaults"

    # Add user permissions for NTFS/exFAT
    if [[ "$fstype" =~ ^(ntfs|exfat)$ ]]; then
        mount_options="defaults,uid=$(id -u),gid=$(id -g),umask=0022"
        print_status "info" "Using enhanced permissions for $fstype filesystem"
    fi

    print_status "info" "Mount options: $mount_options"
    if ! mount_device "$device" "$mount_point" "$fstype" "$mount_options"; then
        print_status "error" "Failed to mount device"
        return 1
    fi
    print_status "pass" "Device mounted successfully"

    # Add to fstab for persistence
    print_status "progress" "Configuring persistent mount (fstab entry)..."
    if add_to_fstab "$device" "$mount_point" "$fstype" "$mount_options"; then
        print_status "pass" "Added persistent mount configuration"
        print_status "info" "Device will automatically mount after system reboot"
    else
        print_status "warn" "Could not add to fstab - mount will not persist after reboot"
        print_status "info" "You may need to manually mount the device after reboot"
    fi

    # Set up Nextcloud data directory
    print_status "progress" "Setting up Nextcloud data directory structure..."
    local data_dir="$mount_point/$DEFAULT_DATA_DIR"
    print_status "info" "Creating Nextcloud data directory at: $data_dir"
    if ! setup_nextcloud_data_directory "$data_dir"; then
        print_status "error" "Failed to setup Nextcloud data directory"
        return 1
    fi

    # Save configuration
    print_status "progress" "Saving storage configuration..."
    save_storage_configuration "$device" "$mount_point" "$data_dir"

    print_status "pass" "Device storage setup completed successfully!"
    print_status "info" "Storage ready for Nextcloud deployment"
    return 0
}

# Function to setup local directory storage
setup_local_directory_storage() {
    print_subsection "Setting Up Local Directory Storage"

    print_status "progress" "Initializing local directory storage setup..."
    local base_dir=$(pwd)
    local default_data_dir="$base_dir/nextcloud-data"

    print_status "info" "Setting up storage in current project directory"
    echo -e "${CYAN}This will create a Nextcloud data directory on your current drive.${NC}"
    echo -e "${YELLOW}Note: This uses the same drive as your system and Docker.${NC}"
    echo ""
    print_status "info" "Base directory: $base_dir"

    local data_dir=$(get_user_input "Data directory path" "$default_data_dir")
    print_status "info" "Selected data directory: $data_dir"

    # Validate path
    print_status "progress" "Validating directory path and permissions..."
    local parent_dir=$(dirname "$data_dir")
    if [ ! -d "$parent_dir" ]; then
        print_status "error" "Parent directory does not exist: $parent_dir"
        handle_recoverable_error "Parent directory does not exist: $parent_dir"
        return 1
    fi

    if [ ! -w "$parent_dir" ]; then
        print_status "error" "Parent directory not writable: $parent_dir"
        handle_recoverable_error "Parent directory not writable: $parent_dir"
        return 1
    fi
    print_status "pass" "Directory path validation successful"

    # Check available space
    print_status "progress" "Checking available disk space..."
    local available_gb=$(get_available_disk_space "$parent_dir")
    if [ $available_gb -lt $MIN_STORAGE_SIZE_GB ]; then
        print_status "error" "Insufficient disk space: ${available_gb}GB (minimum: ${MIN_STORAGE_SIZE_GB}GB)"
        handle_recoverable_error "Insufficient disk space: ${available_gb}GB (minimum: ${MIN_STORAGE_SIZE_GB}GB)"
        return 1
    fi

    print_status "pass" "Available space: ${available_gb}GB"
    if [ $available_gb -lt $RECOMMENDED_STORAGE_SIZE_GB ]; then
        print_status "warn" "Available space below recommended ${RECOMMENDED_STORAGE_SIZE_GB}GB"
        print_status "info" "Nextcloud will work but may run out of space with heavy usage"
    else
        print_status "pass" "Available space meets recommended requirements"
    fi

    # Create data directory
    print_status "progress" "Creating local data directory structure..."
    if ! setup_nextcloud_data_directory "$data_dir"; then
        print_status "error" "Failed to create local data directory"
        return 1
    fi

    # Save configuration
    print_status "progress" "Saving local storage configuration..."
    save_config "STORAGE_TYPE" "local"
    save_config "STORAGE_DATA_DIR" "$data_dir"

    print_status "pass" "Local directory storage setup completed!"
    print_status "info" "Local storage ready for Nextcloud deployment"
    return 0
}

# Function to setup manual storage selection
setup_manual_storage_selection() {
    print_subsection "Manual Storage Selection"

    # Use the interactive selection from storage-detection.sh
    interactive_storage_selection
    local selection_result=$?

    case $selection_result in
        0)
            print_status "pass" "Manual storage selection completed"
            return 0
            ;;
        2)
            print_status "info" "Storage setup skipped by user"
            return setup_docker_volume_storage
            ;;
        *)
            print_status "error" "Manual storage selection failed"
            return 1
            ;;
    esac
}

# Function to setup Docker volume storage
setup_docker_volume_storage() {
    print_subsection "Setting Up Docker Volume Storage"

    print_status "progress" "Configuring Docker managed volume storage..."
    print_status "info" "Using Docker managed volumes for Nextcloud data"
    echo -e "${CYAN}This creates Docker-managed storage volumes.${NC}"
    echo -e "${YELLOW}Data will be stored in Docker's volume directory.${NC}"
    echo ""
    print_status "info" "Docker volumes provide automatic management and backup capabilities"
    print_status "info" "Volume location: Docker's internal volume directory (usually /var/lib/docker/volumes)"

    if ask_yes_no "Use Docker volumes for storage?" "y"; then
        # Save configuration
        print_status "progress" "Saving Docker volume configuration..."
        save_config "STORAGE_TYPE" "docker-volume"
        save_config "STORAGE_DATA_DIR" "nextcloud-data"  # Docker volume name

        print_status "pass" "Docker volume storage configured"
        print_status "info" "Docker will automatically create and manage the volume"
        print_status "info" "Volume name: nextcloud-data"
        return 0
    else
        print_status "info" "User declined Docker volume storage"
    fi

    return 1
}

# Function to setup Nextcloud data directory
setup_nextcloud_data_directory() {
    local data_dir=$1

    print_status "progress" "Setting up Nextcloud data directory: $data_dir"
    print_status "info" "Creating directory structure for Nextcloud data, config, and apps"

    # Create directory structure
    print_status "progress" "Creating main data directory..."
    if ! create_directory "$data_dir" 755; then
        handle_critical_error "Failed to create data directory: $data_dir"
        return 1
    fi
    print_status "pass" "Main data directory created"

    # Create subdirectories
    print_status "progress" "Creating Nextcloud subdirectory structure..."
    local subdirs=(
        "data"
        "config"
        "custom_apps"
        "themes"
    )

    print_status "info" "Creating ${#subdirs[@]} subdirectories for Nextcloud components"
    for subdir in "${subdirs[@]}"; do
        print_status "progress" "Creating subdirectory: $subdir"
        if create_directory "$data_dir/$subdir" 755; then
            print_status "pass" "Created: $data_dir/$subdir"
        else
            print_status "warn" "Could not create: $data_dir/$subdir"
        fi
    done

    # Set proper ownership and permissions for Docker
    print_status "progress" "Setting permissions for Docker access..."
    print_status "info" "Configuring permissions for Nextcloud container (www-data user)"

    # Get www-data UID/GID (typically 33:33)
    local www_data_uid=33
    local www_data_gid=33
    print_status "info" "Using www-data UID:GID ($www_data_uid:$www_data_gid) for container access"

    # Set ownership to www-data for Nextcloud access
    print_status "progress" "Setting directory ownership to www-data..."
    if safe_execute "sudo chown -R $www_data_uid:$www_data_gid '$data_dir'" "Set data directory ownership" false; then
        print_status "pass" "Set ownership to www-data (optimal for containers)"
    else
        # Fallback to current user
        print_status "warn" "Could not set www-data ownership, falling back to current user"
        print_status "progress" "Setting ownership to current user as fallback..."
        if safe_execute "chown -R $USER:$USER '$data_dir'" "Set data directory ownership to current user" false; then
            print_status "pass" "Set ownership to current user ($USER)"
            print_status "info" "Note: Container may need to adjust permissions at runtime"
        else
            print_status "warn" "Could not set proper ownership"
        fi
    fi

    # Set permissions
    print_status "progress" "Setting directory permissions (755)..."
    if safe_execute "chmod -R 755 '$data_dir'" "Set data directory permissions"; then
        print_status "pass" "Set directory permissions (755 - read/write/execute for owner, read/execute for others)"
    else
        print_status "warn" "Could not set directory permissions"
    fi

    # Create a test file to verify write access
    print_status "progress" "Testing directory write permissions..."
    local test_file="$data_dir/.kekeli-test"
    if echo "Kekeli-HomeCloud test file - $(date)" > "$test_file" 2>/dev/null; then
        rm -f "$test_file" 2>/dev/null
        print_status "pass" "Data directory write test successful"
        print_status "info" "Directory is ready for Nextcloud container access"
    else
        print_status "warn" "Data directory write test failed"
        print_status "info" "Container may need to adjust permissions at startup"
    fi

    print_status "pass" "Nextcloud data directory setup completed"
    print_status "info" "Directory structure and permissions configured for Nextcloud"
    return 0
}

# Function to validate existing storage configuration
validate_existing_storage() {
    local device=$1
    local mount_point=$2

    print_status "progress" "Validating existing storage configuration..."

    # Check if device exists
    if [ ! -b "/dev/$device" ]; then
        print_status "error" "Configured device does not exist: /dev/$device"
        return 1
    fi

    # Check if mount point exists and is mounted
    if [ ! -d "$mount_point" ]; then
        print_status "error" "Mount point does not exist: $mount_point"
        return 1
    fi

    # Check if device is mounted at mount point
    if ! mount | grep -q "/dev/$device.*$mount_point"; then
        print_status "warn" "Device not currently mounted at configured location"

        if ask_yes_no "Attempt to mount device now?"; then
            local fstype=$(get_device_fstype "$device")
            if mount_device "$device" "$mount_point" "$fstype"; then
                print_status "pass" "Device mounted successfully"
            else
                return 1
            fi
        else
            return 1
        fi
    fi

    # Check data directory
    local data_dir=$(load_config "STORAGE_DATA_DIR" "$mount_point/$DEFAULT_DATA_DIR")
    if [ ! -d "$data_dir" ]; then
        print_status "warn" "Data directory missing: $data_dir"
        if ! setup_nextcloud_data_directory "$data_dir"; then
            return 1
        fi
    fi

    print_status "pass" "Existing storage configuration is valid"
    return 0
}

# Function to save storage configuration
save_storage_configuration() {
    local device=$1
    local mount_point=$2
    local data_dir=$3

    save_config "STORAGE_TYPE" "device"
    save_config "STORAGE_DEVICE" "$device"
    save_config "STORAGE_MOUNT_POINT" "$mount_point"
    save_config "STORAGE_DATA_DIR" "$data_dir"

    print_status "pass" "Storage configuration saved"
}

# Function to display storage summary
show_storage_summary() {
    print_section "📊" "Storage Configuration Summary"

    local storage_type=$(load_config "STORAGE_TYPE")
    local storage_device=$(load_config "STORAGE_DEVICE")
    local storage_mount_point=$(load_config "STORAGE_MOUNT_POINT")
    local storage_data_dir=$(load_config "STORAGE_DATA_DIR")

    echo -e "${CYAN}Storage Configuration:${NC}"
    echo -e "  Type: ${GREEN}$storage_type${NC}"

    case "$storage_type" in
        "device")
            echo -e "  Device: ${GREEN}/dev/$storage_device${NC}"
            echo -e "  Mount Point: ${GREEN}$storage_mount_point${NC}"
            echo -e "  Data Directory: ${GREEN}$storage_data_dir${NC}"

            # Show device info
            if [ -b "/dev/$storage_device" ]; then
                local size_bytes=$(get_device_size "$storage_device")
                local size_gb=$((size_bytes / 1024 / 1024 / 1024))
                local fstype=$(get_device_fstype "$storage_device")
                echo -e "  Size: ${GREEN}${size_gb}GB${NC}"
                echo -e "  Filesystem: ${GREEN}$fstype${NC}"
            fi
            ;;
        "local")
            echo -e "  Data Directory: ${GREEN}$storage_data_dir${NC}"
            local available_gb=$(get_available_disk_space "$(dirname "$storage_data_dir")")
            echo -e "  Available Space: ${GREEN}${available_gb}GB${NC}"
            ;;
        "docker-volume")
            echo -e "  Volume Name: ${GREEN}$storage_data_dir${NC}"
            echo -e "  Managed by: ${GREEN}Docker${NC}"
            ;;
    esac

    echo ""
    print_status "pass" "Storage ready for Nextcloud deployment"
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

# Help function
show_help() {
    echo "Kekeli-HomeCloud Storage Setup"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -a, --auto        Auto-detect and setup optimal storage"
    echo "  -l, --local       Use local directory storage"
    echo "  -d, --docker      Use Docker volume storage"
    echo "  -m, --manual      Manual storage device selection"
    echo "  -s, --summary     Show current storage configuration"
    echo "  -v, --validate    Validate existing storage setup"
    echo ""
    echo "Examples:"
    echo "  $0 --auto        # Auto-detect best storage option"
    echo "  $0 --local       # Use local directory"
    echo "  $0 --summary     # Show current configuration"
}

# Main function
main() {
    # Immediate feedback to user
    print_status "progress" "Starting storage configuration..."

    local auto_mode=false
    local local_mode=false
    local docker_mode=false
    local manual_mode=false
    local summary_mode=false
    local validate_mode=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -a|--auto)
                auto_mode=true
                shift
                ;;
            -l|--local)
                local_mode=true
                shift
                ;;
            -d|--docker)
                docker_mode=true
                shift
                ;;
            -m|--manual)
                manual_mode=true
                shift
                ;;
            -s|--summary)
                summary_mode=true
                shift
                ;;
            -v|--validate)
                validate_mode=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    # Initialize error handling
    set_error_context "Storage Setup"

    # Handle specific modes
    if [ "$summary_mode" = true ]; then
        show_storage_summary
        exit 0
    fi

    if [ "$validate_mode" = true ]; then
        local device=$(load_config "STORAGE_DEVICE")
        local mount_point=$(load_config "STORAGE_MOUNT_POINT")

        if [ -n "$device" ] && [ -n "$mount_point" ]; then
            if validate_existing_storage "$device" "$mount_point"; then
                print_status "pass" "Storage validation successful"
                exit 0
            else
                print_status "fail" "Storage validation failed"
                exit 1
            fi
        else
            print_status "error" "No storage configuration found to validate"
            exit 1
        fi
    fi

    # Execute storage setup based on mode
    local setup_success=false

    if [ "$auto_mode" = true ]; then
        print_status "info" "Running in auto-detection mode"
        if setup_auto_detected_storage; then
            setup_success=true
        else
            setup_success=false
        fi
    elif [ "$local_mode" = true ]; then
        print_status "info" "Running in local directory mode"
        if setup_local_directory_storage; then
            setup_success=true
        else
            setup_success=false
        fi
    elif [ "$docker_mode" = true ]; then
        print_status "info" "Running in Docker volume mode"
        if setup_docker_volume_storage; then
            setup_success=true
        else
            setup_success=false
        fi
    elif [ "$manual_mode" = true ]; then
        print_status "info" "Running in manual selection mode"
        if setup_manual_storage_selection; then
            setup_success=true
        else
            setup_success=false
        fi
    else
        # Interactive mode (default)
        if interactive_storage_setup; then
            setup_success=true
        else
            setup_success=false
        fi
    fi

    # Show summary if setup was successful
    if [ "$setup_success" = true ]; then
        echo ""
        show_storage_summary
        echo ""
        print_status "pass" "Storage setup completed successfully!"
        echo -e "${CYAN}Next step: Run network configuration${NC}"
        exit 0
    else
        print_status "fail" "Storage setup failed"
        exit 1
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi