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
)

# Phase order for display
PHASE_ORDER=("1" "2" "3" "4" "5" "6")

# Scripts for each phase
declare -A PHASE_SCRIPTS=(
    ["requirements"]="$SCRIPT_DIR/scripts/check-requirements.sh"
    ["docker"]="$SCRIPT_DIR/scripts/setup-docker.sh"
    ["storage"]="$SCRIPT_DIR/scripts/setup-storage.sh"
    ["networking"]="$SCRIPT_DIR/scripts/setup-networking.sh"
    ["nextcloud"]="$SCRIPT_DIR/scripts/setup-nextcloud.sh"
    ["mobile"]="$SCRIPT_DIR/scripts/setup-mobile.sh"
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
    echo -e "${CYAN}📝 Current Configuration:${NC}"
    echo ""

    # Docker Status
    if docker --version >/dev/null 2>&1; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        echo -e "  ${GREEN}🐳 Docker:${NC} $docker_version"
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
    if [[ -n "$nextcloud_port" ]]; then
        echo -e "  ${GREEN}🌐 Network:${NC} Port $nextcloud_port"
        if [[ -n "$primary_ip" ]]; then
            echo -e "     ${CYAN}Access URL:${NC} http://$primary_ip:$nextcloud_port"
        fi
    else
        echo -e "  ${YELLOW}🌐 Network:${NC} Not configured"
    fi

    # Nextcloud Status
    if docker ps --format "table {{.Names}}" | grep -q "kekeli-nextcloud" 2>/dev/null; then
        echo -e "  ${GREEN}☁️  Nextcloud:${NC} Running"
    else
        echo -e "  ${YELLOW}☁️  Nextcloud:${NC} Not deployed"
    fi

    echo ""
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
    echo -e "  ${GREEN}[R]${NC} Review Configuration"
    echo -e "  ${GREEN}[L]${NC} View Logs"
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
            echo ""
            ;;
        "networking")
            echo -e "${YELLOW}ℹ️  Requirements:${NC}"
            echo -e "   • May require sudo for firewall configuration"
            echo -e "   • Network interface available"
            echo ""
            ;;
        "nextcloud")
            echo -e "${YELLOW}ℹ️  Requirements:${NC}"
            echo -e "   • Docker must be running"
            echo -e "   • Storage must be configured"
            echo -e "   • Network must be configured"
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

# Main function
main() {
    # Initialize logging
    setup_logging false

    while true; do
        show_header
        show_progress
        show_configuration
        show_menu

        local choice=$(get_menu_choice)
        echo ""

        case $choice in
            "1"|"2"|"3"|"4"|"5"|"6")
                local phase_info="${PHASES[$choice]}"
                local phase_key=$(echo "$phase_info" | cut -d'|' -f1)
                run_phase "$phase_key"
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