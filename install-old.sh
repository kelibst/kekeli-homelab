#!/bin/bash
# install.sh - Kekeli-HomeCloud One-Click Installer
# Part of the Kekeli-HomeCloud Easy Installer Project
#
# Transform your computer into a personal cloud server with mobile access
# Run: ./install.sh

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/scripts/utils/common.sh" 2>/dev/null || {
    echo "Error: Cannot find required utility files. Please run from project root."
    exit 1
}

# Installation phases and their scripts
declare -A INSTALLATION_PHASES=(
    ["requirements"]="$SCRIPT_DIR/scripts/check-requirements.sh"
    ["docker"]="$SCRIPT_DIR/scripts/setup-docker.sh"
    ["storage"]="$SCRIPT_DIR/scripts/setup-storage.sh"
    ["networking"]="$SCRIPT_DIR/scripts/setup-networking.sh"
    ["nextcloud"]="$SCRIPT_DIR/scripts/setup-nextcloud.sh"
    ["mobile"]="$SCRIPT_DIR/scripts/setup-mobile.sh"
)

# Phase display names for progress
declare -A PHASE_NAMES=(
    ["requirements"]="System Requirements Check"
    ["docker"]="Docker Installation & Setup"
    ["storage"]="Storage Detection & Mounting"
    ["networking"]="Network & Firewall Configuration"
    ["nextcloud"]="Nextcloud Server Deployment"
    ["mobile"]="Mobile Device Setup"
)

# Installation order
INSTALLATION_ORDER=("requirements" "docker" "storage" "networking" "nextcloud" "mobile")

# Progress tracking
CURRENT_PHASE=0
TOTAL_PHASES=${#INSTALLATION_ORDER[@]}
COMPLETED_PHASES=()

# Cleanup function for interruption
cleanup() {
    echo -e "\n${YELLOW}⚠️  Installation interrupted by user${NC}"

    if [[ ${#COMPLETED_PHASES[@]} -gt 0 ]]; then
        echo -e "${CYAN}ℹ️  The following phases completed successfully:${NC}"
        for phase in "${COMPLETED_PHASES[@]}"; do
            echo -e "   ✅ ${PHASE_NAMES[$phase]}"
        done
        echo -e "${CYAN}ℹ️  You can resume installation by running ./install.sh again${NC}"
        echo -e "${YELLOW}💡 Or run ./install.sh --rollback to undo completed changes${NC}"
    else
        echo -e "${CYAN}ℹ️  No changes were made. You can restart anytime.${NC}"
    fi

    exit $ERROR_USER_ABORT
}

# Trap interruption signals
trap cleanup SIGINT SIGTERM

# Function to save completed phases to config
save_completed_phases() {
    local phases_list=""
    for phase in "${COMPLETED_PHASES[@]}"; do
        phases_list="$phases_list$phase,"
    done
    # Remove trailing comma
    phases_list="${phases_list%,}"

    save_config "COMPLETED_PHASES" "$phases_list"
}

# Function to load completed phases from config
load_completed_phases() {
    local phases_str=$(load_config "COMPLETED_PHASES" "")
    if [[ -n "$phases_str" ]]; then
        IFS=',' read -ra COMPLETED_PHASES <<< "$phases_str"
    fi
}

# Function to perform rollback
perform_rollback() {
    echo -e "${YELLOW}🔄 Kekeli-HomeCloud Rollback${NC}"
    echo -e "${YELLOW}============================${NC}"
    echo ""

    load_completed_phases

    if [[ ${#COMPLETED_PHASES[@]} -eq 0 ]]; then
        echo -e "${GREEN}✅ No installation found to rollback${NC}"
        return 0
    fi

    echo -e "${CYAN}The following components will be removed:${NC}"
    for phase in "${COMPLETED_PHASES[@]}"; do
        echo -e "   ❌ ${PHASE_NAMES[$phase]}"
    done
    echo ""

    echo -e "${YELLOW}⚠️  This will remove:${NC}"
    echo -e "   • Docker containers and images"
    echo -e "   • Configuration files in ~/.kekeli-homecloud/"
    echo -e "   • Network and firewall changes"
    echo -e "   • Storage mount configurations"
    echo ""

    while true; do
        read -p "Are you sure you want to rollback the installation? (y/n): " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* )
                echo -e "${CYAN}Rollback cancelled${NC}"
                return 0
                ;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done

    echo ""
    echo -e "${BLUE}🔄 Starting rollback process...${NC}"

    # Reverse order for rollback
    local reverse_phases=()
    for ((i=${#COMPLETED_PHASES[@]}-1; i>=0; i--)); do
        reverse_phases+=("${COMPLETED_PHASES[i]}")
    done

    # Rollback each phase
    for phase in "${reverse_phases[@]}"; do
        rollback_phase "$phase"
    done

    # Clear completed phases
    save_config "COMPLETED_PHASES" ""

    echo ""
    echo -e "${GREEN}✅ Rollback completed successfully${NC}"
    echo -e "${CYAN}Your system has been restored to its previous state${NC}"
}

# Function to rollback a specific phase
rollback_phase() {
    local phase_key="$1"
    local phase_name="${PHASE_NAMES[$phase_key]}"

    echo -e "${BLUE}🔄 Rolling back: $phase_name${NC}"

    case $phase_key in
        "nextcloud")
            rollback_nextcloud
            ;;
        "mobile")
            rollback_mobile
            ;;
        "networking")
            rollback_networking
            ;;
        "storage")
            rollback_storage
            ;;
        "docker")
            rollback_docker
            ;;
        "requirements")
            # Requirements check doesn't install anything, no rollback needed
            ;;
    esac

    echo -e "   ✅ ${GREEN}Rollback complete: $phase_name${NC}"
}

# Rollback functions for each component
rollback_nextcloud() {
    # Stop and remove Nextcloud containers
    if docker ps -a | grep -q nextcloud; then
        docker stop nextcloud postgres redis 2>/dev/null || true
        docker rm nextcloud postgres redis 2>/dev/null || true
    fi

    # Remove Nextcloud images
    docker rmi nextcloud postgres redis 2>/dev/null || true

    # Remove docker-compose files
    rm -f "$KEKELI_CONFIG_DIR/docker-compose.yml" 2>/dev/null || true
    rm -f "$KEKELI_CONFIG_DIR/.env" 2>/dev/null || true
}

rollback_mobile() {
    # Remove mobile setup files
    rm -f "$KEKELI_CONFIG_DIR/mobile-setup-guide.html" 2>/dev/null || true
    rm -rf "$KEKELI_CONFIG_DIR/qr-codes/" 2>/dev/null || true
}

rollback_networking() {
    # Remove firewall rules (this is basic - individual scripts might have more specific rules)
    if command -v ufw >/dev/null 2>&1; then
        sudo ufw delete allow 80/tcp 2>/dev/null || true
        sudo ufw delete allow 443/tcp 2>/dev/null || true
    fi
}

rollback_storage() {
    # Unmount any mounted external storage
    if [[ -f "$KEKELI_CONFIG_DIR/mounted-drives.txt" ]]; then
        while read -r mount_point; do
            if [[ -n "$mount_point" ]]; then
                sudo umount "$mount_point" 2>/dev/null || true
            fi
        done < "$KEKELI_CONFIG_DIR/mounted-drives.txt"
        rm -f "$KEKELI_CONFIG_DIR/mounted-drives.txt"
    fi
}

rollback_docker() {
    # Only remove Docker if it was installed by us
    if [[ -f "$KEKELI_CONFIG_DIR/docker-installed-by-kekeli" ]]; then
        if ask_yes_no "Remove Docker that was installed during setup?" "n"; then
            sudo systemctl stop docker 2>/dev/null || true
            sudo systemctl disable docker 2>/dev/null || true

            local os=$(detect_os)
            case $os in
                ubuntu|debian)
                    sudo apt-get remove -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin 2>/dev/null || true
                    ;;
            esac

            # Remove user from docker group
            sudo deluser "$USER" docker 2>/dev/null || true
        fi
        rm -f "$KEKELI_CONFIG_DIR/docker-installed-by-kekeli"
    fi
}

# Function to show welcome message
show_welcome() {
    clear
    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}                 ${GREEN}🏠 Kekeli-HomeCloud Installer${NC}                 ${BLUE}│${NC}"
    echo -e "${BLUE}├─────────────────────────────────────────────────────────────┤${NC}"
    echo -e "${BLUE}│${NC}   Transform your computer into a personal cloud server      ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}   with mobile access - no technical knowledge required!     ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""
    echo -e "${CYAN}🎯 What this installer will do:${NC}"
    echo -e "   • Check your system meets requirements"
    echo -e "   • Install and configure Docker containers"
    echo -e "   • Set up automatic storage detection"
    echo -e "   • Configure network access for all devices"
    echo -e "   • Deploy Nextcloud server with database"
    echo -e "   • Provide mobile setup instructions"
    echo ""
    echo -e "${GREEN}📱 After installation you'll have:${NC}"
    echo -e "   • Web access to your personal cloud"
    echo -e "   • Android and iPhone apps working"
    echo -e "   • Automatic external storage mounting"
    echo -e "   • Secure local network access"
    echo ""
    echo -e "${YELLOW}⏱️  Estimated time: 5-10 minutes${NC}"
    echo ""
}

# Function to show progress bar
show_progress() {
    local current=$1
    local total=$2
    local phase_name="$3"

    local percentage=$((current * 100 / total))
    local filled=$((current * 40 / total))
    local empty=$((40 - filled))

    # Calculate estimated time remaining
    local est_remaining=""
    if [[ $current -gt 0 ]]; then
        local phases_remaining=$((total - current))
        local minutes_remaining=$((phases_remaining * 2))  # Rough estimate: 2 minutes per phase
        if [[ $minutes_remaining -gt 0 ]]; then
            est_remaining=" (~${minutes_remaining}m remaining)"
        fi
    fi

    printf "\r${BLUE}Overall Progress: [${NC}"
    printf "%${filled}s" | tr ' ' '█'
    printf "%${empty}s" | tr ' ' '░'
    printf "${BLUE}] %3d%% - %s${NC}%s" "$percentage" "$phase_name" "$est_remaining"
}

# Function to confirm installation
confirm_installation() {
    echo -e "${YELLOW}⚠️  This installer will make changes to your system:${NC}"
    echo -e "   • Install Docker (if not present)"
    echo -e "   • Create configuration files in ~/.kekeli-homecloud/"
    echo -e "   • Configure firewall rules for local access"
    echo -e "   • Mount external storage devices"
    echo ""

    while true; do
        read -p "Do you want to proceed with the installation? (y/n): " yn
        case $yn in
            [Yy]* ) break;;
            [Nn]* )
                echo -e "${CYAN}Installation cancelled. Come back anytime!${NC}"
                exit $ERROR_USER_ABORT
                ;;
            * ) echo "Please answer yes (y) or no (n).";;
        esac
    done
    echo ""
}

# Function to run a phase
run_phase() {
    local phase_key="$1"
    local script_path="${INSTALLATION_PHASES[$phase_key]}"
    local phase_name="${PHASE_NAMES[$phase_key]}"

    # Check if script exists
    if [[ ! -f "$script_path" ]]; then
        log_error "Script not found: $script_path"
        return $ERROR_GENERAL
    fi

    # Make script executable
    chmod +x "$script_path"

    # Update progress
    CURRENT_PHASE=$((CURRENT_PHASE + 1))
    echo ""
    show_progress $CURRENT_PHASE $TOTAL_PHASES "$phase_name"
    echo ""
    echo -e "${BLUE}📋 Phase $CURRENT_PHASE/$TOTAL_PHASES: $phase_name${NC}"
    echo -e "${BLUE}$(printf '=%.0s' {1..60})${NC}"

    # Track timing
    local phase_start_time=$(date +%s)

    # Log phase start
    log_info "Starting phase: $phase_name"

    # Run the script as external process to capture exit code properly
    "$script_path"
    local exit_code=$?

    # Debug output
    log_info "Phase $phase_key completed with exit code: $exit_code"

    if [[ $exit_code -eq 0 ]]; then
        local phase_end_time=$(date +%s)
        local phase_duration=$((phase_end_time - phase_start_time))
        local duration_text=""
        if [[ $phase_duration -ge 60 ]]; then
            local minutes=$((phase_duration / 60))
            local seconds=$((phase_duration % 60))
            duration_text=" (${minutes}m ${seconds}s)"
        else
            duration_text=" (${phase_duration}s)"
        fi

        log_info "Phase completed successfully: $phase_name in ${phase_duration}s"
        echo -e "${GREEN}✅ $phase_name completed successfully${NC}${CYAN}$duration_text${NC}"

        # Track completed phase for rollback purposes
        COMPLETED_PHASES+=("$phase_key")
        save_completed_phases

        return $SUCCESS
    else
        local phase_end_time=$(date +%s)
        local phase_duration=$((phase_end_time - phase_start_time))
        log_error "Phase failed: $phase_name (exit code: $exit_code) after ${phase_duration}s"
        echo -e "${RED}❌ $phase_name failed after ${phase_duration}s (exit code: $exit_code)${NC}"
        return $exit_code
    fi
}

# Function to handle phase failure
handle_phase_failure() {
    local failed_phase="$1"
    local exit_code="$2"
    local phase_name="${PHASE_NAMES[$failed_phase]}"

    echo ""
    echo -e "${RED}🚨 Installation Failed${NC}"
    echo -e "${RED}=========================${NC}"
    echo -e "${YELLOW}Failed Phase:${NC} $phase_name"
    echo -e "${YELLOW}Exit Code:${NC} $exit_code"
    echo ""
    echo -e "${CYAN}📋 Troubleshooting Steps:${NC}"

    case $failed_phase in
        "requirements")
            case $exit_code in
                2) # ERROR_OS_NOT_SUPPORTED
                    echo -e "   • Your operating system is not yet supported"
                    echo -e "   • Try using Ubuntu 20.04+, Debian 11+, or WSL2"
                    ;;
                3) # ERROR_INSUFFICIENT_DISK
                    echo -e "   • Free up disk space (need at least 4GB available)"
                    echo -e "   • Consider adding external storage"
                    ;;
                4) # ERROR_INSUFFICIENT_MEMORY
                    echo -e "   • Close unnecessary applications to free memory"
                    echo -e "   • Need at least 2GB RAM available"
                    ;;
                5) # ERROR_NO_SUDO
                    echo -e "   • Run: sudo usermod -aG sudo \$USER"
                    echo -e "   • Then log out and log back in"
                    echo -e "   • Or ask your system administrator for sudo access"
                    ;;
                6) # ERROR_DOCKER_UNAVAILABLE
                    echo -e "   • Docker installation failed or is not compatible"
                    echo -e "   • Try installing Docker manually first"
                    ;;
                *)
                    echo -e "   • Check that you're running on a supported Linux distribution"
                    echo -e "   • Ensure you have sufficient disk space (4GB minimum)"
                    echo -e "   • Verify you have sudo privileges"
                    ;;
            esac
            ;;
        "docker")
            echo -e "   • Ensure you have sudo privileges"
            echo -e "   • Check your internet connection for Docker download"
            echo -e "   • Verify your system supports Docker"
            echo -e "   • Try running: sudo systemctl status docker"
            ;;
        "storage")
            echo -e "   • Ensure external drives are properly connected"
            echo -e "   • Check that drives are not already mounted elsewhere"
            echo -e "   • Verify drive permissions and filesystem support"
            ;;
        "networking")
            echo -e "   • Check firewall configuration"
            echo -e "   • Verify network interface detection"
            echo -e "   • Ensure no conflicts with existing services"
            ;;
        "nextcloud")
            echo -e "   • Check that Docker is running properly"
            echo -e "   • Verify port 80 and 443 are available"
            echo -e "   • Check disk space for container images"
            ;;
        "mobile")
            echo -e "   • Verify Nextcloud is accessible via web browser"
            echo -e "   • Check network configuration"
            echo -e "   • Ensure mobile devices are on same network"
            ;;
    esac

    echo ""
    echo -e "${CYAN}📝 Log files for debugging:${NC}"
    echo -e "   • Installation log: $KEKELI_LOG_FILE"
    echo -e "   • Run with debug: ./install.sh --debug"
    echo ""
    echo -e "${YELLOW}💡 Recovery options:${NC}"
    echo -e "   • Restart installation: ./install.sh"
    if [[ ${#COMPLETED_PHASES[@]} -gt 0 ]]; then
        echo -e "   • Rollback changes: ./install.sh --rollback"
    fi
}

# Function to show completion message
show_completion() {
    clear
    echo -e "${GREEN}🎉 Installation Completed Successfully!${NC}"
    echo -e "${GREEN}======================================${NC}"
    echo ""
    echo -e "${BLUE}🌟 Your Kekeli-HomeCloud is now running!${NC}"
    echo ""

    # Try to get the local IP
    local local_ip
    local_ip=$(hostname -I | awk '{print $1}' 2>/dev/null || echo "your-local-ip")

    echo -e "${CYAN}🌐 Access your cloud:${NC}"
    echo -e "   • Web Interface: ${GREEN}http://$local_ip${NC}"
    echo -e "   • Mobile Setup: Check mobile device setup instructions below"
    echo ""

    echo -e "${CYAN}📱 Next Steps:${NC}"
    echo -e "   1. Open ${GREEN}http://$local_ip${NC} in your web browser"
    echo -e "   2. Complete the Nextcloud initial setup wizard"
    echo -e "   3. Install the Nextcloud app on your phone"
    echo -e "   4. Use server address: ${GREEN}http://$local_ip${NC}"
    echo ""

    echo -e "${CYAN}📚 Documentation:${NC}"
    echo -e "   • Configuration: ${KEKELI_CONFIG_DIR}/"
    echo -e "   • Logs: ${KEKELI_LOG_FILE}"
    echo -e "   • Mobile Setup Guide: docs/mobile-setup.md"
    echo ""

    echo -e "${YELLOW}💡 Tip: Bookmark ${GREEN}http://$local_ip${NC} for easy access!${NC}"
    echo ""
    echo -e "${GREEN}Happy cloud computing! 🚀${NC}"
}

# Function to show help
show_help() {
    echo "Kekeli-HomeCloud One-Click Installer"
    echo ""
    echo "USAGE:"
    echo "    ./install.sh [OPTIONS]"
    echo ""
    echo "OPTIONS:"
    echo "    -h, --help     Show this help message"
    echo "    -q, --quiet    Run in quiet mode (minimal output)"
    echo "    -d, --debug    Enable debug mode (verbose output)"
    echo "    --skip-confirm Skip installation confirmation"
    echo "    --rollback     Remove previous installation"
    echo ""
    echo "DESCRIPTION:"
    echo "    Transforms your computer into a personal cloud server with mobile access."
    echo "    This installer will automatically:"
    echo "    • Check system requirements"
    echo "    • Install and configure Docker"
    echo "    • Set up storage and networking"
    echo "    • Deploy Nextcloud with database"
    echo "    • Configure mobile device access"
    echo ""
    echo "EXAMPLES:"
    echo "    ./install.sh                    # Standard installation"
    echo "    ./install.sh --quiet            # Minimal output"
    echo "    ./install.sh --debug            # Verbose logging"
    echo "    ./install.sh --skip-confirm     # Skip confirmation prompt"
    echo "    ./install.sh --rollback         # Remove previous installation"
    echo ""
}

# Main installation function
main() {
    local skip_confirm=false
    local quiet_mode=false
    local debug_mode=false
    local rollback_mode=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -q|--quiet)
                quiet_mode=true
                shift
                ;;
            -d|--debug)
                debug_mode=true
                set -x
                shift
                ;;
            --skip-confirm)
                skip_confirm=true
                export KEKELI_NON_INTERACTIVE=true
                shift
                ;;
            --rollback)
                rollback_mode=true
                shift
                ;;
            *)
                echo -e "${RED}Error: Unknown option $1${NC}"
                echo "Use --help for usage information."
                exit $ERROR_GENERAL
                ;;
        esac
    done

    # Handle rollback mode
    if [[ "$rollback_mode" = true ]]; then
        setup_logging "$debug_mode"
        perform_rollback
        exit $SUCCESS
    fi

    # Setup logging
    setup_logging "$debug_mode"

    # Log installation start
    log_info "Kekeli-HomeCloud installation started"
    log_info "Arguments: $*"

    # Show welcome message (unless quiet)
    if [[ "$quiet_mode" != true ]]; then
        show_welcome

        # Get user confirmation (unless skipped)
        if [[ "$skip_confirm" != true ]]; then
            confirm_installation
        fi
    fi

    # Initialize progress
    CURRENT_PHASE=0

    # Run installation phases
    for phase in "${INSTALLATION_ORDER[@]}"; do
        run_phase "$phase"
        local phase_exit_code=$?
        if [[ $phase_exit_code -ne 0 ]]; then
            handle_phase_failure "$phase" "$phase_exit_code"
            log_error "Installation failed at phase: $phase"
            exit $phase_exit_code
        fi

        # Small delay for better UX
        sleep 1
    done

    # Show completion message
    if [[ "$quiet_mode" != true ]]; then
        show_completion
    else
        echo -e "${GREEN}Kekeli-HomeCloud installation completed successfully${NC}"
    fi

    log_info "Kekeli-HomeCloud installation completed successfully"
    exit $SUCCESS
}

# Handle script being sourced vs executed
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi