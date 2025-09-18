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

    set_operation "Interactive Storage Setup"

    # Check for existing configuration
    local existing_storage_device=$(load_config "STORAGE_DEVICE")
    local existing_mount_point=$(load_config "STORAGE_MOUNT_POINT")

    if [ -n "$existing_storage_device" ] && [ -n "$existing_mount_point" ]; then
        print_status "info" "Found existing storage configuration:"
        echo -e "  Device: ${CYAN}/dev/$existing_storage_device${NC}"
        echo -e "  Mount Point: ${CYAN}$existing_mount_point${NC}"
        echo ""

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
    echo -e "${CYAN}Storage Options:${NC}"
    echo -e "  ${GREEN}1.${NC} Auto-detect and setup external storage (recommended)"
    echo -e "  ${GREEN}2.${NC} Use existing directory on current drive"
    echo -e "  ${GREEN}3.${NC} Manual storage device selection"
    echo -e "  ${GREEN}4.${NC} Skip storage setup (use Docker volumes)"
    echo ""

    local choice=$(get_user_input "Select storage option (1-4)" "1")

    case $choice in
        1)
            if setup_auto_detected_storage; then
                complete_operation "success"
                return 0
            else
                print_status "warn" "Auto-detection failed, falling back to manual selection"
                if setup_manual_storage_selection; then
                    complete_operation "success"
                    return 0
                fi
            fi
            ;;
        2)
            if setup_local_directory_storage; then
                complete_operation "success"
                return 0
            fi
            ;;
        3)
            if setup_manual_storage_selection; then
                complete_operation "success"
                return 0
            fi
            ;;
        4)
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

    local recommended_device
    recommended_device=$(detect_optimal_storage)

    if [ $? -ne 0 ] || [ -z "$recommended_device" ]; then
        print_status "warn" "No suitable external storage detected"
        return 1
    fi

    local device_size_bytes=$(get_device_size "$recommended_device")
    local device_size_gb=$((device_size_bytes / 1024 / 1024 / 1024))
    local device_fstype=$(get_device_fstype "$recommended_device")
    local device_mount=$(get_device_mountpoint "$recommended_device")

    print_status "pass" "Recommended device: /dev/$recommended_device"
    print_status "info" "Size: ${device_size_gb}GB"
    print_status "info" "Filesystem: ${device_fstype:-unknown}"
    print_status "info" "Currently mounted: ${device_mount:-no}"

    if [ $device_size_gb -lt $MIN_STORAGE_SIZE_GB ]; then
        print_status "error" "Device too small (${device_size_gb}GB < ${MIN_STORAGE_SIZE_GB}GB minimum)"
        return 1
    fi

    echo ""
    if ask_yes_no "Use /dev/$recommended_device for Nextcloud data storage?" "y"; then
        return setup_device_storage "$recommended_device"
    fi

    return 1
}

# Function to setup storage on a specific device
setup_device_storage() {
    local device=$1
    local mount_point=${2:-"$DEFAULT_MOUNT_POINT"}
    local format_device=false

    print_subsection "Setting Up Device Storage: /dev/$device"

    # Validate device exists
    if [ ! -b "/dev/$device" ]; then
        handle_critical_error "Device does not exist: /dev/$device"
        return 1
    fi

    # Check filesystem
    local fstype=$(get_device_fstype "$device")
    if [ -z "$fstype" ]; then
        print_status "warn" "Device /dev/$device has no filesystem"
        if ask_yes_no "Format device with ext4 filesystem? (THIS WILL ERASE ALL DATA)" "n"; then
            format_device=true
        else
            print_status "error" "Cannot proceed without filesystem"
            return 1
        fi
    elif [[ ! "$fstype" =~ ^(ext4|ext3|ntfs|exfat)$ ]]; then
        print_status "warn" "Device has unsupported filesystem: $fstype"
        if ask_yes_no "Reformat device with ext4? (THIS WILL ERASE ALL DATA)" "n"; then
            format_device=true
        else
            print_status "error" "Unsupported filesystem type"
            return 1
        fi
    fi

    # Get mount point preference
    echo ""
    mount_point=$(get_user_input "Mount point for storage" "$mount_point")

    # Validate mount point
    validate_mount_point "$mount_point"
    local validate_result=$?
    if [ $validate_result -eq 1 ]; then
        return 1
    elif [ $validate_result -eq 2 ]; then
        if ! ask_yes_no "Mount point not empty. Continue anyway?"; then
            return 1
        fi
    fi

    # Unmount if currently mounted elsewhere
    local current_mount=$(get_device_mountpoint "$device")
    if [ -n "$current_mount" ] && [ "$current_mount" != "$mount_point" ]; then
        print_status "progress" "Unmounting /dev/$device from $current_mount..."
        if safe_execute "sudo umount /dev/$device" "Unmount device" false; then
            print_status "pass" "Device unmounted successfully"
        else
            handle_recoverable_error "Could not unmount device"
            return 1
        fi
    fi

    # Format if requested
    if [ "$format_device" = true ]; then
        if ! format_device "$device" "ext4"; then
            return 1
        fi
        fstype="ext4"
    fi

    # Create mount point
    if ! create_directory "$mount_point" 755; then
        handle_critical_error "Failed to create mount point: $mount_point"
        return 1
    fi

    # Mount device
    print_status "progress" "Mounting /dev/$device to $mount_point..."
    local mount_options="defaults"

    # Add user permissions for NTFS/exFAT
    if [[ "$fstype" =~ ^(ntfs|exfat)$ ]]; then
        mount_options="defaults,uid=$(id -u),gid=$(id -g),umask=0022"
    fi

    if ! mount_device "$device" "$mount_point" "$fstype" "$mount_options"; then
        return 1
    fi

    # Add to fstab for persistence
    if add_to_fstab "$device" "$mount_point" "$fstype" "$mount_options"; then
        print_status "pass" "Added persistent mount configuration"
    else
        print_status "warn" "Could not add to fstab - mount will not persist after reboot"
    fi

    # Set up Nextcloud data directory
    local data_dir="$mount_point/$DEFAULT_DATA_DIR"
    if ! setup_nextcloud_data_directory "$data_dir"; then
        return 1
    fi

    # Save configuration
    save_storage_configuration "$device" "$mount_point" "$data_dir"

    print_status "pass" "Device storage setup completed successfully!"
    return 0
}

# Function to setup local directory storage
setup_local_directory_storage() {
    print_subsection "Setting Up Local Directory Storage"

    local base_dir=$(pwd)
    local default_data_dir="$base_dir/nextcloud-data"

    echo -e "${CYAN}This will create a Nextcloud data directory on your current drive.${NC}"
    echo -e "${YELLOW}Note: This uses the same drive as your system and Docker.${NC}"
    echo ""

    local data_dir=$(get_user_input "Data directory path" "$default_data_dir")

    # Validate path
    local parent_dir=$(dirname "$data_dir")
    if [ ! -d "$parent_dir" ]; then
        handle_recoverable_error "Parent directory does not exist: $parent_dir"
        return 1
    fi

    if [ ! -w "$parent_dir" ]; then
        handle_recoverable_error "Parent directory not writable: $parent_dir"
        return 1
    fi

    # Check available space
    local available_gb=$(get_available_disk_space "$parent_dir")
    if [ $available_gb -lt $MIN_STORAGE_SIZE_GB ]; then
        handle_recoverable_error "Insufficient disk space: ${available_gb}GB (minimum: ${MIN_STORAGE_SIZE_GB}GB)"
        return 1
    fi

    print_status "info" "Available space: ${available_gb}GB"
    if [ $available_gb -lt $RECOMMENDED_STORAGE_SIZE_GB ]; then
        print_status "warn" "Available space below recommended ${RECOMMENDED_STORAGE_SIZE_GB}GB"
    fi

    # Create data directory
    if ! setup_nextcloud_data_directory "$data_dir"; then
        return 1
    fi

    # Save configuration
    save_config "STORAGE_TYPE" "local"
    save_config "STORAGE_DATA_DIR" "$data_dir"

    print_status "pass" "Local directory storage setup completed!"
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

    print_status "info" "Using Docker managed volumes for Nextcloud data"
    echo -e "${CYAN}This creates Docker-managed storage volumes.${NC}"
    echo -e "${YELLOW}Data will be stored in Docker's volume directory.${NC}"
    echo ""

    if ask_yes_no "Use Docker volumes for storage?" "y"; then
        # Save configuration
        save_config "STORAGE_TYPE" "docker-volume"
        save_config "STORAGE_DATA_DIR" "nextcloud-data"  # Docker volume name

        print_status "pass" "Docker volume storage configured"
        return 0
    fi

    return 1
}

# Function to setup Nextcloud data directory
setup_nextcloud_data_directory() {
    local data_dir=$1

    print_status "progress" "Setting up Nextcloud data directory: $data_dir"

    # Create directory structure
    if ! create_directory "$data_dir" 755; then
        handle_critical_error "Failed to create data directory: $data_dir"
        return 1
    fi

    # Create subdirectories
    local subdirs=(
        "data"
        "config"
        "custom_apps"
        "themes"
    )

    for subdir in "${subdirs[@]}"; do
        if create_directory "$data_dir/$subdir" 755; then
            print_status "pass" "Created: $data_dir/$subdir"
        else
            print_status "warn" "Could not create: $data_dir/$subdir"
        fi
    done

    # Set proper ownership and permissions for Docker
    print_status "progress" "Setting permissions for Docker access..."

    # Get www-data UID/GID (typically 33:33)
    local www_data_uid=33
    local www_data_gid=33

    # Set ownership to www-data for Nextcloud access
    if safe_execute "sudo chown -R $www_data_uid:$www_data_gid '$data_dir'" "Set data directory ownership" false; then
        print_status "pass" "Set ownership to www-data"
    else
        # Fallback to current user
        if safe_execute "chown -R $USER:$USER '$data_dir'" "Set data directory ownership to current user" false; then
            print_status "pass" "Set ownership to current user"
        else
            print_status "warn" "Could not set proper ownership"
        fi
    fi

    # Set permissions
    if safe_execute "chmod -R 755 '$data_dir'" "Set data directory permissions"; then
        print_status "pass" "Set directory permissions"
    fi

    # Create a test file to verify write access
    local test_file="$data_dir/.kekeli-test"
    if echo "Kekeli-HomeCloud test file" > "$test_file" 2>/dev/null; then
        rm -f "$test_file" 2>/dev/null
        print_status "pass" "Data directory write test successful"
    else
        print_status "warn" "Data directory write test failed"
    fi

    print_status "pass" "Nextcloud data directory setup completed"
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
        setup_success=$(setup_auto_detected_storage && echo true || echo false)
    elif [ "$local_mode" = true ]; then
        setup_success=$(setup_local_directory_storage && echo true || echo false)
    elif [ "$docker_mode" = true ]; then
        setup_success=$(setup_docker_volume_storage && echo true || echo false)
    elif [ "$manual_mode" = true ]; then
        setup_success=$(setup_manual_storage_selection && echo true || echo false)
    else
        # Interactive mode (default)
        setup_success=$(interactive_storage_setup && echo true || echo false)
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