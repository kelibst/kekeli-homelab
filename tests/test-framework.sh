#!/bin/bash
# test-framework.sh - Testing framework for Kekeli-HomeCloud installer
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$(dirname "$SCRIPT_DIR")/scripts/utils"
source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/error-handling.sh"

# =============================================================================
# TEST FRAMEWORK CONFIGURATION
# =============================================================================

readonly TEST_LOG_FILE="$KEKELI_CONFIG_DIR/test_results.log"
readonly TEST_REPORT_FILE="$KEKELI_CONFIG_DIR/test_report.html"

# Test statistics
declare -g TESTS_TOTAL=0
declare -g TESTS_PASSED=0
declare -g TESTS_FAILED=0
declare -g TESTS_SKIPPED=0

# Test context
declare -g CURRENT_TEST_SUITE=""
declare -g CURRENT_TEST_NAME=""
declare -g TEST_START_TIME=""

# Test results storage
declare -A TEST_RESULTS
declare -A TEST_DURATIONS
declare -A TEST_OUTPUTS

# =============================================================================
# CORE TEST FUNCTIONS
# =============================================================================

# Function to start a test suite
start_test_suite() {
    local suite_name=$1
    local description=${2:-""}

    CURRENT_TEST_SUITE="$suite_name"
    print_section "🧪" "Test Suite: $suite_name"

    if [ -n "$description" ]; then
        print_status "info" "$description"
    fi

    log_message "TEST_SUITE" "Started test suite: $suite_name"
}

# Function to end a test suite
end_test_suite() {
    local suite_results="Passed: $TESTS_PASSED, Failed: $TESTS_FAILED, Skipped: $TESTS_SKIPPED"

    print_status "info" "Test suite '$CURRENT_TEST_SUITE' completed: $suite_results"
    log_message "TEST_SUITE" "Completed test suite: $CURRENT_TEST_SUITE ($suite_results)"

    CURRENT_TEST_SUITE=""
}

# Function to run a single test
run_test() {
    local test_name=$1
    local test_function=$2
    local description=${3:-""}

    CURRENT_TEST_NAME="$test_name"
    TEST_START_TIME=$(date +%s.%N)
    ((TESTS_TOTAL++))

    local test_id="${CURRENT_TEST_SUITE}.${test_name}"

    print_status "progress" "Running: $test_name"
    if [ -n "$description" ]; then
        print_status "info" "  $description"
    fi

    log_message "TEST" "Starting test: $test_id"

    # Capture test output
    local test_output
    local test_result=0

    # Run the test function
    if test_output=$($test_function 2>&1); then
        test_result=0
        ((TESTS_PASSED++))
        print_status "pass" "$test_name"
        TEST_RESULTS["$test_id"]="PASS"
        log_message "TEST" "Test passed: $test_id"
    else
        test_result=$?
        ((TESTS_FAILED++))
        print_status "fail" "$test_name"
        TEST_RESULTS["$test_id"]="FAIL"
        log_message "TEST" "Test failed: $test_id (exit code: $test_result)"

        # Show test output on failure
        if [ -n "$test_output" ]; then
            echo -e "    ${RED}Output: $test_output${NC}"
        fi
    fi

    # Record test duration
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $TEST_START_TIME" | bc -l 2>/dev/null || echo "0")
    TEST_DURATIONS["$test_id"]="$duration"
    TEST_OUTPUTS["$test_id"]="$test_output"

    CURRENT_TEST_NAME=""
    return $test_result
}

# Function to skip a test
skip_test() {
    local test_name=$1
    local reason=${2:-"No reason provided"}

    ((TESTS_TOTAL++))
    ((TESTS_SKIPPED++))

    local test_id="${CURRENT_TEST_SUITE}.${test_name}"
    TEST_RESULTS["$test_id"]="SKIP"
    TEST_OUTPUTS["$test_id"]="Skipped: $reason"

    print_status "warn" "$test_name (skipped: $reason)"
    log_message "TEST" "Test skipped: $test_id ($reason)"
}

# Function to assert condition
assert_true() {
    local condition=$1
    local message=${2:-"Assertion failed"}

    if [ "$condition" = true ] || [ "$condition" = "0" ]; then
        return 0
    else
        echo "ASSERTION FAILED: $message"
        return 1
    fi
}

# Function to assert equality
assert_equals() {
    local expected=$1
    local actual=$2
    local message=${3:-"Values not equal"}

    if [ "$expected" = "$actual" ]; then
        return 0
    else
        echo "ASSERTION FAILED: $message (expected: '$expected', actual: '$actual')"
        return 1
    fi
}

# Function to assert command success
assert_command_success() {
    local command="$1"
    local message=${2:-"Command failed"}

    if eval "$command" >/dev/null 2>&1; then
        return 0
    else
        echo "ASSERTION FAILED: $message (command: $command)"
        return 1
    fi
}

# Function to assert command failure
assert_command_failure() {
    local command="$1"
    local message=${2:-"Command unexpectedly succeeded"}

    if ! eval "$command" >/dev/null 2>&1; then
        return 0
    else
        echo "ASSERTION FAILED: $message (command: $command)"
        return 1
    fi
}

# Function to assert file exists
assert_file_exists() {
    local file_path=$1
    local message=${2:-"File does not exist"}

    if [ -f "$file_path" ]; then
        return 0
    else
        echo "ASSERTION FAILED: $message (file: $file_path)"
        return 1
    fi
}

# Function to assert directory exists
assert_dir_exists() {
    local dir_path=$1
    local message=${2:-"Directory does not exist"}

    if [ -d "$dir_path" ]; then
        return 0
    else
        echo "ASSERTION FAILED: $message (directory: $dir_path)"
        return 1
    fi
}

# =============================================================================
# TEST ENVIRONMENT SETUP
# =============================================================================

# Function to set up test environment
setup_test_environment() {
    print_section "⚙️" "Setting Up Test Environment"

    # Create test directories
    local test_dirs=(
        "$KEKELI_CONFIG_DIR/test-temp"
        "$KEKELI_CONFIG_DIR/test-data"
        "$KEKELI_CONFIG_DIR/test-logs"
    )

    for dir in "${test_dirs[@]}"; do
        if create_directory "$dir"; then
            print_status "pass" "Created test directory: $dir"
        else
            print_status "fail" "Failed to create test directory: $dir"
            return 1
        fi
    done

    # Initialize test log
    {
        echo "=== Kekeli-HomeCloud Test Session ==="
        echo "Started: $(date)"
        echo "User: $USER"
        echo "System: $(detect_os) $(detect_os_version)"
        echo ""
    } > "$TEST_LOG_FILE"

    print_status "pass" "Test environment ready"
    return 0
}

# Function to clean up test environment
cleanup_test_environment() {
    print_section "🧹" "Cleaning Up Test Environment"

    # Remove test directories
    local test_dirs=(
        "$KEKELI_CONFIG_DIR/test-temp"
        "$KEKELI_CONFIG_DIR/test-data"
    )

    for dir in "${test_dirs[@]}"; do
        if [ -d "$dir" ]; then
            rm -rf "$dir" 2>/dev/null
            print_status "pass" "Removed test directory: $dir"
        fi
    done

    print_status "pass" "Test environment cleaned up"
}

# =============================================================================
# TEST REPORTING
# =============================================================================

# Function to generate test summary
generate_test_summary() {
    print_section "📊" "Test Summary"

    local total_duration=0
    for duration in "${TEST_DURATIONS[@]}"; do
        total_duration=$(echo "$total_duration + $duration" | bc -l 2>/dev/null || echo "$total_duration")
    done

    echo -e "${CYAN}Test Results:${NC}"
    echo -e "  Total Tests: $TESTS_TOTAL"
    echo -e "  ${GREEN}Passed: $TESTS_PASSED${NC}"
    echo -e "  ${RED}Failed: $TESTS_FAILED${NC}"
    echo -e "  ${YELLOW}Skipped: $TESTS_SKIPPED${NC}"
    echo -e "  Total Duration: $(printf "%.2f" "$total_duration")s"
    echo ""

    # Calculate success rate
    local success_rate=0
    if [ $TESTS_TOTAL -gt 0 ]; then
        success_rate=$(echo "scale=1; $TESTS_PASSED * 100 / $TESTS_TOTAL" | bc -l 2>/dev/null || echo "0")
    fi

    echo -e "${CYAN}Success Rate: ${success_rate}%${NC}"
    echo ""

    # Show failed tests
    if [ $TESTS_FAILED -gt 0 ]; then
        echo -e "${RED}Failed Tests:${NC}"
        for test_id in "${!TEST_RESULTS[@]}"; do
            if [ "${TEST_RESULTS[$test_id]}" = "FAIL" ]; then
                echo -e "  ${RED}✗${NC} $test_id"
                if [ -n "${TEST_OUTPUTS[$test_id]}" ]; then
                    echo -e "    ${RED}${TEST_OUTPUTS[$test_id]}${NC}"
                fi
            fi
        done
        echo ""
    fi

    # Log summary
    {
        echo "=== Test Summary ==="
        echo "Total: $TESTS_TOTAL, Passed: $TESTS_PASSED, Failed: $TESTS_FAILED, Skipped: $TESTS_SKIPPED"
        echo "Success Rate: ${success_rate}%"
        echo "Duration: $(printf "%.2f" "$total_duration")s"
        echo "Completed: $(date)"
    } >> "$TEST_LOG_FILE"
}

# Function to generate HTML test report
generate_html_report() {
    local report_file=${1:-"$TEST_REPORT_FILE"}

    print_status "progress" "Generating HTML test report..."

    cat > "$report_file" << 'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Kekeli-HomeCloud Test Report</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; margin: 20px; background-color: #f5f5f5; }
        .container { max-width: 1200px; margin: 0 auto; background: white; padding: 20px; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }
        .header { text-align: center; border-bottom: 2px solid #007acc; padding-bottom: 20px; margin-bottom: 30px; }
        .summary { display: grid; grid-template-columns: repeat(auto-fit, minmax(200px, 1fr)); gap: 20px; margin-bottom: 30px; }
        .stat-card { background: #f8f9fa; padding: 20px; border-radius: 8px; text-align: center; border-left: 4px solid #007acc; }
        .stat-number { font-size: 2em; font-weight: bold; color: #007acc; }
        .stat-label { font-size: 0.9em; color: #666; text-transform: uppercase; }
        .test-results { margin-top: 30px; }
        .test-suite { margin-bottom: 30px; border: 1px solid #ddd; border-radius: 8px; }
        .suite-header { background: #007acc; color: white; padding: 15px; font-weight: bold; border-radius: 8px 8px 0 0; }
        .test-item { padding: 10px 15px; border-bottom: 1px solid #eee; display: flex; justify-content: space-between; align-items: center; }
        .test-item:last-child { border-bottom: none; }
        .test-name { font-weight: 500; }
        .test-status { padding: 4px 12px; border-radius: 20px; font-size: 0.8em; font-weight: bold; }
        .status-pass { background: #d4edda; color: #155724; }
        .status-fail { background: #f8d7da; color: #721c24; }
        .status-skip { background: #fff3cd; color: #856404; }
        .test-output { margin-top: 10px; padding: 10px; background: #f8f9fa; border-radius: 4px; font-family: monospace; font-size: 0.9em; }
        .footer { text-align: center; margin-top: 30px; color: #666; font-size: 0.9em; }
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>🧪 Kekeli-HomeCloud Test Report</h1>
            <p>Generated on $(date)</p>
        </div>

        <div class="summary">
            <div class="stat-card">
                <div class="stat-number">$TESTS_TOTAL</div>
                <div class="stat-label">Total Tests</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" style="color: #28a745;">$TESTS_PASSED</div>
                <div class="stat-label">Passed</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" style="color: #dc3545;">$TESTS_FAILED</div>
                <div class="stat-label">Failed</div>
            </div>
            <div class="stat-card">
                <div class="stat-number" style="color: #ffc107;">$TESTS_SKIPPED</div>
                <div class="stat-label">Skipped</div>
            </div>
        </div>

        <div class="test-results">
EOF

    # Group tests by suite
    local current_suite=""
    local suite_tests=()

    for test_id in $(printf '%s\n' "${!TEST_RESULTS[@]}" | sort); do
        local suite_name=$(echo "$test_id" | cut -d'.' -f1)
        local test_name=$(echo "$test_id" | cut -d'.' -f2-)
        local status="${TEST_RESULTS[$test_id]}"
        local output="${TEST_OUTPUTS[$test_id]:-""}"
        local duration="${TEST_DURATIONS[$test_id]:-0}"

        if [ "$suite_name" != "$current_suite" ]; then
            # Close previous suite
            if [ -n "$current_suite" ]; then
                echo "            </div>" >> "$report_file"
            fi

            # Start new suite
            echo "            <div class=\"test-suite\">" >> "$report_file"
            echo "                <div class=\"suite-header\">$suite_name</div>" >> "$report_file"
            current_suite="$suite_name"
        fi

        # Add test item
        local status_class=""
        case "$status" in
            "PASS") status_class="status-pass" ;;
            "FAIL") status_class="status-fail" ;;
            "SKIP") status_class="status-skip" ;;
        esac

        cat >> "$report_file" << EOF
                <div class="test-item">
                    <div>
                        <div class="test-name">$test_name</div>
                        $([ -n "$output" ] && echo "<div class=\"test-output\">$output</div>")
                    </div>
                    <div>
                        <span class="test-status $status_class">$status</span>
                        $([ "$duration" != "0" ] && echo "<div style=\"font-size: 0.8em; color: #666; margin-top: 4px;\">$(printf "%.2f" "$duration")s</div>")
                    </div>
                </div>
EOF
    done

    # Close last suite
    if [ -n "$current_suite" ]; then
        echo "            </div>" >> "$report_file"
    fi

    cat >> "$report_file" << 'EOF'
        </div>

        <div class="footer">
            <p>Generated by Kekeli-HomeCloud Test Framework</p>
        </div>
    </div>
</body>
</html>
EOF

    if [ -f "$report_file" ]; then
        print_status "pass" "HTML report generated: $report_file"
        return 0
    else
        print_status "fail" "Failed to generate HTML report"
        return 1
    fi
}

# =============================================================================
# TEST EXECUTION CONTROL
# =============================================================================

# Function to run all tests in a directory
run_test_directory() {
    local test_dir=$1
    local pattern=${2:-"test-*.sh"}

    if [ ! -d "$test_dir" ]; then
        print_status "error" "Test directory not found: $test_dir"
        return 1
    fi

    print_section "📁" "Running Tests from Directory: $test_dir"

    local test_files=()
    while IFS= read -r -d '' file; do
        test_files+=("$file")
    done < <(find "$test_dir" -name "$pattern" -type f -print0 | sort -z)

    if [ ${#test_files[@]} -eq 0 ]; then
        print_status "warn" "No test files found matching pattern: $pattern"
        return 1
    fi

    for test_file in "${test_files[@]}"; do
        print_status "info" "Executing test file: $(basename "$test_file")"
        if bash "$test_file"; then
            print_status "pass" "Test file completed: $(basename "$test_file")"
        else
            print_status "fail" "Test file failed: $(basename "$test_file")"
        fi
    done
}

# Function to initialize test framework
init_test_framework() {
    print_section "🚀" "Initializing Test Framework"

    # Reset counters
    TESTS_TOTAL=0
    TESTS_PASSED=0
    TESTS_FAILED=0
    TESTS_SKIPPED=0

    # Clear results
    TEST_RESULTS=()
    TEST_DURATIONS=()
    TEST_OUTPUTS=()

    # Set up environment
    setup_test_environment

    print_status "pass" "Test framework initialized"
}

# Function to finalize test framework
finalize_test_framework() {
    print_section "🏁" "Finalizing Test Framework"

    # Generate reports
    generate_test_summary
    generate_html_report

    # Clean up
    cleanup_test_environment

    # Return appropriate exit code
    if [ $TESTS_FAILED -gt 0 ]; then
        print_status "fail" "Some tests failed"
        return 1
    else
        print_status "pass" "All tests passed"
        return 0
    fi
}

# =============================================================================
# INITIALIZATION
# =============================================================================

log_message "INIT" "Test framework loaded"

# Set up test-specific error handling
trap 'echo "Test interrupted"; finalize_test_framework; exit 1' INT TERM