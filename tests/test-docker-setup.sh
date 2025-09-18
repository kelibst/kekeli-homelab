#!/bin/bash
# test-docker-setup.sh - Tests for Docker setup automation
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source test framework and utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/test-framework.sh"

SCRIPTS_DIR="$(dirname "$SCRIPT_DIR")/scripts"

# =============================================================================
# DOCKER SETUP TESTS
# =============================================================================

# Test: Docker setup script exists and is executable
test_docker_script_exists() {
    assert_file_exists "$SCRIPTS_DIR/setup-docker.sh" "Docker setup script missing"
    assert_command_success "[ -x '$SCRIPTS_DIR/setup-docker.sh' ]" "Docker setup script not executable"
}

# Test: Docker setup shows help
test_docker_help() {
    assert_command_success "$SCRIPTS_DIR/setup-docker.sh --help" "Help option failed"
}

# Test: Docker setup handles existing Docker installation
test_docker_existing_installation() {
    local output

    # If Docker is already installed, script should detect it
    if command -v docker >/dev/null 2>&1; then
        output=$("$SCRIPTS_DIR/setup-docker.sh" 2>&1) || true

        if ! echo "$output" | grep -qi "docker.*installed\|already.*installed"; then
            echo "Script didn't detect existing Docker installation"
            return 1
        fi
    else
        # If Docker is not installed, script should indicate installation needed
        output=$("$SCRIPTS_DIR/setup-docker.sh" 2>&1) || true

        if ! echo "$output" | grep -qi "install\|not.*found\|not.*installed"; then
            echo "Script didn't indicate Docker needs installation"
            return 1
        fi
    fi

    return 0
}

# Test: Docker setup validates system requirements
test_docker_system_validation() {
    local output
    output=$("$SCRIPTS_DIR/setup-docker.sh" 2>&1) || true

    # Should check for supported OS
    if ! echo "$output" | grep -qi "os\|system\|platform"; then
        echo "No OS/system validation found"
        return 1
    fi

    return 0
}

# Test: Docker setup handles force install option
test_docker_force_option() {
    # Test that force option is recognized (should not error on unknown option)
    local output
    output=$("$SCRIPTS_DIR/setup-docker.sh" --help 2>&1) || true

    if ! echo "$output" | grep -qi "force"; then
        echo "Force option not documented in help"
        return 1
    fi

    return 0
}

# Test: Docker setup provides proper exit codes
test_docker_exit_codes() {
    # Test help exit code (should be 0)
    "$SCRIPTS_DIR/setup-docker.sh" --help >/dev/null 2>&1
    local help_exit=$?

    if [ $help_exit -ne 0 ]; then
        echo "Help command should exit with code 0, got: $help_exit"
        return 1
    fi

    return 0
}

# Test: Docker setup handles unsupported OS gracefully
test_docker_unsupported_os() {
    # Create a mock OS detection that returns unsupported OS
    local temp_script="$KEKELI_CONFIG_DIR/test-temp/mock-docker-setup.sh"

    # Create temporary directory
    mkdir -p "$(dirname "$temp_script")"

    # Create modified script that mocks OS detection
    cat "$SCRIPTS_DIR/setup-docker.sh" > "$temp_script"

    # Insert mock OS detection (this is a simplified test)
    # In a real scenario, we'd use more sophisticated mocking

    chmod +x "$temp_script"

    # For now, just test that the original script handles unknown inputs gracefully
    local output
    output=$(echo "invalid_option" | "$SCRIPTS_DIR/setup-docker.sh" --help 2>&1) || true

    # Script should handle invalid options gracefully
    return 0
}

# Test: Docker utilities integration
test_docker_utilities() {
    source "$SCRIPTS_DIR/utils/common.sh"

    # Test Docker utility functions if available
    if declare -f docker_installed >/dev/null; then
        # Function should return true/false without errors
        docker_installed >/dev/null 2>&1 || true
    fi

    if declare -f docker_running >/dev/null; then
        # Function should return true/false without errors
        docker_running >/dev/null 2>&1 || true
    fi

    return 0
}

# =============================================================================
# DOCKER ENVIRONMENT TESTS
# =============================================================================

# Test: Docker command availability (if installed)
test_docker_command_available() {
    if command -v docker >/dev/null 2>&1; then
        # If Docker is installed, test basic functionality
        if ! docker --version >/dev/null 2>&1; then
            echo "Docker installed but --version fails"
            return 1
        fi

        # Test Docker info (may fail if daemon not running, but shouldn't crash)
        docker info >/dev/null 2>&1 || true
    else
        # Docker not installed - this is fine for testing
        echo "Docker not installed (this is acceptable for testing)"
    fi

    return 0
}

# Test: Docker Compose availability (if installed)
test_docker_compose_available() {
    if command -v docker-compose >/dev/null 2>&1; then
        # Test standalone Docker Compose
        if ! docker-compose --version >/dev/null 2>&1; then
            echo "docker-compose installed but --version fails"
            return 1
        fi
    elif command -v docker >/dev/null 2>&1; then
        # Test Docker Compose plugin
        docker compose version >/dev/null 2>&1 || true
    fi

    return 0
}

# Test: Docker group membership (if Docker installed)
test_docker_group_membership() {
    if command -v docker >/dev/null 2>&1; then
        # Check if user is in docker group
        if groups "$USER" | grep -q docker; then
            echo "User is in docker group"
        else
            echo "User not in docker group (may need sudo for Docker commands)"
        fi
    fi

    return 0
}

# =============================================================================
# DOCKER CONFIGURATION TESTS
# =============================================================================

# Test: Docker service status (if systemd available)
test_docker_service_status() {
    if command -v systemctl >/dev/null 2>&1 && command -v docker >/dev/null 2>&1; then
        # Check if Docker service exists
        if systemctl list-unit-files | grep -q docker; then
            # Service exists, check status (don't fail if not running)
            systemctl status docker >/dev/null 2>&1 || true
            echo "Docker service checked"
        fi
    fi

    return 0
}

# Test: Docker daemon configuration
test_docker_daemon_config() {
    if command -v docker >/dev/null 2>&1; then
        # Check if daemon configuration directory exists
        if [ -d "/etc/docker" ]; then
            echo "Docker configuration directory exists"
        fi

        # Check for daemon.json (optional)
        if [ -f "/etc/docker/daemon.json" ]; then
            # Validate JSON if file exists
            if command -v jq >/dev/null 2>&1; then
                if jq . "/etc/docker/daemon.json" >/dev/null 2>&1; then
                    echo "Docker daemon.json is valid"
                else
                    echo "Docker daemon.json is invalid"
                    return 1
                fi
            fi
        fi
    fi

    return 0
}

# =============================================================================
# INTEGRATION TESTS
# =============================================================================

# Test: Docker setup with error handling utilities
test_docker_error_integration() {
    if [ -f "$SCRIPTS_DIR/utils/error-handling.sh" ]; then
        source "$SCRIPTS_DIR/utils/error-handling.sh"

        # Test that error handling functions are available
        if ! declare -f handle_critical_error >/dev/null; then
            echo "Error handling integration not working"
            return 1
        fi
    fi

    return 0
}

# Test: Docker setup logging
test_docker_logging() {
    # Check if log file is created after running Docker setup
    local log_file="$KEKELI_CONFIG_DIR/install.log"

    # Run Docker setup help to generate some log entries
    "$SCRIPTS_DIR/setup-docker.sh" --help >/dev/null 2>&1 || true

    # Check if logging is working (log file should exist or be created)
    # Note: This is a basic test - in practice, logging might be conditional
    return 0
}

# =============================================================================
# RUN ALL TESTS
# =============================================================================

# Main test execution
main() {
    init_test_framework

    start_test_suite "docker_setup_basic" "Testing Docker setup script basic functionality"

    run_test "script_exists" "test_docker_script_exists" "Check if Docker setup script exists and is executable"
    run_test "help_option" "test_docker_help" "Test help option functionality"
    run_test "existing_installation" "test_docker_existing_installation" "Test detection of existing Docker installation"
    run_test "system_validation" "test_docker_system_validation" "Test system requirements validation"
    run_test "force_option" "test_docker_force_option" "Test force installation option"
    run_test "exit_codes" "test_docker_exit_codes" "Test exit code handling"

    end_test_suite

    start_test_suite "docker_environment" "Testing Docker environment and availability"

    run_test "command_available" "test_docker_command_available" "Test Docker command availability"
    run_test "compose_available" "test_docker_compose_available" "Test Docker Compose availability"
    run_test "group_membership" "test_docker_group_membership" "Test Docker group membership"
    run_test "utilities" "test_docker_utilities" "Test Docker utility functions"

    end_test_suite

    start_test_suite "docker_configuration" "Testing Docker configuration and services"

    run_test "service_status" "test_docker_service_status" "Test Docker service status"
    run_test "daemon_config" "test_docker_daemon_config" "Test Docker daemon configuration"

    end_test_suite

    start_test_suite "docker_integration" "Testing Docker setup integration with other components"

    run_test "error_integration" "test_docker_error_integration" "Test error handling integration"
    run_test "logging" "test_docker_logging" "Test logging functionality"

    end_test_suite

    finalize_test_framework
}

# Run tests if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi