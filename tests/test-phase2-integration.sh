#!/bin/bash
# test-phase2-integration.sh - Integration tests for Phase 2 components
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source test framework and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SCRIPTS_DIR="$PROJECT_DIR/scripts"
TEMPLATES_DIR="$PROJECT_DIR/templates"

source "$SCRIPT_DIR/test-framework.sh"

# =============================================================================
# PHASE 2 INTEGRATION TESTS
# =============================================================================

# Test: All Phase 2 scripts exist and are executable
test_phase2_scripts_exist() {
    local scripts=(
        "setup-storage.sh"
        "setup-networking.sh"
        "setup-nextcloud.sh"
        "setup-mobile.sh"
    )

    for script in "${scripts[@]}"; do
        if ! assert_file_exists "$SCRIPTS_DIR/$script" "Script missing: $script"; then
            return 1
        fi

        if ! assert_command_success "[ -x '$SCRIPTS_DIR/$script' ]" "Script not executable: $script"; then
            return 1
        fi
    done

    return 0
}

# Test: All templates exist
test_templates_exist() {
    local templates=(
        "docker-compose.yml.template"
        ".env.template"
    )

    for template in "${templates[@]}"; do
        if ! assert_file_exists "$TEMPLATES_DIR/$template" "Template missing: $template"; then
            return 1
        fi
    done

    return 0
}

# Test: Storage setup script help functionality
test_storage_script_help() {
    local output
    output=$("$SCRIPTS_DIR/setup-storage.sh" --help 2>&1)

    if [ $? -ne 0 ]; then
        echo "Storage script help command failed"
        return 1
    fi

    if ! echo "$output" | grep -qi "storage setup"; then
        echo "Storage script help output doesn't contain expected content"
        return 1
    fi

    return 0
}

# Test: Network setup script help functionality
test_network_script_help() {
    local output
    output=$("$SCRIPTS_DIR/setup-networking.sh" --help 2>&1)

    if [ $? -ne 0 ]; then
        echo "Network script help command failed"
        return 1
    fi

    if ! echo "$output" | grep -qi "network configuration"; then
        echo "Network script help output doesn't contain expected content"
        return 1
    fi

    return 0
}

# Test: Nextcloud setup script help functionality
test_nextcloud_script_help() {
    local output
    output=$("$SCRIPTS_DIR/setup-nextcloud.sh" --help 2>&1)

    if [ $? -ne 0 ]; then
        echo "Nextcloud script help command failed"
        return 1
    fi

    if ! echo "$output" | grep -qi "nextcloud deployment"; then
        echo "Nextcloud script help output doesn't contain expected content"
        return 1
    fi

    return 0
}

# Test: Mobile setup script help functionality
test_mobile_script_help() {
    local output
    output=$("$SCRIPTS_DIR/setup-mobile.sh" --help 2>&1)

    if [ $? -ne 0 ]; then
        echo "Mobile script help command failed"
        return 1
    fi

    if ! echo "$output" | grep -qi "mobile setup"; then
        echo "Mobile script help output doesn't contain expected content"
        return 1
    fi

    return 0
}

# Test: Storage detection utilities integration
test_storage_utilities_integration() {
    source "$SCRIPTS_DIR/utils/storage-detection.sh"

    # Test that key storage functions are available
    if ! declare -f detect_storage_devices >/dev/null; then
        echo "detect_storage_devices function not available"
        return 1
    fi

    if ! declare -f detect_optimal_storage >/dev/null; then
        echo "detect_optimal_storage function not available"
        return 1
    fi

    # Test storage device detection (should not fail even if no devices)
    local devices
    devices=$(detect_storage_devices 2>/dev/null) || true

    return 0
}

# Test: Network detection utilities integration
test_network_utilities_integration() {
    source "$SCRIPTS_DIR/utils/network-detection.sh"

    # Test that key network functions are available
    if ! declare -f detect_network_interfaces >/dev/null; then
        echo "detect_network_interfaces function not available"
        return 1
    fi

    if ! declare -f detect_access_ips >/dev/null; then
        echo "detect_access_ips function not available"
        return 1
    fi

    # Test network interface detection
    local interfaces
    interfaces=$(detect_network_interfaces 2>/dev/null) || true

    return 0
}

# Test: Configuration persistence across scripts
test_config_persistence() {
    source "$SCRIPTS_DIR/utils/common.sh"

    # Test configuration save and load
    local test_key="TEST_CONFIG_KEY"
    local test_value="test_value_$(date +%s)"

    # Save configuration
    save_config "$test_key" "$test_value"

    # Load configuration
    local loaded_value
    loaded_value=$(load_config "$test_key")

    if [ "$loaded_value" != "$test_value" ]; then
        echo "Configuration persistence failed: expected '$test_value', got '$loaded_value'"
        return 1
    fi

    # Clean up test configuration
    save_config "$test_key" ""

    return 0
}

# Test: Error handling integration
test_error_handling_integration() {
    source "$SCRIPTS_DIR/utils/error-handling.sh"

    # Test that error handling functions are available
    if ! declare -f handle_critical_error >/dev/null; then
        echo "handle_critical_error function not available"
        return 1
    fi

    if ! declare -f safe_execute >/dev/null; then
        echo "safe_execute function not available"
        return 1
    fi

    # Test error context setting
    set_error_context "Test Context"
    clear_error_context

    return 0
}

# Test: Template processing functionality
test_template_processing() {
    local template_file="$TEMPLATES_DIR/docker-compose.yml.template"
    local test_output="/tmp/test-docker-compose.yml"

    # Read template
    local template_content
    if ! template_content=$(cat "$template_file"); then
        echo "Failed to read Docker Compose template"
        return 1
    fi

    # Test basic template variable replacement
    local test_content="$template_content"
    test_content=${test_content//__NEXTCLOUD_HTTP_PORT__/8080}
    test_content=${test_content//__POSTGRES_DB__/testdb}

    # Write test output
    if ! echo "$test_content" > "$test_output"; then
        echo "Failed to write test template output"
        return 1
    fi

    # Verify replacements worked
    if grep -q "__NEXTCLOUD_HTTP_PORT__" "$test_output"; then
        echo "Template variable replacement failed"
        rm -f "$test_output"
        return 1
    fi

    # Clean up
    rm -f "$test_output"
    return 0
}

# Test: Script interdependencies
test_script_interdependencies() {
    # Test that scripts can source utilities without errors
    if ! bash -c "source '$SCRIPTS_DIR/utils/common.sh'; exit 0" 2>/dev/null; then
        echo "Failed to source common utilities"
        return 1
    fi

    if ! bash -c "source '$SCRIPTS_DIR/utils/error-handling.sh'; exit 0" 2>/dev/null; then
        echo "Failed to source error handling utilities"
        return 1
    fi

    if ! bash -c "source '$SCRIPTS_DIR/utils/storage-detection.sh'; exit 0" 2>/dev/null; then
        echo "Failed to source storage detection utilities"
        return 1
    fi

    if ! bash -c "source '$SCRIPTS_DIR/utils/network-detection.sh'; exit 0" 2>/dev/null; then
        echo "Failed to source network detection utilities"
        return 1
    fi

    return 0
}

# Test: Docker Compose template validation
test_docker_compose_template() {
    local template_file="$TEMPLATES_DIR/docker-compose.yml.template"

    # Check for required services
    local required_services=("nextcloud-db" "redis" "nextcloud")
    for service in "${required_services[@]}"; do
        if ! grep -q "$service:" "$template_file"; then
            echo "Required service '$service' not found in template"
            return 1
        fi
    done

    # Check for required environment variables placeholders
    local required_vars=("__NEXTCLOUD_HTTP_PORT__" "__POSTGRES_DB__" "__ADMIN_USER__")
    for var in "${required_vars[@]}"; do
        if ! grep -q "$var" "$template_file"; then
            echo "Required template variable '$var' not found"
            return 1
        fi
    done

    return 0
}

# Test: Environment template validation
test_env_template() {
    local template_file="$TEMPLATES_DIR/.env.template"

    # Check for required configuration sections
    local required_sections=("NETWORK CONFIGURATION" "DATABASE CONFIGURATION" "NEXTCLOUD CONFIGURATION")
    for section in "${required_sections[@]}"; do
        if ! grep -q "$section" "$template_file"; then
            echo "Required section '$section' not found in .env template"
            return 1
        fi
    done

    return 0
}

# Test: Phase 2 workflow simulation (dry run)
test_phase2_workflow_simulation() {
    source "$SCRIPTS_DIR/utils/common.sh"

    # Simulate storage configuration
    save_config "STORAGE_TYPE" "local"
    save_config "STORAGE_DATA_DIR" "/tmp/test-nextcloud-data"

    # Simulate network configuration
    save_config "NEXTCLOUD_HTTP_PORT" "8080"
    save_config "TRUSTED_DOMAINS" "localhost,127.0.0.1"

    # Simulate deployment configuration
    save_config "ADMIN_USER" "testadmin"
    save_config "POSTGRES_DB" "testdb"

    # Verify configuration chain
    local storage_type=$(load_config "STORAGE_TYPE")
    local http_port=$(load_config "NEXTCLOUD_HTTP_PORT")
    local admin_user=$(load_config "ADMIN_USER")

    if [ "$storage_type" != "local" ] || [ "$http_port" != "8080" ] || [ "$admin_user" != "testadmin" ]; then
        echo "Configuration chain test failed"
        return 1
    fi

    # Clean up test configuration
    save_config "STORAGE_TYPE" ""
    save_config "STORAGE_DATA_DIR" ""
    save_config "NEXTCLOUD_HTTP_PORT" ""
    save_config "TRUSTED_DOMAINS" ""
    save_config "ADMIN_USER" ""
    save_config "POSTGRES_DB" ""

    return 0
}

# Test: Mobile setup guide generation
test_mobile_guide_generation() {
    # This test checks if mobile setup guide can be generated without errors
    source "$SCRIPTS_DIR/utils/common.sh"

    # Set up minimal configuration for guide generation
    save_config "MOBILE_ACCESS_URLS" "http://192.168.1.100:8080"
    save_config "MOBILE_ADMIN_USER" "admin"
    save_config "MOBILE_ADMIN_PASSWORD" "testpass"
    save_config "NEXTCLOUD_HTTP_PORT" "8080"

    # Test mobile script can load configuration
    if ! bash -c "source '$SCRIPTS_DIR/setup-mobile.sh'; exit 0" 2>/dev/null; then
        echo "Mobile setup script failed to load"
        return 1
    fi

    # Clean up test configuration
    save_config "MOBILE_ACCESS_URLS" ""
    save_config "MOBILE_ADMIN_USER" ""
    save_config "MOBILE_ADMIN_PASSWORD" ""
    save_config "NEXTCLOUD_HTTP_PORT" ""

    return 0
}

# Test: Resource requirements validation
test_resource_requirements() {
    source "$SCRIPTS_DIR/utils/common.sh"

    # Test memory detection
    local available_memory=$(get_available_memory)
    if [ -z "$available_memory" ] || [ "$available_memory" -eq 0 ]; then
        echo "Memory detection failed"
        return 1
    fi

    # Test disk space detection
    local available_disk=$(get_available_disk_space)
    if [ -z "$available_disk" ] || [ "$available_disk" -eq 0 ]; then
        echo "Disk space detection failed"
        return 1
    fi

    return 0
}

# Test: Network validation utilities
test_network_validation() {
    source "$SCRIPTS_DIR/utils/common.sh"

    # Test IP validation
    if ! validate_ip "192.168.1.1"; then
        echo "Valid IP validation failed"
        return 1
    fi

    if validate_ip "256.1.1.1"; then
        echo "Invalid IP incorrectly validated"
        return 1
    fi

    # Test port validation
    if ! validate_port "8080"; then
        echo "Valid port validation failed"
        return 1
    fi

    if validate_port "99999"; then
        echo "Invalid port incorrectly validated"
        return 1
    fi

    return 0
}

# =============================================================================
# RUN ALL PHASE 2 INTEGRATION TESTS
# =============================================================================

# Main test execution
main() {
    init_test_framework

    start_test_suite "phase2_scripts" "Testing Phase 2 script availability and basic functionality"

    run_test "scripts_exist" "test_phase2_scripts_exist" "Check if all Phase 2 scripts exist and are executable"
    run_test "templates_exist" "test_templates_exist" "Check if all templates exist"
    run_test "storage_help" "test_storage_script_help" "Test storage script help functionality"
    run_test "network_help" "test_network_script_help" "Test network script help functionality"
    run_test "nextcloud_help" "test_nextcloud_script_help" "Test Nextcloud script help functionality"
    run_test "mobile_help" "test_mobile_script_help" "Test mobile script help functionality"

    end_test_suite

    start_test_suite "utilities_integration" "Testing Phase 2 utilities integration"

    run_test "storage_utilities" "test_storage_utilities_integration" "Test storage detection utilities"
    run_test "network_utilities" "test_network_utilities_integration" "Test network detection utilities"
    run_test "config_persistence" "test_config_persistence" "Test configuration persistence"
    run_test "error_handling" "test_error_handling_integration" "Test error handling integration"
    run_test "script_dependencies" "test_script_interdependencies" "Test script interdependencies"

    end_test_suite

    start_test_suite "template_processing" "Testing template processing and validation"

    run_test "template_processing" "test_template_processing" "Test template variable replacement"
    run_test "docker_compose_template" "test_docker_compose_template" "Test Docker Compose template structure"
    run_test "env_template" "test_env_template" "Test environment template structure"

    end_test_suite

    start_test_suite "workflow_simulation" "Testing Phase 2 workflow simulation"

    run_test "workflow_simulation" "test_phase2_workflow_simulation" "Test Phase 2 configuration workflow"
    run_test "mobile_guide" "test_mobile_guide_generation" "Test mobile setup guide generation"
    run_test "resource_requirements" "test_resource_requirements" "Test resource requirements validation"

    end_test_suite

    start_test_suite "validation_utilities" "Testing validation and utility functions"

    run_test "network_validation" "test_network_validation" "Test network validation utilities"

    end_test_suite

    finalize_test_framework
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi