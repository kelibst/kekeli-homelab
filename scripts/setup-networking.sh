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

    print_status "progress" "Starting network environment analysis..."
    print_status "info" "This will check connectivity and identify network interfaces"

    # Test basic connectivity
    print_status "progress" "Testing network connectivity and accessibility..."
    if ! test_network_connectivity; then
        print_status "warn" "Network connectivity issues detected"
        handle_recoverable_error "Network connectivity issues detected"
        if ! ask_yes_no "Continue despite network issues?"; then
            print_status "info" "User chose to abort due to network issues"
            return 1
        fi
        print_status "progress" "Continuing with limited network connectivity..."
    else
        print_status "pass" "Network connectivity tests passed"
    fi

    # Detect all available IP addresses
    print_status "progress" "Scanning for available network interfaces and IP addresses..."
    local access_ips
    access_ips=$(detect_access_ips)

    if [ -z "$access_ips" ]; then
        print_status "error" "No network interfaces detected - network setup cannot proceed"
        handle_critical_error "No network interfaces detected"
        return 1
    fi

    print_status "pass" "Network environment detected successfully"
    print_status "info" "Found network interfaces and IP addresses for Nextcloud access"

    # Save detected IPs for later use
    print_status "progress" "Saving network configuration for later use..."
    save_config "DETECTED_ACCESS_IPS" "$access_ips"
    print_status "pass" "Network detection completed"

    return 0
}

# Function to perform complete network setup
setup_network_configuration() {
    print_section "🌐" "Kekeli-HomeCloud Network Configuration"

    print_status "info" "Configuring network access for your Nextcloud instance"
    echo -e "${CYAN}This will set up local and mobile network access.${NC}"
    echo ""

    print_status "progress" "Starting network configuration setup"
    print_status "info" "This process will configure network access, ports, and mobile connectivity"

    # Step 0: Check for IP address changes (if not initial setup)
    local completed_phases=$(load_config "COMPLETED_PHASES" "")
    if [[ "$completed_phases" == *"networking"* ]]; then
        print_status "progress" "Step 0/5: Checking for IP address changes..."
        if ! handle_ip_change false; then
            print_status "warn" "IP change handling completed with issues"
        fi
        print_status "pass" "Step 0/5: IP change detection completed"
    fi

    # Step 1: Detect and validate network environment
    print_status "progress" "Step 1/6: Detecting and validating network environment..."
    if ! detect_and_validate_network; then
        print_status "fail" "Network detection failed"
        return 1
    fi
    print_status "pass" "Step 1/6: Network environment detection completed successfully"

    # Step 2: Apply static IP configuration (if HOST_IP is set)
    print_status "progress" "Step 2/6: Checking for static IP configuration..."
    if apply_static_ip_configuration; then
        local configured_host_ip=$(load_config "HOST_IP")
        if [ -n "$configured_host_ip" ]; then
            echo ""
            print_status "pass" "✅ Static IP successfully configured!"
            print_status "info" "Your system IP: $configured_host_ip"
            print_status "info" "This IP will persist across reboots"
            print_status "info" "Family access URL: http://$configured_host_ip:$(load_config 'NEXTCLOUD_HTTP_PORT' '8080')"
            echo ""
        fi
    else
        print_status "warn" "Static IP configuration had issues"
        print_status "info" "Continuing with current network configuration..."
    fi
    print_status "pass" "Step 2/6: Static IP configuration completed"

    # Step 3: Configure ports and firewall
    print_status "progress" "Step 3/6: Configuring firewall and network ports..."
    if ! configure_firewall_and_ports; then
        print_status "fail" "Firewall configuration failed"
        return 1
    fi
    print_status "pass" "Step 3/6: Firewall and port configuration completed successfully"

    # Step 4: Generate network configuration
    print_status "progress" "Step 4/6: Generating network configuration files..."
    if ! generate_network_configuration; then
        print_status "fail" "Network configuration generation failed"
        return 1
    fi
    print_status "pass" "Step 4/6: Network configuration generation completed successfully"

    # Step 5: Set up mobile access
    print_status "progress" "Step 5/6: Setting up mobile device network access..."
    if ! setup_mobile_network_access; then
        print_status "fail" "Mobile network access setup failed"
        return 1
    fi
    print_status "pass" "Step 5/6: Mobile network access setup completed successfully"

    # Step 6: Validate MOBILE_URL configuration (skip if advanced static IP is configured)
    local static_ip_method=$(load_config "STATIC_IP_METHOD" "none")
    if [ "$static_ip_method" = "none" ]; then
        print_status "progress" "Step 6/8: Validating MOBILE_URL configuration..."
        if ! validate_mobile_url_configuration; then
            print_status "warn" "MOBILE_URL validation completed with recommendations"
        fi
        print_status "pass" "Step 6/8: MOBILE_URL validation completed"
    else
        print_status "info" "Step 6/8: Skipping MOBILE_URL validation (Advanced static IP configured: $static_ip_method)"
    fi

    # Step 7: Check IP persistence and provide guidance (skip if advanced static IP is configured)
    if [ "$static_ip_method" = "none" ]; then
        print_status "progress" "Step 7/9: Checking IP persistence for family network consistency..."
        if ! check_ip_persistence_and_guide; then
            print_status "warn" "IP persistence check completed with recommendations"
        fi
        print_status "pass" "Step 7/9: IP persistence guidance provided"
    else
        print_status "info" "Step 7/9: Skipping IP persistence check (Advanced static IP configured: $static_ip_method)"

        # Show the configured static IP method status
        echo ""
        print_subsection "Advanced Static IP Configuration Active"
        case $static_ip_method in
            macvlan)
                local container_ip=$(load_config "MACVLAN_CONTAINER_IP")
                local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
                print_status "pass" "Macvlan network configured"
                print_status "info" "Static IP: $container_ip"
                print_status "info" "Family access URL: http://${container_ip}:${port}"
                print_status "info" "This IP will NOT change after reboots"
                ;;
            avahi)
                local hostname=$(load_config "AVAHI_HOSTNAME" "nextcloud")
                local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
                print_status "pass" "Avahi mDNS configured"
                print_status "info" "Hostname: ${hostname}.local"
                print_status "info" "Family access URL: http://${hostname}.local:${port}"
                ;;
            duckdns)
                local subdomain=$(load_config "DUCKDNS_SUBDOMAIN")
                local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
                print_status "pass" "DuckDNS configured"
                print_status "info" "Domain: ${subdomain}.duckdns.org"
                print_status "info" "Family access URL: http://${subdomain}.duckdns.org:${port}"
                ;;
            combo)
                local container_ip=$(load_config "MACVLAN_CONTAINER_IP")
                local hostname=$(load_config "AVAHI_HOSTNAME" "nextcloud")
                local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
                print_status "pass" "Combo configuration (Macvlan + Avahi)"
                print_status "info" "Static IP: http://${container_ip}:${port}"
                print_status "info" "Hostname: http://${hostname}.local:${port}"
                print_status "info" "Both URLs will persist after reboots"
                ;;
        esac
        echo ""
    fi

    # Step 7.5: Detect Starlink or frequent reboot scenarios (only if no static IP configured)
    if [ "$static_ip_method" = "none" ]; then
        print_status "progress" "Step 7.5/9: Detecting Starlink or frequent reboot scenarios..."
        if detect_starlink_or_frequent_reboot_scenario; then
            suggest_advanced_static_ip_setup
        fi
        print_status "pass" "Step 7.5/9: Starlink/frequent reboot detection completed"
    else
        print_status "info" "Step 7.5/9: Starlink detection skipped (Advanced static IP already configured)"
    fi

    # Step 8: Validate configuration
    print_status "progress" "Step 8/9: Validating complete network configuration..."
    if ! validate_network_setup; then
        print_status "fail" "Network configuration validation failed"
        return 1
    fi
    print_status "pass" "Step 8/9: Network configuration validation completed successfully"

    print_status "pass" "Network configuration completed successfully"
    return 0
}

# Function to configure firewall and ports
configure_firewall_and_ports() {
    print_subsection "Configuring Firewall and Ports"

    print_status "progress" "Analyzing network port availability..."
    print_status "info" "Checking for available ports for Nextcloud services"

    # Check if required ports are available
    print_status "progress" "Scanning ports 8080-8090 for availability..."
    local available_ports
    available_ports=$(scan_available_ports 8080 8090)

    local nextcloud_port=$DEFAULT_NEXTCLOUD_PORT
    local nextcloud_ssl_port=$DEFAULT_NEXTCLOUD_SSL_PORT

    print_status "info" "Default Nextcloud port: $DEFAULT_NEXTCLOUD_PORT"
    print_status "info" "Default Nextcloud SSL port: $DEFAULT_NEXTCLOUD_SSL_PORT"

    # Select available port if default is in use
    print_status "progress" "Checking if default port $DEFAULT_NEXTCLOUD_PORT is available..."
    if netstat -tln 2>/dev/null | grep -q ":$DEFAULT_NEXTCLOUD_PORT "; then
        print_status "warn" "Default port $DEFAULT_NEXTCLOUD_PORT is in use"
        print_status "progress" "Searching for alternative available port..."

        # Find first available port
        while IFS= read -r port; do
            if [ "$port" -ge 8080 ] && [ "$port" -le 8090 ]; then
                nextcloud_port=$port
                nextcloud_ssl_port=$((port + 363))  # 8080 -> 8443, 8081 -> 8444, etc.
                print_status "pass" "Found available port: $nextcloud_port"
                break
            fi
        done <<< "$available_ports"

        print_status "info" "Using alternative port: $nextcloud_port (SSL: $nextcloud_ssl_port)"
    else
        print_status "pass" "Default port $DEFAULT_NEXTCLOUD_PORT is available"
    fi

    # Save port configuration
    print_status "progress" "Saving port configuration..."
    save_config "NEXTCLOUD_HTTP_PORT" "$nextcloud_port"
    save_config "NEXTCLOUD_HTTPS_PORT" "$nextcloud_ssl_port"
    print_status "pass" "Port configuration saved"

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

    # Get preferred network configuration (handles MOBILE_URL priority)
    local preferred_config
    if preferred_config=$(get_preferred_network_config); then
        local preferred_ip=$(echo "$preferred_config" | cut -d'|' -f1)
        local preferred_port=$(echo "$preferred_config" | cut -d'|' -f2)
        local preferred_url=$(echo "$preferred_config" | cut -d'|' -f3)
        local config_source=$(echo "$preferred_config" | cut -d'|' -f4)

        print_status "pass" "Using preferred configuration: $preferred_url (source: $config_source)"
    else
        print_status "warn" "Could not determine preferred configuration, using defaults"
        local preferred_ip="127.0.0.1"
        local preferred_port=$(load_config "NEXTCLOUD_HTTP_PORT" "$DEFAULT_NEXTCLOUD_PORT")
        local preferred_url="http://localhost:$preferred_port"
        local config_source="fallback"
    fi

    local access_ips=$(load_config "DETECTED_ACCESS_IPS")
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "$DEFAULT_NEXTCLOUD_PORT")
    local nextcloud_ssl_port=$(load_config "NEXTCLOUD_HTTPS_PORT" "$DEFAULT_NEXTCLOUD_SSL_PORT")

    # Generate trusted domains list
    local trusted_domains=()
    local access_urls=()

    # Add preferred/MOBILE_URL configuration first (highest priority)
    if [ "$preferred_ip" != "127.0.0.1" ]; then
        trusted_domains+=("$preferred_ip")
        trusted_domains+=("$preferred_ip:$preferred_port")
        access_urls+=("$preferred_url|Primary family access")

        # Also add HTTPS variant if different port
        if [ "$preferred_port" != "$nextcloud_ssl_port" ]; then
            trusted_domains+=("$preferred_ip:$nextcloud_ssl_port")
            local https_url="${preferred_url/http:/https:}"
            https_url="${https_url/:$preferred_port/:$nextcloud_ssl_port}"
            access_urls+=("$https_url|Primary family access (SSL)")
        fi
    fi

    # Add localhost entries (always include for local access)
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

# Function to check IP persistence and provide guidance
check_ip_persistence_and_guide() {
    print_subsection "IP Persistence Check for Family Network"

    # Use custom parameters if provided
    local custom_ip=$(load_config "CUSTOM_IP")
    local custom_interface=$(load_config "CUSTOM_INTERFACE")

    local primary_interface=${custom_interface:-$(detect_primary_interface)}
    local current_ip=${custom_ip:-$(get_interface_ip "$primary_interface")}
    local assignment_type=$(detect_ip_assignment_type "$primary_interface" "$current_ip")

    if [ -z "$primary_interface" ] || [ -z "$current_ip" ]; then
        print_status "error" "Could not determine network configuration"
        return 1
    fi

    print_status "info" "Network Interface: $primary_interface $([ -n "$custom_interface" ] && echo "(custom)")"
    print_status "info" "Current IP: $current_ip $([ -n "$custom_ip" ] && echo "(custom)")"
    print_status "info" "Assignment Type: $assignment_type"

    # Save current IP for configuration
    save_config "PRIMARY_IP" "$current_ip"
    save_config "PRIMARY_INTERFACE" "$primary_interface"
    save_config "IP_ASSIGNMENT_TYPE" "$assignment_type"

    # Update PRIMARY_DOMAIN if not already set
    # If HOST_IP was configured, use that as PRIMARY_DOMAIN
    local configured_host_ip=$(load_config "HOST_IP")
    local current_primary_domain=$(load_config "PRIMARY_DOMAIN")

    if [ -n "$configured_host_ip" ]; then
        # HOST_IP is set, use it as PRIMARY_DOMAIN with port
        local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
        save_config "HOST_IP" "$configured_host_ip"
        save_config "PRIMARY_IP" "$configured_host_ip"
        save_config "PRIMARY_DOMAIN" "$configured_host_ip:$port"
        save_config "PROTOCOL" "http"
        print_status "pass" "Set PRIMARY_DOMAIN to HOST_IP: $configured_host_ip:$port"
    elif [ -z "$current_primary_domain" ]; then
        # No HOST_IP and no PRIMARY_DOMAIN, use current IP
        save_config "PRIMARY_DOMAIN" "$current_ip"
        save_config "PROTOCOL" "http"
        print_status "pass" "Set PRIMARY_DOMAIN to: $current_ip"
    fi

    if [ "$assignment_type" = "static" ] || [ -n "$configured_host_ip" ]; then
        print_status "pass" "IP is statically configured - family access will be consistent"
        local display_ip="${configured_host_ip:-$current_ip}"
        print_status "info" "Family access URL: http://$display_ip:$(load_config "NEXTCLOUD_HTTP_PORT" "8080")"
        return 0
    fi

    print_status "warn" "IP is DHCP-assigned - may change after reboot"
    print_status "info" "This could disrupt family access to Nextcloud"

    echo ""
    if ask_yes_no "Would you like guidance on making your IP persistent for consistent family access?"; then
        provide_static_ip_instructions "$primary_interface" "$current_ip"
    else
        print_status "info" "You can run this guidance later with: $0 --ip-setup"
        create_ip_setup_shortcut
    fi

    return 0
}

# Function to create IP setup shortcut
create_ip_setup_shortcut() {
    local shortcut_script="$KEKELI_CONFIG_DIR/setup-static-ip.sh"

    cat > "$shortcut_script" << 'EOF'
#!/bin/bash
# Quick access to IP persistence setup guidance

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Source utilities if available
if [ -f "$PROJECT_DIR/scripts/utils/common.sh" ]; then
    source "$PROJECT_DIR/scripts/utils/common.sh"
    source "$PROJECT_DIR/scripts/utils/network-detection.sh"

    provide_static_ip_instructions
else
    echo "Please run this from the main network setup script"
    echo "Use: ./scripts/setup-networking.sh --ip-setup"
fi
EOF

    chmod +x "$shortcut_script"
    print_status "pass" "IP setup shortcut created: $shortcut_script"
}

# Function to validate and provide guidance for MOBILE_URL configuration
validate_mobile_url_configuration() {
    print_subsection "MOBILE_URL Configuration Validation"

    local mobile_url=$(load_config "MOBILE_URL")

    if [ -n "$mobile_url" ]; then
        print_status "info" "MOBILE_URL configured: $mobile_url"

        # Parse and validate the URL
        local mobile_url_info
        if mobile_url_info=$(parse_mobile_url); then
            local mobile_ip=$(echo "$mobile_url_info" | cut -d'|' -f1)
            local mobile_port=$(echo "$mobile_url_info" | cut -d'|' -f2)

            print_status "pass" "MOBILE_URL format is valid"
            print_status "info" "Extracted - IP: $mobile_ip, Port: $mobile_port"

            # Test if the IP is accessible from this system
            if ping -c 1 -W 2 "$mobile_ip" >/dev/null 2>&1; then
                print_status "pass" "IP address $mobile_ip is reachable"
            else
                print_status "warn" "IP address $mobile_ip is not reachable from this system"
                print_status "info" "This might be normal if it's your external IP or DHCP reservation"
            fi

            # Check if it matches any detected network interfaces
            local current_ips=$(ip addr show | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | grep -v '127.0.0.1')
            if echo "$current_ips" | grep -q "^$mobile_ip$"; then
                print_status "pass" "MOBILE_URL IP matches a current network interface"
            else
                print_status "warn" "MOBILE_URL IP doesn't match current network interfaces"
                print_status "info" "Current IPs: $(echo "$current_ips" | tr '\n' ', ' | sed 's/,$//')"
                print_status "info" "This is OK if you're using a static IP or DHCP reservation"
            fi

            # Provide setup recommendations
            echo ""
            print_status "info" "📱 Family Setup Recommendations:"
            echo -e "  ${GREEN}✓${NC} Family bookmark URL: ${CYAN}$mobile_url${NC}"
            echo -e "  ${GREEN}✓${NC} Mobile app server: ${CYAN}$mobile_url${NC}"
            if [[ ! "$mobile_url" =~ ^https:// ]]; then
                echo -e "  ${YELLOW}⚠${NC} Consider HTTPS for enhanced security (advanced setup)"
            fi

        else
            print_status "fail" "MOBILE_URL format is invalid: $mobile_url"
            print_status "info" "Expected format: http://IP_ADDRESS:PORT"
            print_status "info" "Examples:"
            echo -e "  ${CYAN}MOBILE_URL=http://192.168.1.100:8080${NC}"
            echo -e "  ${CYAN}MOBILE_URL=http://10.0.1.50:8080${NC}"
            return 1
        fi
    else
        print_status "info" "No MOBILE_URL configured - using auto-detection"
        print_status "info" "Consider setting MOBILE_URL for consistent family access"

        # Show what would be auto-detected
        local preferred_config
        if preferred_config=$(get_preferred_network_config); then
            local preferred_url=$(echo "$preferred_config" | cut -d'|' -f3)
            print_status "info" "Auto-detected URL would be: $preferred_url"
            echo ""
            print_status "info" "💡 To set a permanent family URL:"
            echo -e "  ${CYAN}1.${NC} Set up static IP or DHCP reservation on your router"
            echo -e "  ${CYAN}2.${NC} Add to .env file: ${GREEN}MOBILE_URL=$preferred_url${NC}"
            echo -e "  ${CYAN}3.${NC} Test access from family devices"
        fi
    fi

    return 0
}

# Function to setup mobile network access
setup_mobile_network_access() {
    print_subsection "Setting Up Mobile Access"

    # Check if advanced static IP is configured
    local static_ip_method=$(load_config "STATIC_IP_METHOD" "none")

    # If advanced static IP is configured, use those URLs instead
    if [ "$static_ip_method" != "none" ]; then
        print_status "info" "Advanced static IP configured ($static_ip_method)"
        print_status "info" "Using static IP method for mobile access"

        local mobile_urls=()
        local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")

        case $static_ip_method in
            macvlan)
                local container_ip=$(load_config "MACVLAN_CONTAINER_IP")
                mobile_urls+=("http://${container_ip}:${port}")
                ;;
            avahi)
                local hostname=$(load_config "AVAHI_HOSTNAME" "nextcloud")
                mobile_urls+=("http://${hostname}.local:${port}")
                ;;
            duckdns)
                local subdomain=$(load_config "DUCKDNS_SUBDOMAIN")
                mobile_urls+=("http://${subdomain}.duckdns.org:${port}")
                ;;
            combo)
                local container_ip=$(load_config "MACVLAN_CONTAINER_IP")
                local hostname=$(load_config "AVAHI_HOSTNAME" "nextcloud")
                mobile_urls+=("http://${container_ip}:${port}")
                mobile_urls+=("http://${hostname}.local:${port}")
                ;;
        esac

        # Save mobile configuration
        save_config "MOBILE_ACCESS_URLS" "$(printf '%s\n' "${mobile_urls[@]}")"

        print_status "pass" "Mobile access configured with static IP method"

        # Display mobile access information
        echo ""
        echo -e "${CYAN}📱 Mobile Access URLs (Persistent - Won't Change):${NC}"
        for url in "${mobile_urls[@]}"; do
            echo -e "  ${GREEN}✓ $url${NC}"
        done
        echo ""

        return 0
    fi

    # Original logic for when no advanced static IP is configured
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
    echo ""
    echo -e "${YELLOW}⚠️  Note: These URLs use DHCP and may change after reboot${NC}"
    echo -e "${CYAN}💡 Tip: Run Phase 7 (Advanced Static IP) for persistent URLs${NC}"

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
# STARLINK AND FREQUENT REBOOT DETECTION
# =============================================================================

# Function to detect Starlink or frequent reboot scenario
detect_starlink_or_frequent_reboot_scenario() {
    local primary_ip=$(get_primary_ip)
    local primary_interface=$(detect_primary_interface)
    local detected=false
    local reasons=()

    # Check for CGNAT ranges (common with Starlink, mobile carriers)
    if [[ "$primary_ip" =~ ^100\.(6[4-9]|[7-9][0-9]|1[0-2][0-7])\. ]]; then
        detected=true
        reasons+=("CGNAT IP range detected (${primary_ip})")
        print_status "warn" "CGNAT detected: $primary_ip"
        print_status "info" "Common with Starlink, mobile hotspots, or carrier-grade NAT"
    fi

    # Check for Starlink interface naming patterns
    if [[ "$primary_interface" =~ ^enx[0-9a-f]{12}$ ]]; then
        detected=true
        reasons+=("Starlink network adapter detected (${primary_interface})")
        print_status "warn" "Starlink adapter detected: $primary_interface"
    fi

    # Check for specific Starlink subnet patterns
    if [[ "$primary_ip" =~ ^10\.23[0-9]\. ]]; then
        detected=true
        reasons+=("Starlink subnet pattern detected")
        print_status "warn" "Starlink subnet detected"
    fi

    # Check if DHCP-assigned (potential for IP changes)
    local assignment_type=$(detect_ip_assignment_type "$primary_interface" "$primary_ip")
    if [ "$assignment_type" = "dhcp" ]; then
        reasons+=("DHCP-assigned IP (may change after reboots)")
        print_status "info" "DHCP detected - IP may change after reboots"
    fi

    if [ "$detected" = true ]; then
        echo ""
        print_status "info" "⚠️  Detected scenario requiring advanced static IP setup:"
        for reason in "${reasons[@]}"; do
            echo -e "   ${YELLOW}•${NC} $reason"
        done
        return 0
    fi

    return 1
}

# Function to suggest advanced static IP setup
suggest_advanced_static_ip_setup() {
    echo ""
    print_subsection "💡 Advanced Static IP Recommendation"

    echo -e "${CYAN}Your network environment would benefit from advanced static IP setup!${NC}"
    echo ""

    echo -e "${YELLOW}Why this matters:${NC}"
    echo -e "  • Your IP address may change frequently (reboots, reconnections)"
    echo -e "  • Family members need a consistent URL to access Nextcloud"
    echo -e "  • Current setup may break mobile access after IP changes"
    echo ""

    echo -e "${GREEN}Recommended solution: Macvlan + Avahi Combo${NC}"
    echo -e "  ✓ Container gets its own static IP (never changes)"
    echo -e "  ✓ Easy hostname access (nextcloud.local)"
    echo -e "  ✓ Survives any number of reboots"
    echo -e "  ✓ No router configuration needed"
    echo -e "  ✓ Setup time: ~30 minutes"
    echo ""

    echo -e "${CYAN}Alternative solutions:${NC}"
    echo -e "  • ${YELLOW}DuckDNS:${NC} Free domain name for internet access"
    echo -e "  • ${YELLOW}Avahi only:${NC} Simple hostname access"
    echo -e "  • ${YELLOW}Macvlan only:${NC} Just the static IP"
    echo ""

    if ask_yes_no "Would you like to set up advanced static IP now?"; then
        echo ""
        print_status "info" "You can run Phase 7: Advanced Static IP from the main menu"
        print_status "info" "Or run directly: $SCRIPT_DIR/setup-static-ip.sh"
        echo ""

        # Save suggestion flag
        save_config "STATIC_IP_SUGGESTED" "true"
        save_config "STATIC_IP_SUGGESTION_REASON" "starlink_or_frequent_reboot"
    else
        print_status "info" "You can run Phase 7 later if you experience IP-related issues"
        save_config "STATIC_IP_SUGGESTED" "false"
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
    echo "  --ip-setup        Get guidance for setting up persistent IP"
    echo "  --check-ip        Check for IP address changes and offer to update configuration"
    echo "  --update-ip       Automatically update configuration if IP has changed"
    echo "  --ip=IP           Specify custom IP address to use"
    echo "  --interface=NAME  Specify network interface to use"
    echo "  --port=PORT       Specify custom HTTP port (default: 8080)"
    echo ""
    echo "Examples:"
    echo "  $0 --setup                    # Run complete network configuration"
    echo "  $0 --test                     # Test current network setup"
    echo "  $0 --status                   # Show network status"
    echo "  $0 --setup --ip=192.168.1.100 # Use specific IP address"
    echo "  $0 --setup --interface=eth0   # Use specific network interface"
    echo "  $0 --setup --port=9000        # Use custom port"
}

# Main function
main() {
    # Immediate feedback to user
    print_status "progress" "Starting network configuration..."

    local setup_mode=false
    local test_mode=false
    local validate_mode=false
    local status_mode=false
    local generate_env_mode=false
    local ip_setup_mode=false
    local check_ip_mode=false
    local update_ip_mode=false
    local custom_ip=""
    local custom_interface=""
    local custom_port=""

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
            --ip-setup)
                ip_setup_mode=true
                shift
                ;;
            --check-ip)
                check_ip_mode=true
                shift
                ;;
            --update-ip)
                update_ip_mode=true
                shift
                ;;
            --ip=*)
                custom_ip="${1#*=}"
                shift
                ;;
            --interface=*)
                custom_interface="${1#*=}"
                shift
                ;;
            --port=*)
                custom_port="${1#*=}"
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

    if [ "$ip_setup_mode" = true ]; then
        local primary_interface=$(detect_primary_interface)
        local current_ip=$(get_interface_ip "$primary_interface")
        if provide_static_ip_instructions "$primary_interface" "$current_ip"; then
            exit 0
        else
            exit 1
        fi
    fi

    if [ "$check_ip_mode" = true ]; then
        if handle_ip_change false; then
            print_status "pass" "IP change detection completed"
            exit 0
        else
            print_status "warn" "IP change detection completed with issues"
            exit 1
        fi
    fi

    if [ "$update_ip_mode" = true ]; then
        if handle_ip_change true; then
            print_status "pass" "IP configuration updated successfully"
            exit 0
        else
            print_status "fail" "IP configuration update failed"
            exit 1
        fi
    fi

    # Default: Run setup
    if [ "$setup_mode" = true ] || [ $# -eq 0 ]; then
        print_status "info" "Running network configuration setup mode"
        print_status "progress" "Initializing network configuration process..."

        # Validate and apply custom parameters if provided
        if [ -n "$custom_ip" ]; then
            if validate_ip "$custom_ip"; then
                save_config "CUSTOM_IP" "$custom_ip"
                print_status "pass" "Using custom IP: $custom_ip"
            else
                print_status "fail" "Invalid IP address format: $custom_ip"
                print_status "info" "IP address should be in format: 192.168.1.100"
                exit 1
            fi
        fi

        if [ -n "$custom_interface" ]; then
            if validate_interface "$custom_interface"; then
                save_config "CUSTOM_INTERFACE" "$custom_interface"
                print_status "pass" "Using custom interface: $custom_interface"
            else
                print_status "fail" "Network interface not found: $custom_interface"
                print_status "info" "Available interfaces:"
                ip link show | grep -E '^[0-9]+:' | awk -F': ' '{print "  " $2}' | grep -v lo
                exit 1
            fi
        fi

        if [ -n "$custom_port" ]; then
            if [[ "$custom_port" =~ ^[0-9]+$ ]] && [ "$custom_port" -ge 1 ] && [ "$custom_port" -le 65535 ]; then
                save_config "NEXTCLOUD_HTTP_PORT" "$custom_port"
                print_status "pass" "Using custom port: $custom_port"
            else
                print_status "fail" "Invalid port number: $custom_port"
                print_status "info" "Port should be between 1 and 65535"
                exit 1
            fi
        fi

        if setup_network_configuration; then
            echo ""
            print_status "progress" "Generating network configuration summary..."
            show_network_status
            echo ""
            print_status "pass" "Network configuration completed successfully!"
            print_status "info" "Network ready for Nextcloud deployment"
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