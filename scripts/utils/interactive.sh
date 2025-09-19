#!/bin/bash
# Bash Interactive and Progress Utilities
# Provides enhanced user experience for Linux installation

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
NC='\033[0m' # No Color

# Check for dialog/whiptail availability
DIALOG_CMD=""
if command -v dialog &> /dev/null; then
    DIALOG_CMD="dialog"
elif command -v whiptail &> /dev/null; then
    DIALOG_CMD="whiptail"
fi

# Spinner animation
show_spinner() {
    local message="$1"
    local pid=$2
    local delay=0.1
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'

    echo -n "  "
    while [ "$(ps a | awk '{print $1}' | grep $pid)" ]; do
        local temp=${spinstr#?}
        printf "\r  [%c] %s" "$spinstr" "$message"
        local spinstr=$temp${spinstr%"$temp"}
        sleep $delay
    done
    printf "\r  ✅ %s\n" "$message"
}

# Progress bar
show_progress() {
    local current=$1
    local total=$2
    local message="$3"
    local width=50

    local percent=$((current * 100 / total))
    local filled=$((width * current / total))

    printf "\r  %s: [" "$message"
    printf "%${filled}s" | tr ' ' '█'
    printf "%$((width - filled))s" | tr ' ' '▒'
    printf "] %d%%" "$percent"

    if [ "$current" -eq "$total" ]; then
        echo " ✅"
    fi
}

# Download with progress
download_with_progress() {
    local url="$1"
    local output="$2"
    local description="$3"

    if command -v wget &> /dev/null; then
        echo -e "${CYAN}  Downloading $description...${NC}"
        wget --progress=bar:force "$url" -O "$output" 2>&1 | \
            grep --line-buffered "%" | \
            sed -u -e "s,\.,,g" | \
            awk '{printf("\r  Progress: [%s] %s", substr($2, 1, length($2)-1), $1)}'
        echo -e "\n${GREEN}  ✅ Download complete${NC}"
    elif command -v curl &> /dev/null; then
        echo -e "${CYAN}  Downloading $description...${NC}"
        curl -# -L "$url" -o "$output"
        echo -e "${GREEN}  ✅ Download complete${NC}"
    else
        echo -e "${RED}  ❌ No download tool available${NC}"
        return 1
    fi
}

# Interactive menu (with dialog fallback)
show_menu() {
    local title="$1"
    local prompt="$2"
    shift 2
    local options=("$@")

    if [ -n "$DIALOG_CMD" ]; then
        # Use dialog/whiptail
        local menu_items=()
        for i in "${!options[@]}"; do
            menu_items+=("$((i+1))" "${options[$i]}")
        done

        local choice=$($DIALOG_CMD --clear --title "$title" \
                                   --menu "$prompt" 15 60 "${#options[@]}" \
                                   "${menu_items[@]}" \
                                   3>&1 1>&2 2>&3)
        clear
        echo $((choice - 1))
    else
        # Fallback to text menu
        echo ""
        echo -e "${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
        echo -e "${CYAN}║ $title${NC}"
        echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
        echo ""
        echo -e "${YELLOW}$prompt${NC}"
        echo ""

        for i in "${!options[@]}"; do
            if [ "$i" -eq 0 ]; then
                echo -e "  ${GREEN}➤ [$((i+1))] ${options[$i]} (default)${NC}"
            else
                echo -e "    [$((i+1))] ${options[$i]}"
            fi
        done

        echo ""
        read -p "Enter choice (1-${#options[@]}) or press Enter for default: " selection

        if [ -z "$selection" ]; then
            echo 0
        else
            echo $((selection - 1))
        fi
    fi
}

# Confirmation prompt
get_confirmation() {
    local question="$1"
    local default="${2:-y}"

    if [ "$default" = "y" ]; then
        local prompt="$question (Y/n): "
    else
        local prompt="$question (y/N): "
    fi

    read -p "$prompt" response
    response=${response:-$default}

    [[ "$response" =~ ^[Yy]$ ]]
}

# Animated banner
show_animated_banner() {
    local lines=(
        "╔══════════════════════════════════════════════════════════════╗"
        "║            🏠 Kekeli-HomeCloud Easy Installer                ║"
        "║         Transform Your Computer Into Your Cloud              ║"
        "╚══════════════════════════════════════════════════════════════╝"
    )

    clear
    for line in "${lines[@]}"; do
        echo -e "${CYAN}${line}${NC}"
        sleep 0.1
    done
    echo ""
}

# Installation profile selection
select_installation_profile() {
    echo ""
    echo -e "${CYAN}📦 INSTALLATION PROFILES${NC}"
    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "  ${GREEN}[1] Express${NC} ${BOLD}(Recommended)${NC}"
    echo -e "      Quick installation with recommended settings (5 minutes)"
    echo -e "      ${CYAN}• Automatic configuration${NC}"
    echo -e "      ${CYAN}• Default paths${NC}"
    echo -e "      ${CYAN}• Mobile support enabled${NC}"
    echo ""

    echo -e "  ${YELLOW}[2] Custom${NC}"
    echo -e "      Choose your components and settings (10-15 minutes)"
    echo -e "      ${CYAN}• Component selection${NC}"
    echo -e "      ${CYAN}• Custom paths${NC}"
    echo -e "      ${CYAN}• Advanced options${NC}"
    echo ""

    echo -e "  ${MAGENTA}[3] Developer${NC}"
    echo -e "      Full installation with development tools (15-20 minutes)"
    echo -e "      ${CYAN}• All components${NC}"
    echo -e "      ${CYAN}• Debug tools${NC}"
    echo -e "      ${CYAN}• Log verbosity${NC}"
    echo -e "      ${CYAN}• API access${NC}"
    echo ""

    echo -e "${BOLD}═══════════════════════════════════════════════════════${NC}"
    read -p "Select profile (1-3) or press Enter for Express: " selection

    case "$selection" in
        2) echo "Custom" ;;
        3) echo "Developer" ;;
        *) echo "Express" ;;
    esac
}

# System requirements check with progress
check_system_requirements() {
    local checks=(
        "Operating System:check_os"
        "Disk Space:check_disk_space"
        "Memory:check_memory"
        "Network:check_network"
        "Docker:check_docker"
        "Permissions:check_permissions"
    )

    local total=${#checks[@]}
    local passed=0

    echo ""
    echo -e "${CYAN}🔍 SYSTEM REQUIREMENTS CHECK${NC}"
    echo ""

    for i in "${!checks[@]}"; do
        IFS=':' read -r name func <<< "${checks[$i]}"

        show_progress $((i)) $total "Checking requirements"
        echo -ne "\r  Checking $name..."

        if $func &>/dev/null; then
            echo -e " ${GREEN}✅${NC}"
            ((passed++))
        else
            echo -e " ${RED}❌${NC}"
        fi

        sleep 0.3
    done

    show_progress $total $total "Checking requirements"
    echo ""

    if [ "$passed" -eq "$total" ]; then
        echo -e "  ${GREEN}All checks passed! ($passed/$total)${NC}"
        return 0
    else
        echo -e "  ${YELLOW}Some checks failed ($passed/$total)${NC}"
        return 1
    fi
}

# Check functions (stubs)
check_os() {
    [ -f /etc/os-release ]
}

check_disk_space() {
    local available=$(df / | awk 'NR==2 {print $4}')
    [ "$available" -ge 4194304 ]  # 4GB in KB
}

check_memory() {
    local total_mem=$(free -m | awk 'NR==2 {print $2}')
    [ "$total_mem" -ge 2048 ]  # 2GB
}

check_network() {
    ping -c 1 8.8.8.8 &>/dev/null
}

check_docker() {
    command -v docker &>/dev/null || return 1
}

check_permissions() {
    [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null
}

# Success animation
show_success() {
    local message="$1"
    local frames=("   ✨" "  ✨✨" " ✨✅✨" "  ✅" "  ✅ $message")

    for frame in "${frames[@]}"; do
        echo -ne "\r${GREEN}$frame${NC}"
        sleep 0.2
    done
    echo ""
}

# Live log viewer
show_live_log() {
    local log_file="$1"
    local height=${2:-10}

    if [ -n "$DIALOG_CMD" ]; then
        $DIALOG_CMD --title "Installation Log" --tailbox "$log_file" 20 80
    else
        echo -e "${CYAN}═══ Live Installation Log ═══${NC}"
        tail -f "$log_file" | head -n "$height"
    fi
}

# Multi-step wizard
run_installation_wizard() {
    local steps=(
        "Welcome:show_welcome"
        "Requirements:check_system_requirements"
        "Profile:select_installation_profile"
        "Configuration:configure_settings"
        "Installation:run_installation"
        "Completion:show_completion"
    )

    local total=${#steps[@]}

    for i in "${!steps[@]}"; do
        IFS=':' read -r name func <<< "${steps[$i]}"

        echo ""
        echo -e "${BOLD}Step $((i+1)) of $total: $name${NC}"
        echo -e "${CYAN}════════════════════════════════════════${NC}"

        if ! $func; then
            echo -e "${RED}Installation stopped at step: $name${NC}"
            return 1
        fi
    done

    return 0
}

# Welcome screen
show_welcome() {
    if [ -n "$DIALOG_CMD" ]; then
        $DIALOG_CMD --title "Welcome to Kekeli-HomeCloud" \
                   --msgbox "Transform your computer into your personal cloud!\n\n\
This installer will guide you through setting up Nextcloud with:\n\
• Automatic mobile device configuration\n\
• External storage integration\n\
• Secure network access\n\n\
Press OK to continue." 15 60
    else
        show_animated_banner
        echo -e "${GREEN}Welcome to the Kekeli-HomeCloud installer!${NC}"
        echo ""
        echo "This will set up your personal Nextcloud instance with:"
        echo -e "  ${CYAN}• Automatic mobile device configuration${NC}"
        echo -e "  ${CYAN}• External storage integration${NC}"
        echo -e "  ${CYAN}• Secure network access${NC}"
        echo ""
        get_confirmation "Ready to begin?" "y"
    fi
}

# Configuration settings
configure_settings() {
    echo -e "${CYAN}Configuring installation settings...${NC}"
    # This would contain actual configuration logic
    sleep 1
    return 0
}

# Run installation
run_installation() {
    echo -e "${CYAN}Running installation...${NC}"
    # This would contain actual installation logic
    show_spinner "Installing components" $$ &
    sleep 3
    kill $! 2>/dev/null
    return 0
}

# Completion screen
show_completion() {
    show_success "Installation complete!"
    echo ""
    echo -e "${GREEN}🎉 Congratulations!${NC}"
    echo "Your Kekeli-HomeCloud is ready to use."
    echo ""
    echo -e "${CYAN}Next steps:${NC}"
    echo "  1. Access web interface: http://localhost"
    echo "  2. Set up mobile devices using the generated QR codes"
    echo "  3. Configure external storage if needed"
    echo ""
    return 0
}

# Export all functions
export -f show_spinner
export -f show_progress
export -f download_with_progress
export -f show_menu
export -f get_confirmation
export -f show_animated_banner
export -f select_installation_profile
export -f check_system_requirements
export -f show_success
export -f show_live_log
export -f run_installation_wizard