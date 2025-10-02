#!/bin/bash
# install-menu.sh - Interactive Step-by-Step Kekeli-HomeCloud Installer
# Part of the Kekeli-HomeCloud Easy Installer Project

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/scripts/utils/common.sh" 2>/dev/null || {
    echo "Error: Cannot find required utility files. Please run from project root."
    exit 1
}

# =============================================================================
# INSTALLATION PHASES CONFIGURATION
# =============================================================================

# Define installation phases
declare -A PHASES=(
    ["1"]="requirements|System Requirements Check|Check if your system meets all requirements"
    ["2"]="docker|Docker Setup|Install and configure Docker containers"
    ["3"]="storage|Storage Configuration|Set up data storage for Nextcloud"
    ["4"]="networking|Network Configuration|Configure network access and firewall"
    ["5"]="nextcloud|Nextcloud Deployment|Deploy and configure Nextcloud server"
    ["6"]="mobile|Mobile Setup|Configure mobile device access"
    ["7"]="static-ip|Advanced Static IP (Optional)|Configure persistent IP for frequent reboots"
)

# Phase order for display
PHASE_ORDER=("1" "2" "3" "4" "5" "6" "7")

# Scripts for each phase
declare -A PHASE_SCRIPTS=(
    ["requirements"]="$SCRIPT_DIR/scripts/check-requirements.sh"
    ["docker"]="$SCRIPT_DIR/scripts/setup-docker.sh"
    ["storage"]="$SCRIPT_DIR/scripts/setup-storage.sh"
    ["networking"]="$SCRIPT_DIR/scripts/setup-networking.sh"
    ["nextcloud"]="$SCRIPT_DIR/scripts/setup-nextcloud.sh"
    ["mobile"]="$SCRIPT_DIR/scripts/setup-mobile.sh"
    ["static-ip"]="$SCRIPT_DIR/scripts/setup-static-ip.sh"
)

# =============================================================================
# STATUS MANAGEMENT FUNCTIONS
# =============================================================================

# Function to get phase status
get_phase_status() {
    local phase_key=$1
    local completed_phases=$(load_config "COMPLETED_PHASES" "")

    if [[ "$completed_phases" == *"$phase_key"* ]]; then
        echo "completed"
    else
        # Check if this phase has any saved configuration
        case $phase_key in
            "docker")
                if docker --version >/dev/null 2>&1 && docker info >/dev/null 2>&1; then
                    echo "ready"
                else
                    echo "pending"
                fi
                ;;
            "storage")
                local storage_type=$(load_config "STORAGE_TYPE" "")
                if [[ -n "$storage_type" ]]; then
                    echo "ready"
                else
                    echo "pending"
                fi
                ;;
            "networking")
                local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "")
                if [[ -n "$nextcloud_port" ]]; then
                    echo "ready"
                else
                    echo "pending"
                fi
                ;;
            "nextcloud")
                if docker ps --format "table {{.Names}}" | grep -q "kekeli-nextcloud"; then
                    echo "ready"
                else
                    echo "pending"
                fi
                ;;
            *)
                echo "pending"
                ;;
        esac
    fi
}

# Function to get status icon
get_status_icon() {
    local status=$1
    case $status in
        "completed") echo "✅" ;;
        "ready") echo "🔄" ;;
        "pending") echo "⏳" ;;
        "error") echo "❌" ;;
        *) echo "⏳" ;;
    esac
}

# Function to get status color
get_status_color() {
    local status=$1
    case $status in
        "completed") echo "${GREEN}" ;;
        "ready") echo "${BLUE}" ;;
        "pending") echo "${YELLOW}" ;;
        "error") echo "${RED}" ;;
        *) echo "${NC}" ;;
    esac
}

# =============================================================================
# DISPLAY FUNCTIONS
# =============================================================================

# Function to show header
show_header() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}                 ${GREEN}🏠 Kekeli-HomeCloud Installer${NC}                 ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}                    ${CYAN}Step-by-Step Setup${NC}                       ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
}

# Function to show installation progress
show_progress() {
    echo -e "${CYAN}📋 Installation Progress:${NC}"
    echo ""

    for phase_num in "${PHASE_ORDER[@]}"; do
        local phase_info="${PHASES[$phase_num]}"
        local phase_key=$(echo "$phase_info" | cut -d'|' -f1)
        local phase_name=$(echo "$phase_info" | cut -d'|' -f2)
        local phase_desc=$(echo "$phase_info" | cut -d'|' -f3)

        local status=$(get_phase_status "$phase_key")
        local icon=$(get_status_icon "$status")
        local color=$(get_status_color "$status")

        printf "  %s ${color}%s. %s${NC}\n" "$icon" "$phase_num" "$phase_name"
        printf "     ${CYAN}%s${NC}\n" "$phase_desc"
        echo ""
    done
}

# Function to show current configuration
show_configuration() {
    # Check Docker status first
    local docker_status=$(get_docker_status_summary)

    # Show Docker running services prominently if they exist
    if [[ "$docker_status" == "all_running" || "$docker_status" == "partially_running" ]]; then
        show_running_services_summary "$docker_status"
    fi

    echo -e "${CYAN}📝 Current Configuration:${NC}"
    echo ""

    # Docker Status
    if docker --version >/dev/null 2>&1; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        case $docker_status in
            "all_running")
                echo -e "  ${GREEN}🐳 Docker:${NC} $docker_version ${GREEN}(All services running)${NC}"
                ;;
            "partially_running")
                echo -e "  ${YELLOW}🐳 Docker:${NC} $docker_version ${YELLOW}(Some services running)${NC}"
                ;;
            "not_running")
                echo -e "  ${YELLOW}🐳 Docker:${NC} $docker_version ${YELLOW}(Services deployed but stopped)${NC}"
                ;;
            "docker_not_running")
                echo -e "  ${RED}🐳 Docker:${NC} $docker_version ${RED}(Daemon not running)${NC}"
                ;;
            *)
                echo -e "  ${GREEN}🐳 Docker:${NC} $docker_version"
                ;;
        esac
    else
        echo -e "  ${YELLOW}🐳 Docker:${NC} Not installed"
    fi

    # Storage Configuration
    local storage_type=$(load_config "STORAGE_TYPE" "")
    local storage_dir=$(load_config "STORAGE_DATA_DIR" "")
    if [[ -n "$storage_type" ]]; then
        echo -e "  ${GREEN}💾 Storage:${NC} $storage_type"
        echo -e "     ${CYAN}Location:${NC} $storage_dir"
    else
        echo -e "  ${YELLOW}💾 Storage:${NC} Not configured"
    fi

    # Network Configuration
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "")
    local primary_ip=$(load_config "PRIMARY_IP" "")
    local host_ip=$(load_config "HOST_IP" "")

    if [[ -n "$nextcloud_port" ]]; then
        echo -e "  ${GREEN}🌐 Network:${NC} Port $nextcloud_port"

        # Show HOST_IP status if configured
        if [[ -n "$host_ip" ]]; then
            echo -e "     ${GREEN}Static IP:${NC} $host_ip (configured via HOST_IP)"
            echo -e "     ${CYAN}Access URL:${NC} http://$host_ip:$nextcloud_port"
        elif [[ -n "$primary_ip" ]]; then
            echo -e "     ${YELLOW}Dynamic IP:${NC} $primary_ip (DHCP)"
            echo -e "     ${CYAN}Access URL:${NC} http://$primary_ip:$nextcloud_port"
            echo -e "     ${CYAN}Tip:${NC} Set HOST_IP in .env for consistent static IP"
        fi
    else
        echo -e "  ${YELLOW}🌐 Network:${NC} Not configured"
    fi

    # Enhanced Nextcloud Status
    case $docker_status in
        "all_running")
            echo -e "  ${GREEN}☁️  Nextcloud:${NC} Running (All services healthy)"
            ;;
        "partially_running")
            echo -e "  ${YELLOW}☁️  Nextcloud:${NC} Partially running (Check services)"
            ;;
        "not_running")
            echo -e "  ${YELLOW}☁️  Nextcloud:${NC} Deployed but stopped"
            ;;
        *)
            echo -e "  ${YELLOW}☁️  Nextcloud:${NC} Not deployed"
            ;;
    esac

    echo ""
}

# Function to show running services summary
show_running_services_summary() {
    local docker_status=$1

    echo -e "${GREEN}✅ SERVICES RUNNING${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    echo ""

    # Check for HOST_IP configuration
    local host_ip=$(load_config "HOST_IP" "")
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")

    if [[ -n "$host_ip" ]]; then
        # HOST_IP is configured - show static IP prominently
        echo -e "${GREEN}🎯 Static IP Configured!${NC}"
        echo -e "${CYAN}Your Nextcloud URL (consistent after reboots):${NC}"
        echo -e "  ${GREEN}➤ http://$host_ip:$nextcloud_port${NC} ${YELLOW}(Recommended - Use this for family access)${NC}"
        echo ""
    fi

    # Show all access routes
    local routes=($(build_access_routes))
    if [[ ${#routes[@]} -gt 0 ]]; then
        if [[ -n "$host_ip" ]]; then
            echo -e "${CYAN}🌐 Alternative access URLs:${NC}"
        else
            echo -e "${CYAN}🌐 Your Nextcloud is accessible at:${NC}"
        fi
        for route in "${routes[@]}"; do
            # Skip showing HOST_IP route again if already shown
            if [[ -n "$host_ip" && "$route" == "http://$host_ip:$nextcloud_port" ]]; then
                continue
            fi
            echo -e "  ${GREEN}➤ $route${NC}"
        done
        echo ""

        echo -e "${CYAN}📱 Mobile Setup:${NC}"
        local admin_user=$(load_config "ADMIN_USER" "admin")
        if [[ -n "$host_ip" ]]; then
            echo -e "  ${GREEN}Server URL:${NC} http://$host_ip:$nextcloud_port ${YELLOW}(Use this - it won't change)${NC}"
        else
            echo -e "  ${GREEN}Server URL:${NC} ${routes[0]}"
            echo -e "  ${YELLOW}💡 Tip:${NC} Set HOST_IP in .env for a consistent URL"
        fi
        echo -e "  ${GREEN}Username:${NC} $admin_user"
        echo -e "  ${GREEN}Password:${NC} (From your .env file)"
        echo ""
    fi

    if [[ "$docker_status" == "partially_running" ]]; then
        echo -e "${YELLOW}⚠️  Note: Some services may not be fully running. Use option [D] to check detailed status.${NC}"
        echo ""
    fi
}

# Function to show menu options
show_menu() {
    echo -e "${CYAN}📌 Available Actions:${NC}"
    echo ""

    # Show runnable phases
    for phase_num in "${PHASE_ORDER[@]}"; do
        local phase_info="${PHASES[$phase_num]}"
        local phase_key=$(echo "$phase_info" | cut -d'|' -f1)
        local phase_name=$(echo "$phase_info" | cut -d'|' -f2)
        local status=$(get_phase_status "$phase_key")

        if [[ "$status" != "completed" ]]; then
            echo -e "  ${GREEN}[$phase_num]${NC} Run: $phase_name"
        fi
    done

    echo ""
    echo -e "  ${GREEN}[D]${NC} Check Docker Status & Routes"
    echo -e "  ${GREEN}[R]${NC} Review Configuration"
    echo -e "  ${GREEN}[L]${NC} View Logs"
    echo -e "  ${GREEN}[I]${NC} Check IP Configuration"
    echo -e "  ${GREEN}[S]${NC} Manage Storage & Sharing"
    echo -e "  ${GREEN}[H]${NC} Help & Troubleshooting"
    echo -e "  ${GREEN}[Q]${NC} Quit"
    echo ""
}

# =============================================================================
# PHASE EXECUTION FUNCTIONS
# =============================================================================

# Function to run a phase
run_phase() {
    local phase_key=$1
    local phase_info=""
    local phase_name=""

    # Find phase info
    for phase_num in "${PHASE_ORDER[@]}"; do
        local info="${PHASES[$phase_num]}"
        local key=$(echo "$info" | cut -d'|' -f1)
        if [[ "$key" == "$phase_key" ]]; then
            phase_info="$info"
            phase_name=$(echo "$info" | cut -d'|' -f2)
            break
        fi
    done

    if [[ -z "$phase_info" ]]; then
        echo -e "${RED}Error: Unknown phase '$phase_key'${NC}"
        return 1
    fi

    local script_path="${PHASE_SCRIPTS[$phase_key]}"

    if [[ ! -f "$script_path" ]]; then
        echo -e "${RED}Error: Script not found: $script_path${NC}"
        return 1
    fi

    echo -e "${BLUE}🚀 Starting: $phase_name${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"
    echo ""

    # Show any special requirements
    show_phase_requirements "$phase_key"

    # Ask for confirmation
    echo -e "${YELLOW}Ready to run this step?${NC}"
    if ! ask_yes_no "Continue with $phase_name?" "y"; then
        echo -e "${CYAN}Step cancelled by user${NC}"
        return 0
    fi

    echo ""
    echo -e "${BLUE}Running: $script_path${NC}"
    echo ""

    # Run the script
    chmod +x "$script_path"
    "$script_path"
    local exit_code=$?

    echo ""
    if [[ $exit_code -eq 0 ]]; then
        echo -e "${GREEN}✅ $phase_name completed successfully!${NC}"
        mark_phase_completed "$phase_key"
    else
        echo -e "${RED}❌ $phase_name failed (exit code: $exit_code)${NC}"
        show_troubleshooting_help "$phase_key"
    fi

    echo ""
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

# Function to show phase requirements
show_phase_requirements() {
    local phase_key=$1

    case $phase_key in
        "docker")
            echo -e "${YELLOW}ℹ️  Requirements:${NC}"
            echo -e "   • This step requires sudo privileges"
            echo -e "   • Internet connection (for downloading Docker)"
            echo ""
            ;;
        "storage")
            echo -e "${YELLOW}ℹ️  Requirements:${NC}"
            echo -e "   • May require sudo for external storage mounting"
            echo -e "   • At least 5GB available disk space"
            echo -e "   • Includes folder sharing configuration with Docker mount points"
            echo ""
            ;;
        "networking")
            echo -e "${YELLOW}ℹ️  Requirements:${NC}"
            echo -e "   • May require sudo for firewall configuration"
            echo -e "   • Network interface available"
            echo -e "   • Includes automatic IP change detection and configuration"
            echo ""
            echo -e "${CYAN}💡 Static IP Feature:${NC}"
            echo -e "   • Set ${GREEN}HOST_IP=192.168.1.98${NC} in .env for automatic static IP"
            echo -e "   • Leave empty to use DHCP (dynamic IP)"
            echo -e "   • Static IP ensures consistent family access URL"
            echo ""
            ;;
        "nextcloud")
            echo -e "${YELLOW}ℹ️  Requirements:${NC}"
            echo -e "   • Docker must be running"
            echo -e "   • Storage must be configured"
            echo -e "   • Network must be configured"
            echo ""
            ;;
        "mobile")
            echo -e "${YELLOW}ℹ️  Requirements:${NC}"
            echo -e "   • Nextcloud must be deployed and running"
            echo -e "   • Network configuration must be completed"
            echo -e "   • Includes automatic IP change detection and mobile URL updates"
            echo ""
            ;;
        "static-ip")
            echo -e "${YELLOW}ℹ️  Requirements:${NC}"
            echo -e "   • Network configuration must be completed"
            echo -e "   • May require sudo for system configuration"
            echo ""
            echo -e "${CYAN}💡 Static IP Methods:${NC}"
            echo -e "   • ${GREEN}Macvlan:${NC} Container gets its own static IP (Recommended)"
            echo -e "   • ${GREEN}Avahi mDNS:${NC} Access via nextcloud.local hostname"
            echo -e "   • ${GREEN}DuckDNS:${NC} Free domain name for internet access"
            echo -e "   • ${GREEN}Combo:${NC} Macvlan + Avahi for maximum reliability"
            echo ""
            echo -e "${YELLOW}⚠️  Best for:${NC}"
            echo -e "   • Starlink Mini or similar (frequent reboots)"
            echo -e "   • CGNAT networks (100.x.x.x IP addresses)"
            echo -e "   • Ensuring consistent family access after reboots"
            echo ""
            ;;
    esac
}

# Function to mark phase as completed
mark_phase_completed() {
    local phase_key=$1
    local completed_phases=$(load_config "COMPLETED_PHASES" "")

    if [[ "$completed_phases" != *"$phase_key"* ]]; then
        if [[ -n "$completed_phases" ]]; then
            completed_phases="$completed_phases,$phase_key"
        else
            completed_phases="$phase_key"
        fi
        save_config "COMPLETED_PHASES" "$completed_phases"
    fi
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Function to show logs
show_logs() {
    echo -e "${BLUE}📋 Installation Logs${NC}"
    echo -e "${BLUE}===================${NC}"
    echo ""

    if [[ -f "$KEKELI_LOG_FILE" ]]; then
        echo -e "${CYAN}Recent log entries:${NC}"
        echo ""
        tail -20 "$KEKELI_LOG_FILE"
        echo ""
        echo -e "${CYAN}Full log location: $KEKELI_LOG_FILE${NC}"
    else
        echo -e "${YELLOW}No log file found yet${NC}"
    fi

    echo ""
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

# Function to show help
show_help() {
    echo -e "${BLUE}📚 Help & Troubleshooting${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""

    echo -e "${CYAN}🔧 Common Issues:${NC}"
    echo ""
    echo -e "${YELLOW}• Permission denied errors:${NC}"
    echo -e "  Run individual scripts with sudo when prompted"
    echo -e "  Example: sudo ./scripts/setup-docker.sh"
    echo ""

    echo -e "${YELLOW}• Docker not working:${NC}"
    echo -e "  Check if Docker daemon is running: sudo systemctl status docker"
    echo -e "  Restart Docker: sudo systemctl restart docker"
    echo ""

    echo -e "${YELLOW}• Storage setup fails:${NC}"
    echo -e "  Check available disk space: df -h"
    echo -e "  Try local directory option instead of external storage"
    echo ""

    echo -e "${YELLOW}• Network access issues:${NC}"
    echo -e "  Check firewall: sudo ufw status"
    echo -e "  Verify IP address: ip addr show"
    echo ""

    echo -e "${CYAN}📖 Documentation:${NC}"
    echo -e "  • Project README: ./README.md"
    echo -e "  • Logs: $KEKELI_LOG_FILE"
    echo -e "  • Configuration: $KEKELI_CONFIG_FILE"
    echo ""

    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

# Function to show troubleshooting for specific phase
show_troubleshooting_help() {
    local phase_key=$1

    echo ""
    echo -e "${YELLOW}🔧 Troubleshooting for $phase_key:${NC}"

    case $phase_key in
        "requirements")
            echo -e "  • Check if your OS is supported (Ubuntu, Debian, WSL2)"
            echo -e "  • Ensure you have enough disk space (4GB minimum)"
            echo -e "  • Verify sudo access: sudo echo 'test'"
            ;;
        "docker")
            echo -e "  • Check internet connection"
            echo -e "  • Verify sudo privileges"
            echo -e "  • Try: sudo systemctl start docker"
            ;;
        "storage")
            echo -e "  • Check disk space: df -h"
            echo -e "  • Try selecting 'local directory' option"
            echo -e "  • Ensure write permissions in project directory"
            ;;
        "networking")
            echo -e "  • Check firewall settings: sudo ufw status"
            echo -e "  • Verify network interfaces: ip addr"
            echo -e "  • Try different port if 8080 is in use"
            ;;
        "nextcloud")
            echo -e "  • Ensure Docker is running: docker info"
            echo -e "  • Check ports are free: netstat -tlnp | grep 8080"
            echo -e "  • Verify storage and network are configured"
            ;;
        "mobile")
            echo -e "  • Ensure Nextcloud is running first"
            echo -e "  • Check network configuration"
            echo -e "  • Verify firewall allows connections"
            ;;
    esac

    echo -e "  • View logs: option [L] from main menu"
    echo -e "  • Full help: option [H] from main menu"
}

# =============================================================================
# MAIN MENU LOOP
# =============================================================================

# Function to get user input
get_menu_choice() {
    echo -ne "${GREEN}Enter your choice: ${NC}" >&2
    read -r choice
    echo "$choice"
}

# =============================================================================
# DOCKER STATUS CHECK FUNCTION
# =============================================================================

# Function to run Docker status check
run_docker_status_check() {
    echo -e "${BLUE}🐳 Docker Status & Routes${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    echo ""

    # Check if the status check script exists
    local status_script="$SCRIPT_DIR/scripts/check-docker-status.sh"
    if [[ -f "$status_script" ]]; then
        # Make it executable and run it
        chmod +x "$status_script"
        "$status_script"
    else
        # Fallback to basic status display
        echo -e "${YELLOW}Docker status script not found. Showing basic status:${NC}"
        echo ""

        local docker_status=$(get_docker_status_summary)
        case $docker_status in
            "all_running")
                echo -e "  ${GREEN}✅ All Kekeli-HomeCloud services are running${NC}"
                ;;
            "partially_running")
                echo -e "  ${YELLOW}⚠️  Some Kekeli-HomeCloud services are running${NC}"
                ;;
            "not_running")
                echo -e "  ${YELLOW}⏹️  Kekeli-HomeCloud services are deployed but stopped${NC}"
                ;;
            "docker_not_running")
                echo -e "  ${RED}❌ Docker daemon is not running${NC}"
                ;;
            "docker_not_installed")
                echo -e "  ${RED}❌ Docker is not installed${NC}"
                ;;
            *)
                echo -e "  ${RED}❓ Unknown Docker status${NC}"
                ;;
        esac

        # Show basic routes if services are running
        if [[ "$docker_status" == "all_running" || "$docker_status" == "partially_running" ]]; then
            echo ""
            echo -e "${CYAN}🌐 Available Routes:${NC}"
            local routes=($(build_access_routes))
            for route in "${routes[@]}"; do
                echo -e "  ${GREEN}➤ $route${NC}"
            done
        fi

        echo ""
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
    fi
}

# =============================================================================
# IP AND STORAGE MANAGEMENT FUNCTIONS
# =============================================================================

# Function to manage IP configuration
manage_ip_configuration() {
    echo -e "${BLUE}🔧 IP Configuration Management${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    echo ""

    echo -e "${CYAN}📌 Available Actions:${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} Check current IP configuration"
    echo -e "  ${GREEN}[2]${NC} Detect and update IP changes"
    echo -e "  ${GREEN}[3]${NC} Update mobile URLs with current IP"
    echo -e "  ${GREEN}[4]${NC} Test network connectivity"
    echo -e "  ${GREEN}[B]${NC} Back to main menu"
    echo ""

    local ip_choice=$(get_user_input "Select action" "1")
    echo ""

    case "$ip_choice" in
        "1")
            echo -e "${BLUE}🔍 Checking IP Configuration${NC}"
            "$SCRIPT_DIR/scripts/setup-networking.sh" --check-ip
            ;;
        "2")
            echo -e "${BLUE}🔄 Updating IP Configuration${NC}"
            "$SCRIPT_DIR/scripts/setup-networking.sh" --update-ip
            ;;
        "3")
            echo -e "${BLUE}📱 Updating Mobile URLs${NC}"
            "$SCRIPT_DIR/scripts/setup-mobile.sh" --update-ip
            ;;
        "4")
            echo -e "${BLUE}🌐 Testing Network${NC}"
            "$SCRIPT_DIR/scripts/setup-networking.sh" --test
            ;;
        "B"|"b"|"")
            return 0
            ;;
        *)
            echo -e "${RED}Invalid choice: $ip_choice${NC}"
            ;;
    esac

    echo ""
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

# Function to manage storage and sharing
manage_storage_sharing() {
    echo -e "${BLUE}💾 Storage & Sharing Management${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..50})${NC}"
    echo ""

    echo -e "${CYAN}📌 Available Actions:${NC}"
    echo ""
    echo -e "  ${GREEN}[1]${NC} View current storage configuration"
    echo -e "  ${GREEN}[2]${NC} Add additional folder mount points"
    echo -e "  ${GREEN}[3]${NC} Test storage access"
    echo -e "  ${GREEN}[4]${NC} Setup external storage device"
    echo -e "  ${GREEN}[5]${NC} View Docker mount points"
    echo -e "  ${GREEN}[B]${NC} Back to main menu"
    echo ""

    local storage_choice=$(get_user_input "Select action" "1")
    echo ""

    case "$storage_choice" in
        "1")
            echo -e "${BLUE}📋 Current Storage Configuration${NC}"
            "$SCRIPT_DIR/scripts/setup-storage.sh" --status
            ;;
        "2")
            echo -e "${BLUE}📁 Adding Folder Mount Points${NC}"
            echo -e "${CYAN}This feature will configure additional folders for sharing with Nextcloud${NC}"
            "$SCRIPT_DIR/scripts/setup-storage.sh" --add-mount
            ;;
        "3")
            echo -e "${BLUE}🔍 Testing Storage${NC}"
            "$SCRIPT_DIR/scripts/setup-storage.sh" --test
            ;;
        "4")
            echo -e "${BLUE}💽 Setting Up External Storage${NC}"
            "$SCRIPT_DIR/scripts/setup-storage.sh" --setup
            ;;
        "5")
            echo -e "${BLUE}🐳 Docker Mount Points${NC}"
            docker ps --format "table {{.Names}}\t{{.Mounts}}" | grep kekeli || echo "No Kekeli containers running"
            ;;
        "B"|"b"|"")
            return 0
            ;;
        *)
            echo -e "${RED}Invalid choice: $storage_choice${NC}"
            ;;
    esac

    echo ""
    echo -e "${CYAN}Press Enter to continue...${NC}"
    read -r
}

# Function to show help
show_installer_help() {
    echo "Kekeli-HomeCloud Easy Installer"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  --check-status    Check Docker status and show available routes"
    echo "  --status-only     Check Docker status and exit (non-interactive)"
    echo "  --help, -h        Show this help message"
    echo ""
    echo "Interactive Mode (default):"
    echo "  Runs the full interactive installer menu"
    echo ""
    echo "Examples:"
    echo "  $0                    # Start interactive installer"
    echo "  $0 --check-status     # Check Docker status interactively"
    echo "  $0 --status-only      # Quick status check and exit"
    echo ""
}

# Main function
main() {
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --check-status)
                # Initialize logging
                setup_logging false
                show_header
                run_docker_status_check
                exit 0
                ;;
            --status-only)
                # Initialize logging
                setup_logging false
                # Run the standalone status check script in status-only mode
                local status_script="$SCRIPT_DIR/scripts/check-docker-status.sh"
                if [[ -f "$status_script" ]]; then
                    chmod +x "$status_script"
                    exec "$status_script" --status-only
                else
                    # Fallback to basic status
                    local docker_status=$(get_docker_status_summary)
                    case $docker_status in
                        "all_running")
                            echo "All Kekeli-HomeCloud services are running"
                            exit 0
                            ;;
                        "partially_running")
                            echo "Some Kekeli-HomeCloud services are running"
                            exit 1
                            ;;
                        "not_running")
                            echo "Kekeli-HomeCloud services are deployed but stopped"
                            exit 2
                            ;;
                        "docker_not_running")
                            echo "Docker daemon is not running"
                            exit 3
                            ;;
                        "docker_not_installed")
                            echo "Docker is not installed"
                            exit 4
                            ;;
                        *)
                            echo "Unknown Docker status"
                            exit 5
                            ;;
                    esac
                fi
                ;;
            --help|-h)
                show_installer_help
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
        shift
    done

    # Initialize logging for interactive mode
    setup_logging false

    while true; do
        show_header
        show_progress
        show_configuration
        show_menu

        local choice=$(get_menu_choice)
        echo ""

        case $choice in
            "1"|"2"|"3"|"4"|"5"|"6"|"7")
                local phase_info="${PHASES[$choice]}"
                local phase_key=$(echo "$phase_info" | cut -d'|' -f1)
                run_phase "$phase_key"
                ;;
            "D"|"d")
                show_header
                run_docker_status_check
                ;;
            "R"|"r")
                show_header
                show_configuration
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
            "L"|"l")
                show_header
                show_logs
                ;;
            "I"|"i")
                show_header
                manage_ip_configuration
                ;;
            "S"|"s")
                show_header
                manage_storage_sharing
                ;;
            "H"|"h")
                show_header
                show_help
                ;;
            "Q"|"q")
                echo -e "${CYAN}Thank you for using Kekeli-HomeCloud Installer!${NC}"
                exit 0
                ;;
            *)
                echo -e "${RED}Invalid choice: $choice${NC}"
                echo -e "${CYAN}Press Enter to continue...${NC}"
                read -r
                ;;
        esac
    done
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi