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

    # Step 0: Check for IP address changes and refresh configuration
    print_status "progress" "Checking for IP address changes..."
    if ! validate_current_network_config; then
        print_status "warn" "Network configuration issues detected"
        if handle_ip_change false; then
            print_status "pass" "Network configuration updated"
        else
            print_status "warn" "Network configuration issues remain - continuing with mobile setup"
        fi
    else
        print_status "pass" "Network configuration is current"
    fi

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
            # Check if Nextcloud is ready first
            if docker exec kekeli-nextcloud-app php occ status --output json 2>/dev/null | grep -q '"installed":true'; then
                if docker exec kekeli-nextcloud-app php occ config:system:set trusted_domains $domain_index --value="$domain" >/dev/null 2>&1; then
                    print_status "pass" "Added trusted domain: $domain"
                else
                    print_status "warn" "Failed to add trusted domain: $domain"
                fi
            else
                print_status "info" "Skipping trusted domain configuration - Nextcloud not fully installed yet"
                print_status "info" "You can configure trusted domains manually in Nextcloud admin settings"
                return 0
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
        "memories"
        "calendar"
        "contacts"
        "notes"
        "tasks"
    )

    # Check if Nextcloud is ready first
    if ! docker exec kekeli-nextcloud-app php occ status --output json 2>/dev/null | grep -q '"installed":true'; then
        print_status "info" "Skipping app configuration - Nextcloud not fully installed yet"
        print_status "info" "You can enable mobile apps manually in Nextcloud app store"
        return 0
    fi

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

    # Check if Nextcloud is ready first
    if ! docker exec kekeli-nextcloud-app php occ status --output json 2>/dev/null | grep -q '"installed":true'; then
        print_status "info" "Skipping performance configuration - Nextcloud not fully installed yet"
        print_status "info" "Performance settings can be configured manually after setup"
        return 0
    fi

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

# Function to configure mobile network access
configure_mobile_network_access() {
    print_status "progress" "Generating mobile network access URLs..."

    # Get preferred network configuration (handles MOBILE_URL priority)
    local preferred_config
    if preferred_config=$(get_preferred_network_config); then
        local preferred_ip=$(echo "$preferred_config" | cut -d'|' -f1)
        local preferred_port=$(echo "$preferred_config" | cut -d'|' -f2)
        local preferred_url=$(echo "$preferred_config" | cut -d'|' -f3)
        local config_source=$(echo "$preferred_config" | cut -d'|' -f4)

        # Generate mobile access URLs with preferred URL first
        local mobile_urls=()

        # Primary mobile access URL (MOBILE_URL or auto-detected)
        mobile_urls+=("$preferred_url")

        # Add localhost for local debugging
        local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
        if [ "$preferred_url" != "http://localhost:$nextcloud_port" ]; then
            mobile_urls+=("http://localhost:$nextcloud_port")
        fi

        # Save mobile access URLs
        save_config "MOBILE_ACCESS_URLS" "$(printf '%s\n' "${mobile_urls[@]}")"

        print_status "pass" "Generated mobile access URLs (source: $config_source):"
        for url in "${mobile_urls[@]}"; do
            print_status "info" "  📱 $url"
        done

        # Save primary URL for easy access
        save_config "PRIMARY_MOBILE_URL" "$preferred_url"

        case "$config_source" in
            "user_mobile_url")
                print_status "info" "Using your MOBILE_URL setting from .env file"
                print_status "info" "Family bookmark: $preferred_url"
                ;;
            "auto_detected")
                print_status "info" "Auto-detected network configuration"
                print_status "warn" "Consider setting MOBILE_URL in .env for consistency"
                ;;
            "localhost_fallback")
                print_status "warn" "Using localhost fallback - limited to local access only"
                print_status "info" "Set MOBILE_URL in .env file for family mobile access"
                ;;
        esac

        return 0
    else
        print_status "warn" "Could not determine network configuration"
        return 1
    fi
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

    # TODO: QR code generation is temporarily disabled to avoid package installation issues
    # Future implementation should use:
    # 1. Direct apt commands with DEBIAN_FRONTEND=noninteractive
    # 2. Alternative QR generation methods (online APIs, Python qrcode)
    # 3. Optional/configurable QR code generation

    print_status "info" "QR code generation skipped - focusing on core mobile functionality"
    print_status "info" "Mobile URLs will be available in the setup guide"

    # Set QR codes as not generated
    save_config "QR_CODES_GENERATED" "false"

    print_status "pass" "QR code generation completed (skipped)"
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
            <h2>🌐 Host Network Configuration</h2>
EOF

    # Check if HOST_IP is configured
    local configured_host_ip=$(load_config "HOST_IP")
    if [ -n "$configured_host_ip" ]; then
        cat >> "$MOBILE_SETUP_GUIDE_FILE" << EOF
            <div style="background: #e8f5e9; border: 2px solid #4caf50; border-radius: 8px; padding: 15px; margin: 15px 0;">
                <h3 style="color: #2e7d32; margin-top: 0;">✅ Static IP Configured</h3>
                <p><strong>Your Host IP:</strong> <span style="font-family: monospace; font-size: 1.1em; color: #1b5e20;">$configured_host_ip</span></p>
                <p style="margin-bottom: 0;">
                    <strong>Benefits:</strong> Your Nextcloud URL will remain <strong>$configured_host_ip:$nextcloud_port</strong> even after system reboots.
                    Family members can bookmark this URL and it will always work!
                </p>
            </div>
            <p style="color: #666; font-size: 0.9em;">
                <strong>How it works:</strong> The installer configured your system to use <code>$configured_host_ip</code> as a static IP address.
                This ensures consistent mobile access without needing to update apps or bookmarks after reboots.
            </p>
EOF
    else
        cat >> "$MOBILE_SETUP_GUIDE_FILE" << EOF
            <div style="background: #fff3e0; border: 2px solid #ff9800; border-radius: 8px; padding: 15px; margin: 15px 0;">
                <h3 style="color: #e65100; margin-top: 0;">⚠️ Dynamic IP (DHCP)</h3>
                <p>Your system is using DHCP (dynamic IP assignment). Your IP address may change after reboots.</p>
                <p style="margin-bottom: 0;">
                    <strong>Recommendation:</strong> Set <code>HOST_IP=192.168.1.98</code> (your desired IP) in the <code>.env</code> file
                    and rerun the networking setup for consistent family access.
                </p>
            </div>
EOF
    fi

    cat >> "$MOBILE_SETUP_GUIDE_FILE" << EOF
        </div>

        <div class="section">
            <h2>🔧 Docker Network Configuration</h2>
            <p>Your Nextcloud uses a dedicated Docker network with static IP addresses for reliability:</p>
            <div class="url-list">
                <div class="url-item">🌐 Network: kekeli-network (172.20.0.0/16)</div>
                <div class="url-item">📍 Gateway: 172.20.0.1</div>
                <div class="url-item">🗄️ Database: 172.20.0.2</div>
                <div class="url-item">⚡ Redis Cache: 172.20.0.3</div>
                <div class="url-item">☁️ Nextcloud App: 172.20.0.4</div>
            </div>
            <p style="margin-top: 10px; font-size: 0.9em; color: #666;">
                <strong>Benefits:</strong> Static IPs ensure consistent container networking,
                easier troubleshooting, and reliable mobile connectivity across container restarts.
            </p>
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

        <div class="section">
            <h2>📸 Family Photo Management with Memories</h2>
            <p>Your Nextcloud includes the <strong>Memories</strong> app - a modern photo gallery for family sharing!</p>

            <div class="step">
                <h3>🖼️ What is Memories?</h3>
                <p>• Fast, modern photo gallery similar to Google Photos</p>
                <p>• Automatic photo organization by date and location</p>
                <p>• Face recognition and smart photo grouping</p>
                <p>• Timeline view for easy browsing</p>
                <p>• Perfect for family photo sharing and management</p>
            </div>

            <div class="step">
                <h3>📱 Using Memories on Mobile</h3>
                <p>1. <strong>Access via Web:</strong> Open your Nextcloud URL in mobile browser</p>
                <p>2. <strong>Navigate:</strong> Tap the "Memories" app icon in the app menu</p>
                <p>3. <strong>Browse:</strong> View your photos in a beautiful timeline</p>
                <p>4. <strong>Upload:</strong> Use the Nextcloud mobile app to auto-upload photos</p>
                <p>5. <strong>Share:</strong> Create shared albums for family members</p>
            </div>

            <div class="step">
                <h3>👨‍👩‍👧‍👦 Family Photo Workflow</h3>
                <p>• <strong>Auto-upload:</strong> Configure Nextcloud app to automatically upload photos</p>
                <p>• <strong>Organize:</strong> Memories automatically sorts photos by date and creates albums</p>
                <p>• <strong>Share:</strong> Create family albums that everyone can access</p>
                <p>• <strong>Privacy:</strong> All photos stay on your home server - no cloud uploads!</p>
                <p>• <strong>Access:</strong> View from any device using your Nextcloud URLs above</p>
            </div>
        </div>
EOF

    # QR code section removed - focusing on core mobile functionality
    # Future versions may include QR codes with improved installation methods

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
    echo "  --check-ip        Check network configuration and IP changes"
    echo "  --update-ip       Update mobile URLs if IP has changed"
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
    local check_ip_mode=false
    local update_ip_mode=false

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
            --check-ip)
                check_ip_mode=true
                shift
                ;;
            --update-ip)
                update_ip_mode=true
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

    if [ "$check_ip_mode" = true ]; then
        if validate_current_network_config; then
            print_status "pass" "Network configuration is current and valid"
            exit 0
        else
            print_status "warn" "Network configuration issues detected"
            if handle_ip_change false; then
                print_status "pass" "Network configuration has been updated"
                exit 0
            else
                print_status "fail" "Network configuration issues could not be resolved"
                exit 1
            fi
        fi
    fi

    if [ "$update_ip_mode" = true ]; then
        if handle_ip_change true; then
            print_status "pass" "Mobile configuration updated successfully"
            # Re-run mobile setup to regenerate mobile guide with new URLs
            if setup_mobile_connectivity; then
                print_status "pass" "Mobile setup refreshed with new IP configuration"
                exit 0
            else
                print_status "warn" "IP updated but mobile setup had issues"
                exit 1
            fi
        else
            print_status "fail" "Failed to update mobile configuration"
            exit 1
        fi
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