#!/bin/bash
# test-requirements.sh - Tests for requirements checker
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source test framework and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")/scripts"

# =============================================================================
# REQUIREMENTS CHECKER TESTS
# =============================================================================

# Test: Requirements checker script exists and is executable
test_requirements_script_exists() {
    assert_file_exists "$SCRIPTS_DIR/check-requirements.sh" "Requirements script missing"
    assert_command_success "[ -x '$SCRIPTS_DIR/check-requirements.sh' ]" "Requirements script not executable"
}

# Test: Requirements checker shows help
test_requirements_help() {
    assert_command_success "$SCRIPTS_DIR/check-requirements.sh --help" "Help option failed"
}

# Test: Requirements checker runs without critical errors
test_requirements_basic_run() {
    local output
    output=$("$SCRIPTS_DIR/check-requirements.sh" 2>&1) || true

    # Check that script produces output
    if [ -z "$output" ]; then
        echo "Requirements checker produced no output"
        return 1
    fi

    # Check for expected sections
    if ! echo "$output" | grep -q "Operating System"; then
        echo "Missing Operating System check section"
        return 1
    fi

    if ! echo "$output" | grep -q "Disk Space"; then
        echo "Missing Disk Space check section"
        return 1
    fi

    return 0
}

# Test: Requirements checker detects OS correctly
test_requirements_os_detection() {
    local output
    output=$("$SCRIPTS_DIR/check-requirements.sh" 2>&1) || true

    # Should detect current OS
    local current_os=$(detect_os)
    if [ "$current_os" != "unknown" ]; then
        if ! echo "$output" | grep -qi "$current_os"; then
            echo "Failed to detect current OS: $current_os"
            return 1
        fi
    fi

    return 0
}

# Test: Requirements checker validates disk space
test_requirements_disk_space() {
    local output
    output=$("$SCRIPTS_DIR/check-requirements.sh" 2>&1) || true

    # Should show disk space information
    if ! echo "$output" | grep -qi "disk space"; then
        echo "No disk space information found"
        return 1
    fi

    # Should show available space
    if ! echo "$output" | grep -qE "[0-9]+ (GB|MB)"; then
        echo "No space measurements found"
        return 1
    fi

    return 0
}

# Test: Requirements checker validates memory
test_requirements_memory() {
    local output
    output=$("$SCRIPTS_DIR/check-requirements.sh" 2>&1) || true

    # Should show memory information
    if ! echo "$output" | grep -qi "memory"; then
        echo "No memory information found"
        return 1
    fi

    return 0
}

# Test: Requirements checker tests network connectivity
test_requirements_network() {
    local output
    output=$("$SCRIPTS_DIR/check-requirements.sh" 2>&1) || true

    # Should test network connectivity
    if ! echo "$output" | grep -qi "network"; then
        echo "No network check found"
        return 1
    fi

    return 0
}

# Test: Requirements checker validates sudo access
test_requirements_sudo() {
    local output
    output=$("$SCRIPTS_DIR/check-requirements.sh" 2>&1) || true

    # Should check sudo privileges
    if ! echo "$output" | grep -qi "sudo\|admin"; then
        echo "No sudo check found"
        return 1
    fi

    return 0
}

# Test: Requirements checker handles Docker detection
test_requirements_docker() {
    local output
    output=$("$SCRIPTS_DIR/check-requirements.sh" 2>&1) || true

    # Should check Docker availability
    if ! echo "$output" | grep -qi "docker"; then
        echo "No Docker check found"
        return 1
    fi

    return 0
}

# Test: Requirements checker provides exit codes
test_requirements_exit_codes() {
    # Test help exit code (should be 0)
    "$SCRIPTS_DIR/check-requirements.sh" --help >/dev/null 2>&1
    local help_exit=$?

    if [ $help_exit -ne 0 ]; then
        echo "Help command should exit with code 0, got: $help_exit"
        return 1
    fi

    return 0
}

# Test: Requirements checker handles quiet mode
test_requirements_quiet_mode() {
    # Quiet mode should produce minimal output
    local output
    output=$("$SCRIPTS_DIR/check-requirements.sh" --quiet 2>&1) || true

    # In quiet mode, output should be much shorter
    local line_count=$(echo "$output" | wc -l)
    if [ "$line_count" -gt 5 ]; then
        echo "Quiet mode produced too much output ($line_count lines)"
        return 1
    fi

    return 0
}

# =============================================================================
# UTILITY FUNCTIONS TESTS
# =============================================================================

# Test: Common utilities are available
test_common_utilities() {
    source "$SCRIPTS_DIR/utils/common.sh"

    # Test that key functions exist
    if ! declare -f print_status >/dev/null; then
        echo "print_status function not available"
        return 1
    fi

    if ! declare -f detect_os >/dev/null; then
        echo "detect_os function not available"
        return 1
    fi

    if ! declare -f validate_ip >/dev/null; then
        echo "validate_ip function not available"
        return 1
    fi

    return 0
}

# Test: IP validation function works
test_ip_validation() {
    source "$SCRIPTS_DIR/utils/common.sh"

    # Test valid IPs
    if ! validate_ip "192.168.1.1"; then
        echo "Failed to validate valid IP: 192.168.1.1"
        return 1
    fi

    if ! validate_ip "10.0.0.1"; then
        echo "Failed to validate valid IP: 10.0.0.1"
        return 1
    fi

    # Test invalid IPs
    if validate_ip "256.1.1.1"; then
        echo "Incorrectly validated invalid IP: 256.1.1.1"
        return 1
    fi

    if validate_ip "not.an.ip.address"; then
        echo "Incorrectly validated invalid IP: not.an.ip.address"
        return 1
    fi

    return 0
}

# Test: OS detection works
test_os_detection() {
    source "$SCRIPTS_DIR/utils/common.sh"

    local os=$(detect_os)
    if [ "$os" = "unknown" ]; then
        echo "Could not detect operating system"
        return 1
    fi

    # Should be one of the supported OSes
    case "$os" in
        ubuntu|debian|deepin|centos|rhel|fedora)
            return 0
            ;;
        *)
            echo "Detected unsupported OS: $os"
            return 1
            ;;
    esac
}

# =============================================================================
# RUN ALL TESTS
# =============================================================================

# Main test execution
main() {
    init_test_framework

    start_test_suite "requirements_checker" "Testing requirements checker functionality"

    run_test "script_exists" "test_requirements_script_exists" "Check if requirements script exists and is executable"
    run_test "help_option" "test_requirements_help" "Test help option functionality"
    run_test "basic_run" "test_requirements_basic_run" "Test basic requirements checker execution"
    run_test "os_detection" "test_requirements_os_detection" "Test operating system detection"
    run_test "disk_space" "test_requirements_disk_space" "Test disk space validation"
    run_test "memory_check" "test_requirements_memory" "Test memory validation"
    run_test "network_check" "test_requirements_network" "Test network connectivity check"
    run_test "sudo_check" "test_requirements_sudo" "Test sudo privilege validation"
    run_test "docker_check" "test_requirements_docker" "Test Docker detection"
    run_test "exit_codes" "test_requirements_exit_codes" "Test exit code handling"
    run_test "quiet_mode" "test_requirements_quiet_mode" "Test quiet mode functionality"

    end_test_suite

    start_test_suite "utility_functions" "Testing utility functions"

    run_test "common_utilities" "test_common_utilities" "Test common utility functions availability"
    run_test "ip_validation" "test_ip_validation" "Test IP address validation"
    run_test "os_detection" "test_os_detection" "Test OS detection utility"

    end_test_suite

    finalize_test_framework
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi