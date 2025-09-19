#!/bin/bash
# Kekeli-HomeCloud Linux/WSL2 Installer
# One-command installation script for Linux systems

set -e

# Configuration
REPO_URL="https://github.com/kelibst/kekeli-homelab"
BRANCH="windows"
INSTALL_DIR="$HOME/kekeli-homelab"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Output functions
print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_info() {
    echo -e "${CYAN}ℹ️  $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Show banner
show_banner() {
    echo -e "${CYAN}"
    cat << "EOF"

╔════════════════════════════════════════════════════╗
║     🏠 Kekeli-HomeCloud Easy Installer             ║
║     Transform Your Computer Into Your Cloud        ║
╚════════════════════════════════════════════════════╝

EOF
    echo -e "${NC}"
}

# Parse arguments
CHECK_ONLY=false
SHOW_PLATFORM=false
SHOW_HELP=false

while [[ "$#" -gt 0 ]]; do
    case $1 in
        --check-only) CHECK_ONLY=true ;;
        --platform) SHOW_PLATFORM=true ;;
        --help|-h) SHOW_HELP=true ;;
        *) echo "Unknown parameter: $1"; exit 1 ;;
    esac
    shift
done

# Show help
if [ "$SHOW_HELP" = true ]; then
    show_banner
    cat << EOF
Usage: $0 [options]

Options:
    --check-only    Only check requirements without installing
    --platform      Show platform information
    --help, -h      Show this help message

Examples:
    # Full installation (recommended)
    ./install.sh

    # Check requirements only
    ./install.sh --check-only

    # Show platform info
    ./install.sh --platform

EOF
    exit 0
fi

# Show platform info
if [ "$SHOW_PLATFORM" = true ]; then
    print_info "Platform Information:"
    echo "OS: $(uname -a)"
    echo "Distribution: $(lsb_release -ds 2>/dev/null || cat /etc/*release | head -n1)"
    echo "Kernel: $(uname -r)"
    echo "Architecture: $(uname -m)"
    echo "User: $USER"
    echo "Install Directory: $INSTALL_DIR"

    # Check if running in WSL
    if grep -qi microsoft /proc/version 2>/dev/null; then
        echo "Environment: WSL2"
    fi
    exit 0
fi

show_banner

# Detect platform
PLATFORM="linux"
if grep -qi microsoft /proc/version 2>/dev/null; then
    PLATFORM="wsl2"
    print_info "Detected WSL2 environment"
elif [ -f /etc/os-release ]; then
    . /etc/os-release
    print_info "Detected $NAME $VERSION"
fi

# Check for root/sudo
if [ "$EUID" -eq 0 ]; then
   print_warning "Running as root is not recommended"
   print_info "The installer will use sudo when needed"
else
    # Check sudo access
    if ! sudo -n true 2>/dev/null; then
        print_info "This installer needs sudo access for some operations"
        print_info "Please enter your password when prompted"
        sudo -v
    fi
fi

# Check system requirements
print_info "Checking system requirements..."

# Check Python
if command -v python3 &> /dev/null; then
    PYTHON_VERSION=$(python3 --version 2>&1 | grep -Po '(?<=Python )\d+\.\d+')
    if [ "$(echo "$PYTHON_VERSION >= 3.6" | bc -l 2>/dev/null || echo "0")" = "1" ]; then
        print_success "Python $PYTHON_VERSION found"
    else
        print_error "Python 3.6+ required, found $PYTHON_VERSION"
        exit 1
    fi
else
    print_warning "Python3 not found"
    if [ "$CHECK_ONLY" = false ]; then
        print_info "Installing Python3..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y python3 python3-pip
        elif command -v yum &> /dev/null; then
            sudo yum install -y python3 python3-pip
        else
            print_error "Cannot install Python3 automatically. Please install manually."
            exit 1
        fi
        print_success "Python3 installed"
    else
        print_error "Python3 is required. Please install it manually."
        exit 1
    fi
fi

# Check Git
if command -v git &> /dev/null; then
    GIT_VERSION=$(git --version | grep -Po '(?<=git version )\d+\.\d+')
    print_success "Git $GIT_VERSION found"
else
    print_warning "Git not found"
    if [ "$CHECK_ONLY" = false ]; then
        print_info "Installing Git..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y git
        elif command -v yum &> /dev/null; then
            sudo yum install -y git
        else
            print_error "Cannot install Git automatically. Please install manually."
            exit 1
        fi
        print_success "Git installed"
    else
        print_error "Git is required. Please install it manually."
        exit 1
    fi
fi

# Check curl
if ! command -v curl &> /dev/null; then
    print_warning "curl not found"
    if [ "$CHECK_ONLY" = false ]; then
        print_info "Installing curl..."
        if command -v apt-get &> /dev/null; then
            sudo apt-get update && sudo apt-get install -y curl
        elif command -v yum &> /dev/null; then
            sudo yum install -y curl
        else
            print_error "Cannot install curl automatically. Please install manually."
            exit 1
        fi
        print_success "curl installed"
    else
        print_error "curl is required. Please install it manually."
        exit 1
    fi
else
    print_success "curl found"
fi

# Check disk space (require at least 4GB)
AVAILABLE_SPACE=$(df "$HOME" | awk 'NR==2 {print $4}')
REQUIRED_SPACE=4194304  # 4GB in KB

if [ "$AVAILABLE_SPACE" -lt "$REQUIRED_SPACE" ]; then
    print_error "Insufficient disk space. At least 4GB required."
    print_info "Available: $(echo "scale=2; $AVAILABLE_SPACE/1048576" | bc)GB"
    exit 1
else
    print_success "Sufficient disk space available"
fi

if [ "$CHECK_ONLY" = true ]; then
    print_success "All requirements satisfied!"
    print_info "Run without --check-only flag to proceed with installation"
    exit 0
fi

# Clone or update repository
print_info "Setting up Kekeli-HomeCloud..."

if [ -d "$INSTALL_DIR" ]; then
    print_info "Found existing installation at $INSTALL_DIR"
    read -p "Update existing installation? (Y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cd "$INSTALL_DIR"
        print_info "Updating from repository..."
        git fetch origin "$BRANCH"
        git checkout "$BRANCH"
        git pull origin "$BRANCH"
        print_success "Repository updated"
    fi
else
    print_info "Cloning repository..."
    git clone -b "$BRANCH" "$REPO_URL" "$INSTALL_DIR"
    cd "$INSTALL_DIR"
    print_success "Repository cloned"
fi

cd "$INSTALL_DIR"

# Install Python requirements if they exist
if [ -f "requirements.txt" ]; then
    print_info "Installing Python dependencies..."
    python3 -m pip install --upgrade pip
    python3 -m pip install -r requirements.txt
    print_success "Dependencies installed"
fi

# Make scripts executable
chmod +x install.py
chmod +x scripts/*.sh 2>/dev/null || true

# Run the main installer
print_info "Starting Kekeli-HomeCloud installation..."
echo

if python3 install.py; then
    echo
    print_success "Installation completed successfully!"
    print_info "Your Nextcloud instance should be accessible soon"
    print_info "Check the generated documentation for mobile setup instructions"
else
    EXIT_CODE=$?
    print_error "Installation failed with exit code $EXIT_CODE"
    print_info "Check the installation log for details"
    exit $EXIT_CODE
fi

echo
print_info "Installation directory: $INSTALL_DIR"
print_info "For troubleshooting, see: $INSTALL_DIR/docs/troubleshooting.md"
echo
print_success "Thank you for using Kekeli-HomeCloud!"