#!/bin/bash
# setup-mobile.sh - Mobile connectivity setup for Kekeli-HomeCloud
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/error-handling.sh"
source "$UTILS_DIR/network-detection.sh"

# =============================================================================
# MOBILE SETUP CONFIGURATION
# =============================================================================

readonly MOBILE_SETUP_GUIDE_FILE="$KEKELI_CONFIG_DIR/mobile-setup-guide.html"
readonly QR_CODE_DIR="$KEKELI_CONFIG_DIR/qr-codes"

# =============================================================================
# MAIN MOBILE SETUP FUNCTIONS
# =============================================================================

# Function to setup mobile connectivity
setup_mobile_connectivity() {
    print_section "📱" "Kekeli-HomeCloud Mobile Setup"

    print_status "info" "Configuring mobile device connectivity"
    echo -e "${CYAN}This will optimize your Nextcloud for mobile device access.${NC}"
    echo ""

    set_operation "Mobile Connectivity Setup"

    # Step 1: Validate Nextcloud deployment
    if ! validate_nextcloud_for_mobile; then
        complete_operation "failed"
        return 1
    fi

    # Step 2: Configure mobile-optimized settings
    if ! configure_mobile_optimizations; then
        complete_operation "failed"
        return 1
    fi

    # Step 3: Generate mobile access information
    if ! generate_mobile_access_info; then
        complete_operation "failed"
        return 1
    fi

    # Step 4: Create QR codes for easy setup
    if ! generate_mobile_qr_codes; then
        complete_operation "failed"
        return 1
    fi

    # Step 5: Create mobile setup guide
    if ! create_mobile_setup_guide; then
        complete_operation "failed"
        return 1
    fi

    # Step 6: Test mobile connectivity
    if ! test_mobile_connectivity; then
        complete_operation "failed"
        return 1
    fi

    complete_operation "success"
    return 0
}

# Function to validate Nextcloud for mobile setup
validate_nextcloud_for_mobile() {
    print_subsection "Validating Nextcloud for Mobile Setup"

    local validation_passed=true

    # Check if Nextcloud containers are running
    local containers=("kekeli-nextcloud-app" "kekeli-nextcloud-db" "kekeli-nextcloud-redis")
    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            print_status "pass" "Container running: $container"
        else
            print_status "fail" "Container not running: $container"
            validation_passed=false
        fi
    done

    # Check Nextcloud accessibility
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")
    if curl -f "http://localhost:$nextcloud_port/status.php" >/dev/null 2>&1; then
        print_status "pass" "Nextcloud web interface accessible"
    else
        print_status "fail" "Nextcloud web interface not accessible"
        validation_passed=false
    fi

    # Check network configuration
    local mobile_urls=$(load_config "MOBILE_ACCESS_URLS")
    if [ -n "$mobile_urls" ]; then
        print_status "pass" "Mobile access URLs configured"
    else
        print_status "warn" "No mobile access URLs found - will generate new ones"
    fi

    if [ "$validation_passed" = true ]; then
        print_status "pass" "Nextcloud validation for mobile setup successful"
        return 0
    else
        print_status "fail" "Nextcloud validation failed"
        return 1
    fi
}

# Function to configure mobile optimizations
configure_mobile_optimizations() {
    print_subsection "Configuring Mobile Optimizations"

    # Configure trusted domains for mobile access
    if ! configure_trusted_domains_mobile; then
        return 1
    fi

    # Enable mobile-friendly apps
    if ! enable_mobile_apps; then
        return 1
    fi

    # Configure mobile performance settings
    if ! configure_mobile_performance; then
        return 1
    fi

    # Configure mobile security settings
    if ! configure_mobile_security; then
        return 1
    fi

    print_status "pass" "Mobile optimizations configured"
    return 0
}

# Function to configure trusted domains for mobile
configure_trusted_domains_mobile() {
    print_status "progress" "Configuring trusted domains for mobile access..."

    local trusted_domains=$(load_config "TRUSTED_DOMAINS")
    if [ -z "$trusted_domains" ]; then
        print_status "warn" "No trusted domains configured"
        return 1
    fi

    # Clear existing trusted domains
    docker exec kekeli-nextcloud-app php occ config:system:delete trusted_domains >/dev/null 2>&1 || true

    # Add each domain with proper indexing
    local domain_index=0
    IFS=',' read -ra DOMAIN_ARRAY <<< "$trusted_domains"

    for domain in "${DOMAIN_ARRAY[@]}"; do
        domain=$(echo "$domain" | xargs)  # Trim whitespace
        if [ -n "$domain" ]; then
            if docker exec kekeli-nextcloud-app php occ config:system:set trusted_domains $domain_index --value="$domain" >/dev/null 2>&1; then
                print_status "pass" "Added trusted domain: $domain"
            else
                print_status "warn" "Failed to add trusted domain: $domain"
            fi
            ((domain_index++))
        fi
    done

    return 0
}

# Function to enable mobile-friendly apps
enable_mobile_apps() {
    print_status "progress" "Enabling mobile-friendly applications..."

    local mobile_apps=(
        "files"
        "activity"
        "notifications"
        "photos"
        "calendar"
        "contacts"
        "notes"
        "tasks"
    )

    local enabled_count=0
    for app in "${mobile_apps[@]}"; do
        if docker exec kekeli-nextcloud-app php occ app:enable "$app" >/dev/null 2>&1; then
            print_status "pass" "Enabled app: $app"
            ((enabled_count++))
        else
            print_status "info" "App not available or already enabled: $app"
        fi
    done

    if [ $enabled_count -gt 0 ]; then
        print_status "pass" "Enabled $enabled_count mobile-friendly apps"
    fi

    return 0
}

# Function to configure mobile performance settings
configure_mobile_performance() {
    print_status "progress" "Configuring mobile performance settings..."

    # Configure mobile-optimized settings
    local mobile_configs=(
        "config:system:set default_phone_region --value=US"
        "config:system:set memcache.local --value=\\\\OC\\\\Memcache\\\\APCu"
        "config:system:set memcache.distributed --value=\\\\OC\\\\Memcache\\\\Redis"
        "config:system:set memcache.locking --value=\\\\OC\\\\Memcache\\\\Redis"
        "config:system:set redis host --value=redis"
        "config:system:set redis port --value=6379"
        "config:system:set redis password --value=$(load_config "REDIS_PASSWORD")"
    )

    for config in "${mobile_configs[@]}"; do
        if docker exec kekeli-nextcloud-app php occ $config >/dev/null 2>&1; then
            print_status "pass" "Applied config: $(echo "$config" | cut -d' ' -f3)"
        else
            print_status "warn" "Failed to apply config: $(echo "$config" | cut -d' ' -f3)"
        fi
    done

    # Configure file scanning for mobile
    docker exec kekeli-nextcloud-app php occ config:system:set filesystem_check_changes --value=1 >/dev/null 2>&1 || true

    return 0
}

# Function to configure mobile security settings
configure_mobile_security() {
    print_status "progress" "Configuring mobile security settings..."

    # Configure session settings for mobile
    local security_configs=(
        "config:system:set session_lifetime --value=86400"
        "config:system:set session_keepalive --value=true"
        "config:system:set remember_login_cookie_lifetime --value=2592000"
    )

    for config in "${security_configs[@]}"; do
        docker exec kekeli-nextcloud-app php occ $config >/dev/null 2>&1 || true
    done

    return 0
}

# Function to generate mobile access information
generate_mobile_access_info() {
    print_subsection "Generating Mobile Access Information"

    # Get or generate mobile access URLs
    local mobile_urls=$(load_config "MOBILE_ACCESS_URLS")
    if [ -z "$mobile_urls" ]; then
        # Generate mobile URLs from network detection
        if ! configure_mobile_network_access; then
            return 1
        fi
        mobile_urls=$(load_config "MOBILE_ACCESS_URLS")
    fi

    if [ -z "$mobile_urls" ]; then
        print_status "error" "Failed to generate mobile access URLs"
        return 1
    fi

    # Display mobile access information
    echo ""
    echo -e "${CYAN}📱 Mobile Access Information:${NC}"
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            echo -e "  🌐 ${GREEN}$url${NC}"
        fi
    done <<< "$mobile_urls"

    # Get admin credentials for mobile setup
    local admin_user=$(load_config "ADMIN_USER")
    local admin_password=$(load_config "ADMIN_PASSWORD")

    save_config "MOBILE_ADMIN_USER" "$admin_user"
    save_config "MOBILE_ADMIN_PASSWORD" "$admin_password"

    print_status "pass" "Mobile access information generated"
    return 0
}

# Function to generate QR codes for mobile setup
generate_mobile_qr_codes() {
    print_subsection "Generating QR Codes for Mobile Setup"

    # Check if qrencode is available
    if ! command_exists qrencode; then
        print_status "warn" "qrencode not available - installing..."
        if safe_execute "sudo apt update && sudo apt install -y qrencode" "Install qrencode" false; then
            print_status "pass" "qrencode installed successfully"
        else
            print_status "warn" "Could not install qrencode - QR codes will not be generated"
            return 0  # Don't fail the entire mobile setup
        fi
    fi

    # Create QR code directory
    if ! create_directory "$QR_CODE_DIR"; then
        print_status "warn" "Could not create QR code directory"
        return 0
    fi

    local mobile_urls=$(load_config "MOBILE_ACCESS_URLS")
    local qr_count=0

    # Generate QR codes for mobile URLs
    while IFS= read -r url; do
        if [ -n "$url" ] && [ $qr_count -lt 3 ]; then  # Limit to 3 QR codes
            local filename="mobile_access_$((qr_count + 1)).png"
            local qr_file="$QR_CODE_DIR/$filename"

            if qrencode -s 6 -o "$qr_file" "$url" 2>/dev/null; then
                print_status "pass" "QR code generated: $filename"
                ((qr_count++))

                # Also generate a text file with the URL
                echo "$url" > "${qr_file%.png}.txt"
            else
                print_status "warn" "Failed to generate QR code for: $url"
            fi
        fi
    done <<< "$mobile_urls"

    if [ $qr_count -gt 0 ]; then
        print_status "pass" "Generated $qr_count QR codes for mobile setup"
        save_config "QR_CODES_GENERATED" "true"
    else
        print_status "warn" "No QR codes generated"
    fi

    return 0
}

# Function to create mobile setup guide
create_mobile_setup_guide() {
    print_subsection "Creating Mobile Setup Guide"

    local mobile_urls=$(load_config "MOBILE_ACCESS_URLS")
    local admin_user=$(load_config "MOBILE_ADMIN_USER")
    local qr_generated=$(load_config "QR_CODES_GENERATED" "false")
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")

    cat > "$MOBILE_SETUP_GUIDE_FILE" << EOF
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kekeli-HomeCloud Mobile Setup Guide</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 800px; margin: 0 auto; background: white; padding: 30px; border-radius: 12px; box-shadow: 0 4px 20px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 3px solid #007acc; padding-bottom: 20px; margin-bottom: 30px; }
        .section { margin-bottom: 30px; padding: 20px; background: #f8f9fa; border-radius: 8px; border-left: 4px solid #007acc; }
        .url-list { background: white; padding: 15px; border-radius: 8px; border: 1px solid #ddd; }
        .url-item { padding: 10px; margin: 5px 0; background: #e3f2fd; border-radius: 6px; font-family: monospace; }
        .credentials { background: #fff3e0; border: 2px solid #ff9800; border-radius: 8px; padding: 15px; margin: 15px 0; }
        .step { background: white; margin: 10px 0; padding: 15px; border-radius: 8px; border-left: 3px solid #4caf50; }
        .warning { background: #ffebee; border: 1px solid #f44336; border-radius: 8px; padding: 15px; margin: 15px 0; }
        .qr-section { text-align: center; background: white; padding: 20px; border-radius: 8px; }
        h1 { color: #007acc; margin: 0; }
        h2 { color: #333; margin-top: 0; }
        .icon { font-size: 1.2em; margin-right: 8px; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📱 Kekeli-HomeCloud Mobile Setup</h1>
            <p>Your personal cloud storage is ready for mobile access!</p>
        </div>

        <div class="section">
            <h2>🌐 Access URLs</h2>
            <p>Use any of these URLs to access your Nextcloud from your mobile device:</p>
            <div class="url-list">
EOF

    # Add mobile URLs to the guide
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            echo "                <div class=\"url-item\">🔗 $url</div>" >> "$MOBILE_SETUP_GUIDE_FILE"
        fi
    done <<< "$mobile_urls"

    cat >> "$MOBILE_SETUP_GUIDE_FILE" << EOF
            </div>
        </div>

        <div class="section">
            <h2>🔐 Login Credentials</h2>
            <div class="credentials">
                <strong>Username:</strong> $admin_user<br>
                <strong>Password:</strong> <span style="font-family: monospace; background: #f0f0f0; padding: 2px 4px; border-radius: 3px;">$(load_config "MOBILE_ADMIN_PASSWORD")</span>
            </div>
        </div>

        <div class="section">
            <h2>📋 Mobile App Setup Instructions</h2>

            <div class="step">
                <h3>📱 Step 1: Download the Nextcloud App</h3>
                <p><strong>Android:</strong> Download from Google Play Store</p>
                <p><strong>iPhone:</strong> Download from Apple App Store</p>
                <p>Search for "Nextcloud" (by Nextcloud GmbH)</p>
            </div>

            <div class="step">
                <h3>🌐 Step 2: Connect to Your Server</h3>
                <p>1. Open the Nextcloud app</p>
                <p>2. When prompted for server address, enter one of the URLs above</p>
                <p>3. Enter your username and password from the credentials section</p>
                <p>4. Tap "Connect" or "Login"</p>
            </div>

            <div class="step">
                <h3>⚙️ Step 3: Configure Sync Settings</h3>
                <p>1. Choose which folders to sync automatically</p>
                <p>2. Enable photo/video upload if desired</p>
                <p>3. Configure offline access for important files</p>
            </div>
        </div>
EOF

    # Add QR code section if available
    if [ "$qr_generated" = "true" ]; then
        cat >> "$MOBILE_SETUP_GUIDE_FILE" << EOF
        <div class="section">
            <h2>📷 QR Code Quick Setup</h2>
            <div class="qr-section">
                <p>Scan with your mobile device's camera or QR code reader:</p>
                <p><strong>QR codes saved to:</strong> $QR_CODE_DIR/</p>
                <p>Each QR code contains a server URL for quick setup.</p>
            </div>
        </div>
EOF
    fi

    cat >> "$MOBILE_SETUP_GUIDE_FILE" << EOF
        <div class="section">
            <h2>🔧 Troubleshooting</h2>

            <div class="warning">
                <h3>⚠️ Can't Connect?</h3>
                <p>• Make sure your mobile device is on the same WiFi network</p>
                <p>• Try each URL in the list above</p>
                <p>• Check that port $nextcloud_port is not blocked by your router</p>
                <p>• Ensure Nextcloud containers are running</p>
            </div>

            <div class="step">
                <h3>🔍 Common Solutions</h3>
                <p><strong>Connection timeout:</strong> Try the different URLs listed above</p>
                <p><strong>Certificate errors:</strong> This is normal for local installations - proceed anyway</p>
                <p><strong>Login fails:</strong> Double-check username and password</p>
                <p><strong>Sync issues:</strong> Check available storage space on your device</p>
            </div>
        </div>

        <div class="section">
            <h2>💡 Tips for Mobile Use</h2>
            <div class="step">
                <p>• Enable automatic photo upload to backup your photos</p>
                <p>• Use offline sync for files you need when traveling</p>
                <p>• Set up folder sharing to collaborate with family</p>
                <p>• Enable notifications to stay updated on shared files</p>
            </div>
        </div>

        <div class="footer">
            <p>Generated by Kekeli-HomeCloud Easy Installer on $(date)</p>
            <p>Keep this guide handy for setting up additional devices!</p>
        </div>
    </div>
</body>
</html>
EOF

    if [ -f "$MOBILE_SETUP_GUIDE_FILE" ]; then
        print_status "pass" "Mobile setup guide created: $MOBILE_SETUP_GUIDE_FILE"
        return 0
    else
        print_status "fail" "Failed to create mobile setup guide"
        return 1
    fi
}

# Function to test mobile connectivity
test_mobile_connectivity() {
    print_subsection "Testing Mobile Connectivity"

    local test_passed=true
    local mobile_urls=$(load_config "MOBILE_ACCESS_URLS")

    if [ -z "$mobile_urls" ]; then
        print_status "fail" "No mobile URLs to test"
        return 1
    fi

    # Test each mobile URL
    while IFS= read -r url; do
        if [ -n "$url" ]; then
            print_status "progress" "Testing URL: $url"

            if curl -f -s --max-time 10 "$url/status.php" >/dev/null 2>&1; then
                print_status "pass" "URL accessible: $url"
            elif curl -f -s --max-time 10 "$url/" >/dev/null 2>&1; then
                print_status "pass" "URL accessible (basic): $url"
            else
                print_status "warn" "URL not accessible: $url"
                # Don't fail completely - other URLs might work
            fi
        fi
    done <<< "$mobile_urls"

    # Test Nextcloud app functionality
    print_status "progress" "Testing Nextcloud core functionality..."
    if docker exec kekeli-nextcloud-app php occ status >/dev/null 2>&1; then
        print_status "pass" "Nextcloud core functionality working"
    else
        print_status "warn" "Nextcloud core functionality may have issues"
        test_passed=false
    fi

    # Test trusted domains configuration
    print_status "progress" "Verifying trusted domains configuration..."
    local trusted_domains_count=$(docker exec kekeli-nextcloud-app php occ config:system:get trusted_domains 2>/dev/null | wc -l)
    if [ "$trusted_domains_count" -gt 0 ]; then
        print_status "pass" "Trusted domains configured ($trusted_domains_count entries)"
    else
        print_status "warn" "No trusted domains configured"
    fi

    if [ "$test_passed" = true ]; then
        print_status "pass" "Mobile connectivity tests completed"
        return 0
    else
        print_status "warn" "Some mobile connectivity tests had issues"
        return 1
    fi
}

# Function to show mobile setup summary
show_mobile_setup_summary() {
    print_section "📱" "Mobile Setup Summary"

    local mobile_urls=$(load_config "MOBILE_ACCESS_URLS")
    local admin_user=$(load_config "MOBILE_ADMIN_USER")
    local qr_generated=$(load_config "QR_CODES_GENERATED" "false")

    echo -e "${GREEN}✅ Mobile Setup Complete!${NC}"
    echo ""

    echo -e "${CYAN}📱 Mobile Access URLs:${NC}"
    if [ -n "$mobile_urls" ]; then
        while IFS= read -r url; do
            if [ -n "$url" ]; then
                echo -e "  🌐 ${GREEN}$url${NC}"
            fi
        done <<< "$mobile_urls"
    else
        echo -e "  ${YELLOW}No mobile URLs configured${NC}"
    fi
    echo ""

    echo -e "${CYAN}🔐 Login Credentials:${NC}"
    echo -e "  Username: ${GREEN}$admin_user${NC}"
    echo -e "  Password: ${GREEN}$(load_config "MOBILE_ADMIN_PASSWORD")${NC}"
    echo ""

    echo -e "${CYAN}📚 Setup Resources:${NC}"
    echo -e "  📖 Setup Guide: ${GREEN}$MOBILE_SETUP_GUIDE_FILE${NC}"

    if [ "$qr_generated" = "true" ]; then
        echo -e "  📷 QR Codes: ${GREEN}$QR_CODE_DIR/${NC}"
    fi
    echo ""

    echo -e "${CYAN}📲 Next Steps:${NC}"
    echo -e "  1. Download Nextcloud app from your app store"
    echo -e "  2. Use any URL above to connect"
    echo -e "  3. Login with the credentials shown"
    echo -e "  4. Enjoy your personal cloud! 🎉"
    echo ""

    print_status "pass" "Your mobile setup is ready!"
}

# Function to troubleshoot mobile connectivity
troubleshoot_mobile() {
    print_section "🔍" "Mobile Connectivity Troubleshooting"

    # Check container status
    print_status "progress" "Checking container status..."
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep kekeli

    # Check network connectivity
    echo ""
    print_status "progress" "Testing network connectivity..."
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")

    local test_urls=("localhost:$nextcloud_port" "127.0.0.1:$nextcloud_port")
    local local_ips=$(get_local_ips)

    while IFS= read -r ip; do
        if [ -n "$ip" ]; then
            test_urls+=("$ip:$nextcloud_port")
        fi
    done <<< "$local_ips"

    for url in "${test_urls[@]}"; do
        if curl -f -s --max-time 5 "http://$url/status.php" >/dev/null 2>&1; then
            print_status "pass" "✅ $url - Accessible"
        else
            print_status "fail" "❌ $url - Not accessible"
        fi
    done

    # Check trusted domains
    echo ""
    print_status "progress" "Checking trusted domains..."
    docker exec kekeli-nextcloud-app php occ config:system:get trusted_domains 2>/dev/null || {
        print_status "warn" "Could not retrieve trusted domains"
    }

    # Check logs for errors
    echo ""
    print_status "progress" "Recent Nextcloud logs (last 10 lines):"
    docker logs --tail 10 kekeli-nextcloud-app 2>/dev/null || {
        print_status "warn" "Could not retrieve logs"
    }
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

# Help function
show_help() {
    echo "Kekeli-HomeCloud Mobile Setup"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -s, --setup       Setup mobile connectivity"
    echo "  -t, --test        Test mobile connectivity"
    echo "  --troubleshoot    Troubleshoot mobile issues"
    echo "  --summary         Show mobile setup summary"
    echo "  --guide           Show path to mobile setup guide"
    echo ""
    echo "Examples:"
    echo "  $0 --setup       # Setup mobile connectivity"
    echo "  $0 --test        # Test mobile access"
    echo "  $0 --summary     # Show setup summary"
}

# Main function
main() {
    local setup_mode=false
    local test_mode=false
    local troubleshoot_mode=false
    local summary_mode=false
    local guide_mode=false

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
            --troubleshoot)
                troubleshoot_mode=true
                shift
                ;;
            --summary)
                summary_mode=true
                shift
                ;;
            --guide)
                guide_mode=true
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
    set_error_context "Mobile Setup"

    # Handle specific modes
    if [ "$summary_mode" = true ]; then
        show_mobile_setup_summary
        exit 0
    fi

    if [ "$guide_mode" = true ]; then
        if [ -f "$MOBILE_SETUP_GUIDE_FILE" ]; then
            echo "$MOBILE_SETUP_GUIDE_FILE"
        else
            print_status "error" "Mobile setup guide not found. Run setup first."
            exit 1
        fi
        exit 0
    fi

    if [ "$test_mode" = true ]; then
        if test_mobile_connectivity; then
            print_status "pass" "Mobile connectivity test passed"
            exit 0
        else
            print_status "fail" "Mobile connectivity test failed"
            exit 1
        fi
    fi

    if [ "$troubleshoot_mode" = true ]; then
        troubleshoot_mobile
        exit 0
    fi

    # Default: Setup mode
    if [ "$setup_mode" = true ] || [ $# -eq 0 ]; then
        if setup_mobile_connectivity; then
            echo ""
            show_mobile_setup_summary
            exit 0
        else
            print_status "fail" "Mobile setup failed"
            exit 1
        fi
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi