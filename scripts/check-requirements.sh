#!/bin/bash
# check-requirements.sh - Validate system requirements for Kekeli-HomeCloud installer
# Part of the Kekeli-HomeCloud Easy Installer Project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Requirements
MIN_DISK_SPACE_GB=4
RECOMMENDED_DISK_SPACE_GB=10
MIN_MEMORY_MB=2048
RECOMMENDED_MEMORY_MB=4096

# Exit codes
SUCCESS=0
ERROR_OS_NOT_SUPPORTED=1
ERROR_INSUFFICIENT_DISK=2
ERROR_INSUFFICIENT_MEMORY=3
ERROR_NO_NETWORK=4
ERROR_NO_SUDO=5
ERROR_DOCKER_UNAVAILABLE=6

echo -e "${BLUE}🔍 Kekeli-HomeCloud Requirements Checker${NC}"
echo -e "${BLUE}======================================${NC}"
echo ""

# Function to print status with icon
print_status() {
    local status=$1
    local message=$2
    case $status in
        "pass")
            echo -e "  ✅ ${GREEN}$message${NC}"
            ;;
        "warn")
            echo -e "  ⚠️  ${YELLOW}$message${NC}"
            ;;
        "fail")
            echo -e "  ❌ ${RED}$message${NC}"
            ;;
        "info")
            echo -e "  ℹ️  ${CYAN}$message${NC}"
            ;;
    esac
}

# Function to convert bytes to human readable format
human_readable_size() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(($bytes / 1073741824)) GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(($bytes / 1048576)) MB"
    else
        echo "$(($bytes / 1024)) KB"
    fi
}

# Check operating system support
check_os_support() {
    echo -e "${YELLOW}📱 Checking Operating System Support...${NC}"

    local os_supported=false
    local os_info=""

    if [ -f /etc/os-release ]; then
        source /etc/os-release
        os_info="$PRETTY_NAME"

        case $ID in
            ubuntu)
                if [[ "$VERSION_ID" =~ ^(18\.04|20\.04|22\.04|24\.04)$ ]]; then
                    os_supported=true
                fi
                ;;
            debian)
                if [[ "$VERSION_ID" =~ ^(10|11|12)$ ]]; then
                    os_supported=true
                fi
                ;;
            deepin)
                os_supported=true
                ;;
        esac
    fi

    # Check for WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
        os_info="$os_info (WSL2)"
        os_supported=true
    fi

    if [ "$os_supported" = true ]; then
        print_status "pass" "Operating System: $os_info"
        return 0
    else
        print_status "fail" "Unsupported OS: $os_info"
        echo -e "${RED}    Supported: Ubuntu 18.04+, Debian 10+, DeepinOS, WSL2${NC}"
        return $ERROR_OS_NOT_SUPPORTED
    fi
}

# Check available disk space
check_disk_space() {
    echo -e "${YELLOW}💾 Checking Disk Space...${NC}"

    local available_space_kb=$(df . | tail -1 | awk '{print $4}')
    local available_space_gb=$((available_space_kb / 1024 / 1024))
    local available_space_mb=$((available_space_kb / 1024))

    print_status "info" "Available space: $(human_readable_size $((available_space_kb * 1024)))"

    if [ $available_space_gb -ge $RECOMMENDED_DISK_SPACE_GB ]; then
        print_status "pass" "Disk space: Excellent (>= ${RECOMMENDED_DISK_SPACE_GB}GB)"
        return 0
    elif [ $available_space_gb -ge $MIN_DISK_SPACE_GB ]; then
        print_status "warn" "Disk space: Adequate (>= ${MIN_DISK_SPACE_GB}GB, recommended: ${RECOMMENDED_DISK_SPACE_GB}GB)"
        return 0
    else
        print_status "fail" "Insufficient disk space: ${available_space_gb}GB (minimum: ${MIN_DISK_SPACE_GB}GB)"
        return $ERROR_INSUFFICIENT_DISK
    fi
}

# Check available memory
check_memory() {
    echo -e "${YELLOW}🧠 Checking Available Memory...${NC}"

    local total_memory_kb=$(grep MemTotal /proc/meminfo | awk '{print $2}')
    local available_memory_kb=$(grep MemAvailable /proc/meminfo | awk '{print $2}')
    local total_memory_mb=$((total_memory_kb / 1024))
    local available_memory_mb=$((available_memory_kb / 1024))

    print_status "info" "Total memory: $(human_readable_size $((total_memory_kb * 1024)))"
    print_status "info" "Available memory: $(human_readable_size $((available_memory_kb * 1024)))"

    if [ $available_memory_mb -ge $RECOMMENDED_MEMORY_MB ]; then
        print_status "pass" "Memory: Excellent (>= ${RECOMMENDED_MEMORY_MB}MB available)"
        return 0
    elif [ $available_memory_mb -ge $MIN_MEMORY_MB ]; then
        print_status "warn" "Memory: Adequate (>= ${MIN_MEMORY_MB}MB available, recommended: ${RECOMMENDED_MEMORY_MB}MB)"
        return 0
    else
        print_status "fail" "Insufficient memory: ${available_memory_mb}MB available (minimum: ${MIN_MEMORY_MB}MB)"
        return $ERROR_INSUFFICIENT_MEMORY
    fi
}

# Check network connectivity
check_network() {
    echo -e "${YELLOW}🌐 Checking Network Connectivity...${NC}"

    # Check internet connectivity
    if ping -c 1 -W 5 8.8.8.8 >/dev/null 2>&1; then
        print_status "pass" "Internet connectivity: Available"
    else
        print_status "fail" "No internet connectivity (required for Docker installation)"
        return $ERROR_NO_NETWORK
    fi

    # Check local network interfaces
    local interfaces=$(ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1)
    if [ -n "$interfaces" ]; then
        print_status "pass" "Local network interfaces: Available"
        while IFS= read -r ip; do
            print_status "info" "  Interface IP: $ip"
        done <<< "$interfaces"
    else
        print_status "warn" "No local network interfaces found (mobile access may be limited)"
    fi

    return 0
}

# Check sudo privileges
check_sudo() {
    echo -e "${YELLOW}🔐 Checking Administrative Privileges...${NC}"

    if sudo -n true 2>/dev/null; then
        print_status "pass" "Sudo privileges: Available (passwordless)"
        return 0
    elif sudo -l >/dev/null 2>&1; then
        print_status "pass" "Sudo privileges: Available (password required)"
        return 0
    else
        print_status "fail" "No sudo privileges (required for system configuration)"
        echo -e "${RED}    Run: sudo usermod -aG sudo \$USER${NC}"
        echo -e "${RED}    Then log out and back in${NC}"
        return $ERROR_NO_SUDO
    fi
}

# Check Docker availability
check_docker() {
    echo -e "${YELLOW}🐳 Checking Docker Availability...${NC}"

    local docker_available=false
    local docker_compose_available=false

    # Check if Docker is already installed and working
    if command -v docker >/dev/null 2>&1; then
        if docker --version >/dev/null 2>&1; then
            local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
            print_status "pass" "Docker installed: $docker_version"
            docker_available=true

            # Check if user is in docker group
            if groups $USER | grep -q docker; then
                print_status "pass" "Docker group membership: OK"
            else
                print_status "warn" "User not in docker group (will be added during installation)"
            fi

            # Check Docker daemon
            if docker info >/dev/null 2>&1; then
                print_status "pass" "Docker daemon: Running"
            else
                print_status "warn" "Docker daemon: Not running (will be started during installation)"
            fi
        else
            print_status "warn" "Docker installed but not working properly"
        fi
    else
        print_status "info" "Docker not installed (will be installed automatically)"
    fi

    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
        print_status "pass" "Docker Compose installed: $compose_version"
        docker_compose_available=true
    elif docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version | awk '{print $4}')
        print_status "pass" "Docker Compose (plugin) installed: $compose_version"
        docker_compose_available=true
    else
        print_status "info" "Docker Compose not installed (will be installed automatically)"
    fi

    # Check if installation is possible
    if [ "$docker_available" = false ]; then
        # Check if we can install Docker
        if command -v apt >/dev/null 2>&1; then
            print_status "pass" "Package manager: apt (Docker installation supported)"
        elif command -v yum >/dev/null 2>&1; then
            print_status "warn" "Package manager: yum (Docker installation may require manual steps)"
        else
            print_status "fail" "No supported package manager for automatic Docker installation"
            return $ERROR_DOCKER_UNAVAILABLE
        fi
    fi

    return 0
}

# Check external storage detection
check_storage_detection() {
    echo -e "${YELLOW}📁 Checking Storage Detection...${NC}"

    # Check for common external storage mount points
    local storage_found=false
    local mount_points=(
        "/mnt"
        "/media"
        "/Volumes"
    )

    for mount_point in "${mount_points[@]}"; do
        if [ -d "$mount_point" ]; then
            local devices=$(find "$mount_point" -maxdepth 2 -type d 2>/dev/null | wc -l)
            if [ $devices -gt 1 ]; then
                print_status "info" "External storage mount point: $mount_point ($((devices-1)) devices)"
                storage_found=true
            fi
        fi
    done

    # Check for block devices
    local block_devices=$(lsblk -J 2>/dev/null | grep -c '"type":"disk"')
    if [ $block_devices -gt 0 ]; then
        print_status "pass" "Block devices detected: $block_devices"
    fi

    # Check for UUID availability (for persistent mounting)
    if command -v blkid >/dev/null 2>&1; then
        print_status "pass" "UUID detection: Available (blkid)"
    else
        print_status "warn" "UUID detection: Not available (may affect persistent mounting)"
    fi

    print_status "info" "External storage will be detected during installation"
    return 0
}

# Main requirements check
main() {
    local overall_status=0
    local warnings=0

    echo -e "${CYAN}Starting comprehensive system requirements check...${NC}"
    echo ""

    # Run all checks
    check_os_support || overall_status=$?
    echo ""

    check_disk_space || overall_status=$?
    echo ""

    check_memory || { overall_status=$?; }
    echo ""

    check_network || overall_status=$?
    echo ""

    check_sudo || overall_status=$?
    echo ""

    check_docker || overall_status=$?
    echo ""

    check_storage_detection
    echo ""

    # Final summary
    echo -e "${BLUE}======================================${NC}"
    if [ $overall_status -eq 0 ]; then
        echo -e "${GREEN}✅ Requirements Check: PASSED${NC}"
        echo -e "${GREEN}Your system is ready for Kekeli-HomeCloud installation!${NC}"
        echo ""
        echo -e "${CYAN}Next steps:${NC}"
        echo -e "  1. Run: ./install.sh"
        echo -e "  2. Follow the interactive setup wizard"
        echo -e "  3. Access your Nextcloud via web browser"
    else
        echo -e "${RED}❌ Requirements Check: FAILED${NC}"
        echo -e "${RED}Please resolve the issues above before installation.${NC}"
        echo ""
        echo -e "${CYAN}Common solutions:${NC}"
        case $overall_status in
            $ERROR_OS_NOT_SUPPORTED)
                echo -e "  • Upgrade to a supported OS version"
                echo -e "  • Use WSL2 on Windows with a supported Linux distribution"
                ;;
            $ERROR_INSUFFICIENT_DISK)
                echo -e "  • Free up disk space or add external storage"
                echo -e "  • Move to a location with more available space"
                ;;
            $ERROR_INSUFFICIENT_MEMORY)
                echo -e "  • Close unnecessary applications"
                echo -e "  • Add more RAM to your system"
                ;;
            $ERROR_NO_NETWORK)
                echo -e "  • Check your internet connection"
                echo -e "  • Verify network configuration"
                ;;
            $ERROR_NO_SUDO)
                echo -e "  • Contact your system administrator"
                echo -e "  • Run: sudo usermod -aG sudo \$USER && logout"
                ;;
            $ERROR_DOCKER_UNAVAILABLE)
                echo -e "  • Install Docker manually: https://docs.docker.com/install/"
                echo -e "  • Use a supported Linux distribution"
                ;;
        esac
    fi

    echo ""
    exit $overall_status
}

# Help function
show_help() {
    echo "Kekeli-HomeCloud Requirements Checker"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo "  -q, --quiet   Quiet mode (only show final result)"
    echo "  -v, --verbose Verbose mode (show detailed information)"
    echo ""
    echo "Exit codes:"
    echo "  0 - All requirements met"
    echo "  1 - Unsupported operating system"
    echo "  2 - Insufficient disk space"
    echo "  3 - Insufficient memory"
    echo "  4 - No network connectivity"
    echo "  5 - No sudo privileges"
    echo "  6 - Docker unavailable"
}

# Parse command line arguments
case ${1:-} in
    -h|--help)
        show_help
        exit 0
        ;;
    -q|--quiet)
        exec >/dev/null
        ;;
    -v|--verbose)
        set -x
        ;;
esac

# Run main function
main "$@"