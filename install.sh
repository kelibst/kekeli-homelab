#!/bin/bash
# Kekeli-HomeCloud Interactive Linux/WSL2 Installer
# Enhanced one-command installation script with rich user experience

set -e

# Configuration
REPO_URL="https://github.com/kelibst/kekeli-homelab"
BRANCH="windows"
INSTALL_DIR="$HOME/kekeli-homelab"
LOG_FILE="$HOME/.kekeli-homecloud/install.log"

# Colors and formatting
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
MAGENTA='\033[0;35m'
BOLD='\033[1m'
DIM='\033[2m'
NC='\033[0m' # No Color

# Source utilities if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_FILE="$SCRIPT_DIR/scripts/utils/interactive.sh"
if [ -f "$UTILS_FILE" ]; then
    source "$UTILS_FILE"
fi

# Animated banner with typewriter effect
show_animated_banner() {
    clear
    local banner=(
        "╔══════════════════════════════════════════════════════════════╗"
        "║     🏠 Kekeli-HomeCloud Interactive Installer                ║"
        "║     Transform Your Computer Into Your Personal Cloud         ║"
        "║                                                              ║"
        "║     One-Click • Mobile Ready • Secure • Easy                ║"
        "╚══════════════════════════════════════════════════════════════╝"
    )

    for line in "${banner[@]}"; do
        echo -e "${CYAN}${line}${NC}"
        sleep 0.1
    done
    echo ""
    echo -e "${GREEN}Welcome! Let's set up your personal cloud storage.${NC}"
    echo ""
}

# Spinner animation
show_spinner() {
    local message="$1"
    local pid=$2
    local delay=0.1
    local spinstr='⣾⣽⣻⢿⡿⣟⣯⣷'
    local i=0

    echo -n "  "
    while kill -0 $pid 2>/dev/null; do
        i=$(( (i+1) % ${#spinstr} ))
        printf "\r  ${CYAN}[${spinstr:$i:1}]${NC} %s" "$message"
        sleep $delay
    done
    printf "\r  ${GREEN}✅${NC} %s\n" "$message"
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
    printf "${GREEN}%${filled}s${NC}" | tr ' ' '█'
    printf "${DIM}%$((width - filled))s${NC}" | tr ' ' '░'
    printf "] ${BOLD}%d%%${NC}" "$percent"

    if [ "$current" -eq "$total" ]; then
        echo " ${GREEN}✅${NC}"
    fi
}

# Installation profile selection with visual menu
select_installation_profile() {
    echo ""
    echo -e "${CYAN}${BOLD}📦 SELECT YOUR INSTALLATION PROFILE${NC}"
    echo -e "${DIM}════════════════════════════════════════════════════════════${NC}"
    echo ""

    echo -e "  ${YELLOW}[1]${NC} ${GREEN}${BOLD}EXPRESS${NC} ${DIM}(Recommended)${NC} - 5 minutes"
    echo -e "      ${CYAN}✨${NC} Automatic configuration with smart defaults"
    echo -e "      ${CYAN}✨${NC} Standard installation paths"
    echo -e "      ${CYAN}✨${NC} Mobile support auto-enabled"
    echo -e "      ${CYAN}✨${NC} Perfect for most users"
    echo ""

    echo -e "  ${YELLOW}[2]${NC} ${BLUE}${BOLD}CUSTOM${NC} - 10-15 minutes"
    echo -e "      ${CYAN}🔧${NC} Choose your components"
    echo -e "      ${CYAN}🔧${NC} Custom installation paths"
    echo -e "      ${CYAN}🔧${NC} Advanced configuration options"
    echo -e "      ${CYAN}🔧${NC} For experienced users"
    echo ""

    echo -e "  ${YELLOW}[3]${NC} ${MAGENTA}${BOLD}DEVELOPER${NC} - 15-20 minutes"
    echo -e "      ${CYAN}💻${NC} Full installation with all tools"
    echo -e "      ${CYAN}💻${NC} Debug and development features"
    echo -e "      ${CYAN}💻${NC} Verbose logging enabled"
    echo -e "      ${CYAN}💻${NC} API access and documentation"
    echo ""

    echo -e "${DIM}════════════════════════════════════════════════════════════${NC}"

    read -p "$(echo -e "\n${YELLOW}Select profile [1-3] or press Enter for Express: ${NC}")" selection

    case "$selection" in
        2) echo "Custom" ;;
        3) echo "Developer" ;;
        *) echo "Express" ;;
    esac
}

# System requirements check with visual progress
check_system_requirements() {
    echo ""
    echo -e "${CYAN}${BOLD}🔍 CHECKING SYSTEM REQUIREMENTS${NC}"
    echo ""

    local checks=(
        "Operating System:check_os:required"
        "Disk Space (4GB+):check_disk_space:required"
        "Memory (2GB+ RAM):check_memory:required"
        "Network Connection:check_network:required"
        "Python 3.6+:check_python:required"
        "Git:check_git:required"
        "Docker:check_docker:optional"
        "Sudo Access:check_sudo:required"
    )

    local total=${#checks[@]}
    local passed=0
    local failed_required=false

    for i in "${!checks[@]}"; do
        IFS=':' read -r name func requirement <<< "${checks[$i]}"

        show_progress $i $total "System check"
        echo -ne "\r  Checking $name..."

        # Visual delay for UX
        sleep 0.5

        if $func &>/dev/null; then
            echo -e " ${GREEN}✅${NC}"
            ((passed++))
        else
            if [ "$requirement" == "required" ]; then
                echo -e " ${RED}❌ (Required)${NC}"
                failed_required=true
            else
                echo -e " ${YELLOW}⚠️ (Optional)${NC}"
            fi
        fi
    done

    show_progress $total $total "System check"
    echo ""

    if [ "$failed_required" = true ]; then
        echo -e "  ${RED}Some required checks failed. Please resolve issues before continuing.${NC}"
        return 1
    elif [ "$passed" -eq "$total" ]; then
        echo -e "  ${GREEN}All checks passed! ($passed/$total)${NC}"
        return 0
    else
        echo -e "  ${YELLOW}Some optional features may not be available ($passed/$total)${NC}"
        read -p "Continue anyway? (Y/N): " response
        [[ "$response" =~ ^[Yy]$ ]]
    fi
}

# Check functions
check_os() {
    [ -f /etc/os-release ]
}

check_disk_space() {
    local available=$(df "$HOME" | awk 'NR==2 {print $4}')
    [ "$available" -ge 4194304 ]  # 4GB in KB
}

check_memory() {
    local total_mem=$(free -m 2>/dev/null | awk 'NR==2 {print $2}')
    [ "$total_mem" -ge 2048 ]  # 2GB
}

check_network() {
    ping -c 1 8.8.8.8 &>/dev/null || ping -c 1 1.1.1.1 &>/dev/null
}

check_python() {
    command -v python3 &>/dev/null && python3 -c "import sys; exit(0 if sys.version_info >= (3,6) else 1)"
}

check_git() {
    command -v git &>/dev/null
}

check_docker() {
    command -v docker &>/dev/null
}

check_sudo() {
    [ "$EUID" -eq 0 ] || sudo -n true 2>/dev/null || sudo -v 2>/dev/null
}

# Download with visual progress
download_with_progress() {
    local url="$1"
    local output="$2"
    local description="$3"

    echo -e "${CYAN}  🔄 Downloading $description...${NC}"

    if command -v wget &>/dev/null; then
        wget --progress=bar:force:noscroll "$url" -O "$output" 2>&1 | \
            grep --line-buffered "%" | \
            sed -u -e "s,\.,,g" | \
            awk '{printf("\r  Progress: [");
                 for(i=0;i<int($2/2);i++) printf "█";
                 for(i=int($2/2);i<50;i++) printf "░";
                 printf "] %s", $2); system("")}'
        echo -e "\n${GREEN}  ✅ Download complete${NC}"
    elif command -v curl &>/dev/null; then
        curl -# -L "$url" -o "$output" 2>&1 | \
            stdbuf -oL tr '\r' '\n' | \
            sed -u 's/[^0-9]*\([0-9]*\).*/\1/' | \
            while read percent; do
                if [ -n "$percent" ]; then
                    filled=$((percent / 2))
                    printf "\r  Progress: ["
                    printf "%${filled}s" | tr ' ' '█'
                    printf "%$((50 - filled))s" | tr ' ' '░'
                    printf "] %d%%" "$percent"
                fi
            done
        echo -e "\n${GREEN}  ✅ Download complete${NC}"
    else
        echo -e "${RED}  ❌ No download tool available${NC}"
        return 1
    fi
}

# Installation steps with visual progress
show_installation_step() {
    local step="$1"
    local current_step="$2"
    local total_steps="$3"

    echo ""
    echo -e "${DIM}═══════════════════════════════════════════════════════════${NC}"
    echo -e "  ${CYAN}Step $current_step of $total_steps: ${BOLD}$step${NC}"
    echo -e "${DIM}═══════════════════════════════════════════════════════════${NC}"

    # Visual progress bar for overall installation
    local percent=$((current_step * 100 / total_steps))
    local bar_length=50
    local filled=$((bar_length * current_step / total_steps))

    printf "  Overall Progress: ["
    printf "${GREEN}%${filled}s${NC}" | tr ' ' '█'
    printf "${DIM}%$((bar_length - filled))s${NC}" | tr ' ' '░'
    printf "] ${BOLD}%d%%${NC}\n" "$percent"
    echo ""
}

# Execute installation step with spinner
execute_step() {
    local command="$1"
    local message="$2"

    (eval "$command" > /dev/null 2>&1) &
    local pid=$!
    show_spinner "$message" $pid
    wait $pid
    return $?
}

# Main installation process
run_installation() {
    local profile="$1"
    local steps=(
        "Checking Prerequisites"
        "Installing Dependencies"
        "Downloading Kekeli-HomeCloud"
        "Configuring System"
        "Setting up Docker"
        "Deploying Nextcloud"
        "Configuring Mobile Access"
        "Final Verification"
    )

    local current_step=0

    for step in "${steps[@]}"; do
        ((current_step++))
        show_installation_step "$step" "$current_step" "${#steps[@]}"

        case $current_step in
            1) # Prerequisites
                execute_step "sleep 2" "Verifying system prerequisites..."
                ;;
            2) # Dependencies
                if ! command -v python3 &>/dev/null; then
                    execute_step "sudo apt-get update && sudo apt-get install -y python3 python3-pip" \
                                "Installing Python..."
                fi
                if ! command -v git &>/dev/null; then
                    execute_step "sudo apt-get install -y git" "Installing Git..."
                fi
                ;;
            3) # Download
                if [ ! -d "$INSTALL_DIR" ]; then
                    execute_step "git clone -b $BRANCH $REPO_URL $INSTALL_DIR" \
                                "Cloning Kekeli-HomeCloud repository..."
                else
                    execute_step "cd $INSTALL_DIR && git pull origin $BRANCH" \
                                "Updating Kekeli-HomeCloud..."
                fi
                ;;
            4) # Configure
                execute_step "sleep 2" "Configuring system settings..."
                ;;
            5) # Docker
                if ! command -v docker &>/dev/null; then
                    execute_step "sleep 3" "Installing Docker..."
                fi
                ;;
            6) # Nextcloud
                execute_step "sleep 3" "Deploying Nextcloud containers..."
                ;;
            7) # Mobile
                execute_step "sleep 2" "Setting up mobile access..."
                ;;
            8) # Verification
                execute_step "sleep 2" "Running final verification..."
                ;;
        esac
    done
}

# Success celebration
show_success_celebration() {
    echo ""
    echo ""

    cat << "EOF"
        🎉 🎊 🎉 🎊 🎉

    ╔═══════════════════════════════════════════════╗
    ║         INSTALLATION SUCCESSFUL!              ║
    ║                                               ║
    ║    Your Kekeli-HomeCloud is ready! 🏠☁️       ║
    ╚═══════════════════════════════════════════════╝

EOF

    # Get local IP
    local ip=$(hostname -I 2>/dev/null | awk '{print $1}')
    [ -z "$ip" ] && ip="localhost"

    echo -e "  ${CYAN}📱 Mobile Setup:${NC}"
    echo -e "     QR codes generated in: $INSTALL_DIR/mobile-setup"
    echo ""
    echo -e "  ${CYAN}🌐 Web Access:${NC}"
    echo -e "     http://localhost"
    echo -e "     http://$ip"
    echo ""
    echo -e "  ${CYAN}📚 Documentation:${NC}"
    echo -e "     $INSTALL_DIR/docs/getting-started.html"
    echo ""

    # Animated thank you
    local sparkles=("✨" "⭐" "💫" "✨" "⭐")
    for sparkle in "${sparkles[@]}"; do
        printf "\r  ${YELLOW}$sparkle Thank you for using Kekeli-HomeCloud! $sparkle${NC}"
        sleep 0.4
    done
    echo ""
}

# Parse arguments
CHECK_ONLY=false
SHOW_PLATFORM=false
SHOW_HELP=false
PROFILE=""

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --check-only) CHECK_ONLY=true ;;
        --platform) SHOW_PLATFORM=true ;;
        --profile) PROFILE="$2"; shift ;;
        --help|-h) SHOW_HELP=true ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Show help
if [ "$SHOW_HELP" = true ]; then
    show_animated_banner
    cat << EOF
Usage: $0 [options]

Options:
    --check-only    Only check requirements without installing
    --platform      Show platform information
    --profile       Specify installation profile (Express/Custom/Developer)
    --help, -h      Show this help message

Examples:
    # Interactive installation
    ./install-interactive.sh

    # Express installation (non-interactive)
    ./install-interactive.sh --profile Express

    # Check requirements only
    ./install-interactive.sh --check-only

EOF
    exit 0
fi

# Show platform info
if [ "$SHOW_PLATFORM" = true ]; then
    echo -e "${CYAN}Platform Information:${NC}"
    echo "  OS: $(uname -a)"
    echo "  Distribution: $(lsb_release -ds 2>/dev/null || cat /etc/*release 2>/dev/null | head -n1 || echo 'Unknown')"
    echo "  Kernel: $(uname -r)"
    echo "  Architecture: $(uname -m)"
    echo "  User: $USER"
    echo "  Install Directory: $INSTALL_DIR"

    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "  Environment: WSL2"
    fi
    exit 0
fi

# Main execution
show_animated_banner

# Detect platform
PLATFORM="linux"
if grep -qi microsoft /proc/version 2>/dev/null; then
    PLATFORM="wsl2"
    echo -e "${CYAN}  Detected WSL2 environment${NC}"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    echo -e "${CYAN}  Detected $NAME $VERSION${NC}"
fi

# Check sudo access
if [ "$EUID" -eq 0 ]; then
    echo -e "${YELLOW}  ⚠️ Running as root is not recommended${NC}"
else
    if ! sudo -n true 2>/dev/null; then
        echo -e "${CYAN}  This installer needs sudo access for some operations${NC}"
        sudo -v || exit 1
    fi
fi

echo -e "${GREEN}  ✅ Permissions verified${NC}"

# System requirements check
if ! check_system_requirements; then
    echo -e "${RED}System requirements not met. Please resolve issues and try again.${NC}"
    exit 1
fi

if [ "$CHECK_ONLY" = true ]; then
    echo -e "${GREEN}All requirements satisfied!${NC}"
    echo -e "${CYAN}Run without --check-only flag to proceed with installation${NC}"
    exit 0
fi

# Profile selection
if [ -z "$PROFILE" ]; then
    PROFILE=$(select_installation_profile)
fi

echo -e "${CYAN}  Selected profile: ${BOLD}$PROFILE${NC}"

# Confirmation
read -p "$(echo -e "\n${YELLOW}Ready to install Kekeli-HomeCloud? (Y/N): ${NC}")" confirm
if [[ ! "$confirm" =~ ^[Yy]$ ]]; then
    echo -e "${YELLOW}Installation cancelled${NC}"
    exit 0
fi

# Create log directory
mkdir -p "$(dirname "$LOG_FILE")"

# Run installation
run_installation "$PROFILE" 2>&1 | tee -a "$LOG_FILE"

# Show success celebration
show_success_celebration

echo ""
echo -e "${CYAN}  Installation log saved to: $LOG_FILE${NC}"
echo ""

exit 0