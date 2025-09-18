#!/bin/bash
# setup-networking.sh - Network configuration automation for Kekeli-HomeCloud
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/error-handling.sh"
source "$UTILS_DIR/network-detection.sh"

# =============================================================================
# NETWORK CONFIGURATION
# =============================================================================

readonly DEFAULT_NEXTCLOUD_PORT=8080
readonly DEFAULT_NEXTCLOUD_SSL_PORT=8443
readonly REQUIRED_PORTS="80,443,8080,8443"

# =============================================================================
# MAIN NETWORK SETUP FUNCTIONS
# =============================================================================

# Function to detect and validate network environment
detect_and_validate_network() {
    print_subsection "Detecting Network Environment"

    # Test basic connectivity
    if ! test_network_connectivity; then
        handle_recoverable_error "Network connectivity issues detected"
        if ! ask_yes_no "Continue despite network issues?"; then
            return 1
        fi
    fi

    # Detect all available IP addresses
    local access_ips
    access_ips=$(detect_access_ips)

    if [ -z "$access_ips" ]; then
        handle_critical_error "No network interfaces detected"
        return 1
    fi

    print_status "pass" "Network environment detected successfully"

    # Save detected IPs for later use
    save_config "DETECTED_ACCESS_IPS" "$access_ips"

    return 0
}

# Function to perform complete network setup
setup_network_configuration() {
    print_section "🌐" "Kekeli-HomeCloud Network Configuration"

    print_status "info" "Configuring network access for your Nextcloud instance"
    echo -e "${CYAN}This will set up local and mobile network access.${NC}"
    echo ""

    print_status "progress" "Starting network configuration setup"

    # Step 1: Detect and validate network environment
    if ! detect_and_validate_network(); then
        print_status "fail" "Network detection failed"
        return 1
    fi

    # Step 2: Configure ports and firewall
    if ! configure_firewall_and_ports(); then
        print_status "fail" "Firewall configuration failed"
        return 1
    fi

    # Step 3: Generate network configuration
    if ! generate_network_configuration(); then
        print_status "fail" "Network configuration generation failed"
        return 1
    fi

    # Step 4: Set up mobile access
    if ! setup_mobile_network_access(); then
        print_status "fail" "Mobile network access setup failed"
        return 1
    fi

    # Step 5: Validate configuration
    if ! validate_network_setup(); then
        print_status "fail" "Network configuration validation failed"
        return 1
    fi

    print_status "pass" "Network configuration completed successfully"
    return 0
}

# Function to configure firewall and ports
configure_firewall_and_ports() {
    print_subsection "Configuring Firewall and Ports"

    # Check if required ports are available
    local available_ports
    available_ports=$(scan_available_ports 8080 8090)

    local nextcloud_port=$DEFAULT_NEXTCLOUD_PORT
    local nextcloud_ssl_port=$DEFAULT_NEXTCLOUD_SSL_PORT

    # Select available port if default is in use
    if netstat -tln 2>/dev/null | grep -q ":$DEFAULT_NEXTCLOUD_PORT "; then
        print_status "warn" "Default port $DEFAULT_NEXTCLOUD_PORT is in use"

        # Find first available port
        while IFS= read -r port; do
            if [ "$port" -ge 8080 ] && [ "$port" -le 8090 ]; then
                nextcloud_port=$port
                nextcloud_ssl_port=$((port + 363))  # 8080 -> 8443, 8081 -> 8444, etc.
                break
            fi
        done <<< "$available_ports"

        print_status "info" "Using alternative port: $nextcloud_port"
    fi

    # Save port configuration
    save_config "NEXTCLOUD_HTTP_PORT" "$nextcloud_port"
    save_config "NEXTCLOUD_HTTPS_PORT" "$nextcloud_ssl_port"

    # Configure firewall
    local ports_to_open="$nextcloud_port,$nextcloud_ssl_port"
    if configure_firewall "$ports_to_open"; then
        print_status "pass" "Firewall configured for ports: $ports_to_open"
    else
        print_status "warn" "Firewall configuration may be incomplete"
        if is_wsl; then
            print_status "info" "WSL2 detected - additional Windows firewall configuration may be needed"
        fi
    fi

    return 0
}

# Function to generate network configuration
generate_network_configuration() {
    print_subsection "Generating Network Configuration"

    local access_ips=$(load_config "DETECTED_ACCESS_IPS")
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "$DEFAULT_NEXTCLOUD_PORT")
    local nextcloud_ssl_port=$(load_config "NEXTCLOUD_HTTPS_PORT" "$DEFAULT_NEXTCLOUD_SSL_PORT")

    # Generate trusted domains list
    local trusted_domains=()
    local access_urls=()

    # Add localhost entries
    trusted_domains+=("localhost")
    trusted_domains+=("localhost:$nextcloud_port")
    trusted_domains+=("127.0.0.1")
    trusted_domains+=("127.0.0.1:$nextcloud_port")

    # Add detected IPs
    while IFS= read -r ip_info; do
        if [ -z "$ip_info" ]; then continue; fi

        local ip=$(echo "$ip_info" | cut -d'|' -f1)
        local description=$(echo "$ip_info" | cut -d'|' -f2)

        # Add to trusted domains
        trusted_domains+=("$ip")
        trusted_domains+=("$ip:$nextcloud_port")

        # Generate access URLs
        access_urls+=("http://$ip:$nextcloud_port|$description")

        # Add HTTPS if SSL port is different
        if [ "$nextcloud_ssl_port" != "$nextcloud_port" ]; then
            trusted_domains+=("$ip:$nextcloud_ssl_port")
            access_urls+=("https://$ip:$nextcloud_ssl_port|$description (SSL)")
        fi

    done <<< "$access_ips"

    # Add Docker internal networking
    trusted_domains+=("host.docker.internal")
    trusted_domains+=("host.docker.internal:$nextcloud_port")

    # WSL2 specific additions
    if is_wsl; then
        local windows_ip=$(get_windows_ip_from_wsl)
        if [ -n "$windows_ip" ]; then
            save_config "WINDOWS_HOST_IP" "$windows_ip"
        fi

        local wsl_ip=$(hostname -I | awk '{print $1}')
        if [ -n "$wsl_ip" ]; then
            save_config "WSL_IP" "$wsl_ip"
        fi
    fi

    # Save configuration
    save_config "TRUSTED_DOMAINS" "$(printf '%s\n' "${trusted_domains[@]}" | sort -u | tr '\n' ',')"
    save_config "ACCESS_URLS" "$(printf '%s\n' "${access_urls[@]}")"

    print_status "pass" "Network configuration generated"

    # Display configuration summary
    echo ""
    echo -e "${CYAN}Network Configuration Summary:${NC}"
    echo -e "  HTTP Port: ${GREEN}$nextcloud_port${NC}"
    echo -e "  HTTPS Port: ${GREEN}$nextcloud_ssl_port${NC}"
    echo -e "  Trusted Domains: ${GREEN}${#trusted_domains[@]} entries${NC}"
    echo -e "  Access URLs: ${GREEN}${#access_urls[@]} endpoints${NC}"

    return 0
}

# Function to setup mobile network access
setup_mobile_network_access() {
    print_subsection "Setting Up Mobile Access"

    local access_urls=$(load_config "ACCESS_URLS")
    local mobile_urls=()
    local qr_codes=()

    # Generate mobile-friendly URLs
    while IFS= read -r url_info; do
        if [ -z "$url_info" ]; then continue; fi

        local url=$(echo "$url_info" | cut -d'|' -f1)
        local description=$(echo "$url_info" | cut -d'|' -f2)

        # Filter for primary network IPs (exclude localhost)
        if [[ "$url" =~ ^https?://192\.168\.|^https?://10\.|^https?://172\. ]]; then
            mobile_urls+=("$url")

            # Generate QR code data if qrencode is available
            if command_exists qrencode; then
                qr_codes+=("$url")
            fi
        fi
    done <<< "$access_urls"

    if [ ${#mobile_urls[@]} -eq 0 ]; then
        print_status "warn" "No mobile-accessible URLs generated"
        return 1
    fi

    # Save mobile configuration
    save_config "MOBILE_ACCESS_URLS" "$(printf '%s\n' "${mobile_urls[@]}")"

    print_status "pass" "Mobile access configured"

    # Display mobile access information
    echo ""
    echo -e "${CYAN}Mobile Access URLs:${NC}"
    for url in "${mobile_urls[@]}"; do
        echo -e "  📱 ${GREEN}$url${NC}"
    done

    # Generate QR codes if possible
    if [ ${#qr_codes[@]} -gt 0 ] && command_exists qrencode; then
        echo ""
        echo -e "${CYAN}QR Codes for Mobile Setup:${NC}"
        local qr_dir="$KEKELI_CONFIG_DIR/qr-codes"
        create_directory "$qr_dir"

        for url in "${qr_codes[@]:0:2}"; do  # Limit to first 2 URLs
            local filename="qr_$(echo "$url" | sed 's|[^a-zA-Z0-9]|_|g').png"
            local qr_file="$qr_dir/$filename"

            if qrencode -o "$qr_file" "$url" 2>/dev/null; then
                print_status "pass" "QR code generated: $qr_file"
                echo -e "    📱 Scan to connect: ${CYAN}$url${NC}"
            fi
        done
    fi

    return 0
}

# Function to validate network setup
validate_network_setup() {
    print_subsection "Validating Network Configuration"

    local validation_passed=true

    # Test 1: Validate configuration completeness
    local required_configs=(
        "NEXTCLOUD_HTTP_PORT"
        "TRUSTED_DOMAINS"
        "ACCESS_URLS"
    )

    for config in "${required_configs[@]}"; do
        local value=$(load_config "$config")
        if [ -z "$value" ]; then
            print_status "fail" "Missing configuration: $config"
            validation_passed=false
        else
            print_status "pass" "Configuration present: $config"
        fi
    done

    # Test 2: Validate port accessibility
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")
    if ! netstat -tln 2>/dev/null | grep -q ":$nextcloud_port "; then
        print_status "pass" "Port $nextcloud_port is available"
    else
        print_status "warn" "Port $nextcloud_port may be in use"
    fi

    # Test 3: Validate network connectivity
    if check_internet; then
        print_status "pass" "Internet connectivity available"
    else
        print_status "warn" "Limited internet connectivity"
    fi

    # Test 4: Validate firewall configuration
    if is_wsl; then
        print_status "info" "WSL2 environment - firewall validation skipped"
    else
        # Basic firewall test - check if UFW is configured
        if command_exists ufw && ufw status | grep -q "Status: active"; then
            if ufw status | grep -q "$nextcloud_port"; then
                print_status "pass" "Firewall rule configured"
            else
                print_status "warn" "Firewall rule may not be configured"
            fi
        fi
    fi

    if [ "$validation_passed" = true ]; then
        print_status "pass" "Network configuration validation successful"
        return 0
    else
        print_status "fail" "Network configuration validation failed"
        return 1
    fi
}

# Function to show network status
show_network_status() {
    print_section "📊" "Network Status Summary"

    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "$DEFAULT_NEXTCLOUD_PORT")
    local nextcloud_ssl_port=$(load_config "NEXTCLOUD_HTTPS_PORT" "$DEFAULT_NEXTCLOUD_SSL_PORT")
    local trusted_domains=$(load_config "TRUSTED_DOMAINS")
    local access_urls=$(load_config "ACCESS_URLS")
    local mobile_urls=$(load_config "MOBILE_ACCESS_URLS")

    echo -e "${CYAN}Current Network Configuration:${NC}"
    echo -e "  Status: ${GREEN}Configured${NC}"
    echo -e "  HTTP Port: ${GREEN}$nextcloud_port${NC}"
    echo -e "  HTTPS Port: ${GREEN}$nextcloud_ssl_port${NC}"

    if [ -n "$trusted_domains" ]; then
        local domain_count=$(echo "$trusted_domains" | tr ',' '\n' | wc -l)
        echo -e "  Trusted Domains: ${GREEN}$domain_count entries${NC}"
    fi

    # Show access URLs
    if [ -n "$access_urls" ]; then
        echo ""
        echo -e "${CYAN}Access URLs:${NC}"
        while IFS= read -r url_info; do
            if [ -z "$url_info" ]; then continue; fi
            local url=$(echo "$url_info" | cut -d'|' -f1)
            local description=$(echo "$url_info" | cut -d'|' -f2)
            echo -e "  🌐 ${GREEN}$url${NC} - $description"
        done <<< "$access_urls"
    fi

    # Show mobile URLs
    if [ -n "$mobile_urls" ]; then
        echo ""
        echo -e "${CYAN}Mobile Access:${NC}"
        while IFS= read -r url; do
            if [ -z "$url" ]; then continue; fi
            echo -e "  📱 ${GREEN}$url${NC}"
        done <<< "$mobile_urls"
    fi

    # Network environment info
    echo ""
    echo -e "${CYAN}Network Environment:${NC}"
    if is_wsl; then
        echo -e "  Environment: ${GREEN}WSL2${NC}"
        local windows_ip=$(load_config "WINDOWS_HOST_IP")
        local wsl_ip=$(load_config "WSL_IP")
        [ -n "$windows_ip" ] && echo -e "  Windows Host IP: ${GREEN}$windows_ip${NC}"
        [ -n "$wsl_ip" ] && echo -e "  WSL IP: ${GREEN}$wsl_ip${NC}"
    else
        echo -e "  Environment: ${GREEN}Native Linux${NC}"
        local primary_interface=$(detect_primary_interface)
        [ -n "$primary_interface" ] && echo -e "  Primary Interface: ${GREEN}$primary_interface${NC}"
    fi

    # Firewall status
    if command_exists ufw; then
        local firewall_status=$(ufw status | head -1 | awk '{print $2}')
        echo -e "  Firewall (UFW): ${GREEN}$firewall_status${NC}"
    elif is_wsl; then
        echo -e "  Firewall: ${YELLOW}Windows managed${NC}"
    else
        echo -e "  Firewall: ${YELLOW}Unknown${NC}"
    fi

    echo ""
    print_status "pass" "Network ready for Nextcloud deployment"
}

# Function to test network configuration
test_network_configuration() {
    print_section "🧪" "Testing Network Configuration"

    local test_passed=true
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")

    # Test 1: Port availability
    print_status "progress" "Testing port availability..."
    if ! netstat -tln 2>/dev/null | grep -q ":$nextcloud_port "; then
        print_status "pass" "Port $nextcloud_port is available"
    else
        print_status "fail" "Port $nextcloud_port is in use"
        test_passed=false
    fi

    # Test 2: Network interfaces
    print_status "progress" "Testing network interfaces..."
    local interfaces=$(detect_network_interfaces)
    if [ -n "$interfaces" ]; then
        local interface_count=$(echo "$interfaces" | wc -l)
        print_status "pass" "Network interfaces detected: $interface_count"
    else
        print_status "fail" "No network interfaces detected"
        test_passed=false
    fi

    # Test 3: Internet connectivity
    print_status "progress" "Testing internet connectivity..."
    if check_internet; then
        print_status "pass" "Internet connectivity available"
    else
        print_status "warn" "Internet connectivity limited"
    fi

    # Test 4: DNS resolution
    print_status "progress" "Testing DNS resolution..."
    if nslookup google.com >/dev/null 2>&1; then
        print_status "pass" "DNS resolution working"
    else
        print_status "warn" "DNS resolution issues"
    fi

    if [ "$test_passed" = true ]; then
        print_status "pass" "All network tests passed"
        return 0
    else
        print_status "fail" "Some network tests failed"
        return 1
    fi
}

# Function to generate network environment file
generate_network_env_file() {
    local env_file="$KEKELI_CONFIG_DIR/network.env"

    print_status "progress" "Generating network environment file..."

    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")
    local nextcloud_ssl_port=$(load_config "NEXTCLOUD_HTTPS_PORT")
    local trusted_domains=$(load_config "TRUSTED_DOMAINS")
    local windows_ip=$(load_config "WINDOWS_HOST_IP")
    local wsl_ip=$(load_config "WSL_IP")

    # Get primary IP for main URL
    local primary_ip
    if [ -n "$windows_ip" ]; then
        primary_ip="$windows_ip"
    elif [ -n "$wsl_ip" ]; then
        primary_ip="$wsl_ip"
    else
        primary_ip=$(get_local_ips | head -1)
    fi

    cat > "$env_file" << EOF
# Kekeli-HomeCloud Network Configuration
# Generated on $(date)

# Primary network configuration
NEXTCLOUD_HTTP_PORT=$nextcloud_port
NEXTCLOUD_HTTPS_PORT=$nextcloud_ssl_port
PRIMARY_IP=$primary_ip
NEXTCLOUD_URL=http://$primary_ip:$nextcloud_port

# Environment detection
$(is_wsl && echo "WSL_ENVIRONMENT=true" || echo "WSL_ENVIRONMENT=false")
$([ -n "$windows_ip" ] && echo "WINDOWS_HOST_IP=$windows_ip")
$([ -n "$wsl_ip" ] && echo "WSL_IP=$wsl_ip")

# Trusted domains (comma-separated)
TRUSTED_DOMAINS=$trusted_domains

# Docker networking
DOCKER_NETWORK_NAME=kekeli-network
EOF

    if [ -f "$env_file" ]; then
        print_status "pass" "Network environment file created: $env_file"
        return 0
    else
        print_status "fail" "Failed to create network environment file"
        return 1
    fi
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

# Help function
show_help() {
    echo "Kekeli-HomeCloud Network Configuration"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -s, --setup       Run complete network setup"
    echo "  -t, --test        Test network configuration"
    echo "  -v, --validate    Validate existing network setup"
    echo "  --status          Show current network status"
    echo "  --generate-env    Generate network environment file"
    echo ""
    echo "Examples:"
    echo "  $0 --setup       # Run complete network configuration"
    echo "  $0 --test        # Test current network setup"
    echo "  $0 --status      # Show network status"
}

# Main function
main() {
    local setup_mode=false
    local test_mode=false
    local validate_mode=false
    local status_mode=false
    local generate_env_mode=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -s|--setup)
                setup_mode=true
                shift
                ;;
            -t|--test)
                test_mode=true
                shift
                ;;
            -v|--validate)
                validate_mode=true
                shift
                ;;
            --status)
                status_mode=true
                shift
                ;;
            --generate-env)
                generate_env_mode=true
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
    set_error_context "Network Configuration"

    # Handle specific modes
    if [ "$status_mode" = true ]; then
        show_network_status
        exit 0
    fi

    if [ "$test_mode" = true ]; then
        if test_network_configuration; then
            exit 0
        else
            exit 1
        fi
    fi

    if [ "$validate_mode" = true ]; then
        if validate_network_setup; then
            print_status "pass" "Network validation successful"
            exit 0
        else
            print_status "fail" "Network validation failed"
            exit 1
        fi
    fi

    if [ "$generate_env_mode" = true ]; then
        if generate_network_env_file; then
            exit 0
        else
            exit 1
        fi
    fi

    # Default: Run setup
    if [ "$setup_mode" = true ] || [ $# -eq 0 ]; then
        if setup_network_configuration; then
            echo ""
            show_network_status
            echo ""
            print_status "pass" "Network configuration completed successfully!"
            echo -e "${CYAN}Next step: Deploy Nextcloud containers${NC}"
            exit 0
        else
            print_status "fail" "Network configuration failed"
            exit 1
        fi
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi