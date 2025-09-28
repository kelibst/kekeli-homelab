#!/bin/bash
# error-handling.sh - Error handling and logging infrastructure for Kekeli-HomeCloud
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source common utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/common.sh"

# =============================================================================
# ERROR HANDLING CONFIGURATION
# =============================================================================

# Global error handling settings
readonly ERROR_LOG_MAX_SIZE=10485760  # 10MB
readonly ERROR_LOG_BACKUP_COUNT=5
readonly DEBUG_MODE=${DEBUG_MODE:-false}
readonly STRICT_MODE=${STRICT_MODE:-false}

# Error context tracking
declare -g ERROR_CONTEXT=""
declare -g ERROR_STACK=()
declare -g CURRENT_OPERATION=""

# =============================================================================
# ENHANCED LOGGING FUNCTIONS
# =============================================================================

# Function to rotate log file if it gets too large
rotate_log_file() {
    local log_file=$1

    if [ ! -f "$log_file" ]; then
        return 0
    fi

    local file_size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo 0)

    if [ "$file_size" -gt "$ERROR_LOG_MAX_SIZE" ]; then
        print_status "info" "Rotating log file (size: $(bytes_to_human $file_size))"

        # Rotate existing backups
        for i in $(seq $((ERROR_LOG_BACKUP_COUNT - 1)) -1 1); do
            if [ -f "${log_file}.$i" ]; then
                mv "${log_file}.$i" "${log_file}.$((i + 1))" 2>/dev/null
            fi
        done

        # Move current log to .1
        mv "$log_file" "${log_file}.1" 2>/dev/null

        # Start fresh log
        touch "$log_file" 2>/dev/null
        chmod 644 "$log_file" 2>/dev/null
    fi
}

# Enhanced logging with context and stack trace
log_with_context() {
    local level=$1
    local message=$2
    local include_stack=${3:-false}

    local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
    local caller_info=""
    local stack_trace=""

    # Get caller information
    if [ "${#BASH_SOURCE[@]}" -gt 2 ]; then
        local caller_file=$(basename "${BASH_SOURCE[2]}")
        local caller_line="${BASH_LINENO[1]}"
        local caller_function="${FUNCNAME[2]:-main}"
        caller_info="[$caller_file:$caller_line:$caller_function]"
    fi

    # Build log entry
    local log_entry="[$timestamp] [$level] $caller_info"
    if [ -n "$ERROR_CONTEXT" ]; then
        log_entry+=" [CTX:$ERROR_CONTEXT]"
    fi
    if [ -n "$CURRENT_OPERATION" ]; then
        log_entry+=" [OP:$CURRENT_OPERATION]"
    fi
    log_entry+=" $message"

    # Add stack trace if requested
    if [ "$include_stack" = true ] && [ "$level" = "ERROR" ]; then
        stack_trace=$(generate_stack_trace)
        log_entry+="\n$stack_trace"
    fi

    # Rotate log if needed
    rotate_log_file "$KEKELI_LOG_FILE"

    # Write to log file
    echo -e "$log_entry" >> "$KEKELI_LOG_FILE" 2>/dev/null

    # Also write to stderr for errors in debug mode
    if [ "$DEBUG_MODE" = true ] && [ "$level" = "ERROR" ]; then
        echo -e "$log_entry" >&2
    fi
}

# Function to set error context
set_error_context() {
    ERROR_CONTEXT="$1"
    log_with_context "DEBUG" "Error context set: $ERROR_CONTEXT"
}

# Function to clear error context
clear_error_context() {
    local old_context="$ERROR_CONTEXT"
    ERROR_CONTEXT=""
    if [ -n "$old_context" ]; then
        log_with_context "DEBUG" "Error context cleared: $old_context"
    fi
}

# Function to set current operation
set_operation() {
    CURRENT_OPERATION="$1"
    log_with_context "INFO" "Operation started: $CURRENT_OPERATION"
}

# Function to complete current operation
complete_operation() {
    local status=${1:-"success"}
    if [ -n "$CURRENT_OPERATION" ]; then
        log_with_context "INFO" "Operation completed: $CURRENT_OPERATION ($status)"
    fi
    CURRENT_OPERATION=""
}

# =============================================================================
# STACK TRACE FUNCTIONS
# =============================================================================

# Function to generate stack trace
generate_stack_trace() {
    local stack_trace="Stack trace:"
    local i=1

    while [ $i -lt ${#FUNCNAME[@]} ]; do
        local func="${FUNCNAME[$i]}"
        local file="${BASH_SOURCE[$i]}"
        local line="${BASH_LINENO[$((i-1))]}"

        if [ "$func" != "generate_stack_trace" ] && [ "$func" != "log_with_context" ]; then
            stack_trace+="\n  $i: $func() at $(basename "$file"):$line"
        fi
        ((i++))
    done

    echo -e "$stack_trace"
}

# Function to push function to error stack
push_error_stack() {
    local function_name=${1:-"${FUNCNAME[1]}"}
    ERROR_STACK+=("$function_name")
    log_with_context "DEBUG" "Entered function: $function_name (stack depth: ${#ERROR_STACK[@]})"
}

# Function to pop function from error stack
pop_error_stack() {
    if [ ${#ERROR_STACK[@]} -gt 0 ]; then
        local function_name="${ERROR_STACK[-1]}"
        unset ERROR_STACK[-1]
        log_with_context "DEBUG" "Exited function: $function_name (stack depth: ${#ERROR_STACK[@]})"
    fi
}

# =============================================================================
# ERROR HANDLING FUNCTIONS
# =============================================================================

# Function to handle critical errors
handle_critical_error() {
    local error_message=$1
    local exit_code=${2:-1}
    local show_stack=${3:-true}

    log_with_context "ERROR" "CRITICAL ERROR: $error_message" "$show_stack"

    print_status "fail" "Critical Error: $error_message"

    if [ "$show_stack" = true ]; then
        echo -e "${RED}Stack trace:${NC}"
        generate_stack_trace | while IFS= read -r line; do
            echo -e "${RED}$line${NC}"
        done
    fi

    # Show troubleshooting information
    show_error_help "$error_message"

    exit "$exit_code"
}

# Function to handle recoverable errors
handle_recoverable_error() {
    local error_message=$1
    local recovery_action=${2:-""}

    log_with_context "ERROR" "RECOVERABLE ERROR: $error_message"
    print_status "fail" "$error_message"

    if [ -n "$recovery_action" ]; then
        print_status "info" "Recovery action: $recovery_action"
    fi

    return 1
}

# Function to handle warnings
handle_warning() {
    local warning_message=$1
    local continue_anyway=${2:-true}

    log_with_context "WARNING" "$warning_message"
    print_status "warn" "$warning_message"

    if [ "$continue_anyway" = false ]; then
        if ! ask_yes_no "Continue despite this warning?"; then
            handle_critical_error "User chose to abort due to warning" $ERROR_USER_ABORT false
        fi
    fi
}

# Function to validate return codes
validate_return_code() {
    local return_code=$1
    local operation_name=$2
    local critical=${3:-true}

    if [ "$return_code" -ne 0 ]; then
        local error_msg="Operation failed: $operation_name (exit code: $return_code)"

        if [ "$critical" = true ]; then
            handle_critical_error "$error_msg" "$return_code"
        else
            handle_recoverable_error "$error_msg"
            return "$return_code"
        fi
    fi

    return 0
}

# Function to wrap command execution with error handling
safe_execute() {
    local command="$1"
    local operation_name="$2"
    local critical=${3:-true}
    local timeout=${4:-300}  # 5 minute default timeout

    set_operation "$operation_name"
    log_with_context "INFO" "Executing: $command"

    local output
    local return_code

    # Execute command with timeout
    if command_exists timeout; then
        output=$(timeout "$timeout" bash -c "$command" 2>&1)
        return_code=$?
    else
        output=$(bash -c "$command" 2>&1)
        return_code=$?
    fi

    # Log output
    if [ -n "$output" ]; then
        log_with_context "INFO" "Command output: $output"
    fi

    # Handle result
    if [ "$return_code" -eq 0 ]; then
        complete_operation "success"
        log_with_context "INFO" "Command succeeded: $command"
    else
        complete_operation "failed"

        if [ "$return_code" -eq 124 ]; then
            # Timeout error
            if [ "$critical" = true ]; then
                handle_critical_error "Command timed out after ${timeout}s: $operation_name" $ERROR_GENERAL
            else
                handle_recoverable_error "Command timed out after ${timeout}s: $operation_name"
            fi
        else
            validate_return_code "$return_code" "$operation_name" "$critical"
        fi
    fi

    return "$return_code"
}

# Function to execute commands with real-time progress display (no timeout)
execute_with_progress() {
    local command="$1"
    local operation_name="$2"
    local critical=${3:-true}
    local allow_interruption=${4:-true}

    set_operation "$operation_name"
    log_with_context "INFO" "Executing with progress: $command"

    local return_code
    local interrupted=false

    # Set up signal handlers for graceful interruption
    local original_sigint_handler=$(trap -p INT)
    local original_sigterm_handler=$(trap -p TERM)

    if [ "$allow_interruption" = true ]; then
        trap 'interrupted=true; echo ""; print_status "warn" "Operation interrupted by user"' INT TERM
    fi

    # Execute command with real-time output
    print_status "progress" "Starting: $operation_name"
    echo ""  # Add space for better readability

    # Execute command directly, showing all output in real-time
    bash -c "$command"
    return_code=$?

    echo ""  # Add space after command output

    # Restore original signal handlers
    if [ -n "$original_sigint_handler" ]; then
        eval "$original_sigint_handler"
    else
        trap - INT
    fi

    if [ -n "$original_sigterm_handler" ]; then
        eval "$original_sigterm_handler"
    else
        trap - TERM
    fi

    # Handle interruption
    if [ "$interrupted" = true ]; then
        complete_operation "interrupted"
        log_with_context "WARNING" "Command interrupted by user: $command"

        if [ "$critical" = true ]; then
            print_status "question" "Operation was interrupted. What would you like to do?"
            echo "  1) Continue anyway (skip this step)"
            echo "  2) Retry the operation"
            echo "  3) Abort installation"
            echo ""
            read -p "Enter your choice (1-3): " choice
            case "$choice" in
                1)
                    print_status "warn" "Continuing with installation..."
                    return 0
                    ;;
                2)
                    print_status "info" "Retrying operation..."
                    execute_with_progress "$command" "$operation_name" "$critical" "$allow_interruption"
                    return $?
                    ;;
                3|*)
                    handle_critical_error "Installation aborted by user" $ERROR_USER_ABORT false
                    ;;
            esac
        else
            handle_recoverable_error "Operation interrupted: $operation_name"
            return 130  # Standard exit code for SIGINT
        fi
    fi

    # Handle result
    if [ "$return_code" -eq 0 ]; then
        complete_operation "success"
        log_with_context "INFO" "Command succeeded: $command"
        print_status "pass" "$operation_name completed successfully"
    else
        complete_operation "failed"
        log_with_context "ERROR" "Command failed with exit code $return_code: $command"

        if [ "$critical" = true ]; then
            print_status "question" "Operation failed. What would you like to do?"
            echo "  1) Continue anyway (skip this step)"
            echo "  2) Retry the operation"
            echo "  3) Abort installation"
            echo ""
            read -p "Enter your choice (1-3): " choice
            case "$choice" in
                1)
                    print_status "warn" "Continuing despite failure..."
                    return 0
                    ;;
                2)
                    print_status "info" "Retrying operation..."
                    execute_with_progress "$command" "$operation_name" "$critical" "$allow_interruption"
                    return $?
                    ;;
                3|*)
                    handle_critical_error "$operation_name failed" "$return_code"
                    ;;
            esac
        else
            handle_recoverable_error "$operation_name failed"
        fi
    fi

    return "$return_code"
}

# =============================================================================
# ERROR RECOVERY FUNCTIONS
# =============================================================================

# Function to suggest recovery actions
show_error_help() {
    local error_message=$1

    print_status "info" "Troubleshooting suggestions:"

    # Common error patterns and suggestions
    case "$error_message" in
        *"Permission denied"*)
            echo -e "  ${CYAN}• Check if you have sudo privileges${NC}"
            echo -e "  ${CYAN}• Ensure you're in the correct user group${NC}"
            echo -e "  ${CYAN}• Try running with 'sudo' if appropriate${NC}"
            ;;
        *"No space left"*)
            echo -e "  ${CYAN}• Free up disk space${NC}"
            echo -e "  ${CYAN}• Move to a location with more available space${NC}"
            echo -e "  ${CYAN}• Use external storage for data${NC}"
            ;;
        *"docker"*|*"Docker"*)
            echo -e "  ${CYAN}• Check Docker installation: docker --version${NC}"
            echo -e "  ${CYAN}• Restart Docker service: sudo systemctl restart docker${NC}"
            echo -e "  ${CYAN}• Add user to docker group: sudo usermod -aG docker \$USER${NC}"
            ;;
        *"network"*|*"Network"*|*"connection"*)
            echo -e "  ${CYAN}• Check internet connectivity${NC}"
            echo -e "  ${CYAN}• Verify network configuration${NC}"
            echo -e "  ${CYAN}• Check firewall settings${NC}"
            ;;
        *)
            echo -e "  ${CYAN}• Check log file: $KEKELI_LOG_FILE${NC}"
            echo -e "  ${CYAN}• Review the error message above${NC}"
            echo -e "  ${CYAN}• Try running the operation again${NC}"
            ;;
    esac

    echo -e "  ${CYAN}• Full log available at: $KEKELI_LOG_FILE${NC}"
}

# Function to attempt automatic recovery
attempt_recovery() {
    local error_type=$1
    local recovery_data=${2:-""}

    set_operation "Error Recovery: $error_type"
    log_with_context "INFO" "Attempting automatic recovery for: $error_type"

    case "$error_type" in
        "docker_permission")
            print_status "progress" "Attempting Docker permission recovery..."
            if sudo usermod -aG docker "$USER" >/dev/null 2>&1; then
                print_status "pass" "Added user to docker group"
                print_status "warn" "Please log out and log back in for changes to take effect"
                complete_operation "success"
                return 0
            fi
            ;;
        "disk_space")
            print_status "progress" "Attempting disk space cleanup..."
            # Clean up common temporary directories
            local cleaned=false
            for dir in /tmp /var/tmp; do
                if [ -w "$dir" ]; then
                    find "$dir" -type f -atime +7 -delete 2>/dev/null && cleaned=true
                fi
            done

            if [ "$cleaned" = true ]; then
                print_status "pass" "Cleaned temporary files"
                complete_operation "success"
                return 0
            fi
            ;;
        "service_restart")
            print_status "progress" "Attempting service restart..."
            local service_name="$recovery_data"
            if [ -n "$service_name" ] && sudo systemctl restart "$service_name" >/dev/null 2>&1; then
                print_status "pass" "Restarted service: $service_name"
                complete_operation "success"
                return 0
            fi
            ;;
    esac

    complete_operation "failed"
    return 1
}

# =============================================================================
# DEBUGGING AND DIAGNOSTICS
# =============================================================================

# Function to enable debug mode
enable_debug_mode() {
    DEBUG_MODE=true
    set -x
    log_with_context "INFO" "Debug mode enabled"
    print_status "info" "Debug mode enabled - verbose logging active"
}

# Function to disable debug mode
disable_debug_mode() {
    DEBUG_MODE=false
    set +x
    log_with_context "INFO" "Debug mode disabled"
    print_status "info" "Debug mode disabled"
}

# Function to enable strict mode
enable_strict_mode() {
    STRICT_MODE=true
    set -euo pipefail
    log_with_context "INFO" "Strict mode enabled"
    print_status "info" "Strict mode enabled - script will exit on any error"
}

# Function to disable strict mode
disable_strict_mode() {
    STRICT_MODE=false
    set +euo pipefail
    log_with_context "INFO" "Strict mode disabled"
    print_status "info" "Strict mode disabled"
}

# Function to collect diagnostic information
collect_diagnostics() {
    local diagnostic_file="$KEKELI_CONFIG_DIR/diagnostics_$(date +%Y%m%d_%H%M%S).txt"

    print_status "progress" "Collecting diagnostic information..."

    {
        echo "=== Kekeli-HomeCloud Diagnostic Report ==="
        echo "Generated: $(date)"
        echo "User: $USER"
        echo "Working Directory: $(pwd)"
        echo "Script: ${BASH_SOURCE[1]:-unknown}"
        echo ""

        echo "=== System Information ==="
        echo "OS: $(detect_os) $(detect_os_version)"
        echo "WSL: $(is_wsl && echo "Yes" || echo "No")"
        echo "Architecture: $(uname -m)"
        echo "Kernel: $(uname -r)"
        echo "Memory: $(get_total_memory)MB total, $(get_available_memory)MB available"
        echo "Disk Space: $(get_available_disk_space)GB available"
        echo "CPU Cores: $(get_cpu_cores)"
        echo ""

        echo "=== Network Information ==="
        echo "Interfaces:"
        detect_network_interfaces | while IFS= read -r line; do
            echo "  $line"
        done
        echo "Primary Interface: $(detect_primary_interface || echo "unknown")"
        echo "Internet: $(check_internet && echo "Connected" || echo "Disconnected")"
        echo ""

        echo "=== Docker Information ==="
        echo "Docker Installed: $(docker_installed && echo "Yes" || echo "No")"
        echo "Docker Running: $(docker_running && echo "Yes" || echo "No")"
        echo "Docker Group: $(user_in_docker_group && echo "Yes" || echo "No")"
        echo "Docker Compose: $(docker_compose_available && echo "Available" || echo "Not Available")"
        if docker_installed; then
            echo "Docker Version: $(docker --version 2>/dev/null || echo "unknown")"
        fi
        echo ""

        echo "=== Environment Variables ==="
        echo "ERROR_CONTEXT: $ERROR_CONTEXT"
        echo "CURRENT_OPERATION: $CURRENT_OPERATION"
        echo "DEBUG_MODE: $DEBUG_MODE"
        echo "STRICT_MODE: $STRICT_MODE"
        echo "ERROR_STACK: ${ERROR_STACK[*]:-empty}"
        echo ""

        echo "=== Recent Log Entries ==="
        if [ -f "$KEKELI_LOG_FILE" ]; then
            tail -50 "$KEKELI_LOG_FILE" 2>/dev/null || echo "Could not read log file"
        else
            echo "No log file found"
        fi

    } > "$diagnostic_file" 2>/dev/null

    if [ -f "$diagnostic_file" ]; then
        print_status "pass" "Diagnostic information saved: $diagnostic_file"
        echo "$diagnostic_file"
    else
        print_status "error" "Failed to create diagnostic file"
        return 1
    fi
}

# =============================================================================
# SIGNAL HANDLERS
# =============================================================================

# Enhanced cleanup function
enhanced_cleanup() {
    local exit_code=$?
    local cleanup_start=$(date)

    log_with_context "INFO" "Starting cleanup (exit code: $exit_code)"

    # Complete any pending operation
    if [ -n "$CURRENT_OPERATION" ]; then
        complete_operation "interrupted"
    fi

    # Clear error context
    clear_error_context

    # Log cleanup completion
    log_with_context "INFO" "Cleanup completed (started: $cleanup_start)"

    exit "$exit_code"
}

# Enhanced interrupt handler
enhanced_interrupt_handler() {
    echo ""
    print_status "warn" "Installation interrupted by user"
    log_with_context "WARNING" "User interrupted installation (SIGINT/SIGTERM)"

    # Ask if user wants to create diagnostic report
    if ask_yes_no "Create diagnostic report before exiting?"; then
        collect_diagnostics >/dev/null
    fi

    exit $ERROR_USER_ABORT
}

# =============================================================================
# INITIALIZATION
# =============================================================================

# Set up enhanced signal handlers
trap enhanced_cleanup EXIT
trap enhanced_interrupt_handler INT TERM

# Initialize error handling
log_with_context "INFO" "Error handling system initialized"
log_with_context "INFO" "Log file: $KEKELI_LOG_FILE"
log_with_context "INFO" "Debug mode: $DEBUG_MODE"
log_with_context "INFO" "Strict mode: $STRICT_MODE"

# Create initial log entry
log_with_context "INFO" "Kekeli-HomeCloud installer session started"
log_with_context "INFO" "System: $(detect_os) $(detect_os_version) ($(uname -m))"
log_with_context "INFO" "User: $USER ($(id))"
log_with_context "INFO" "Working directory: $(pwd)"