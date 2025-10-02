#!/bin/bash
# network-detection.sh - Network detection utilities for Kekeli-HomeCloud
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# NETWORK DETECTION FUNCTIONS
# =============================================================================

# Function to detect all network interfaces and their IPs
detect_network_interfaces() {
    print_subsection "Detecting Network Interfaces"

    local interfaces=()

    # Get all IPv4 interfaces
    while IFS= read -r line; do
        if [[ "$line" =~ inet\ ([0-9.]+).*\ ([a-zA-Z0-9]+)$ ]]; then
            local ip="${BASH_REMATCH[1]}"
            local interface="${BASH_REMATCH[2]}"

            # Skip loopback
            if [ "$ip" != "127.0.0.1" ]; then
                interfaces+=("$interface:$ip")
                print_status "info" "Interface $interface: $ip"
            fi
        fi
    done < <(ip addr show | grep "inet ")

    printf '%s\n' "${interfaces[@]}"
}

# Function to detect the primary network interface
detect_primary_interface() {
    local primary_interface

    # Method 1: Check default route (most reliable)
    primary_interface=$(ip route show default | awk '/default/ {print $5}' | head -1)

    # Validate that this interface has a valid IP and isn't virtual
    if [ -n "$primary_interface" ]; then
        local interface_ip=$(get_interface_ip "$primary_interface")
        if [ -n "$interface_ip" ] && [ "$interface_ip" != "127.0.0.1" ] && is_physical_interface "$primary_interface"; then
            echo "$primary_interface"
            return 0
        fi
    fi

    # Method 2: Find best physical interface with IP in private range
    local best_interface=""
    local best_priority=0

    # Get all interfaces with IPs
    while IFS= read -r line; do
        if [[ "$line" =~ inet\ ([0-9.]+).*\ ([a-zA-Z0-9]+)$ ]]; then
            local ip="${BASH_REMATCH[1]}"
            local interface="${BASH_REMATCH[2]}"

            # Skip loopback and invalid IPs
            if [ "$ip" = "127.0.0.1" ] || ! validate_ip "$ip"; then
                continue
            fi

            # Calculate priority for this interface
            local priority=$(calculate_interface_priority "$interface" "$ip")

            if [ "$priority" -gt "$best_priority" ]; then
                best_priority="$priority"
                best_interface="$interface"
            fi
        fi
    done < <(ip addr show | grep "inet ")

    if [ -n "$best_interface" ]; then
        echo "$best_interface"
        return 0
    fi

    # Method 3: Fallback to any non-loopback interface
    primary_interface=$(ip addr show | grep -E '^[0-9]+:' | grep -v lo | awk -F': ' '{print $2}' | head -1)

    if [ -n "$primary_interface" ]; then
        echo "$primary_interface"
        return 0
    fi

    return 1
}

# Function to check if interface is physical (not virtual/bridge)
is_physical_interface() {
    local interface=$1

    # Physical interface patterns
    if [[ "$interface" =~ ^(eth|enp|eno|ens|wlan|wlp|wlo|wls)[0-9] ]]; then
        return 0
    fi

    # Exclude virtual interfaces
    if [[ "$interface" =~ ^(docker|br-|veth|tun|tap|lo|virbr) ]]; then
        return 1
    fi

    # Check if interface has a physical address (most reliable method)
    if [ -d "/sys/class/net/$interface" ]; then
        if [ -f "/sys/class/net/$interface/address" ] && [ -f "/sys/class/net/$interface/type" ]; then
            local type=$(cat "/sys/class/net/$interface/type")
            # Type 1 = Ethernet, Type 6 = IEEE 802.11 (WiFi)
            if [ "$type" = "1" ] || [ "$type" = "6" ]; then
                return 0
            fi
        fi
    fi

    return 1
}

# Function to calculate interface priority (higher = better)
calculate_interface_priority() {
    local interface=$1
    local ip=$2
    local priority=0

    # Base priority for having a valid IP
    priority=10

    # Higher priority for physical interfaces
    if is_physical_interface "$interface"; then
        priority=$((priority + 50))
    fi

    # Higher priority for private network ranges
    if [[ "$ip" =~ ^192\.168\. ]]; then
        priority=$((priority + 30))  # Common home networks
    elif [[ "$ip" =~ ^10\. ]]; then
        priority=$((priority + 25))  # Corporate networks
    elif [[ "$ip" =~ ^172\.(1[6-9]|2[0-9]|3[01])\. ]]; then
        priority=$((priority + 20))  # Less common private range
    fi

    # Higher priority for wired over wireless
    if [[ "$interface" =~ ^(eth|enp|eno|ens) ]]; then
        priority=$((priority + 15))  # Wired interfaces
    elif [[ "$interface" =~ ^(wlan|wlp|wlo|wls) ]]; then
        priority=$((priority + 10))  # Wireless interfaces
    fi

    # Higher priority for default route interface
    if ip route show default | grep -q "$interface"; then
        priority=$((priority + 20))
    fi

    # Lower priority for interfaces with common virtual patterns
    if [[ "$interface" =~ [0-9]$ ]] && [[ "$interface" =~ ^(eth|en)[0-9]+$ ]]; then
        # This could be a virtual interface, slight penalty
        priority=$((priority - 5))
    fi

    echo "$priority"
}

# Function to get IP address of specific interface
get_interface_ip() {
    local interface=$1
    ip addr show "$interface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1
}

# Function to validate IP address format
validate_ip() {
    local ip=$1
    local valid_pattern='^([0-9]{1,3}\.){3}[0-9]{1,3}$'

    if [[ $ip =~ $valid_pattern ]]; then
        # Check each octet is between 0-255
        IFS='.' read -ra octets <<< "$ip"
        for octet in "${octets[@]}"; do
            if [ "$octet" -gt 255 ] || [ "$octet" -lt 0 ]; then
                return 1
            fi
        done
        return 0
    else
        return 1
    fi
}

# Function to validate network interface exists
validate_interface() {
    local interface=$1
    if [ -z "$interface" ]; then
        return 1
    fi

    # Check if interface exists
    if ip link show "$interface" >/dev/null 2>&1; then
        return 0
    else
        return 1
    fi
}

# Function to parse and validate MOBILE_URL from .env
parse_mobile_url() {
    local mobile_url=$(load_config "MOBILE_URL")

    if [ -z "$mobile_url" ]; then
        return 1
    fi

    # Validate URL format
    if [[ "$mobile_url" =~ ^https?://([^:/]+)(:([0-9]+))?/?.*$ ]]; then
        local hostname="${BASH_REMATCH[1]}"
        local port="${BASH_REMATCH[3]}"

        # If no port specified, use default
        if [ -z "$port" ]; then
            if [[ "$mobile_url" =~ ^https:// ]]; then
                port="443"
            else
                port="80"
            fi
        fi

        # Validate IP address if hostname is IP
        if validate_ip "$hostname"; then
            echo "$hostname|$port|$mobile_url"
            return 0
        fi

        # For hostnames, try to resolve to IP
        local resolved_ip=$(nslookup "$hostname" 2>/dev/null | grep -A1 "Name:" | tail -1 | awk '{print $2}')
        if [ -n "$resolved_ip" ] && validate_ip "$resolved_ip"; then
            echo "$resolved_ip|$port|$mobile_url"
            return 0
        fi
    fi

    return 1
}

# Function to get preferred network configuration with MOBILE_URL priority
get_preferred_network_config() {
    print_subsection "Determining Network Configuration Priority" >&2

    # Check for user-defined MOBILE_URL first
    local mobile_url_info
    if mobile_url_info=$(parse_mobile_url); then
        local mobile_ip=$(echo "$mobile_url_info" | cut -d'|' -f1)
        local mobile_port=$(echo "$mobile_url_info" | cut -d'|' -f2)
        local mobile_url=$(echo "$mobile_url_info" | cut -d'|' -f3)

        print_status "pass" "Using user-defined MOBILE_URL: $mobile_url" >&2
        print_status "info" "Extracted IP: $mobile_ip, Port: $mobile_port" >&2

        # Save preferred configuration
        save_config "PREFERRED_IP" "$mobile_ip"
        save_config "PREFERRED_PORT" "$mobile_port"
        save_config "PREFERRED_URL" "$mobile_url"
        save_config "CONFIG_SOURCE" "user_mobile_url"

        echo "$mobile_ip|$mobile_port|$mobile_url|user_mobile_url"
        return 0
    fi

    # Fall back to auto-detection
    print_status "info" "No MOBILE_URL configured, using auto-detection" >&2

    local primary_interface=$(detect_primary_interface)
    local detected_ip=$(get_interface_ip "$primary_interface")
    local detected_port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")

    if [ -n "$detected_ip" ] && [ "$detected_ip" != "127.0.0.1" ]; then
        local detected_url="http://$detected_ip:$detected_port"

        print_status "pass" "Auto-detected network configuration" >&2
        print_status "info" "Interface: $primary_interface, IP: $detected_ip, Port: $detected_port" >&2

        # Save detected configuration
        save_config "PREFERRED_IP" "$detected_ip"
        save_config "PREFERRED_PORT" "$detected_port"
        save_config "PREFERRED_URL" "$detected_url"
        save_config "CONFIG_SOURCE" "auto_detected"

        echo "$detected_ip|$detected_port|$detected_url|auto_detected"
        return 0
    fi

    # Last resort: localhost fallback with warning
    print_status "warn" "Could not determine network configuration, falling back to localhost" >&2
    print_status "info" "Consider setting MOBILE_URL in .env file for consistent access" >&2

    local fallback_port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
    local fallback_url="http://localhost:$fallback_port"

    save_config "PREFERRED_IP" "127.0.0.1"
    save_config "PREFERRED_PORT" "$fallback_port"
    save_config "PREFERRED_URL" "$fallback_url"
    save_config "CONFIG_SOURCE" "localhost_fallback"

    echo "127.0.0.1|$fallback_port|$fallback_url|localhost_fallback"
    return 0
}

# Function to detect local network range
detect_network_range() {
    local interface=${1:-$(detect_primary_interface)}
    local ip

    if [ -z "$interface" ]; then
        print_status "error" "No network interface specified or detected"
        return 1
    fi

    ip=$(get_interface_ip "$interface")
    if [ -z "$ip" ]; then
        print_status "error" "Could not get IP for interface: $interface"
        return 1
    fi

    # Get network range from routing table
    local network_range=$(ip route | grep "$interface" | grep "$ip" | awk '{print $1}' | grep '/' | head -1)

    if [ -n "$network_range" ]; then
        echo "$network_range"
        return 0
    fi

    # Fallback: assume /24 network
    local network_base=$(echo "$ip" | cut -d'.' -f1-3)
    echo "$network_base.0/24"
}

# Function to detect Windows host IP from WSL2
detect_windows_ip_from_wsl() {
    if ! is_wsl; then
        return 1
    fi

    print_subsection "Detecting Windows Host IP from WSL2"

    local windows_ip

    # Method 1: PowerShell detection
    print_status "progress" "Trying PowerShell method..."
    windows_ip=$(powershell.exe -Command "
        \$adapters = Get-NetIPAddress -AddressFamily IPv4 | Where-Object {
            \$_.IPAddress -notmatch '^127\.' -and
            \$_.IPAddress -notmatch '^169\.254\.' -and
            \$_.IPAddress -notmatch '^172\.1[6-9]\.' -and
            \$_.IPAddress -notmatch '^172\.2[0-9]\.' -and
            \$_.IPAddress -notmatch '^172\.3[0-1]\.' -and
            \$_.InterfaceAlias -notmatch 'WSL' -and
            \$_.InterfaceAlias -notmatch 'Loopback' -and
            \$_.InterfaceAlias -notmatch 'vEthernet.*WSL'
        } | Sort-Object InterfaceIndex;
        \$mainAdapter = \$adapters | Where-Object {
            \$_.InterfaceAlias -match 'Wi-Fi|Ethernet|Wireless'
        } | Select-Object -First 1;
        if (-not \$mainAdapter) {
            \$mainAdapter = \$adapters | Select-Object -First 1;
        };
        if (\$mainAdapter) {
            Write-Output \$mainAdapter.IPAddress;
        }
    " 2>/dev/null | tr -d '\r\n' | grep -E '^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$')

    if [ -n "$windows_ip" ] && validate_ip "$windows_ip"; then
        print_status "pass" "PowerShell method found: $windows_ip"
        echo "$windows_ip"
        return 0
    fi

    # Method 2: Gateway IP (WSL2 gateway is usually the Windows host)
    print_status "progress" "Trying gateway method..."
    windows_ip=$(ip route show default | awk '{print $3}' | head -1)

    if [ -n "$windows_ip" ] && validate_ip "$windows_ip"; then
        print_status "pass" "Gateway method found: $windows_ip"
        echo "$windows_ip"
        return 0
    fi

    # Method 3: resolv.conf nameserver
    print_status "progress" "Trying resolv.conf method..."
    if [ -f /etc/resolv.conf ]; then
        windows_ip=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | head -1)
        if [ -n "$windows_ip" ] && validate_ip "$windows_ip"; then
            print_status "pass" "resolv.conf method found: $windows_ip"
            echo "$windows_ip"
            return 0
        fi
    fi

    print_status "error" "Could not detect Windows host IP"
    return 1
}

# Function to detect all available IP addresses for Nextcloud access
detect_access_ips() {
    print_section "🌐" "Detecting Network Access Points"

    local access_ips=()

    # Use preferred network configuration first
    local preferred_config
    if preferred_config=$(get_preferred_network_config); then
        local preferred_ip=$(echo "$preferred_config" | cut -d'|' -f1)
        local preferred_port=$(echo "$preferred_config" | cut -d'|' -f2)
        local preferred_url=$(echo "$preferred_config" | cut -d'|' -f3)
        local config_source=$(echo "$preferred_config" | cut -d'|' -f4)

        if [ -n "$preferred_ip" ] && [ "$preferred_ip" != "127.0.0.1" ]; then
            case "$config_source" in
                "user_mobile_url")
                    access_ips+=("$preferred_ip|User-defined MOBILE_URL")
                    print_status "pass" "Using MOBILE_URL: $preferred_url"
                    ;;
                "auto_detected")
                    local primary_interface=$(detect_primary_interface)
                    access_ips+=("$preferred_ip|Auto-detected primary ($primary_interface)")
                    print_status "pass" "Auto-detected IP: $preferred_ip ($primary_interface)"
                    ;;
            esac
        fi
    fi

    # If no valid preferred config, try manual detection
    if [ ${#access_ips[@]} -eq 0 ]; then
        print_status "warn" "No preferred configuration found, trying manual detection"

        local primary_interface=$(detect_primary_interface)
        if [ -n "$primary_interface" ]; then
            local primary_ip=$(get_interface_ip "$primary_interface")
            if [ -n "$primary_ip" ] && [ "$primary_ip" != "127.0.0.1" ]; then
                access_ips+=("$primary_ip|Primary interface ($primary_interface)")
                print_status "pass" "Manual detection IP: $primary_ip ($primary_interface)"
            fi
        fi
    fi

    # WSL2 specific detection
    if is_wsl; then
        print_status "info" "WSL2 environment detected"

        # WSL2 local IP
        local wsl_ip=$(hostname -I | awk '{print $1}')
        if [ -n "$wsl_ip" ] && validate_ip "$wsl_ip"; then
            access_ips+=("$wsl_ip|WSL2 local IP")
            print_status "pass" "WSL2 local IP: $wsl_ip"
        fi

        # Windows host IP
        windows_ip=$(detect_windows_ip_from_wsl)
        if [ -n "$windows_ip" ]; then
            access_ips+=("$windows_ip|Windows host IP")
            print_status "pass" "Windows host IP: $windows_ip"
        fi
    fi

    # Additional interfaces
    local interfaces
    interfaces=$(detect_network_interfaces)
    while IFS= read -r interface_info; do
        if [ -z "$interface_info" ]; then continue; fi

        local interface=$(echo "$interface_info" | cut -d':' -f1)
        local ip=$(echo "$interface_info" | cut -d':' -f2)

        # Skip if already added
        local already_added=false
        for existing_ip in "${access_ips[@]}"; do
            if [[ "$existing_ip" =~ ^$ip\| ]]; then
                already_added=true
                break
            fi
        done

        if [ "$already_added" = false ]; then
            access_ips+=("$ip|Additional interface ($interface)")
            print_status "info" "Additional IP: $ip ($interface)"
        fi
    done <<< "$interfaces"

    # Final validation - ensure we have at least one access IP
    if [ ${#access_ips[@]} -eq 0 ]; then
        print_status "warn" "No network access IPs detected"
        print_status "info" "Adding localhost as fallback access point"
        access_ips+=("127.0.0.1|Localhost fallback")

        # Check if MOBILE_URL is configured but couldn't be parsed
        local mobile_url=$(load_config "MOBILE_URL")
        if [ -n "$mobile_url" ]; then
            print_status "warn" "MOBILE_URL configured but couldn't be validated: $mobile_url"
            print_status "info" "Please check the MOBILE_URL format (example: http://192.168.1.100:8080)"
        else
            print_status "info" "Consider setting MOBILE_URL in .env file for consistent family access"
        fi
    fi

    # Log successful detection
    print_status "pass" "Network access detection completed"
    print_status "info" "Found ${#access_ips[@]} access point(s)"

    # Return access IPs
    printf '%s\n' "${access_ips[@]}"
}

# Function to test network connectivity
test_network_connectivity() {
    print_subsection "Testing Network Connectivity"

    local tests_passed=0
    local total_tests=0

    # Test 1: Internet connectivity
    ((total_tests++))
    print_status "progress" "Testing internet connectivity..."
    if check_internet; then
        print_status "pass" "Internet connectivity: Available"
        ((tests_passed++))
    else
        print_status "fail" "Internet connectivity: Unavailable"
    fi

    # Test 2: DNS resolution
    ((total_tests++))
    print_status "progress" "Testing DNS resolution..."
    if nslookup google.com >/dev/null 2>&1; then
        print_status "pass" "DNS resolution: Working"
        ((tests_passed++))
    else
        print_status "fail" "DNS resolution: Failed"
    fi

    # Test 3: Local network connectivity
    ((total_tests++))
    print_status "progress" "Testing local network connectivity..."
    local gateway_ip=$(ip route show default | awk '{print $3}' | head -1)
    if [ -n "$gateway_ip" ] && ping -c 1 -W 2 "$gateway_ip" >/dev/null 2>&1; then
        print_status "pass" "Local network: Accessible"
        ((tests_passed++))
    else
        print_status "fail" "Local network: Inaccessible"
    fi

    # Test 4: Port availability (check common ports)
    local ports_to_check=(80 443 8080 9000)
    for port in "${ports_to_check[@]}"; do
        ((total_tests++))
        print_status "progress" "Testing port $port availability..."
        if ! netstat -tln 2>/dev/null | grep -q ":$port "; then
            print_status "pass" "Port $port: Available"
            ((tests_passed++))
        else
            print_status "warn" "Port $port: In use"
        fi
    done

    print_status "info" "Network tests: $tests_passed/$total_tests passed"
    return $((total_tests - tests_passed))
}

# Function to configure firewall for Nextcloud
configure_firewall() {
    local ports=${1:-"80,443,8080"}

    print_subsection "Configuring Firewall"

    # Check if running in WSL2
    if is_wsl; then
        print_status "info" "WSL2 detected - firewall configuration needed on Windows host"
        configure_wsl_firewall "$ports"
        return $?
    fi

    # Linux firewall configuration
    configure_linux_firewall "$ports"
}

# Function to detect if current IP is likely DHCP-assigned
detect_ip_assignment_type() {
    local interface=${1:-$(detect_primary_interface)}
    local ip=${2:-$(get_interface_ip "$interface")}

    if [ -z "$interface" ] || [ -z "$ip" ]; then
        echo "unknown"
        return 1
    fi

    # Check if there's a DHCP lease file
    local dhcp_lease_files=(
        "/var/lib/dhcp/dhclient.${interface}.leases"
        "/var/lib/dhcpcd5/dhcpcd.leases"
        "/var/lib/NetworkManager/dhclient-${interface}.lease"
        "/tmp/dhclient.${interface}.leases"
    )

    for lease_file in "${dhcp_lease_files[@]}"; do
        if [ -f "$lease_file" ] && grep -q "$ip" "$lease_file" 2>/dev/null; then
            echo "dhcp"
            return 0
        fi
    done

    # Check NetworkManager configuration
    if command_exists nmcli; then
        local nm_method=$(nmcli -t -f ipv4.method connection show "$interface" 2>/dev/null | cut -d: -f2)
        if [ "$nm_method" = "auto" ] || [ "$nm_method" = "dhcp" ]; then
            echo "dhcp"
            return 0
        elif [ "$nm_method" = "manual" ] || [ "$nm_method" = "static" ]; then
            echo "static"
            return 0
        fi
    fi

    # Check /etc/network/interfaces (Debian/Ubuntu)
    if [ -f "/etc/network/interfaces" ] && grep -A 10 "iface $interface" /etc/network/interfaces | grep -q "static"; then
        echo "static"
        return 0
    fi

    # Default assumption: if we can't determine, assume DHCP
    echo "dhcp"
    return 0
}

# Function to get network information for static IP setup
get_network_setup_info() {
    local interface=${1:-$(detect_primary_interface)}
    local ip=${2:-$(get_interface_ip "$interface")}

    if [ -z "$interface" ] || [ -z "$ip" ]; then
        print_status "error" "Cannot get network information"
        return 1
    fi

    # Get network information
    local gateway=$(ip route show default | awk '{print $3}' | head -1)
    local netmask=$(ip addr show "$interface" | grep "$ip" | awk '{print $2}' | cut -d'/' -f2)
    local mac_address=$(ip link show "$interface" | awk '/ether/ {print $2}')
    local dns_servers=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')

    # Calculate network range
    local network_base=$(echo "$ip" | cut -d'.' -f1-3)
    local cidr_notation="${network_base}.0/${netmask}"

    cat << EOF
Current Network Configuration:
  Interface: $interface
  IP Address: $ip
  Netmask: /$netmask
  Gateway: $gateway
  MAC Address: $mac_address
  DNS Servers: $dns_servers
  Network Range: $cidr_notation
EOF
}

# Function to detect router information
detect_router_info() {
    local gateway=$(ip route show default | awk '{print $3}' | head -1)

    if [ -z "$gateway" ]; then
        print_status "warn" "Could not detect router/gateway IP"
        return 1
    fi

    print_status "info" "Router/Gateway detected: $gateway"

    # Try to detect router model/brand
    local router_info=""

    # Try to get router info via UPnP
    if command_exists nmap; then
        router_info=$(timeout 5 nmap -sU -p 1900 --script=upnp-info "$gateway" 2>/dev/null | grep -E "(Server|Model)" | head -2)
    fi

    # Try HTTP detection
    if [ -z "$router_info" ] && command_exists curl; then
        local http_title=$(timeout 3 curl -s "http://$gateway/" 2>/dev/null | grep -i "<title>" | sed 's/<[^>]*>//g' | head -1)
        if [ -n "$http_title" ]; then
            router_info="Web Interface: $http_title"
        fi
    fi

    cat << EOF
Router Information:
  Gateway IP: $gateway
  Access URL: http://$gateway
  Admin Panel: http://$gateway (usually)
$([ -n "$router_info" ] && echo "  Info: $router_info")
EOF
}

# Function to provide static IP setup instructions
provide_static_ip_instructions() {
    local interface=${1:-$(detect_primary_interface)}
    local current_ip=${2:-$(get_interface_ip "$interface")}
    local assignment_type=$(detect_ip_assignment_type "$interface" "$current_ip")

    print_subsection "Static IP Setup for Family Network Consistency"

    if [ "$assignment_type" = "static" ]; then
        print_status "pass" "IP appears to be statically configured already"
        print_status "info" "Current IP: $current_ip"
        return 0
    fi

    print_status "warn" "Current IP ($current_ip) appears to be DHCP-assigned"
    print_status "info" "For consistent family access, this should be made static"

    echo ""
    echo "Network Information:"
    get_network_setup_info "$interface" "$current_ip"

    echo ""
    echo "Router Information:"
    detect_router_info

    echo ""
    print_status "info" "Choose one of these methods to make your IP persistent:"

    echo ""
    echo -e "${CYAN}Method 1: Router DHCP Reservation (Recommended for families)${NC}"
    echo -e "${GREEN}✓ Pros:${NC} Easy to manage, works across OS reinstalls, family-friendly"
    echo -e "${YELLOW}⚠ Cons:${NC} Requires router admin access"
    echo ""
    echo "Steps:"
    echo "1. Open web browser and go to: http://$(ip route show default | awk '{print $3}' | head -1)"
    echo "2. Login to router admin panel (common credentials: admin/admin, admin/password)"
    echo "3. Find 'DHCP Settings', 'DHCP Reservations', or 'Static DHCP' section"
    echo "4. Add new reservation:"
    echo "   - MAC Address: $(ip link show "$interface" | awk '/ether/ {print $2}')"
    echo "   - IP Address: $current_ip"
    echo "   - Device Name: Nextcloud-Server (optional)"
    echo "5. Save settings and restart router"
    echo "6. Restart this computer"
    echo ""

    echo -e "${CYAN}Method 2: System Static IP Configuration${NC}"
    echo -e "${GREEN}✓ Pros:${NC} No router access needed, immediate control"
    echo -e "${YELLOW}⚠ Cons:${NC} Needs reconfiguration if OS is reinstalled"
    echo ""

    if command_exists nmcli; then
        echo "NetworkManager method (recommended for Ubuntu/desktop systems):"
        echo "sudo nmcli con mod \"$(nmcli -t -f NAME con show --active | head -1)\" ipv4.method manual"
        echo "sudo nmcli con mod \"$(nmcli -t -f NAME con show --active | head -1)\" ipv4.addresses $current_ip/$(ip addr show "$interface" | grep "$current_ip" | awk '{print $2}' | cut -d'/' -f2)"
        echo "sudo nmcli con mod \"$(nmcli -t -f NAME con show --active | head -1)\" ipv4.gateway $(ip route show default | awk '{print $3}' | head -1)"
        echo "sudo nmcli con mod \"$(nmcli -t -f NAME con show --active | head -1)\" ipv4.dns \"$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')\""
        echo "sudo nmcli con down \"$(nmcli -t -f NAME con show --active | head -1)\" && sudo nmcli con up \"$(nmcli -t -f NAME con show --active | head -1)\""
    else
        echo "Manual configuration in /etc/network/interfaces:"
        echo "Edit /etc/network/interfaces and add:"
        echo "auto $interface"
        echo "iface $interface inet static"
        echo "    address $current_ip"
        echo "    netmask $(ip route | grep "$interface" | grep "$current_ip" | awk '{print $1}' | cut -d'/' -f2 | head -1)"
        echo "    gateway $(ip route show default | awk '{print $3}' | head -1)"
        echo "    dns-nameservers $(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ' ')"
    fi

    echo ""
    print_status "question" "Would you like to test if the IP persists after reboot?"
    if ask_yes_no "Set up IP persistence testing?"; then
        setup_ip_persistence_test "$interface" "$current_ip"
    fi
}

# Function to set up IP persistence testing
setup_ip_persistence_test() {
    local interface=$1
    local expected_ip=$2

    local test_script="$KEKELI_CONFIG_DIR/ip-persistence-test.sh"

    cat > "$test_script" << EOF
#!/bin/bash
# IP Persistence Test - Kekeli-HomeCloud
# This script checks if the IP address persists after reboot

EXPECTED_IP="$expected_ip"
INTERFACE="$interface"

echo "Testing IP persistence after reboot..."
echo "Expected IP: \$EXPECTED_IP"
echo "Interface: \$INTERFACE"

CURRENT_IP=\$(ip addr show "\$INTERFACE" 2>/dev/null | grep 'inet ' | awk '{print \$2}' | cut -d'/' -f1 | head -1)

echo "Current IP: \$CURRENT_IP"

if [ "\$CURRENT_IP" = "\$EXPECTED_IP" ]; then
    echo "✅ SUCCESS: IP address persisted after reboot!"
    echo "Family members can consistently access Nextcloud at: http://\$CURRENT_IP:8080"
else
    echo "❌ FAILURE: IP address changed after reboot"
    echo "You need to set up DHCP reservation or static IP configuration"
    echo "Previous IP: \$EXPECTED_IP"
    echo "Current IP: \$CURRENT_IP"
fi
EOF

    chmod +x "$test_script"

    print_status "pass" "IP persistence test script created: $test_script"
    print_status "info" "After setting up static IP/DHCP reservation:"
    print_status "info" "1. Reboot your computer"
    print_status "info" "2. Run: $test_script"
    print_status "info" "3. Verify your IP remained the same"
}

# Function to configure Linux firewall
configure_linux_firewall() {
    local ports=$1
    local firewall_configured=false

    # Try UFW first (Ubuntu/Debian default)
    if command_exists ufw; then
        print_status "progress" "Configuring UFW firewall..."

        # Enable UFW if not already enabled
        if ! sudo ufw status | grep -q "Status: active"; then
            if ask_yes_no "Enable UFW firewall?"; then
                sudo ufw --force enable >/dev/null 2>&1
            fi
        fi

        # Add rules for each port
        IFS=',' read -ra PORT_ARRAY <<< "$ports"
        for port in "${PORT_ARRAY[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            if sudo ufw allow "$port" >/dev/null 2>&1; then
                print_status "pass" "UFW: Opened port $port"
            else
                print_status "warn" "UFW: Could not open port $port"
            fi
        done

        firewall_configured=true

    # Try firewalld (CentOS/RHEL/Fedora)
    elif command_exists firewall-cmd; then
        print_status "progress" "Configuring firewalld..."

        IFS=',' read -ra PORT_ARRAY <<< "$ports"
        for port in "${PORT_ARRAY[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            if sudo firewall-cmd --permanent --add-port="$port/tcp" >/dev/null 2>&1; then
                print_status "pass" "firewalld: Opened port $port"
            else
                print_status "warn" "firewalld: Could not open port $port"
            fi
        done

        # Reload firewall
        sudo firewall-cmd --reload >/dev/null 2>&1
        firewall_configured=true

    # Fallback to iptables
    elif command_exists iptables; then
        print_status "progress" "Configuring iptables..."

        IFS=',' read -ra PORT_ARRAY <<< "$ports"
        for port in "${PORT_ARRAY[@]}"; do
            port=$(echo "$port" | tr -d ' ')
            if sudo iptables -A INPUT -p tcp --dport "$port" -j ACCEPT >/dev/null 2>&1; then
                print_status "pass" "iptables: Opened port $port"
            else
                print_status "warn" "iptables: Could not open port $port"
            fi
        done

        # Try to save iptables rules
        if command_exists iptables-save; then
            sudo iptables-save > /etc/iptables/rules.v4 2>/dev/null || \
            sudo iptables-save > /etc/iptables.rules 2>/dev/null
        fi

        firewall_configured=true
    else
        print_status "warn" "No supported firewall found"
        return 1
    fi

    if [ "$firewall_configured" = true ]; then
        print_status "pass" "Firewall configured for Nextcloud access"
        return 0
    else
        return 1
    fi
}

# Function to configure WSL firewall (Windows)
configure_wsl_firewall() {
    local ports=$1

    print_status "info" "WSL2 requires Windows firewall configuration"

    # Get Windows IP for port forwarding
    local windows_ip=$(detect_windows_ip_from_wsl)
    if [ -z "$windows_ip" ]; then
        print_status "error" "Could not detect Windows IP for firewall configuration"
        return 1
    fi

    # Generate PowerShell commands for port forwarding
    IFS=',' read -ra PORT_ARRAY <<< "$ports"
    local powershell_commands=""

    for port in "${PORT_ARRAY[@]}"; do
        port=$(echo "$port" | tr -d ' ')
        powershell_commands+="netsh interface portproxy add v4tov4 listenport=$port listenaddress=$windows_ip connectport=$port connectaddress=\$(hostname -I | awk '{print \$1}'); "
        powershell_commands+="New-NetFirewallRule -DisplayName 'Kekeli-HomeCloud Port $port' -Direction Inbound -LocalPort $port -Protocol TCP -Action Allow; "
    done

    print_status "info" "Windows firewall configuration required:"
    echo -e "${CYAN}Run these commands in PowerShell as Administrator:${NC}"
    echo ""
    echo -e "${YELLOW}# Enable port forwarding and firewall rules${NC}"
    echo "$powershell_commands"
    echo ""

    if ask_yes_no "Have you run the Windows firewall commands?"; then
        print_status "pass" "Windows firewall configured"
        return 0
    else
        print_status "warn" "Windows firewall configuration pending"
        return 2  # Special code for pending configuration
    fi
}

# Function to generate trusted domains configuration
generate_trusted_domains() {
    local access_ips=()
    local trusted_domains=()

    # Get all access IPs
    while IFS= read -r ip_info; do
        if [ -z "$ip_info" ]; then continue; fi
        local ip=$(echo "$ip_info" | cut -d'|' -f1)
        access_ips+=("$ip")
    done < <(detect_access_ips)

    # Add common domain variations
    for ip in "${access_ips[@]}"; do
        trusted_domains+=("$ip")
        trusted_domains+=("$ip:8080")
        trusted_domains+=("$ip:80")
        trusted_domains+=("$ip:443")
    done

    # Add localhost variations
    trusted_domains+=("localhost")
    trusted_domains+=("localhost:8080")
    trusted_domains+=("127.0.0.1")
    trusted_domains+=("127.0.0.1:8080")

    # Return unique domains
    printf '%s\n' "${trusted_domains[@]}" | sort -u
}

# Function to test network access to specific port
test_port_access() {
    local ip=$1
    local port=$2
    local timeout=${3:-5}

    if command_exists nc; then
        nc -z -w "$timeout" "$ip" "$port" 2>/dev/null
    elif command_exists telnet; then
        timeout "$timeout" telnet "$ip" "$port" </dev/null >/dev/null 2>&1
    else
        # Fallback using /dev/tcp
        timeout "$timeout" bash -c "echo >/dev/tcp/$ip/$port" 2>/dev/null
    fi
}

# Function to scan for available ports
scan_available_ports() {
    local start_port=${1:-8080}
    local end_port=${2:-8090}

    print_subsection "Scanning for Available Ports ($start_port-$end_port)"

    local available_ports=()

    for port in $(seq "$start_port" "$end_port"); do
        if ! netstat -tln 2>/dev/null | grep -q ":$port "; then
            available_ports+=("$port")
            print_status "pass" "Port $port: Available"
        else
            print_status "info" "Port $port: In use"
        fi
    done

    if [ ${#available_ports[@]} -eq 0 ]; then
        print_status "warn" "No available ports found in range $start_port-$end_port"
        return 1
    fi

    printf '%s\n' "${available_ports[@]}"
}

# Function to configure network for optimal mobile access
configure_mobile_access() {
    print_section "📱" "Configuring Mobile Access"

    local primary_ip
    local mobile_config=()

    # Get primary access IP
    local access_ips
    access_ips=$(detect_access_ips)
    primary_ip=$(echo "$access_ips" | head -1 | cut -d'|' -f1)

    if [ -z "$primary_ip" ]; then
        print_status "error" "Could not determine primary IP address"
        return 1
    fi

    print_status "info" "Primary access IP: $primary_ip"

    # Configure firewall
    if configure_firewall "80,443,8080"; then
        print_status "pass" "Firewall configured for mobile access"
    else
        print_status "warn" "Firewall configuration may be incomplete"
    fi

    # Generate mobile access URLs
    local mobile_urls=(
        "http://$primary_ip:8080"
        "https://$primary_ip:8443"
        "http://$primary_ip"
    )

    print_status "pass" "Mobile access configured"
    print_status "info" "Mobile access URLs:"
    for url in "${mobile_urls[@]}"; do
        echo -e "    ${CYAN}$url${NC}"
    done

    # Save mobile configuration
    save_config "MOBILE_PRIMARY_IP" "$primary_ip"
    save_config "MOBILE_ACCESS_URLS" "${mobile_urls[*]}"

    return 0
}

# Function to validate network configuration
validate_network_configuration() {
    print_subsection "Validating Network Configuration"

    local validation_passed=true

    # Test 1: Validate primary IP
    local primary_ip=$(load_config "MOBILE_PRIMARY_IP")
    if [ -n "$primary_ip" ] && validate_ip "$primary_ip"; then
        print_status "pass" "Primary IP validation: $primary_ip"
    else
        print_status "fail" "Primary IP validation: Failed"
        validation_passed=false
    fi

    # Test 2: Test port accessibility
    local ports_to_test=(80 8080)
    for port in "${ports_to_test[@]}"; do
        if ! netstat -tln 2>/dev/null | grep -q ":$port "; then
            print_status "pass" "Port $port: Available"
        else
            print_status "warn" "Port $port: In use (may conflict)"
        fi
    done

    # Test 3: Network connectivity
    if check_internet; then
        print_status "pass" "Internet connectivity: Available"
    else
        print_status "fail" "Internet connectivity: Failed"
        validation_passed=false
    fi

    if [ "$validation_passed" = true ]; then
        print_status "pass" "Network configuration validation passed"
        return 0
    else
        print_status "fail" "Network configuration validation failed"
        return 1
    fi
}


# =============================================================================
# IP CHANGE DETECTION AND AUTO-UPDATE FUNCTIONS
# =============================================================================

# Function to get the primary IP address of the system
get_primary_ip() {
    local primary_interface=$(detect_primary_interface)
    if [ -n "$primary_interface" ]; then
        local primary_ip=$(get_interface_ip "$primary_interface")
        if [ -n "$primary_ip" ] && [ "$primary_ip" != "127.0.0.1" ]; then
            echo "$primary_ip"
            return 0
        fi
    fi

    # Fallback: use IP route to get the outgoing IP
    local fallback_ip=$(ip route get 1.1.1.1 2>/dev/null | grep -oP 'src \K[0-9.]+' | head -1)
    if [ -n "$fallback_ip" ] && [ "$fallback_ip" != "127.0.0.1" ]; then
        echo "$fallback_ip"
        return 0
    fi

    return 1
}

# Function to detect if the IP address has changed since last configuration
detect_ip_change() {
    print_subsection "Checking for IP Address Changes"

    # Get current primary IP
    local current_ip
    current_ip=$(get_primary_ip)

    if [ -z "$current_ip" ]; then
        print_status "warn" "Could not determine current IP address"
        return 1
    fi

    # Get stored IP from configuration
    local stored_ip=$(load_config "PRIMARY_IP")
    local stored_domain=$(load_config "PRIMARY_DOMAIN")

    print_status "info" "Current IP: $current_ip"
    print_status "info" "Stored IP: ${stored_ip:-"not set"}"

    # Check if IP has changed
    if [ -n "$stored_ip" ] && [ "$current_ip" != "$stored_ip" ]; then
        print_status "warn" "IP address has changed!"
        print_status "warn" "  Previous: $stored_ip"
        print_status "warn" "  Current:  $current_ip"
        return 0  # IP changed
    elif [ -z "$stored_ip" ]; then
        print_status "info" "No previous IP configuration found"
        return 2  # No previous config
    else
        print_status "pass" "IP address unchanged: $current_ip"
        return 1  # No change
    fi
}

# Function to update all configuration files with new IP address
update_ip_configuration() {
    local new_ip=$1
    local old_ip=$2
    local port=${3:-$(load_config "NEXTCLOUD_HTTP_PORT" "8090")}

    if [ -z "$new_ip" ]; then
        print_status "error" "New IP address is required"
        return 1
    fi

    print_subsection "Updating IP Configuration"
    print_status "progress" "Updating from $old_ip to $new_ip"

    # Update main .env file
    local env_file="$PROJECT_DIR/.env"
    if [ -f "$env_file" ]; then
        print_status "progress" "Updating .env file..."

        # Update PRIMARY_DOMAIN
        if grep -q "^PRIMARY_DOMAIN=" "$env_file"; then
            sed -i "s|^PRIMARY_DOMAIN=.*|PRIMARY_DOMAIN=$new_ip:$port|" "$env_file"
        else
            echo "PRIMARY_DOMAIN=$new_ip:$port" >> "$env_file"
        fi

        # Update MOBILE_URL
        if grep -q "^MOBILE_URL=" "$env_file"; then
            sed -i "s|^MOBILE_URL=.*|MOBILE_URL=http://$new_ip:$port|" "$env_file"
        else
            echo "MOBILE_URL=http://$new_ip:$port" >> "$env_file"
        fi

        # Update TRUSTED_DOMAINS to include new IP
        if grep -q "^TRUSTED_DOMAINS=" "$env_file"; then
            # Add new IP to existing trusted domains if not already present
            local current_domains=$(grep "^TRUSTED_DOMAINS=" "$env_file" | cut -d'=' -f2)
            if [[ "$current_domains" != *"$new_ip"* ]]; then
                sed -i "s|^TRUSTED_DOMAINS=|TRUSTED_DOMAINS=$new_ip,$new_ip:$port,|" "$env_file"
            fi
        fi

        print_status "pass" "Updated .env file"
    fi

    # Update kekeli configuration
    local config_file="$KEKELI_CONFIG_DIR/config.env"
    if [ -f "$config_file" ]; then
        print_status "progress" "Updating kekeli configuration..."

        # Update all IP-related settings
        save_config "PRIMARY_IP" "$new_ip"
        save_config "PRIMARY_DOMAIN" "$new_ip:$port"
        save_config "PREFERRED_IP" "$new_ip"
        save_config "PREFERRED_URL" "http://$new_ip:$port"
        save_config "MOBILE_ACCESS_URLS" "http://$new_ip:$port"
        save_config "ACCESS_URLS" "http://$new_ip:$port|Primary family access"

        # Update trusted domains
        local new_domains="$new_ip,$new_ip:$port"
        if [ -n "$old_ip" ]; then
            new_domains="$new_domains,$old_ip,$old_ip:$port"
        fi
        new_domains="$new_domains,127.0.0.1,127.0.0.1:$port,host.docker.internal,host.docker.internal:$port,localhost,localhost:$port"
        save_config "TRUSTED_DOMAINS" "$new_domains"

        print_status "pass" "Updated kekeli configuration"
    fi

    print_status "pass" "IP configuration updated successfully"
    return 0
}

# Function to update Nextcloud container configuration with new IP
update_nextcloud_ip_config() {
    local new_ip=$1
    local port=${2:-$(load_config "NEXTCLOUD_HTTP_PORT" "8090")}

    print_subsection "Updating Nextcloud Container Configuration"

    # Check if Nextcloud container is running
    if ! docker ps --format "{{.Names}}" | grep -q "kekeli-nextcloud-app"; then
        print_status "warn" "Nextcloud container not running - will update on next start"
        return 0
    fi

    print_status "progress" "Updating Nextcloud overwritehost setting..."
    if docker exec kekeli-nextcloud-app php occ config:system:set overwritehost --value="$new_ip:$port" >/dev/null 2>&1; then
        print_status "pass" "Updated Nextcloud overwritehost"
    else
        print_status "warn" "Failed to update Nextcloud overwritehost - will update on container restart"
    fi

    print_status "progress" "Adding new IP to trusted domains..."
    # Add new IP to trusted domains
    local trusted_count=$(docker exec kekeli-nextcloud-app php occ config:system:get trusted_domains 2>/dev/null | wc -l)
    docker exec kekeli-nextcloud-app php occ config:system:set trusted_domains $trusted_count --value="$new_ip" >/dev/null 2>&1
    docker exec kekeli-nextcloud-app php occ config:system:set trusted_domains $((trusted_count + 1)) --value="$new_ip:$port" >/dev/null 2>&1

    print_status "pass" "Nextcloud configuration updated"
    return 0
}

# Function to handle IP change detection and user interaction
handle_ip_change() {
    local auto_update=${1:-false}

    print_section "🔄" "IP Address Change Detection"

    local change_status
    detect_ip_change
    change_status=$?

    case $change_status in
        0)  # IP changed
            local current_ip=$(get_primary_ip)
            local stored_ip=$(load_config "PRIMARY_IP")
            local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8090")

            echo ""
            print_status "warn" "Your IP address has changed. This affects mobile access URLs."
            echo ""

            if [ "$auto_update" = "true" ]; then
                print_status "info" "Auto-update mode: updating configuration..."
                update_configuration=true
            else
                echo -e "${CYAN}What would you like to do?${NC}"
                echo "  1) Update configuration automatically (recommended)"
                echo "  2) Update configuration and restart containers"
                echo "  3) Continue without updating (mobile access may not work)"
                echo "  4) Exit and handle manually"
                echo ""

                local choice
                read -p "Enter your choice (1-4): " choice

                case "$choice" in
                    1|"")
                        update_configuration=true
                        restart_containers=false
                        ;;
                    2)
                        update_configuration=true
                        restart_containers=true
                        ;;
                    3)
                        print_status "warn" "Continuing without IP update - mobile access may not work"
                        return 0
                        ;;
                    4)
                        print_status "info" "Exiting for manual configuration"
                        exit 0
                        ;;
                    *)
                        print_status "error" "Invalid choice. Continuing without update."
                        return 1
                        ;;
                esac
            fi

            if [ "$update_configuration" = "true" ]; then
                # Update configuration files
                if update_ip_configuration "$current_ip" "$stored_ip" "$port"; then
                    # Update Nextcloud container configuration
                    update_nextcloud_ip_config "$current_ip" "$port"

                    # Restart containers if requested
                    if [ "$restart_containers" = "true" ]; then
                        print_status "progress" "Restarting containers to apply new configuration..."
                        if docker compose restart >/dev/null 2>&1; then
                            print_status "pass" "Containers restarted successfully"
                        else
                            print_status "warn" "Failed to restart containers - you may need to restart manually"
                        fi
                    fi

                    echo ""
                    print_status "pass" "IP configuration updated successfully!"
                    print_status "info" "New mobile access URL: http://$current_ip:$port"
                    echo ""
                else
                    print_status "error" "Failed to update IP configuration"
                    return 1
                fi
            fi
            ;;
        1)  # No change
            print_status "pass" "IP address is unchanged - no updates needed"
            ;;
        2)  # No previous config
            print_status "info" "No previous IP configuration - this appears to be initial setup"
            ;;
        *)
            print_status "error" "Failed to check IP address"
            return 1
            ;;
    esac

    return 0
}

# Function to validate current network configuration
validate_current_network_config() {
    print_subsection "Validating Current Network Configuration"

    local current_ip=$(get_primary_ip)
    local host_ip=$(load_config "HOST_IP")
    local configured_ip=$(load_config "PRIMARY_IP")
    local mobile_url=$(load_config "MOBILE_ACCESS_URLS")
    local port=$(load_config "NEXTCLOUD_HTTP_PORT" "8090")

    local issues_found=false

    # If HOST_IP is configured (static IP), validate against it
    # Otherwise validate against PRIMARY_IP (dynamic detection)
    local expected_ip="${host_ip:-$configured_ip}"

    # Check IP consistency
    if [ -n "$host_ip" ]; then
        # HOST_IP is configured - this is intentional static IP, skip validation
        print_status "pass" "Static IP configured: $host_ip (skipping auto-detection validation)"
    elif [ -n "$configured_ip" ] && [ "$current_ip" != "$configured_ip" ]; then
        # No HOST_IP, using dynamic detection - warn if changed
        print_status "warn" "IP mismatch detected:"
        print_status "warn" "  Current: $current_ip"
        print_status "warn" "  Configured: $configured_ip"
        issues_found=true
    fi

    # Test mobile URL accessibility
    if [ -n "$mobile_url" ]; then
        print_status "progress" "Testing mobile URL accessibility..."
        if curl -f -s --max-time 5 "$mobile_url/status.php" >/dev/null 2>&1; then
            print_status "pass" "Mobile URL accessible: $mobile_url"
        else
            print_status "warn" "Mobile URL not accessible: $mobile_url"
            issues_found=true
        fi
    fi

    # Test Nextcloud overwritehost setting
    if docker ps --format "{{.Names}}" | grep -q "kekeli-nextcloud-app"; then
        local overwrite_host=$(docker exec kekeli-nextcloud-app php occ config:system:get overwritehost 2>/dev/null)
        if [ -n "$overwrite_host" ] && [[ "$overwrite_host" != *"$current_ip"* ]]; then
            print_status "warn" "Nextcloud overwritehost mismatch:"
            print_status "warn" "  Current IP: $current_ip"
            print_status "warn" "  Overwritehost: $overwrite_host"
            issues_found=true
        fi
    fi

    if [ "$issues_found" = "false" ]; then
        print_status "pass" "Network configuration validation passed"
        return 0
    else
        print_status "warn" "Network configuration issues detected"
        return 1
    fi
}

# =============================================================================
# STATIC IP CONFIGURATION
# =============================================================================

# Function to apply static IP from .env HOST_IP setting
apply_static_ip_configuration() {
    print_subsection "Applying Static IP Configuration"

    # Check for HOST_IP in project .env file first
    local desired_ip=""
    if [ -f "$PWD/.env" ] && grep -q "^HOST_IP=" "$PWD/.env"; then
        desired_ip=$(grep "^HOST_IP=" "$PWD/.env" | cut -d'=' -f2 | tr -d ' "'"'" | head -1)
        if [ -n "$desired_ip" ]; then
            print_status "info" "Found HOST_IP in .env file: $desired_ip"
            # Save to config for future use
            save_config "HOST_IP" "$desired_ip"
        fi
    fi

    # Fallback to config.env if not in .env
    if [ -z "$desired_ip" ]; then
        desired_ip=$(load_config "HOST_IP")
    fi

    # If HOST_IP is not set, skip static IP configuration
    if [ -z "$desired_ip" ]; then
        print_status "info" "HOST_IP not set in .env - using DHCP (dynamic IP)"
        print_status "info" "Set HOST_IP in .env file for consistent static IP"
        return 0
    fi

    print_status "info" "Desired static IP: $desired_ip"

    # Detect primary interface
    local interface=$(detect_primary_interface)
    if [ -z "$interface" ]; then
        print_status "fail" "Could not detect primary network interface"
        return 1
    fi
    print_status "pass" "Primary interface: $interface"

    # Get current IP
    local current_ip=$(get_interface_ip "$interface")
    print_status "info" "Current IP: $current_ip"

    # Check if IP is already configured
    if [ "$current_ip" = "$desired_ip" ]; then
        print_status "pass" "IP already configured to $desired_ip"

        # Verify if it's static or DHCP
        local assignment_type=$(detect_ip_assignment_type "$interface" "$current_ip")
        if [ "$assignment_type" = "static" ]; then
            print_status "pass" "IP is statically assigned"
            return 0
        else
            print_status "warn" "IP matches but appears to be DHCP-assigned"
            print_status "info" "Will configure static IP to ensure persistence"
        fi
    fi

    # Validate the desired IP
    if ! validate_static_ip_configuration "$desired_ip" "$interface"; then
        print_status "fail" "Static IP validation failed"
        return 1
    fi

    # Get network configuration
    local gateway=$(ip route show default | awk '{print $3}' | head -1)
    local netmask=$(ip addr show "$interface" | grep "inet " | awk '{print $2}' | cut -d'/' -f2 | head -1)
    local dns_servers=$(grep nameserver /etc/resolv.conf | awk '{print $2}' | tr '\n' ',' | sed 's/,$//')

    print_status "info" "Network configuration:"
    print_status "info" "  Interface: $interface"
    print_status "info" "  IP: $desired_ip/$netmask"
    print_status "info" "  Gateway: $gateway"
    print_status "info" "  DNS: $dns_servers"

    echo ""
    print_status "question" "Apply static IP configuration?"
    echo -e "${YELLOW}This will configure your system to use $desired_ip as a static IP.${NC}"
    echo -e "${YELLOW}Your network connection may briefly disconnect.${NC}"
    echo ""

    if ! ask_yes_no "Apply static IP now?"; then
        print_status "info" "Static IP configuration skipped"
        print_status "info" "You can manually configure it later or remove HOST_IP from .env"
        return 0
    fi

    # Apply static IP based on network manager
    if command_exists nmcli; then
        apply_static_ip_networkmanager "$interface" "$desired_ip" "$netmask" "$gateway" "$dns_servers"
    elif [ -f /etc/netplan/*.yaml ] || [ -f /etc/netplan/*.yml ]; then
        apply_static_ip_netplan "$interface" "$desired_ip" "$netmask" "$gateway" "$dns_servers"
    else
        apply_static_ip_interfaces "$interface" "$desired_ip" "$netmask" "$gateway" "$dns_servers"
    fi
}

# Function to validate static IP configuration
validate_static_ip_configuration() {
    local desired_ip=$1
    local interface=$2

    # Validate IP format
    if ! [[ "$desired_ip" =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
        print_status "fail" "Invalid IP address format: $desired_ip"
        return 1
    fi

    # Get subnet
    local current_ip=$(get_interface_ip "$interface")
    local subnet=$(ip -o -f inet addr show "$interface" | awk '{print $4}' | cut -d'/' -f1 | cut -d'.' -f1-3)
    local desired_subnet=$(echo "$desired_ip" | cut -d'.' -f1-3)

    # Check if desired IP is in same subnet
    if [ "$subnet" != "$desired_subnet" ]; then
        print_status "warn" "Desired IP ($desired_ip) is in different subnet than current ($subnet.x)"
        print_status "warn" "This may cause network connectivity issues"
        if ! ask_yes_no "Continue anyway?"; then
            return 1
        fi
    fi

    # Check if IP is already in use
    print_status "progress" "Checking if IP is available..."
    if ping -c 1 -W 1 "$desired_ip" >/dev/null 2>&1 && [ "$current_ip" != "$desired_ip" ]; then
        print_status "warn" "IP $desired_ip appears to be in use by another device"
        if ! ask_yes_no "Continue anyway (may cause IP conflict)?"; then
            return 1
        fi
    fi

    print_status "pass" "Static IP validation passed"
    return 0
}

# Function to apply static IP using NetworkManager
apply_static_ip_networkmanager() {
    local interface=$1
    local ip=$2
    local netmask=$3
    local gateway=$4
    local dns=$5

    print_status "progress" "Configuring static IP with NetworkManager..."

    # Get connection name
    local connection=$(nmcli -t -f NAME,DEVICE con show --active | grep "$interface" | cut -d':' -f1 | head -1)

    if [ -z "$connection" ]; then
        print_status "fail" "Could not find NetworkManager connection for $interface"
        return 1
    fi

    print_status "info" "Configuring connection: $connection"

    # Configure static IP
    if sudo nmcli con mod "$connection" ipv4.method manual \
        ipv4.addresses "$ip/$netmask" \
        ipv4.gateway "$gateway" \
        ipv4.dns "$dns" 2>/dev/null; then

        print_status "pass" "Static IP configuration applied"

        # Restart connection
        print_status "progress" "Restarting network connection..."
        sudo nmcli con down "$connection" >/dev/null 2>&1
        sleep 2
        sudo nmcli con up "$connection" >/dev/null 2>&1
        sleep 3

        # Verify new IP
        local new_ip=$(get_interface_ip "$interface")
        if [ "$new_ip" = "$ip" ]; then
            print_status "pass" "Static IP successfully applied: $ip"
            print_status "pass" "Your Nextcloud will be accessible at: http://$ip:$(load_config 'NEXTCLOUD_HTTP_PORT' '8080')"
            return 0
        else
            print_status "fail" "IP configuration failed. Current IP: $new_ip (expected: $ip)"
            return 1
        fi
    else
        print_status "fail" "Failed to apply NetworkManager configuration"
        return 1
    fi
}

# Function to apply static IP using Netplan (Ubuntu 18.04+)
apply_static_ip_netplan() {
    local interface=$1
    local ip=$2
    local netmask=$3
    local gateway=$4
    local dns=$5

    print_status "progress" "Configuring static IP with Netplan..."

    local netplan_file="/etc/netplan/01-kekeli-static.yaml"

    # Create netplan configuration
    sudo tee "$netplan_file" > /dev/null << EOF
# Kekeli-HomeCloud Static IP Configuration
# Generated on $(date)
network:
  version: 2
  renderer: networkd
  ethernets:
    $interface:
      dhcp4: no
      addresses:
        - $ip/$netmask
      gateway4: $gateway
      nameservers:
        addresses: [$(echo $dns | tr ',' ', ')]
EOF

    if [ $? -eq 0 ]; then
        print_status "pass" "Netplan configuration created"

        # Apply netplan
        print_status "progress" "Applying netplan configuration..."
        if sudo netplan apply 2>/dev/null; then
            sleep 3
            local new_ip=$(get_interface_ip "$interface")
            if [ "$new_ip" = "$ip" ]; then
                print_status "pass" "Static IP successfully applied: $ip"
                return 0
            fi
        fi
    fi

    print_status "fail" "Failed to apply Netplan configuration"
    return 1
}

# Function to apply static IP using /etc/network/interfaces (Debian legacy)
apply_static_ip_interfaces() {
    local interface=$1
    local ip=$2
    local netmask=$3
    local gateway=$4
    local dns=$5

    print_status "progress" "Configuring static IP via /etc/network/interfaces..."

    local interfaces_file="/etc/network/interfaces"
    local backup_file="/etc/network/interfaces.backup.$(date +%s)"

    # Backup current configuration
    sudo cp "$interfaces_file" "$backup_file" 2>/dev/null

    # Create new configuration
    sudo tee "$interfaces_file" > /dev/null << EOF
# Kekeli-HomeCloud Static IP Configuration
# Generated on $(date)
# Backup saved to: $backup_file

auto lo
iface lo inet loopback

auto $interface
iface $interface inet static
    address $ip
    netmask $(cidr_to_netmask $netmask)
    gateway $gateway
    dns-nameservers $dns
EOF

    print_status "pass" "Configuration written to $interfaces_file"
    print_status "info" "Backup saved to $backup_file"
    print_status "warn" "Network restart required. Run: sudo systemctl restart networking"

    return 0
}

# Helper function to convert CIDR to netmask
cidr_to_netmask() {
    local cidr=$1
    local mask=""
    local full_octets=$((cidr / 8))
    local partial_octet=$((cidr % 8))

    for ((i=0; i<4; i++)); do
        if [ $i -lt $full_octets ]; then
            mask+="255"
        elif [ $i -eq $full_octets ]; then
            mask+="$((256 - 2 ** (8 - partial_octet)))"
        else
            mask+="0"
        fi
        [ $i -lt 3 ] && mask+="."
    done

    echo "$mask"
}

# =============================================================================
# INITIALIZATION
# =============================================================================

log_message "INIT" "Network detection utilities loaded"