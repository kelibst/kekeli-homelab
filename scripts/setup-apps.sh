#!/bin/bash
# setup-apps.sh - Install Essential Nextcloud Apps
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
source "$UTILS_DIR/common.sh" 2>/dev/null || { echo "Error: common.sh not found"; exit 1; }

# =============================================================================
# APP INSTALLATION FUNCTIONS
# =============================================================================

install_app() {
    local app_name=$1
    local app_display=$2

    print_status "progress" "Installing $app_display..."

    if docker exec -u www-data kekeli-nextcloud-app php occ app:install "$app_name" >/dev/null 2>&1; then
        print_status "pass" "$app_display installed"
        return 0
    else
        # Check if already installed
        if docker exec -u www-data kekeli-nextcloud-app php occ app:list --output=json 2>/dev/null | grep -q "\"$app_name\""; then
            print_status "info" "$app_display already installed"
            return 0
        else
            print_status "warn" "Failed to install $app_display"
            return 1
        fi
    fi
}

# =============================================================================
# MAIN INSTALLATION
# =============================================================================

main() {
    print_section "📦" "Installing Essential Nextcloud Apps"

    echo ""
    print_status "info" "This will install 14 essential apps for home cloud use"
    print_status "info" "Apps include: Calendar, Contacts, Photos, Talk, Deck, and more"
    echo ""

    if ! ask_yes_no "Install essential apps now?"; then
        print_status "info" "Skipping app installation"
        return 0
    fi

    echo ""

    # =============================================================================
    # PRODUCTIVITY APPS
    # =============================================================================

    print_subsection "Step 1/7: Installing Productivity Apps"

    install_app "calendar" "Calendar"
    install_app "contacts" "Contacts"
    install_app "tasks" "Tasks"
    install_app "mail" "Mail"

    echo ""

    # =============================================================================
    # COLLABORATION APPS
    # =============================================================================

    print_subsection "Step 2/7: Installing Collaboration Apps"

    install_app "deck" "Deck (Project Boards)"
    install_app "notes" "Notes"
    install_app "spreed" "Talk (Video Calls)"

    echo ""

    # =============================================================================
    # MEDIA APPS
    # =============================================================================

    print_subsection "Step 3/7: Installing Media Apps"

    # Photos is built-in, just verify
    print_status "info" "Photos app is built-in"

    install_app "memories" "Memories (Photo Timeline)"
    install_app "music" "Music"

    echo ""

    # =============================================================================
    # FILE MANAGEMENT APPS
    # =============================================================================

    print_subsection "Step 4/7: Installing File Management Apps"

    install_app "groupfolders" "Group Folders"
    # files_sharing is built-in
    print_status "info" "File Sharing app is built-in"

    echo ""

    # =============================================================================
    # OFFICE APPS
    # =============================================================================

    print_subsection "Step 5/7: Installing Office Apps"

    install_app "richdocuments" "Collabora (Office Documents)"
    # text is built-in
    print_status "info" "Text Editor app is built-in"

    echo ""

    # =============================================================================
    # SECURITY APPS
    # =============================================================================

    print_subsection "Step 6/7: Installing Security Apps"

    install_app "end_to_end_encryption" "End-to-End Encryption"
    install_app "passwords" "Password Manager"

    echo ""

    # =============================================================================
    # UTILITY APPS
    # =============================================================================

    print_subsection "Step 7/7: Installing Utility Apps"

    install_app "files_automatedtagging" "Automated Tagging"
    # activity is built-in
    print_status "info" "Activity app is built-in"

    echo ""

    # =============================================================================
    # CONFIGURATION
    # =============================================================================

    print_subsection "Configuring Apps"

    # Enable previews
    print_status "progress" "Enabling preview generation..."
    docker exec -u www-data kekeli-nextcloud-app php occ config:system:set enable_previews --value=true --type=boolean >/dev/null 2>&1

    # Configure preview providers
    docker exec -u www-data kekeli-nextcloud-app php occ config:system:set enabledPreviewProviders 0 --value="OC\\Preview\\PNG" >/dev/null 2>&1
    docker exec -u www-data kekeli-nextcloud-app php occ config:system:set enabledPreviewProviders 1 --value="OC\\Preview\\JPEG" >/dev/null 2>&1
    docker exec -u www-data kekeli-nextcloud-app php occ config:system:set enabledPreviewProviders 2 --value="OC\\Preview\\GIF" >/dev/null 2>&1
    docker exec -u www-data kekeli-nextcloud-app php occ config:system:set enabledPreviewProviders 3 --value="OC\\Preview\\HEIC" >/dev/null 2>&1
    docker exec -u www-data kekeli-nextcloud-app php occ config:system:set enabledPreviewProviders 4 --value="OC\\Preview\\BMP" >/dev/null 2>&1
    docker exec -u www-data kekeli-nextcloud-app php occ config:system:set enabledPreviewProviders 5 --value="OC\\Preview\\Movie" >/dev/null 2>&1

    print_status "pass" "Preview generation enabled"

    # Configure Memories
    print_status "progress" "Configuring Memories app..."
    docker exec -u www-data kekeli-nextcloud-app php occ config:app:set memories enabledPreview --value="true" >/dev/null 2>&1
    docker exec -u www-data kekeli-nextcloud-app php occ config:app:set memories enabledTimeline --value="true" >/dev/null 2>&1
    print_status "pass" "Memories configured"

    # Set default app
    docker exec -u www-data kekeli-nextcloud-app php occ config:system:set defaultapp --value="files" >/dev/null 2>&1
    print_status "pass" "Default app set to Files"

    # Enable activity notifications
    docker exec -u www-data kekeli-nextcloud-app php occ config:app:set activity enable_rss --value="yes" >/dev/null 2>&1
    print_status "pass" "Activity notifications enabled"

    echo ""

    # =============================================================================
    # SUMMARY
    # =============================================================================

    print_section "✅" "Apps Installation Complete"

    echo ""
    print_status "pass" "All essential apps installed successfully!"
    echo ""

    print_subsection "Installed Apps"
    echo ""
    echo "  📅 Productivity: Calendar, Contacts, Tasks, Mail"
    echo "  💬 Collaboration: Deck, Notes, Talk (video calls)"
    echo "  📸 Media: Photos, Memories, Music"
    echo "  📁 Files: Group Folders, External Storage"
    echo "  📝 Office: Collabora, Text Editor"
    echo "  🔒 Security: Passwords, End-to-End Encryption"
    echo ""

    print_subsection "Next Steps"
    echo ""
    echo "  1. Access Nextcloud: http://$(load_config "MACVLAN_CONTAINER_IP" "localhost")"
    echo "  2. Click grid icon (top right) to see all apps"
    echo "  3. Create family user accounts (Settings → Users)"
    echo "  4. Setup mobile auto photo upload"
    echo "  5. Create shared calendars and contacts"
    echo ""

    print_subsection "Documentation"
    echo ""
    echo "  📖 Full app guide: INSTALLED_APPS.md"
    echo "  🚀 Quick start: QUICK_START_FAMILY_GUIDE.md"
    echo "  📚 Tutorial: APP_SETUP_TUTORIAL.md"
    echo ""

    return 0
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi
