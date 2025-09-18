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

    # Method 1: Check default route
    primary_interface=$(ip route show default | awk '/default/ {print $5}' | head -1)

    if [ -n "$primary_interface" ]; then
        echo "$primary_interface"
        return 0
    fi

    # Method 2: Find first non-loopback interface with IP
    primary_interface=$(ip addr show | grep -E '^[0-9]+:' | grep -v lo | awk -F': ' '{print $2}' | head -1)

    if [ -n "$primary_interface" ]; then
        echo "$primary_interface"
        return 0
    fi

    return 1
}

# Function to get IP address of specific interface
get_interface_ip() {
    local interface=$1
    ip addr show "$interface" 2>/dev/null | grep 'inet ' | awk '{print $2}' | cut -d'/' -f1 | head -1
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
    local primary_interface
    local primary_ip
    local windows_ip

    # Get primary interface and IP
    primary_interface=$(detect_primary_interface)
    if [ -n "$primary_interface" ]; then
        primary_ip=$(get_interface_ip "$primary_interface")
        if [ -n "$primary_ip" ]; then
            access_ips+=("$primary_ip|Primary interface ($primary_interface)")
            print_status "pass" "Primary network IP: $primary_ip ($primary_interface)"
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
# INITIALIZATION
# =============================================================================

log_message "INIT" "Network detection utilities loaded"