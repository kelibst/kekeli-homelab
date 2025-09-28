#!/bin/bash
# common.sh - Common utility functions for Kekeli-HomeCloud installer
# Part of the Kekeli-HomeCloud Easy Installer Project

# Colors for output (only define if not already defined)
if [[ -z "${RED:-}" ]]; then
    readonly RED='\033[0;31m'
    readonly GREEN='\033[0;32m'
    readonly YELLOW='\033[1;33m'
    readonly BLUE='\033[0;34m'
    readonly CYAN='\033[0;36m'
    readonly MAGENTA='\033[0;35m'
    readonly NC='\033[0m' # No Color
fi

# Common exit codes (only define if not already defined)
if [[ -z "${SUCCESS:-}" ]]; then
    readonly SUCCESS=0
    readonly ERROR_GENERAL=1
    readonly ERROR_OS_NOT_SUPPORTED=2
    readonly ERROR_INSUFFICIENT_RESOURCES=3
    readonly ERROR_NETWORK_UNAVAILABLE=4
    readonly ERROR_PERMISSION_DENIED=5
    readonly ERROR_DOCKER_UNAVAILABLE=6
    readonly ERROR_USER_ABORT=7
fi

# Global configuration (only define if not already defined)
if [[ -z "${KEKELI_CONFIG_DIR:-}" ]]; then
    readonly KEKELI_CONFIG_DIR="$HOME/.kekeli-homecloud"
    readonly KEKELI_LOG_FILE="$KEKELI_CONFIG_DIR/install.log"
    readonly KEKELI_CONFIG_FILE="$KEKELI_CONFIG_DIR/config.env"
fi

# Ensure config directory exists
mkdir -p "$KEKELI_CONFIG_DIR" 2>/dev/null

# =============================================================================
# OUTPUT AND LOGGING FUNCTIONS
# =============================================================================

# Function to print status with icon and color
print_status() {
    local status=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

    case $status in
        "pass"|"success")
            echo -e "  ✅ ${GREEN}$message${NC}"
            echo "[$timestamp] [SUCCESS] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
            ;;
        "warn"|"warning")
            echo -e "  ⚠️  ${YELLOW}$message${NC}"
            echo "[$timestamp] [WARNING] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
            ;;
        "fail"|"error")
            echo -e "  ❌ ${RED}$message${NC}"
            echo "[$timestamp] [ERROR] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
            ;;
        "info")
            echo -e "  ℹ️  ${CYAN}$message${NC}"
            echo "[$timestamp] [INFO] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
            ;;
        "progress")
            echo -e "  🔄 ${BLUE}$message${NC}"
            echo "[$timestamp] [PROGRESS] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
            ;;
        "question")
            echo -e "  ❓ ${MAGENTA}$message${NC}"
            echo "[$timestamp] [QUESTION] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
            ;;
        *)
            echo -e "  📝 $message"
            echo "[$timestamp] [LOG] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
            ;;
    esac
}

# Function for logging without console output
log_message() {
    local level=$1
    local message=$2
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [$level] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
}

# Function to print section headers
print_section() {
    local title=$1
    local icon=$2
    echo ""
    echo -e "${BLUE}$icon $title${NC}"
    echo -e "${BLUE}$(printf '%.0s=' $(seq 1 $((${#title} + ${#icon} + 1))))${NC}"
    echo ""
    log_message "SECTION" "$title"
}

# Function to print subsection headers
print_subsection() {
    local title=$1
    echo -e "${YELLOW}🔸 $title${NC}"
    log_message "SUBSECTION" "$title"
}

# =============================================================================
# USER INPUT FUNCTIONS
# =============================================================================

# Function to ask yes/no questions with default
ask_yes_no() {
    local question=$1
    local default=${2:-"n"}
    local response

    if [ "$default" = "y" ]; then
        print_status "question" "$question [Y/n]: "
        read -r response
        case ${response:-y} in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    else
        print_status "question" "$question [y/N]: "
        read -r response
        case $response in
            [Yy]*) return 0 ;;
            *) return 1 ;;
        esac
    fi
}

# Function to get user input with validation
get_user_input() {
    local prompt=$1
    local default=$2
    local validator=$3
    local value

    # Check if running in non-interactive mode
    if [ ! -t 0 ] || [ "${KEKELI_NON_INTERACTIVE:-false}" = "true" ]; then
        if [ -n "$default" ]; then
            log_info "Non-interactive mode: Using default value for '$prompt': $default"
            echo "$default"
            return 0
        else
            log_error "Non-interactive mode: No default value for required input '$prompt'"
            return 1
        fi
    fi

    while true; do
        if [ -n "$default" ]; then
            print_status "question" "$prompt [$default]: "
        else
            print_status "question" "$prompt: "
        fi

        read -r value
        value=${value:-$default}

        # If no validator specified, accept any non-empty value
        if [ -z "$validator" ]; then
            if [ -n "$value" ]; then
                echo "$value"
                return 0
            fi
        else
            # Run validator function
            if $validator "$value"; then
                echo "$value"
                return 0
            fi
        fi

        print_status "error" "Invalid input. Please try again."
    done
}

# Function to get password input
get_password() {
    local prompt=$1
    local confirm=${2:-false}
    local password
    local password_confirm

    while true; do
        print_status "question" "$prompt: "
        read -s password
        echo ""

        if [ -z "$password" ]; then
            print_status "error" "Password cannot be empty. Please try again."
            continue
        fi

        if [ "$confirm" = true ]; then
            print_status "question" "Confirm password: "
            read -s password_confirm
            echo ""

            if [ "$password" != "$password_confirm" ]; then
                print_status "error" "Passwords do not match. Please try again."
                continue
            fi
        fi

        echo "$password"
        return 0
    done
}

# =============================================================================
# SYSTEM DETECTION FUNCTIONS
# =============================================================================

# Function to detect operating system
detect_os() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Function to detect OS version
detect_os_version() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "$VERSION_ID"
    else
        echo "unknown"
    fi
}

# Function to detect if running in WSL
is_wsl() {
    grep -qi microsoft /proc/version 2>/dev/null
}

# Function to detect package manager
detect_package_manager() {
    if command -v apt >/dev/null 2>&1; then
        echo "apt"
    elif command -v yum >/dev/null 2>&1; then
        echo "yum"
    elif command -v dnf >/dev/null 2>&1; then
        echo "dnf"
    elif command -v pacman >/dev/null 2>&1; then
        echo "pacman"
    else
        echo "unknown"
    fi
}

# Function to check if running as root
is_root() {
    [ "$EUID" -eq 0 ]
}

# Function to check if user has sudo privileges
has_sudo() {
    sudo -n true 2>/dev/null || sudo -v >/dev/null 2>&1
}

# =============================================================================
# NETWORK FUNCTIONS
# =============================================================================

# Function to check internet connectivity
check_internet() {
    local test_urls=(
        "8.8.8.8"
        "1.1.1.1"
        "google.com"
    )

    for url in "${test_urls[@]}"; do
        if ping -c 1 -W 5 "$url" >/dev/null 2>&1; then
            return 0
        fi
    done
    return 1
}

# Function to get local IP addresses
get_local_ips() {
    ip -4 addr show | grep -oP '(?<=inet\s)\d+(\.\d+){3}' | grep -v 127.0.0.1
}

# Function to detect primary network interface
get_primary_interface() {
    ip route | grep default | awk '{print $5}' | head -1
}

# Function to get Windows IP from WSL
get_windows_ip_from_wsl() {
    if is_wsl; then
        # Try PowerShell method first
        local windows_ip=$(powershell.exe -Command "
            \$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
                \$_.IPAddress -notmatch '^127\.' -and
                \$_.IPAddress -notmatch '^169\.254\.' -and
                \$_.IPAddress -notmatch '^172\.1[6-9]\.' -and
                \$_.IPAddress -notmatch '^172\.2[0-9]\.' -and
                \$_.IPAddress -notmatch '^172\.3[0-1]\.' -and
                \$_.InterfaceAlias -notmatch 'WSL' -and
                \$_.InterfaceAlias -notmatch 'Loopback'
            } | Sort-Object InterfaceIndex;
            \$mainAdapter = \$adapters | Where-Object {
                \$_.InterfaceAlias -match 'Wi-Fi|Ethernet|Wireless'
            } | Select-Object -First 1;
            if (-not \$mainAdapter) {
                \$mainAdapter = \$adapters | Select-Object -First 1;
            };
            if (\$mainAdapter) {
                Write-Output \$mainAdapter.IPAddress;
            }
        " 2>/dev/null | tr -d '\r\n' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')

        # Fallback to gateway IP
        if [ -z "$windows_ip" ]; then
            windows_ip=$(ip route show | grep default | awk '{print $3}')
        fi

        echo "$windows_ip"
    fi
}

# =============================================================================
# FILE AND DIRECTORY FUNCTIONS
# =============================================================================

# Function to create directory with proper permissions
create_directory() {
    local dir_path=$1
    local permissions=${2:-755}
    local owner=${3:-$USER}

    if [ ! -d "$dir_path" ]; then
        if mkdir -p "$dir_path" 2>/dev/null; then
            chmod "$permissions" "$dir_path" 2>/dev/null
            if [ "$owner" != "$USER" ] && has_sudo; then
                sudo chown "$owner:$owner" "$dir_path" 2>/dev/null
            fi
            return 0
        else
            return 1
        fi
    fi
    return 0
}

# Function to backup file
backup_file() {
    local file_path=$1
    local backup_suffix=${2:-".backup.$(date +%Y%m%d_%H%M%S)"}

    if [ -f "$file_path" ]; then
        cp "$file_path" "$file_path$backup_suffix" 2>/dev/null
        return $?
    fi
    return 1
}

# Function to check file exists and is readable
file_readable() {
    [ -f "$1" ] && [ -r "$1" ]
}

# Function to check directory exists and is writable
dir_writable() {
    [ -d "$1" ] && [ -w "$1" ]
}

# =============================================================================
# RESOURCE CHECKING FUNCTIONS
# =============================================================================

# Function to check available disk space (in GB)
get_available_disk_space() {
    local path=${1:-.}
    df "$path" | tail -1 | awk '{print int($4/1024/1024)}'
}

# Function to check available memory (in MB)
get_available_memory() {
    grep MemAvailable /proc/meminfo | awk '{print int($2/1024)}'
}

# Function to check total memory (in MB)
get_total_memory() {
    grep MemTotal /proc/meminfo | awk '{print int($2/1024)}'
}

# Function to get CPU cores
get_cpu_cores() {
    nproc
}

# =============================================================================
# DOCKER UTILITY FUNCTIONS
# =============================================================================

# Function to check if Docker is installed
docker_installed() {
    command -v docker >/dev/null 2>&1
}

# Function to check if Docker is running
docker_running() {
    docker info >/dev/null 2>&1
}

# Function to check if user is in docker group
user_in_docker_group() {
    groups "$USER" | grep -q docker
}

# Function to check if Docker Compose is available
docker_compose_available() {
    docker compose version >/dev/null 2>&1 || command -v docker-compose >/dev/null 2>&1
}

# =============================================================================
# PROGRESS AND SPINNER FUNCTIONS
# =============================================================================

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local message=${3:-""}
    local width=50
    local percentage=$((current * 100 / total))
    local filled=$((width * current / total))
    local empty=$((width - filled))

    printf "\r  🔄 $message "
    printf "["
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "] %d%%" $percentage
}

# Function to complete progress bar
complete_progress() {
    local message=${1:-"Complete"}
    printf "\r  ✅ ${GREEN}$message${NC}\n"
}

# Spinner function for long-running operations
show_spinner() {
    local pid=$1
    local message=$2
    local delay=0.1
    local spinstr='|/-\'

    printf "  🔄 $message "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "[%c]" "$spinstr"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
        printf "\b\b\b"
    done
    printf "\b\b\b"
}

# =============================================================================
# VALIDATION FUNCTIONS
# =============================================================================

# Function to validate IP address
validate_ip() {
    local ip=$1
    if [[ $ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        local IFS='.'
        local -a parts=($ip)
        for part in "${parts[@]}"; do
            if [ $part -gt 255 ]; then
                return 1
            fi
        done
        return 0
    fi
    return 1
}

# Function to validate port number
validate_port() {
    local port=$1
    if [[ $port =~ ^[0-9]+$ ]] && [ $port -ge 1 ] && [ $port -le 65535 ]; then
        return 0
    fi
    return 1
}

# Function to validate email address
validate_email() {
    local email=$1
    if [[ $email =~ ^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$ ]]; then
        return 0
    fi
    return 1
}

# Function to validate domain name
validate_domain() {
    local domain=$1
    if [[ $domain =~ ^[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)*$ ]]; then
        return 0
    fi
    return 1
}

# =============================================================================
# CLEANUP AND ERROR HANDLING FUNCTIONS
# =============================================================================

# Function to cleanup on script exit
cleanup_on_exit() {
    local exit_code=$?
    log_message "EXIT" "Script exiting with code $exit_code"

    # Add any cleanup tasks here
    # Remove temporary files, kill background processes, etc.

    exit $exit_code
}

# Function to handle script interruption
handle_interrupt() {
    echo ""
    print_status "warn" "Installation interrupted by user"
    log_message "INTERRUPT" "User interrupted installation"
    exit $ERROR_USER_ABORT
}

# Signal handlers are available but not auto-enabled
# Individual scripts can call: trap cleanup_on_exit EXIT
# Individual scripts can call: trap handle_interrupt INT TERM

# =============================================================================
# CONFIGURATION FUNCTIONS
# =============================================================================

# Function to save configuration value
save_config() {
    local key=$1
    local value=$2

    # Create config file if it doesn't exist
    touch "$KEKELI_CONFIG_FILE" 2>/dev/null

    # Remove existing key if present
    if [ -f "$KEKELI_CONFIG_FILE" ] && [ -s "$KEKELI_CONFIG_FILE" ]; then
        grep -v "^$key=" "$KEKELI_CONFIG_FILE" > "${KEKELI_CONFIG_FILE}.tmp" 2>/dev/null || true
        mv "${KEKELI_CONFIG_FILE}.tmp" "$KEKELI_CONFIG_FILE" 2>/dev/null || true
    fi

    # Add new key-value pair
    echo "$key=$value" >> "$KEKELI_CONFIG_FILE" 2>/dev/null
}

# Function to load configuration value
load_config() {
    local key=$1
    local default=$2

    if [ -f "$KEKELI_CONFIG_FILE" ] && grep -q "^$key=" "$KEKELI_CONFIG_FILE"; then
        grep "^$key=" "$KEKELI_CONFIG_FILE" | cut -d'=' -f2- | tail -1
    else
        echo "$default"
    fi
}

# Function to load all configuration
load_all_config() {
    if [ -f "$KEKELI_CONFIG_FILE" ]; then
        source "$KEKELI_CONFIG_FILE" 2>/dev/null
    fi
}

# =============================================================================
# UTILITY FUNCTIONS
# =============================================================================

# Function to convert human readable size to bytes
human_to_bytes() {
    local size=$1
    local number=$(echo "$size" | grep -oE '^[0-9]+(\.[0-9]+)?')
    local unit=$(echo "$size" | grep -oE '[KMGT]?B?$' | tr '[:lower:]' '[:upper:]')

    case $unit in
        B|'') echo "$number" ;;
        KB) echo "$number * 1024" | bc ;;
        MB) echo "$number * 1024 * 1024" | bc ;;
        GB) echo "$number * 1024 * 1024 * 1024" | bc ;;
        TB) echo "$number * 1024 * 1024 * 1024 * 1024" | bc ;;
        *) echo "0" ;;
    esac
}

# Function to convert bytes to human readable
bytes_to_human() {
    local bytes=$1
    if [ $bytes -gt 1073741824 ]; then
        echo "$(echo "$bytes / 1073741824" | bc -l | awk '{printf "%.1f", $1}') GB"
    elif [ $bytes -gt 1048576 ]; then
        echo "$(echo "$bytes / 1048576" | bc -l | awk '{printf "%.1f", $1}') MB"
    elif [ $bytes -gt 1024 ]; then
        echo "$(echo "$bytes / 1024" | bc -l | awk '{printf "%.1f", $1}') KB"
    else
        echo "$bytes B"
    fi
}

# Function to generate random string
generate_random_string() {
    local length=${1:-32}
    tr -dc 'A-Za-z0-9' < /dev/urandom | head -c "$length"
}

# Function to wait for user input
wait_for_user() {
    local message=${1:-"Press Enter to continue..."}
    print_status "question" "$message"
    read -r
}

# Function to check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# =============================================================================
# MAIN INSTALLER FUNCTIONS
# =============================================================================

# Function to setup logging for main installer
setup_logging() {
    local debug_mode=${1:-false}

    # Ensure log directory exists
    mkdir -p "$KEKELI_CONFIG_DIR" 2>/dev/null

    # Create or clear log file
    echo "# Kekeli-HomeCloud Installation Log" > "$KEKELI_LOG_FILE"
    echo "# Started: $(date)" >> "$KEKELI_LOG_FILE"
    echo "" >> "$KEKELI_LOG_FILE"

    if [ "$debug_mode" = true ]; then
        log_message "SETUP" "Debug mode enabled"
    fi

    log_message "SETUP" "Logging initialized - $KEKELI_LOG_FILE"
}

# Function for main installer info logging
log_info() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [INFO] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
}

# Function for main installer error logging
log_error() {
    local message=$1
    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    echo "[$timestamp] [ERROR] $message" >> "$KEKELI_LOG_FILE" 2>/dev/null
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Initialize logging
log_message "INIT" "Common utilities loaded - $(basename "${BASH_SOURCE[1]}")"

# Verify essential commands are available
for cmd in awk grep sed curl wget; do
    if ! command_exists "$cmd"; then
        print_status "warn" "Command '$cmd' not found - some features may not work properly"
    fi
done