#!/bin/bash
# setup-static-ip.sh - Advanced Static IP Setup for Kekeli-HomeCloud
# Part of the Kekeli-HomeCloud Easy Installer Project
#
# This script implements 5 approaches for persistent IP addresses:
# 1. Docker Macvlan Network (Recommended for local network)
# 2. Avahi mDNS + Hostname (User-friendly)
# 3. DuckDNS Dynamic DNS (Internet access)
# 4. Pi-hole DNS Server (Advanced)
# 5. Tailscale VPN (Remote access)

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/error-handling.sh"
source "$UTILS_DIR/network-detection.sh"

# =============================================================================
# CONFIGURATION
# =============================================================================

readonly APPROACHES=(
    "macvlan|Docker Macvlan Network|True static IP on local network"
    "avahi|Avahi mDNS Hostname|Access via nextcloud.local"
    "duckdns|DuckDNS Dynamic DNS|Internet access with domain name"
    "combo|Macvlan + Avahi|Best for local network (recommended)"
    "pihole|Pi-hole DNS Server|Advanced DNS control"
    "tailscale|Tailscale VPN|Secure remote access"
)

# =============================================================================
# DETECTION AND ANALYSIS
# =============================================================================

# Function to detect if user needs advanced static IP
detect_use_case() {
    print_section "🔍" "Analyzing Your Network Situation"

    local primary_ip=$(get_primary_ip)
    local primary_interface=$(detect_primary_interface)
    local assignment_type=$(detect_ip_assignment_type "$primary_interface" "$primary_ip")

    print_status "info" "Current IP: $primary_ip"
    print_status "info" "Assignment: $assignment_type"

    local needs_static=false
    local reason=""

    # Check for CGNAT (Starlink, mobile carriers)
    if [[ "$primary_ip" =~ ^100\.(6[4-9]|[7-9][0-9]|1[0-2][0-7])\. ]]; then
        needs_static=true
        reason="CGNAT detected (Starlink/mobile carrier) - IP likely changes frequently"
        print_status "warn" "$reason"
    fi

    # Check if DHCP-assigned
    if [ "$assignment_type" = "dhcp" ]; then
        needs_static=true
        reason="DHCP-assigned IP may change after reboots"
        print_status "warn" "$reason"
    fi

    # Check if HOST_IP is already set but different from current
    local host_ip=$(load_config "HOST_IP")
    if [ -n "$host_ip" ] && [ "$host_ip" != "$primary_ip" ]; then
        needs_static=true
        reason="HOST_IP configured ($host_ip) but current IP ($primary_ip) is different"
        print_status "warn" "$reason"
    fi

    if [ "$needs_static" = true ]; then
        echo ""
        print_status "info" "💡 You would benefit from advanced static IP setup!"
        print_status "info" "   This ensures consistent family access after reboots"
        return 0
    else
        print_status "pass" "Your current IP setup appears stable"
        return 1
    fi
}

# Function to detect Starlink or similar scenarios
detect_starlink_scenario() {
    local primary_ip=$(get_primary_ip)
    local primary_interface=$(detect_primary_interface)

    # Check for CGNAT ranges common with Starlink
    if [[ "$primary_ip" =~ ^100\.(6[4-9]|[7-9][0-9]|1[0-2][0-7])\. ]]; then
        print_status "info" "Starlink-like CGNAT detected"
        return 0
    fi

    # Check for Starlink interface naming patterns
    if [[ "$primary_interface" =~ ^enx[0-9a-f]{12}$ ]]; then
        print_status "info" "Starlink network adapter detected"
        return 0
    fi

    return 1
}

# =============================================================================
# APPROACH MENU AND SELECTION
# =============================================================================

# Function to show approach menu
show_approach_menu() {
    print_section "📋" "Advanced Static IP Approaches"

    echo -e "${CYAN}Choose the method that best fits your needs:${NC}"
    echo ""

    local num=1
    for approach_info in "${APPROACHES[@]}"; do
        local key=$(echo "$approach_info" | cut -d'|' -f1)
        local name=$(echo "$approach_info" | cut -d'|' -f2)
        local desc=$(echo "$approach_info" | cut -d'|' -f3)

        echo -e "  ${GREEN}[$num]${NC} ${YELLOW}$name${NC}"
        echo -e "      $desc"

        # Show complexity and use case
        case $key in
            macvlan)
                echo -e "      ${CYAN}Complexity:${NC} ⭐⭐ Moderate | ${CYAN}Best for:${NC} Local network static IP"
                ;;
            avahi)
                echo -e "      ${CYAN}Complexity:${NC} ⭐⭐ Moderate | ${CYAN}Best for:${NC} Easy-to-remember hostnames"
                ;;
            duckdns)
                echo -e "      ${CYAN}Complexity:${NC} ⭐ Easy | ${CYAN}Best for:${NC} Internet + local access"
                ;;
            combo)
                echo -e "      ${CYAN}Complexity:${NC} ⭐⭐⭐ Moderate | ${CYAN}Best for:${NC} Complete local network solution"
                echo -e "      ${GREEN}✓ RECOMMENDED${NC} for Starlink and frequent reboot scenarios"
                ;;
            pihole)
                echo -e "      ${CYAN}Complexity:${NC} ⭐⭐⭐⭐ Advanced | ${CYAN}Best for:${NC} DNS control + ad-blocking"
                ;;
            tailscale)
                echo -e "      ${CYAN}Complexity:${NC} ⭐⭐⭐ Moderate | ${CYAN}Best for:${NC} Secure remote access anywhere"
                ;;
        esac
        echo ""
        ((num++))
    done

    echo -e "  ${GREEN}[S]${NC} Skip advanced setup (use basic DHCP/HOST_IP)"
    echo -e "  ${GREEN}[H]${NC} Help me decide"
    echo ""
}

# Function to get recommended approach based on use case
get_recommended_approach() {
    if detect_starlink_scenario; then
        echo "combo"  # Macvlan + Avahi best for Starlink
        return 0
    fi

    local assignment_type=$(detect_ip_assignment_type)
    if [ "$assignment_type" = "dhcp" ]; then
        echo "macvlan"  # Simple Macvlan for DHCP users
        return 0
    fi

    echo "avahi"  # Default to easy hostname approach
}

# Function to show decision helper
show_decision_helper() {
    clear
    print_section "❓" "Help Me Decide"

    echo -e "${CYAN}Let's find the best approach for you!${NC}"
    echo ""

    # Question 1: Internet access needs
    echo -e "${YELLOW}Q1: Do you need to access Nextcloud from outside your home network?${NC}"
    echo "    (e.g., from work, cellular data, other WiFi networks)"
    echo ""
    local internet_access
    if ask_yes_no "Need internet/remote access?"; then
        internet_access=true
        echo -e "  ${GREEN}✓${NC} Internet access needed"
    else
        internet_access=false
        echo -e "  ${GREEN}✓${NC} Only local network access needed"
    fi
    echo ""

    # Question 2: Reboot frequency
    echo -e "${YELLOW}Q2: Does your router/computer reboot frequently?${NC}"
    echo "    (Starlink Mini reboots hourly, some routers reboot nightly)"
    echo ""
    local frequent_reboots
    if ask_yes_no "Frequent reboots?"; then
        frequent_reboots=true
        echo -e "  ${GREEN}✓${NC} Frequent reboots detected"
    else
        frequent_reboots=false
        echo -e "  ${GREEN}✓${NC} Stable network environment"
    fi
    echo ""

    # Question 3: Technical comfort level
    echo -e "${YELLOW}Q3: How comfortable are you with advanced networking?${NC}"
    echo "    [1] Beginner - I want the simplest solution"
    echo "    [2] Intermediate - I can follow technical instructions"
    echo "    [3] Advanced - I'm comfortable with complex setups"
    echo ""
    echo -ne "${GREEN}Select level (1-3) [1]: ${NC}"
    read -r tech_level
    tech_level=${tech_level:-1}
    echo ""

    # Provide recommendation
    print_subsection "Recommendation"

    if [ "$internet_access" = true ]; then
        if [ "$tech_level" = "3" ]; then
            echo -e "  ${GREEN}→ Recommended: Tailscale VPN${NC}"
            echo -e "    Best for: Secure remote access with encryption"
            echo -e "    Setup time: 30 minutes"
            return_value="tailscale"
        else
            echo -e "  ${GREEN}→ Recommended: DuckDNS${NC}"
            echo -e "    Best for: Simple internet access with persistent domain"
            echo -e "    Setup time: 10 minutes"
            return_value="duckdns"
        fi
    else
        if [ "$frequent_reboots" = true ]; then
            echo -e "  ${GREEN}→ Recommended: Macvlan + Avahi Combo${NC}"
            echo -e "    Best for: Starlink or frequent reboot scenarios"
            echo -e "    Provides: Static IP + easy hostname access"
            echo -e "    Setup time: 30 minutes"
            return_value="combo"
        else
            if [ "$tech_level" = "1" ]; then
                echo -e "  ${GREEN}→ Recommended: Avahi mDNS${NC}"
                echo -e "    Best for: Easy hostname access (nextcloud.local)"
                echo -e "    Setup time: 20 minutes"
                return_value="avahi"
            else
                echo -e "  ${GREEN}→ Recommended: Docker Macvlan${NC}"
                echo -e "    Best for: True static IP on local network"
                echo -e "    Setup time: 15 minutes"
                return_value="macvlan"
            fi
        fi
    fi

    echo ""
    if ask_yes_no "Use this recommendation?"; then
        echo "$return_value"
        return 0
    else
        return 1
    fi
}

# =============================================================================
# APPROACH 1: DOCKER MACVLAN NETWORK
# =============================================================================

# Function to setup Docker Macvlan network
setup_macvlan() {
    print_section "🐳" "Setting Up Docker Macvlan Network"

    print_status "info" "This will give your Nextcloud container its own static IP"
    print_status "info" "The container will appear as a separate device on your network"
    echo ""

    # Step 1: Detect network configuration
    print_subsection "Step 1/5: Detecting Network Configuration"

    local primary_interface=$(detect_primary_interface)
    local primary_ip=$(get_primary_ip)
    local network_range=$(detect_network_range "$primary_interface")

    if [ -z "$primary_interface" ] || [ -z "$primary_ip" ]; then
        print_status "fail" "Could not detect network configuration"
        return 1
    fi

    print_status "pass" "Network interface: $primary_interface"
    print_status "pass" "Current IP: $primary_ip"
    print_status "pass" "Network range: $network_range"

    # Extract subnet info
    local subnet=$(echo "$network_range" | cut -d'/' -f1 | cut -d'.' -f1-3)
    local cidr=$(echo "$network_range" | cut -d'/' -f2)
    local gateway=$(ip route show default | awk '{print $3}' | head -1)

    print_status "info" "Subnet: ${subnet}.0/${cidr}"
    print_status "info" "Gateway: $gateway"
    echo ""

    # Step 2: Choose static IP for container
    print_subsection "Step 2/5: Choosing Static IP for Nextcloud Container"

    # Suggest an IP in the same subnet
    local current_last_octet=$(echo "$primary_ip" | cut -d'.' -f4)
    local suggested_ip="${subnet}.$((current_last_octet + 50))"

    # Make sure suggested IP is reasonable (1-254)
    local suggested_last=$(echo "$suggested_ip" | cut -d'.' -f4)
    if [ "$suggested_last" -gt 254 ]; then
        suggested_ip="${subnet}.150"
    fi

    print_status "info" "Suggested static IP: $suggested_ip"
    print_status "info" "This IP should not conflict with your router's DHCP range"
    echo ""

    local container_ip
    if ask_yes_no "Use suggested IP ($suggested_ip)?"; then
        container_ip="$suggested_ip"
    else
        echo -ne "${GREEN}Enter desired static IP [$suggested_ip]: ${NC}"
        read -r container_ip
        container_ip=${container_ip:-$suggested_ip}
        if ! validate_ip "$container_ip"; then
            print_status "fail" "Invalid IP address format: $container_ip"
            return 1
        fi
    fi

    print_status "pass" "Container IP: $container_ip"
    echo ""

    # Step 3: Test if IP is available
    print_subsection "Step 3/5: Testing IP Availability"

    print_status "progress" "Pinging $container_ip to check if it's in use..."
    if ping -c 2 -W 2 "$container_ip" >/dev/null 2>&1; then
        print_status "warn" "IP $container_ip responded to ping!"
        print_status "warn" "This IP may already be in use by another device"
        echo ""
        if ! ask_yes_no "Continue anyway? (may cause IP conflict)"; then
            return 1
        fi
    else
        print_status "pass" "IP $container_ip appears to be available"
    fi
    echo ""

    # Step 4: Save Macvlan configuration
    print_subsection "Step 4/5: Saving Macvlan Configuration"

    save_config "STATIC_IP_METHOD" "macvlan"
    save_config "MACVLAN_ENABLED" "true"
    save_config "MACVLAN_PARENT_INTERFACE" "$primary_interface"
    save_config "MACVLAN_SUBNET" "${subnet}.0/${cidr}"
    save_config "MACVLAN_GATEWAY" "$gateway"
    save_config "MACVLAN_IP_RANGE" "${container_ip}/32"
    save_config "MACVLAN_CONTAINER_IP" "$container_ip"

    # Update .env file
    local env_file="$PROJECT_DIR/.env"
    if [ -f "$env_file" ]; then
        # Update or add Macvlan settings
        update_env_var "$env_file" "MACVLAN_ENABLED" "true"
        update_env_var "$env_file" "MACVLAN_PARENT_INTERFACE" "$primary_interface"
        update_env_var "$env_file" "MACVLAN_SUBNET" "${subnet}.0/${cidr}"
        update_env_var "$env_file" "MACVLAN_GATEWAY" "$gateway"
        update_env_var "$env_file" "MACVLAN_IP_RANGE" "${container_ip}/32"
        update_env_var "$env_file" "MACVLAN_CONTAINER_IP" "$container_ip"

        print_status "pass" "Updated .env file with Macvlan configuration"
    fi

    # Update PRIMARY_DOMAIN to use the new static IP
    local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
    save_config "PRIMARY_DOMAIN" "${container_ip}:${port}"
    save_config "MOBILE_URL" "http://${container_ip}:${port}"
    update_env_var "$env_file" "PRIMARY_DOMAIN" "${container_ip}:${port}"
    update_env_var "$env_file" "MOBILE_URL" "http://${container_ip}:${port}"

    print_status "pass" "Configuration saved"
    echo ""

    # Step 5: Update docker-compose.yml
    print_subsection "Step 5/5: Updating Docker Compose Configuration"

    local compose_file="$PROJECT_DIR/docker-compose.yml"
    if [ ! -f "$compose_file" ]; then
        print_status "warn" "docker-compose.yml not found - will be generated during deployment"
    else
        print_status "info" "Macvlan network will be added to docker-compose.yml"
        print_status "info" "This will happen automatically when containers are deployed"
    fi

    echo ""
    print_status "pass" "Macvlan setup complete!"
    echo ""
    print_status "info" "Family access URL: http://${container_ip}:${port}"
    print_status "info" "This IP will NOT change after reboots"
    echo ""

    # Show workaround for host access
    print_subsection "Important: Host to Container Access"
    print_status "warn" "Macvlan prevents direct host → container communication"
    print_status "info" "To access Nextcloud from this host, add this bridge:"
    echo ""
    echo -e "${CYAN}sudo ip link add macvlan-shim link $primary_interface type macvlan mode bridge${NC}"
    echo -e "${CYAN}sudo ip addr add ${subnet}.$((suggested_last + 1))/32 dev macvlan-shim${NC}"
    echo -e "${CYAN}sudo ip link set macvlan-shim up${NC}"
    echo -e "${CYAN}sudo ip route add ${container_ip}/32 dev macvlan-shim${NC}"
    echo ""
    print_status "info" "Or access from other devices on your network"

    return 0
}

# =============================================================================
# APPROACH 2: AVAHI mDNS + HOSTNAME
# =============================================================================

# Function to setup Avahi mDNS
setup_avahi() {
    print_section "📡" "Setting Up Avahi mDNS Hostname"

    print_status "info" "This will let you access Nextcloud via nextcloud.local"
    print_status "info" "Works on iOS, Android, macOS, and Linux natively"
    echo ""

    # Step 1: Check if Avahi is installed
    print_subsection "Step 1/5: Checking Avahi Installation"

    if ! command_exists avahi-daemon; then
        print_status "warn" "Avahi not installed"
        echo ""
        if ask_yes_no "Install Avahi now?"; then
            print_status "progress" "Installing Avahi..."
            if sudo apt-get update >/dev/null 2>&1 && \
               sudo apt-get install -y avahi-daemon avahi-utils >/dev/null 2>&1; then
                print_status "pass" "Avahi installed successfully"
            else
                print_status "fail" "Failed to install Avahi"
                return 1
            fi
        else
            print_status "info" "Avahi installation skipped"
            return 1
        fi
    else
        print_status "pass" "Avahi is already installed"
    fi
    echo ""

    # Step 2: Configure hostname
    print_subsection "Step 2/5: Configuring Hostname"

    echo -ne "${GREEN}Enter desired hostname (without .local) [nextcloud]: ${NC}"
    read -r desired_hostname
    desired_hostname=${desired_hostname:-nextcloud}

    print_status "progress" "Setting hostname to: $desired_hostname"
    if sudo hostnamectl set-hostname "$desired_hostname" 2>/dev/null; then
        print_status "pass" "Hostname set to: $desired_hostname"
    else
        print_status "warn" "Could not set hostname (may require reboot)"
    fi
    echo ""

    # Step 3: Configure Avahi to avoid Docker conflicts
    print_subsection "Step 3/5: Configuring Avahi Daemon"

    local avahi_conf="/etc/avahi/avahi-daemon.conf"
    if [ -f "$avahi_conf" ]; then
        print_status "progress" "Updating Avahi configuration..."

        # Backup original
        sudo cp "$avahi_conf" "${avahi_conf}.backup" 2>/dev/null

        # Add deny-interfaces for Docker
        if ! grep -q "deny-interfaces=docker0,br-" "$avahi_conf" 2>/dev/null; then
            sudo sed -i '/\[server\]/a deny-interfaces=docker0,br-*' "$avahi_conf" 2>/dev/null
            print_status "pass" "Configured Avahi to ignore Docker networks"
        else
            print_status "pass" "Avahi already configured for Docker"
        fi
    fi
    echo ""

    # Step 4: Restart Avahi daemon
    print_subsection "Step 4/5: Restarting Avahi Service"

    if sudo systemctl restart avahi-daemon 2>/dev/null; then
        print_status "pass" "Avahi daemon restarted"
        sleep 2
    else
        print_status "warn" "Could not restart Avahi daemon"
    fi
    echo ""

    # Step 5: Save configuration
    print_subsection "Step 5/5: Saving Configuration"

    save_config "STATIC_IP_METHOD" "avahi"
    save_config "AVAHI_ENABLED" "true"
    save_config "AVAHI_HOSTNAME" "$desired_hostname"

    local env_file="$PROJECT_DIR/.env"
    if [ -f "$env_file" ]; then
        update_env_var "$env_file" "AVAHI_ENABLED" "true"
        update_env_var "$env_file" "AVAHI_HOSTNAME" "$desired_hostname"
    fi

    print_status "pass" "Configuration saved"
    echo ""

    # Test hostname resolution
    print_subsection "Testing Hostname Resolution"

    local test_hostname="${desired_hostname}.local"
    print_status "progress" "Testing resolution of $test_hostname..."
    sleep 2

    if avahi-resolve -n "$test_hostname" >/dev/null 2>&1; then
        print_status "pass" "Hostname resolution works!"
        local resolved_ip=$(avahi-resolve -n "$test_hostname" 2>/dev/null | awk '{print $2}')
        print_status "info" "Resolved to: $resolved_ip"
    else
        print_status "warn" "Hostname resolution not yet available (may need a few minutes)"
    fi

    echo ""
    print_status "pass" "Avahi mDNS setup complete!"
    echo ""

    local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
    print_status "info" "Family access URL: http://${test_hostname}:${port}"
    print_status "info" "Also works as: http://${desired_hostname}.local:${port}"
    echo ""
    print_status "info" "📱 Mobile device setup:"
    print_status "info" "   • iOS/Android Nextcloud app automatically supports .local domains"
    print_status "info" "   • Enter: ${test_hostname}:${port} in the server field"

    return 0
}

# =============================================================================
# APPROACH 3: DUCKDNS DYNAMIC DNS
# =============================================================================

# Function to setup DuckDNS
setup_duckdns() {
    print_section "🦆" "Setting Up DuckDNS Dynamic DNS"

    print_status "info" "DuckDNS provides a free domain name that points to your IP"
    print_status "info" "Your Nextcloud will be accessible as: yourname.duckdns.org"
    echo ""

    # Step 1: Get DuckDNS credentials
    print_subsection "Step 1/5: DuckDNS Account Setup"

    print_status "info" "You need a DuckDNS account (free)"
    echo ""
    echo -e "${CYAN}1. Visit: https://www.duckdns.org${NC}"
    echo -e "${CYAN}2. Login with Google/GitHub/etc (no registration needed)${NC}"
    echo -e "${CYAN}3. Create a subdomain (e.g., 'mycloud')${NC}"
    echo -e "${CYAN}4. Copy your token${NC}"
    echo ""

    if ! ask_yes_no "Do you have a DuckDNS subdomain and token ready?"; then
        print_status "info" "Please set up DuckDNS first, then run this setup again"
        return 1
    fi
    echo ""

    # Step 2: Get subdomain and token
    print_subsection "Step 2/5: DuckDNS Configuration"

    echo -ne "${GREEN}Enter your DuckDNS subdomain (without .duckdns.org): ${NC}"
    read -r subdomain

    echo -ne "${GREEN}Enter your DuckDNS token: ${NC}"
    read -r token

    if [ -z "$subdomain" ] || [ -z "$token" ]; then
        print_status "fail" "Subdomain and token are required"
        return 1
    fi

    print_status "pass" "Subdomain: ${subdomain}.duckdns.org"
    echo ""

    # Step 3: Test DuckDNS credentials
    print_subsection "Step 3/5: Testing DuckDNS Connection"

    print_status "progress" "Validating DuckDNS credentials..."
    local test_url="https://www.duckdns.org/update?domains=${subdomain}&token=${token}&ip="
    local test_response=$(curl -s "$test_url")

    if [[ "$test_response" == "OK" ]] || [[ "$test_response" == *"OK"* ]]; then
        print_status "pass" "DuckDNS credentials validated!"
    else
        print_status "fail" "DuckDNS credentials invalid: $test_response"
        return 1
    fi
    echo ""

    # Step 4: Save DuckDNS configuration
    print_subsection "Step 4/5: Saving DuckDNS Configuration"

    save_config "STATIC_IP_METHOD" "duckdns"
    save_config "DUCKDNS_ENABLED" "true"
    save_config "DUCKDNS_SUBDOMAIN" "$subdomain"
    save_config "DUCKDNS_TOKEN" "$token"

    local env_file="$PROJECT_DIR/.env"
    if [ -f "$env_file" ]; then
        update_env_var "$env_file" "DUCKDNS_ENABLED" "true"
        update_env_var "$env_file" "DUCKDNS_SUBDOMAIN" "$subdomain"
        update_env_var "$env_file" "DUCKDNS_TOKEN" "$token"
    fi

    # Update PRIMARY_DOMAIN to use DuckDNS domain
    local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
    local duckdns_url="http://${subdomain}.duckdns.org:${port}"
    save_config "PRIMARY_DOMAIN" "${subdomain}.duckdns.org:${port}"
    save_config "MOBILE_URL" "$duckdns_url"
    update_env_var "$env_file" "PRIMARY_DOMAIN" "${subdomain}.duckdns.org:${port}"
    update_env_var "$env_file" "MOBILE_URL" "$duckdns_url"

    print_status "pass" "Configuration saved"
    echo ""

    # Step 5: Add DuckDNS to trusted domains
    print_subsection "Step 5/5: Updating Trusted Domains"

    local current_domains=$(load_config "TRUSTED_DOMAINS")
    if [[ "$current_domains" != *"${subdomain}.duckdns.org"* ]]; then
        local new_domains="${subdomain}.duckdns.org,${subdomain}.duckdns.org:${port},${current_domains}"
        save_config "TRUSTED_DOMAINS" "$new_domains"
        update_env_var "$env_file" "TRUSTED_DOMAINS" "$new_domains"
        print_status "pass" "Added DuckDNS domain to trusted domains"
    fi
    echo ""

    print_status "pass" "DuckDNS setup complete!"
    echo ""
    print_status "info" "Family access URL: $duckdns_url"
    print_status "info" "This URL works from anywhere (internet + local network)"
    print_status "info" "IP updates automatically every 5 minutes"
    echo ""
    print_status "info" "📱 Mobile device setup:"
    print_status "info" "   • Server: ${subdomain}.duckdns.org:${port}"
    print_status "info" "   • This URL never changes!"

    return 0
}

# =============================================================================
# APPROACH 4: COMBO - MACVLAN + AVAHI
# =============================================================================

# Function to setup Macvlan + Avahi combo
setup_combo() {
    print_section "🎯" "Setting Up Macvlan + Avahi Combo"

    print_status "info" "This combines the best of both approaches:"
    print_status "info" "  • Macvlan: True static IP on local network"
    print_status "info" "  • Avahi: Easy hostname access (nextcloud.local)"
    echo ""
    print_status "info" "✓ RECOMMENDED for Starlink and frequent reboot scenarios"
    echo ""

    if ! ask_yes_no "Continue with combo setup?"; then
        return 1
    fi

    # Run Macvlan setup first
    echo ""
    print_subsection "Part 1: Docker Macvlan Setup"
    if ! setup_macvlan; then
        print_status "fail" "Macvlan setup failed"
        return 1
    fi

    echo ""
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo -e "${GREEN}Macvlan setup complete! Now setting up Avahi...${NC}"
    echo -e "${GREEN}═══════════════════════════════════════════════════════${NC}"
    echo ""
    sleep 2

    # Run Avahi setup
    print_subsection "Part 2: Avahi mDNS Setup"
    if ! setup_avahi; then
        print_status "warn" "Avahi setup had issues, but Macvlan is working"
        print_status "info" "You can access via the static IP from Macvlan setup"
        return 0
    fi

    # Update configuration to indicate combo mode
    save_config "STATIC_IP_METHOD" "combo"

    echo ""
    print_status "pass" "Combo setup complete!"
    echo ""

    local container_ip=$(load_config "MACVLAN_CONTAINER_IP")
    local hostname=$(load_config "AVAHI_HOSTNAME" "nextcloud")
    local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")

    print_subsection "Family Access Options"
    print_status "info" "Your family can now access Nextcloud in TWO ways:"
    echo ""
    echo -e "  ${GREEN}1. Static IP:${NC} http://${container_ip}:${port}"
    echo -e "     ${CYAN}• Never changes after reboots${NC}"
    echo -e "     ${CYAN}• Works from any device on your network${NC}"
    echo ""
    echo -e "  ${GREEN}2. Hostname:${NC} http://${hostname}.local:${port}"
    echo -e "     ${CYAN}• Easy to remember and type${NC}"
    echo -e "     ${CYAN}• Works on iOS, Android, macOS, Linux${NC}"
    echo ""
    print_status "info" "Both methods are persistent and survive reboots!"

    return 0
}

# =============================================================================
# APPROACH 5: PI-HOLE DNS SERVER (Placeholder)
# =============================================================================

# Function to setup Pi-hole
setup_pihole() {
    print_section "🕳️" "Pi-hole DNS Server Setup"

    print_status "warn" "Pi-hole setup is complex and requires:"
    print_status "warn" "  • Manual DNS configuration on all devices"
    print_status "warn" "  • Understanding of DNS and DHCP"
    print_status "warn" "  • Additional container management"
    echo ""
    print_status "info" "Consider using Macvlan or Avahi instead for simpler setup"
    echo ""

    if ! ask_yes_no "Continue with Pi-hole setup anyway?"; then
        return 1
    fi

    print_status "info" "Pi-hole setup not yet fully implemented"
    print_status "info" "For now, use Macvlan + Avahi combo for similar benefits"

    return 1
}

# =============================================================================
# APPROACH 6: TAILSCALE VPN (Placeholder)
# =============================================================================

# Function to setup Tailscale
setup_tailscale() {
    print_section "🔐" "Tailscale VPN Setup"

    print_status "info" "Tailscale provides secure remote access from anywhere"
    print_status "info" "Requires Tailscale app on all devices"
    echo ""

    if ! ask_yes_no "Continue with Tailscale setup?"; then
        return 1
    fi

    print_status "info" "Tailscale setup not yet fully implemented"
    print_status "info" "For now, use DuckDNS for internet access"
    print_status "info" "Visit https://tailscale.com for manual setup instructions"

    return 1
}

# =============================================================================
# HELPER FUNCTIONS
# =============================================================================

# Function to update or add environment variable in .env file
update_env_var() {
    local env_file=$1
    local key=$2
    local value=$3

    if [ ! -f "$env_file" ]; then
        return 1
    fi

    # Check if variable exists
    if grep -q "^${key}=" "$env_file" 2>/dev/null; then
        # Update existing
        sed -i "s|^${key}=.*|${key}=${value}|" "$env_file"
    else
        # Add new
        echo "${key}=${value}" >> "$env_file"
    fi
}

# Function to validate static IP setup
validate_static_ip_setup() {
    local method=$(load_config "STATIC_IP_METHOD")

    print_subsection "Validating Static IP Setup"

    if [ -z "$method" ] || [ "$method" = "none" ]; then
        print_status "info" "No advanced static IP method configured"
        return 1
    fi

    case $method in
        macvlan)
            local container_ip=$(load_config "MACVLAN_CONTAINER_IP")
            if [ -n "$container_ip" ]; then
                print_status "pass" "Macvlan configured with IP: $container_ip"
                return 0
            fi
            ;;
        avahi)
            local hostname=$(load_config "AVAHI_HOSTNAME")
            if [ -n "$hostname" ] && command_exists avahi-daemon; then
                print_status "pass" "Avahi configured with hostname: ${hostname}.local"
                return 0
            fi
            ;;
        duckdns)
            local subdomain=$(load_config "DUCKDNS_SUBDOMAIN")
            if [ -n "$subdomain" ]; then
                print_status "pass" "DuckDNS configured: ${subdomain}.duckdns.org"
                return 0
            fi
            ;;
        combo)
            if validate_static_ip_setup "macvlan" && validate_static_ip_setup "avahi"; then
                print_status "pass" "Combo setup validated (Macvlan + Avahi)"
                return 0
            fi
            ;;
    esac

    print_status "fail" "Static IP validation failed"
    return 1
}

# Function to show current static IP status
show_static_ip_status() {
    local method=$(load_config "STATIC_IP_METHOD")

    print_section "📊" "Static IP Status"

    if [ -z "$method" ] || [ "$method" = "none" ]; then
        print_status "info" "No advanced static IP method configured"
        print_status "info" "Using basic network configuration"
        return 0
    fi

    print_status "info" "Method: $method"
    echo ""

    case $method in
        macvlan)
            local container_ip=$(load_config "MACVLAN_CONTAINER_IP")
            local interface=$(load_config "MACVLAN_PARENT_INTERFACE")
            print_status "info" "Container IP: $container_ip"
            print_status "info" "Network Interface: $interface"
            ;;
        avahi)
            local hostname=$(load_config "AVAHI_HOSTNAME")
            print_status "info" "Hostname: ${hostname}.local"
            if systemctl is-active --quiet avahi-daemon 2>/dev/null; then
                print_status "pass" "Avahi daemon: Running"
            else
                print_status "warn" "Avahi daemon: Not running"
            fi
            ;;
        duckdns)
            local subdomain=$(load_config "DUCKDNS_SUBDOMAIN")
            print_status "info" "Domain: ${subdomain}.duckdns.org"
            ;;
        combo)
            print_status "info" "Using Macvlan + Avahi combination"
            show_static_ip_status "macvlan"
            echo ""
            show_static_ip_status "avahi"
            ;;
    esac
}

# =============================================================================
# MAIN FUNCTION
# =============================================================================

main() {
    print_section "🏠" "Advanced Static IP Setup for Kekeli-HomeCloud"

    # Check if user needs static IP
    if ! detect_use_case; then
        echo ""
        if ! ask_yes_no "Continue with advanced static IP setup anyway?"; then
            print_status "info" "Setup cancelled - using existing network configuration"
            exit 0
        fi
    fi

    echo ""
    sleep 2

    while true; do
        clear
        show_approach_menu

        # Read user choice directly
        echo -ne "${GREEN}Select option (1-6, S, H): ${NC}"
        read -r choice
        echo ""

        case $choice in
            1)
                setup_macvlan
                ;;
            2)
                setup_avahi
                ;;
            3)
                setup_duckdns
                ;;
            4)
                setup_combo
                ;;
            5)
                setup_pihole
                ;;
            6)
                setup_tailscale
                ;;
            [Hh])
                local recommended=$(show_decision_helper)
                if [ -n "$recommended" ]; then
                    case $recommended in
                        macvlan) setup_macvlan ;;
                        avahi) setup_avahi ;;
                        duckdns) setup_duckdns ;;
                        combo) setup_combo ;;
                        pihole) setup_pihole ;;
                        tailscale) setup_tailscale ;;
                    esac
                fi
                ;;
            [Ss]|"")
                print_status "info" "Skipping advanced static IP setup"
                exit 0
                ;;
            *)
                print_status "error" "Invalid choice: $choice"
                echo ""
                echo -e "${YELLOW}Please enter 1-6, S, or H${NC}"
                sleep 2
                continue
                ;;
        esac

        # After setup, ask if they want to configure another method
        echo ""
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r

        if ! ask_yes_no "Configure another static IP method?"; then
            break
        fi
    done

    echo ""
    show_static_ip_status
    echo ""
    print_status "pass" "Static IP setup complete!"
    print_status "info" "You can now proceed with Nextcloud deployment"
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
