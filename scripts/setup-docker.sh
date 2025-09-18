#!/bin/bash
# setup-docker.sh - Automated Docker installation and configuration
# Part of the Kekeli-HomeCloud Easy Installer Project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Exit codes
SUCCESS=0
ERROR_INSTALL_FAILED=1
ERROR_SERVICE_FAILED=2
ERROR_PERMISSION_FAILED=3
ERROR_VALIDATION_FAILED=4

echo -e "${BLUE}🐳 Kekeli-HomeCloud Docker Setup${NC}"
echo -e "${BLUE}===================================${NC}"
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
        "progress")
            echo -e "  🔄 ${BLUE}$message${NC}"
            ;;
    esac
}

# Function to detect OS and package manager
detect_os() {
    if [ -f /etc/os-release ]; then
        source /etc/os-release
        echo "$ID"
    else
        echo "unknown"
    fi
}

# Function to check if Docker is already installed and working
check_existing_docker() {
    echo -e "${YELLOW}🔍 Checking existing Docker installation...${NC}"

    local docker_installed=false
    local docker_working=false
    local docker_compose_available=false

    # Check Docker installation
    if command -v docker >/dev/null 2>&1; then
        local docker_version=$(docker --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        if [ -n "$docker_version" ]; then
            print_status "pass" "Docker installed: $docker_version"
            docker_installed=true

            # Check if Docker daemon is running
            if docker info >/dev/null 2>&1; then
                print_status "pass" "Docker daemon: Running"
                docker_working=true
            else
                print_status "warn" "Docker daemon: Not running"
            fi
        else
            print_status "warn" "Docker installed but not responding"
        fi
    else
        print_status "info" "Docker not installed"
    fi

    # Check Docker Compose
    if command -v docker-compose >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version 2>/dev/null | awk '{print $3}' | tr -d ',')
        if [ -n "$compose_version" ]; then
            print_status "pass" "Docker Compose installed: $compose_version"
            docker_compose_available=true
        fi
    elif docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version 2>/dev/null | awk '{print $4}')
        if [ -n "$compose_version" ]; then
            print_status "pass" "Docker Compose (plugin) installed: $compose_version"
            docker_compose_available=true
        fi
    else
        print_status "info" "Docker Compose not installed"
    fi

    # Check user permissions
    if groups $USER | grep -q docker; then
        print_status "pass" "User in docker group: $USER"
    else
        print_status "warn" "User not in docker group: $USER"
    fi

    echo ""

    # Return status: 0=all good, 1=need install, 2=need service start, 3=need permissions
    if [ "$docker_installed" = true ] && [ "$docker_working" = true ] && [ "$docker_compose_available" = true ] && groups $USER | grep -q docker; then
        return 0  # Everything is working
    elif [ "$docker_installed" = true ]; then
        return 2  # Docker installed but needs configuration
    else
        return 1  # Need to install Docker
    fi
}

# Function to install Docker on Ubuntu/Debian
install_docker_debian() {
    echo -e "${YELLOW}📦 Installing Docker on Debian/Ubuntu...${NC}"

    # Update package index
    print_status "progress" "Updating package index..."
    if ! sudo apt-get update >/dev/null 2>&1; then
        print_status "fail" "Failed to update package index"
        return $ERROR_INSTALL_FAILED
    fi

    # Install prerequisites
    print_status "progress" "Installing prerequisites..."
    if ! sudo apt-get install -y \
        apt-transport-https \
        ca-certificates \
        curl \
        gnupg \
        lsb-release >/dev/null 2>&1; then
        print_status "fail" "Failed to install prerequisites"
        return $ERROR_INSTALL_FAILED
    fi

    # Add Docker's official GPG key
    print_status "progress" "Adding Docker GPG key..."
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg 2>/dev/null
    if [ $? -ne 0 ]; then
        print_status "warn" "Failed to add Docker GPG key, trying alternative method..."
        # Fallback to simpler installation
        if ! sudo apt-get install -y docker.io docker-compose >/dev/null 2>&1; then
            print_status "fail" "Failed to install Docker using fallback method"
            return $ERROR_INSTALL_FAILED
        fi
        print_status "pass" "Docker installed using fallback method"
        return 0
    fi

    # Add Docker repository
    print_status "progress" "Adding Docker repository..."
    local distro=$(lsb_release -cs)
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/ubuntu $distro stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list >/dev/null

    # Update package index again
    print_status "progress" "Updating package index with Docker repository..."
    if ! sudo apt-get update >/dev/null 2>&1; then
        print_status "fail" "Failed to update package index after adding Docker repository"
        return $ERROR_INSTALL_FAILED
    fi

    # Install Docker Engine
    print_status "progress" "Installing Docker Engine..."
    if ! sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin >/dev/null 2>&1; then
        print_status "fail" "Failed to install Docker Engine"
        return $ERROR_INSTALL_FAILED
    fi

    print_status "pass" "Docker Engine installed successfully"
    return 0
}

# Function to install Docker Compose standalone (if not already available)
install_docker_compose() {
    if command -v docker-compose >/dev/null 2>&1 || docker compose version >/dev/null 2>&1; then
        print_status "pass" "Docker Compose already available"
        return 0
    fi

    echo -e "${YELLOW}📦 Installing Docker Compose...${NC}"

    # Get latest version from GitHub API
    print_status "progress" "Getting latest Docker Compose version..."
    local compose_version=$(curl -s https://api.github.com/repos/docker/compose/releases/latest | grep -oP '"tag_name": "\K(.*)(?=")')

    if [ -z "$compose_version" ]; then
        compose_version="v2.21.0"  # Fallback version
        print_status "warn" "Using fallback version: $compose_version"
    else
        print_status "info" "Latest version: $compose_version"
    fi

    # Download and install Docker Compose
    print_status "progress" "Downloading Docker Compose..."
    if sudo curl -L "https://github.com/docker/compose/releases/download/$compose_version/docker-compose-$(uname -s)-$(uname -m)" \
        -o /usr/local/bin/docker-compose >/dev/null 2>&1; then

        # Make it executable
        sudo chmod +x /usr/local/bin/docker-compose
        print_status "pass" "Docker Compose installed successfully"
        return 0
    else
        print_status "fail" "Failed to install Docker Compose"
        return $ERROR_INSTALL_FAILED
    fi
}

# Function to configure Docker service
configure_docker_service() {
    echo -e "${YELLOW}⚙️  Configuring Docker service...${NC}"

    # Enable Docker service
    print_status "progress" "Enabling Docker service..."
    if sudo systemctl enable docker >/dev/null 2>&1; then
        print_status "pass" "Docker service enabled"
    else
        print_status "warn" "Could not enable Docker service"
    fi

    # Start Docker service
    print_status "progress" "Starting Docker service..."
    if sudo systemctl start docker >/dev/null 2>&1; then
        print_status "pass" "Docker service started"
    else
        print_status "fail" "Failed to start Docker service"
        return $ERROR_SERVICE_FAILED
    fi

    # Wait for Docker to be ready
    print_status "progress" "Waiting for Docker to be ready..."
    local attempts=0
    while [ $attempts -lt 30 ]; do
        if sudo docker info >/dev/null 2>&1; then
            print_status "pass" "Docker daemon is ready"
            return 0
        fi
        sleep 1
        attempts=$((attempts + 1))
    done

    print_status "fail" "Docker daemon failed to become ready"
    return $ERROR_SERVICE_FAILED
}

# Function to configure user permissions
configure_user_permissions() {
    echo -e "${YELLOW}👤 Configuring user permissions...${NC}"

    # Add user to docker group
    print_status "progress" "Adding user to docker group..."
    if sudo usermod -aG docker $USER; then
        print_status "pass" "User $USER added to docker group"
    else
        print_status "fail" "Failed to add user to docker group"
        return $ERROR_PERMISSION_FAILED
    fi

    # Apply group changes for current session
    print_status "progress" "Applying group changes..."
    if newgrp docker >/dev/null 2>&1; then
        print_status "pass" "Group changes applied"
    else
        print_status "warn" "Group changes will take effect after logout/login"
    fi

    return 0
}

# Function to validate Docker installation
validate_docker_installation() {
    echo -e "${YELLOW}✅ Validating Docker installation...${NC}"

    # Test Docker command
    print_status "progress" "Testing Docker command..."
    if timeout 30 docker --version >/dev/null 2>&1; then
        local docker_version=$(docker --version | awk '{print $3}' | tr -d ',')
        print_status "pass" "Docker command works: $docker_version"
    else
        print_status "fail" "Docker command failed"
        return $ERROR_VALIDATION_FAILED
    fi

    # Test Docker daemon access
    print_status "progress" "Testing Docker daemon access..."
    if timeout 30 docker info >/dev/null 2>&1; then
        print_status "pass" "Docker daemon accessible"
    elif timeout 30 sudo docker info >/dev/null 2>&1; then
        print_status "warn" "Docker daemon accessible with sudo (logout/login required for user access)"
    else
        print_status "fail" "Docker daemon not accessible"
        return $ERROR_VALIDATION_FAILED
    fi

    # Test Docker Compose
    print_status "progress" "Testing Docker Compose..."
    if docker compose version >/dev/null 2>&1; then
        local compose_version=$(docker compose version | awk '{print $4}')
        print_status "pass" "Docker Compose (plugin) works: $compose_version"
    elif command -v docker-compose >/dev/null 2>&1 && docker-compose --version >/dev/null 2>&1; then
        local compose_version=$(docker-compose --version | awk '{print $3}' | tr -d ',')
        print_status "pass" "Docker Compose standalone works: $compose_version"
    else
        print_status "fail" "Docker Compose not working"
        return $ERROR_VALIDATION_FAILED
    fi

    # Test container run
    print_status "progress" "Testing container execution..."
    if timeout 30 docker run --rm hello-world >/dev/null 2>&1; then
        print_status "pass" "Container execution works"
    elif timeout 30 sudo docker run --rm hello-world >/dev/null 2>&1; then
        print_status "warn" "Container execution works with sudo"
    else
        print_status "fail" "Container execution failed"
        return $ERROR_VALIDATION_FAILED
    fi

    return 0
}

# Function to show next steps
show_next_steps() {
    echo ""
    echo -e "${BLUE}======================================${NC}"
    echo -e "${GREEN}✅ Docker Setup Complete!${NC}"
    echo ""
    echo -e "${CYAN}Docker Information:${NC}"
    docker --version 2>/dev/null || echo "  Docker: Not accessible (logout/login required)"

    if docker compose version >/dev/null 2>&1; then
        docker compose version | head -1
    elif command -v docker-compose >/dev/null 2>&1; then
        docker-compose --version 2>/dev/null || echo "  Docker Compose: Not accessible"
    fi

    echo ""
    echo -e "${CYAN}Next Steps:${NC}"
    if ! groups $USER | grep -q docker || ! docker info >/dev/null 2>&1; then
        echo -e "  1. ${YELLOW}Log out and log back in${NC} (to apply group permissions)"
        echo -e "  2. Run Docker validation: ${BLUE}docker run hello-world${NC}"
        echo -e "  3. Continue with Nextcloud installation"
    else
        echo -e "  1. Continue with Nextcloud installation"
        echo -e "  2. Run requirements check: ${BLUE}./scripts/check-requirements.sh${NC}"
    fi
    echo ""
}

# Help function
show_help() {
    echo "Kekeli-HomeCloud Docker Setup"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help      Show this help message"
    echo "  -f, --force     Force reinstallation even if Docker exists"
    echo "  -q, --quiet     Quiet mode (minimal output)"
    echo "  -v, --verbose   Verbose mode (detailed output)"
    echo "  --skip-compose  Skip Docker Compose installation"
    echo "  --skip-service  Skip Docker service configuration"
    echo ""
    echo "Exit codes:"
    echo "  0 - Success"
    echo "  1 - Installation failed"
    echo "  2 - Service configuration failed"
    echo "  3 - Permission configuration failed"
    echo "  4 - Validation failed"
}

# Main function
main() {
    local force_install=false
    local skip_compose=false
    local skip_service=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -f|--force)
                force_install=true
                shift
                ;;
            -q|--quiet)
                exec >/dev/null
                shift
                ;;
            -v|--verbose)
                set -x
                shift
                ;;
            --skip-compose)
                skip_compose=true
                shift
                ;;
            --skip-service)
                skip_service=true
                shift
                ;;
            *)
                echo "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done

    echo -e "${CYAN}Starting Docker setup for Kekeli-HomeCloud...${NC}"
    echo ""

    # Check existing installation
    check_existing_docker
    local docker_status=$?

    if [ $docker_status -eq 0 ] && [ "$force_install" = false ]; then
        print_status "pass" "Docker is already properly installed and configured"
        show_next_steps
        exit 0
    fi

    # Detect OS
    local os=$(detect_os)
    print_status "info" "Detected OS: $os"
    echo ""

    # Install Docker if needed
    if [ $docker_status -eq 1 ] || [ "$force_install" = true ]; then
        case $os in
            ubuntu|debian)
                install_docker_debian || exit $?
                ;;
            *)
                print_status "fail" "Unsupported OS for automatic Docker installation: $os"
                echo -e "${YELLOW}Please install Docker manually:${NC}"
                echo -e "  https://docs.docker.com/engine/install/"
                exit $ERROR_INSTALL_FAILED
                ;;
        esac
        echo ""
    fi

    # Install Docker Compose if needed and not skipped
    if [ "$skip_compose" = false ]; then
        install_docker_compose || exit $?
        echo ""
    fi

    # Configure Docker service if needed and not skipped
    if [ "$skip_service" = false ]; then
        configure_docker_service || exit $?
        echo ""
    fi

    # Configure user permissions
    configure_user_permissions || exit $?
    echo ""

    # Validate installation
    validate_docker_installation || exit $?

    # Show completion message and next steps
    show_next_steps

    exit 0
}

# Run main function with all arguments
main "$@"