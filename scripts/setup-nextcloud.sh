#!/bin/bash
# setup-nextcloud.sh - Nextcloud container deployment for Kekeli-HomeCloud
# Part of the Kekeli-HomeCloud Easy Installer Project

# Source utilities
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
UTILS_DIR="$SCRIPT_DIR/utils"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
TEMPLATES_DIR="$PROJECT_DIR/templates"

source "$UTILS_DIR/common.sh"
source "$UTILS_DIR/error-handling.sh"

# =============================================================================
# NEXTCLOUD DEPLOYMENT CONFIGURATION
# =============================================================================

readonly NEXTCLOUD_DEFAULT_VERSION="latest"
readonly DEFAULT_ADMIN_USER="admin"
readonly DEFAULT_DB_NAME="nextcloud"
readonly DEFAULT_DB_USER="nextcloud"
readonly KEKELI_VERSION="1.0.0"

# Performance defaults
readonly DEFAULT_PHP_MEMORY="512M"
readonly DEFAULT_PHP_UPLOAD="10G"
readonly DEFAULT_PHP_MAX_FILES="100"
readonly DEFAULT_NEXTCLOUD_MEMORY="1g"
readonly DEFAULT_NEXTCLOUD_CPU="1.0"

# =============================================================================
# MAIN DEPLOYMENT FUNCTIONS
# =============================================================================

# Function to deploy Nextcloud containers
deploy_nextcloud() {
    print_section "🐳" "Kekeli-HomeCloud Nextcloud Deployment"

    print_status "info" "Deploying Nextcloud with PostgreSQL and Redis"
    echo -e "${CYAN}This will create and start your Nextcloud instance.${NC}"
    echo ""

    set_operation "Nextcloud Deployment"

    # Step 1: Validate prerequisites
    if ! validate_deployment_prerequisites; then
        complete_operation "failed"
        return 1
    fi

    # Step 2: Generate deployment configuration
    if ! generate_deployment_configuration; then
        complete_operation "failed"
        return 1
    fi

    # Step 3: Create deployment files
    if ! create_deployment_files; then
        complete_operation "failed"
        return 1
    fi

    # Step 4: Deploy containers
    if ! deploy_containers; then
        complete_operation "failed"
        return 1
    fi

    # Step 5: Configure Nextcloud
    if ! configure_nextcloud_post_deploy; then
        complete_operation "failed"
        return 1
    fi

    # Step 6: Validate deployment
    if ! validate_deployment; then
        complete_operation "failed"
        return 1
    fi

    complete_operation "success"
    return 0
}

# Function to validate deployment prerequisites
validate_deployment_prerequisites() {
    print_subsection "Validating Deployment Prerequisites"

    local validation_passed=true

    # Check Docker availability
    if ! docker_installed || ! docker_running; then
        print_status "fail" "Docker is not available or not running"
        validation_passed=false
    else
        print_status "pass" "Docker is available and running"
    fi

    # Check Docker Compose
    if ! docker_compose_available; then
        print_status "fail" "Docker Compose is not available"
        validation_passed=false
    else
        print_status "pass" "Docker Compose is available"
    fi

    # Check storage configuration
    local storage_type=$(load_config "STORAGE_TYPE")
    if [ -z "$storage_type" ]; then
        print_status "fail" "Storage configuration not found"
        validation_passed=false
    else
        print_status "pass" "Storage configuration found: $storage_type"
    fi

    # Check network configuration
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")
    if [ -z "$nextcloud_port" ]; then
        print_status "fail" "Network configuration not found"
        validation_passed=false
    else
        print_status "pass" "Network configuration found: port $nextcloud_port"
    fi

    # Check port availability
    if netstat -tln 2>/dev/null | grep -q ":$nextcloud_port "; then
        print_status "warn" "Port $nextcloud_port is in use"
        if ! ask_yes_no "Continue deployment anyway?"; then
            validation_passed=false
        fi
    else
        print_status "pass" "Port $nextcloud_port is available"
    fi

    # Check available resources
    local available_memory=$(get_available_memory)
    if [ $available_memory -lt 1024 ]; then
        print_status "warn" "Low available memory: ${available_memory}MB"
        if ! ask_yes_no "Continue with limited memory?"; then
            validation_passed=false
        fi
    else
        print_status "pass" "Sufficient memory available: ${available_memory}MB"
    fi

    if [ "$validation_passed" = true ]; then
        print_status "pass" "All prerequisites validated"
        return 0
    else
        print_status "fail" "Prerequisites validation failed"
        return 1
    fi
}

# Function to generate deployment configuration
generate_deployment_configuration() {
    print_subsection "Generating Deployment Configuration"

    # Get or generate credentials
    local admin_user=$(load_config "ADMIN_USER" "$DEFAULT_ADMIN_USER")
    local admin_password=$(load_config "ADMIN_PASSWORD")

    if [ -z "$admin_password" ]; then
        admin_password=$(generate_random_string 16)
        save_config "ADMIN_PASSWORD" "$admin_password"
        print_status "pass" "Generated admin password"
    fi

    # Database credentials
    local db_name=$(load_config "POSTGRES_DB" "$DEFAULT_DB_NAME")
    local db_user=$(load_config "POSTGRES_USER" "$DEFAULT_DB_USER")
    local db_password=$(load_config "POSTGRES_PASSWORD")

    if [ -z "$db_password" ]; then
        db_password=$(generate_random_string 24)
        save_config "POSTGRES_DB" "$db_name"
        save_config "POSTGRES_USER" "$db_user"
        save_config "POSTGRES_PASSWORD" "$db_password"
        print_status "pass" "Generated database credentials"
    fi

    # Redis password
    local redis_password=$(load_config "REDIS_PASSWORD")
    if [ -z "$redis_password" ]; then
        redis_password=$(generate_random_string 24)
        save_config "REDIS_PASSWORD" "$redis_password"
        print_status "pass" "Generated Redis password"
    fi

    # Nextcloud version
    local nextcloud_version=$(load_config "NEXTCLOUD_VERSION" "$NEXTCLOUD_DEFAULT_VERSION")
    save_config "NEXTCLOUD_VERSION" "$nextcloud_version"

    # Performance configuration
    save_config "PHP_MEMORY_LIMIT" "$(load_config "PHP_MEMORY_LIMIT" "$DEFAULT_PHP_MEMORY")"
    save_config "PHP_UPLOAD_LIMIT" "$(load_config "PHP_UPLOAD_LIMIT" "$DEFAULT_PHP_UPLOAD")"
    save_config "PHP_MAX_FILE_UPLOADS" "$(load_config "PHP_MAX_FILE_UPLOADS" "$DEFAULT_PHP_MAX_FILES")"
    save_config "NEXTCLOUD_MEMORY_LIMIT" "$(load_config "NEXTCLOUD_MEMORY_LIMIT" "$DEFAULT_NEXTCLOUD_MEMORY")"
    save_config "NEXTCLOUD_CPU_LIMIT" "$(load_config "NEXTCLOUD_CPU_LIMIT" "$DEFAULT_NEXTCLOUD_CPU")"

    # System configuration
    save_config "TIMEZONE" "$(timedatectl show -p Timezone --value 2>/dev/null || echo "UTC")"
    save_config "KEKELI_VERSION" "$KEKELI_VERSION"
    save_config "INSTALLATION_DATE" "$(date -u +"%Y-%m-%dT%H:%M:%SZ")"

    # Backup configuration
    save_config "BACKUP_ENABLED" "$(load_config "BACKUP_ENABLED" "true")"
    save_config "BACKUP_RETENTION_DAYS" "$(load_config "BACKUP_RETENTION_DAYS" "30")"

    print_status "pass" "Deployment configuration generated"
    return 0
}

# Function to create deployment files
create_deployment_files() {
    print_subsection "Creating Deployment Files"

    local deployment_dir="$PWD"
    local docker_compose_file="$deployment_dir/docker-compose.yml"
    local env_file="$deployment_dir/.env"

    # Create Docker Compose file
    if ! create_docker_compose_file "$docker_compose_file"; then
        return 1
    fi

    # Create environment file
    if ! create_environment_file "$env_file"; then
        return 1
    fi

    # Set proper permissions
    chmod 600 "$env_file" 2>/dev/null  # Protect sensitive environment file
    chmod 644 "$docker_compose_file" 2>/dev/null

    print_status "pass" "Deployment files created successfully"
    return 0
}

# Function to create Docker Compose file
create_docker_compose_file() {
    local output_file=$1

    print_status "progress" "Creating Docker Compose configuration..."

    # Read template
    local template_file="$TEMPLATES_DIR/docker-compose.yml.template"
    if [ ! -f "$template_file" ]; then
        handle_critical_error "Docker Compose template not found: $template_file"
        return 1
    fi

    local template_content
    template_content=$(cat "$template_file")

    # Load configuration values
    local nextcloud_version=$(load_config "NEXTCLOUD_VERSION")
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")
    local postgres_db=$(load_config "POSTGRES_DB")
    local postgres_user=$(load_config "POSTGRES_USER")
    local postgres_password=$(load_config "POSTGRES_PASSWORD")
    local redis_password=$(load_config "REDIS_PASSWORD")
    local admin_user=$(load_config "ADMIN_USER")
    local admin_password=$(load_config "ADMIN_PASSWORD")
    local trusted_domains=$(load_config "TRUSTED_DOMAINS")
    local primary_domain=$(load_config "PRIMARY_IP" "localhost")
    local protocol=$(load_config "PROTOCOL" "http")
    local php_memory=$(load_config "PHP_MEMORY_LIMIT")
    local php_upload=$(load_config "PHP_UPLOAD_LIMIT")
    local php_max_files=$(load_config "PHP_MAX_FILE_UPLOADS")
    local nextcloud_memory=$(load_config "NEXTCLOUD_MEMORY_LIMIT")
    local nextcloud_cpu=$(load_config "NEXTCLOUD_CPU_LIMIT")

    # Generate storage volumes configuration
    local storage_volumes
    storage_volumes=$(generate_storage_volumes_config)

    # Replace template variables
    template_content=${template_content//__NEXTCLOUD_VERSION__/$nextcloud_version}
    template_content=${template_content//__NEXTCLOUD_HTTP_PORT__/$nextcloud_port}
    template_content=${template_content//__POSTGRES_DB__/$postgres_db}
    template_content=${template_content//__POSTGRES_USER__/$postgres_user}
    template_content=${template_content//__POSTGRES_PASSWORD__/$postgres_password}
    template_content=${template_content//__REDIS_PASSWORD__/$redis_password}
    template_content=${template_content//__ADMIN_USER__/$admin_user}
    template_content=${template_content//__ADMIN_PASSWORD__/$admin_password}
    template_content=${template_content//__TRUSTED_DOMAINS__/$trusted_domains}
    template_content=${template_content//__PRIMARY_DOMAIN__/$primary_domain}
    template_content=${template_content//__PROTOCOL__/$protocol}
    template_content=${template_content//__PHP_MEMORY_LIMIT__/$php_memory}
    template_content=${template_content//__PHP_UPLOAD_LIMIT__/$php_upload}
    template_content=${template_content//__PHP_MAX_FILE_UPLOADS__/$php_max_files}
    template_content=${template_content//__NEXTCLOUD_MEMORY_LIMIT__/$nextcloud_memory}
    template_content=${template_content//__NEXTCLOUD_CPU_LIMIT__/$nextcloud_cpu}
    template_content=${template_content//__STORAGE_VOLUMES__/$storage_volumes}

    # Write output file
    if echo "$template_content" > "$output_file"; then
        print_status "pass" "Docker Compose file created: $output_file"
        return 0
    else
        print_status "fail" "Failed to create Docker Compose file"
        return 1
    fi
}

# Function to generate storage volumes configuration
generate_storage_volumes_config() {
    local storage_type=$(load_config "STORAGE_TYPE")
    local storage_volumes=""

    case "$storage_type" in
        "device"|"local")
            local data_dir=$(load_config "STORAGE_DATA_DIR")
            if [ -n "$data_dir" ]; then
                storage_volumes="      - $data_dir:/var/www/html/data:rw"
            fi
            ;;
        "docker-volume")
            # Use named Docker volume (already defined in template)
            storage_volumes="      # Using Docker managed volume for data"
            ;;
        *)
            storage_volumes="      # No external storage configured"
            ;;
    esac

    echo "$storage_volumes"
}

# Function to create environment file
create_environment_file() {
    local output_file=$1

    print_status "progress" "Creating environment configuration..."

    # Read template
    local template_file="$TEMPLATES_DIR/.env.template"
    if [ ! -f "$template_file" ]; then
        handle_critical_error "Environment template not found: $template_file"
        return 1
    fi

    local template_content
    template_content=$(cat "$template_file")

    # Load all configuration values
    local config_vars=(
        "NEXTCLOUD_HTTP_PORT" "NEXTCLOUD_HTTPS_PORT" "PRIMARY_DOMAIN" "PROTOCOL"
        "TRUSTED_DOMAINS" "POSTGRES_DB" "POSTGRES_USER" "POSTGRES_PASSWORD"
        "REDIS_PASSWORD" "NEXTCLOUD_VERSION" "ADMIN_USER" "ADMIN_PASSWORD"
        "PHP_MEMORY_LIMIT" "PHP_UPLOAD_LIMIT" "PHP_MAX_FILE_UPLOADS"
        "NEXTCLOUD_MEMORY_LIMIT" "NEXTCLOUD_CPU_LIMIT" "STORAGE_TYPE"
        "STORAGE_DATA_DIR" "STORAGE_DEVICE" "STORAGE_MOUNT_POINT"
        "TIMEZONE" "KEKELI_VERSION" "INSTALLATION_DATE"
        "BACKUP_ENABLED" "BACKUP_RETENTION_DAYS"
    )

    # Replace template variables
    for var in "${config_vars[@]}"; do
        local value=$(load_config "$var" "")
        template_content=${template_content//__${var}__/$value}
    done

    # Add current date
    template_content=${template_content//\$(date)/$(date)}

    # Write output file
    if echo "$template_content" > "$output_file"; then
        print_status "pass" "Environment file created: $output_file"
        return 0
    else
        print_status "fail" "Failed to create environment file"
        return 1
    fi
}

# Function to deploy containers
deploy_containers() {
    print_subsection "Deploying Nextcloud Containers"

    # Stop any existing containers
    print_status "progress" "Stopping existing containers..."
    docker compose down 2>/dev/null || true

    # Pull latest images with real-time progress
    print_status "info" "Downloading container images (this may take a while on slow connections)..."
    print_status "info" "Images to download: Nextcloud, PostgreSQL, and Redis"
    print_status "info" "You can press Ctrl+C to interrupt and choose how to proceed"
    echo ""

    if ! execute_with_progress "docker compose pull" "Download container images" false; then
        print_status "warn" "Some images failed to download, attempting to continue with existing images"
        print_status "info" "If containers fail to start, you may need to retry the installation"
    fi

    # Start containers
    print_status "progress" "Starting Nextcloud containers..."
    if ! safe_execute "docker compose up -d" "Start containers"; then
        return 1
    fi

    print_status "pass" "Containers deployed successfully"
    return 0
}

# Function to configure Nextcloud after deployment
configure_nextcloud_post_deploy() {
    print_subsection "Configuring Nextcloud Post-Deployment"

    # Wait for Nextcloud to be ready
    print_status "progress" "Waiting for Nextcloud to initialize..."
    if ! wait_for_nextcloud_ready; then
        handle_recoverable_error "Nextcloud failed to become ready"
        return 1
    fi

    # Configure external storage (if applicable)
    local storage_type=$(load_config "STORAGE_TYPE")
    if [[ "$storage_type" =~ ^(device|local)$ ]]; then
        if ! configure_external_storage; then
            print_status "warn" "External storage configuration may be incomplete"
        fi
    fi

    # Set up mobile access optimizations
    if ! configure_mobile_optimizations; then
        print_status "warn" "Mobile optimizations may be incomplete"
    fi

    print_status "pass" "Post-deployment configuration completed"
    return 0
}

# Function to wait for Nextcloud to be ready
wait_for_nextcloud_ready() {
    local max_attempts=60
    local attempt=0

    while [ $attempt -lt $max_attempts ]; do
        if docker exec kekeli-nextcloud-app curl -f http://localhost/status.php >/dev/null 2>&1; then
            print_status "pass" "Nextcloud is ready"
            return 0
        fi

        if docker exec kekeli-nextcloud-app curl -f http://localhost/ >/dev/null 2>&1; then
            print_status "pass" "Nextcloud web interface is accessible"
            return 0
        fi

        sleep 5
        ((attempt++))

        if [ $((attempt % 12)) -eq 0 ]; then  # Every minute
            print_status "progress" "Still waiting for Nextcloud... ($((attempt * 5))s elapsed)"
        fi
    done

    print_status "fail" "Nextcloud failed to become ready after $((max_attempts * 5)) seconds"
    return 1
}

# Function to configure external storage
configure_external_storage() {
    print_status "progress" "Configuring external storage access..."

    local data_dir=$(load_config "STORAGE_DATA_DIR")
    if [ -z "$data_dir" ]; then
        return 1
    fi

    # Ensure proper permissions
    if [ -d "$data_dir" ]; then
        # Set ownership to www-data (UID 33) for Nextcloud access
        if safe_execute "sudo chown -R 33:33 '$data_dir'" "Set storage permissions" false; then
            print_status "pass" "Storage permissions configured"
        fi
    fi

    return 0
}

# Function to configure mobile optimizations
configure_mobile_optimizations() {
    print_status "progress" "Configuring mobile access optimizations..."

    # Configure trusted domains via occ command
    local trusted_domains=$(load_config "TRUSTED_DOMAINS")
    if [ -n "$trusted_domains" ]; then
        # Convert comma-separated domains to array and configure
        local domain_index=0
        IFS=',' read -ra DOMAIN_ARRAY <<< "$trusted_domains"
        for domain in "${DOMAIN_ARRAY[@]}"; do
            domain=$(echo "$domain" | xargs)  # Trim whitespace
            if [ -n "$domain" ]; then
                docker exec kekeli-nextcloud-app php occ config:system:set trusted_domains $domain_index --value="$domain" >/dev/null 2>&1 || true
                ((domain_index++))
            fi
        done
        print_status "pass" "Trusted domains configured"
    fi

    # Enable recommended mobile apps
    local mobile_apps=("files" "activity" "notifications")
    for app in "${mobile_apps[@]}"; do
        docker exec kekeli-nextcloud-app php occ app:enable "$app" >/dev/null 2>&1 || true
    done

    return 0
}

# Function to validate deployment
validate_deployment() {
    print_subsection "Validating Nextcloud Deployment"

    local validation_passed=true

    # Check container status
    print_status "progress" "Checking container status..."
    local containers=("kekeli-nextcloud-app" "kekeli-nextcloud-db" "kekeli-nextcloud-redis")

    for container in "${containers[@]}"; do
        if docker ps --format "table {{.Names}}" | grep -q "^$container$"; then
            print_status "pass" "Container running: $container"
        else
            print_status "fail" "Container not running: $container"
            validation_passed=false
        fi
    done

    # Check web interface accessibility
    print_status "progress" "Testing web interface accessibility..."
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")
    if curl -f "http://localhost:$nextcloud_port/" >/dev/null 2>&1; then
        print_status "pass" "Web interface accessible"
    else
        print_status "fail" "Web interface not accessible"
        validation_passed=false
    fi

    # Check database connectivity
    print_status "progress" "Testing database connectivity..."
    if docker exec kekeli-nextcloud-db pg_isready -U nextcloud >/dev/null 2>&1; then
        print_status "pass" "Database connectivity verified"
    else
        print_status "fail" "Database connectivity failed"
        validation_passed=false
    fi

    # Check Redis connectivity
    print_status "progress" "Testing Redis connectivity..."
    if docker exec kekeli-nextcloud-redis redis-cli ping >/dev/null 2>&1; then
        print_status "pass" "Redis connectivity verified"
    else
        print_status "fail" "Redis connectivity failed"
        validation_passed=false
    fi

    if [ "$validation_passed" = true ]; then
        print_status "pass" "Deployment validation successful"
        return 0
    else
        print_status "fail" "Deployment validation failed"
        return 1
    fi
}

# Function to show deployment summary
show_deployment_summary() {
    print_section "🎉" "Nextcloud Deployment Summary"

    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT")
    local admin_user=$(load_config "ADMIN_USER")
    local admin_password=$(load_config "ADMIN_PASSWORD")
    local access_urls=$(load_config "ACCESS_URLS")
    local mobile_urls=$(load_config "MOBILE_ACCESS_URLS")

    echo -e "${GREEN}✅ Kekeli-HomeCloud Deployment Successful!${NC}"
    echo ""

    echo -e "${CYAN}🔐 Admin Access:${NC}"
    echo -e "  Username: ${GREEN}$admin_user${NC}"
    echo -e "  Password: ${GREEN}$admin_password${NC}"
    echo ""

    echo -e "${CYAN}🌐 Web Access:${NC}"
    if [ -n "$access_urls" ]; then
        while IFS= read -r url_info; do
            if [ -z "$url_info" ]; then continue; fi
            local url=$(echo "$url_info" | cut -d'|' -f1)
            local description=$(echo "$url_info" | cut -d'|' -f2)
            echo -e "  🖥️  ${GREEN}$url${NC} - $description"
        done <<< "$access_urls"
    else
        echo -e "  🖥️  ${GREEN}http://localhost:$nextcloud_port${NC} - Local access"
    fi
    echo ""

    echo -e "${CYAN}📱 Mobile Access:${NC}"
    if [ -n "$mobile_urls" ]; then
        while IFS= read -r url; do
            if [ -z "$url" ]; then continue; fi
            echo -e "  📱 ${GREEN}$url${NC}"
        done <<< "$mobile_urls"
    else
        echo -e "  📱 Use any web access URL above"
    fi
    echo ""

    echo -e "${CYAN}🐳 Container Status:${NC}"
    docker ps --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}" | grep kekeli || echo "  No containers found"
    echo ""

    echo -e "${CYAN}💾 Storage:${NC}"
    local storage_type=$(load_config "STORAGE_TYPE")
    local storage_data_dir=$(load_config "STORAGE_DATA_DIR")
    echo -e "  Type: ${GREEN}$storage_type${NC}"
    echo -e "  Location: ${GREEN}$storage_data_dir${NC}"
    echo ""

    print_status "pass" "Your Kekeli-HomeCloud is ready to use!"
}

# =============================================================================
# CONTAINER MANAGEMENT FUNCTIONS
# =============================================================================

# Function to stop containers
stop_containers() {
    print_status "progress" "Stopping Nextcloud containers..."
    if docker compose down; then
        print_status "pass" "Containers stopped successfully"
        return 0
    else
        print_status "fail" "Failed to stop containers"
        return 1
    fi
}

# Function to restart containers
restart_containers() {
    print_status "progress" "Restarting Nextcloud containers..."
    if docker compose restart; then
        print_status "pass" "Containers restarted successfully"
        return 0
    else
        print_status "fail" "Failed to restart containers"
        return 1
    fi
}

# Function to show container logs
show_container_logs() {
    local container=${1:-"kekeli-nextcloud-app"}
    local lines=${2:-50}

    print_status "info" "Showing logs for container: $container"
    docker logs --tail "$lines" "$container" 2>/dev/null || {
        print_status "error" "Failed to get logs for container: $container"
        return 1
    }
}

# =============================================================================
# COMMAND LINE INTERFACE
# =============================================================================

# Help function
show_help() {
    echo "Kekeli-HomeCloud Nextcloud Deployment"
    echo ""
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help        Show this help message"
    echo "  -d, --deploy      Deploy Nextcloud containers"
    echo "  -s, --stop        Stop Nextcloud containers"
    echo "  -r, --restart     Restart Nextcloud containers"
    echo "  --status          Show deployment status"
    echo "  --logs [CONTAINER] Show container logs"
    echo "  --validate        Validate deployment"
    echo ""
    echo "Examples:"
    echo "  $0 --deploy      # Deploy Nextcloud"
    echo "  $0 --status      # Show status"
    echo "  $0 --logs        # Show app logs"
}

# Main function
main() {
    local deploy_mode=false
    local stop_mode=false
    local restart_mode=false
    local status_mode=false
    local logs_mode=false
    local logs_container=""
    local validate_mode=false

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -d|--deploy)
                deploy_mode=true
                shift
                ;;
            -s|--stop)
                stop_mode=true
                shift
                ;;
            -r|--restart)
                restart_mode=true
                shift
                ;;
            --status)
                status_mode=true
                shift
                ;;
            --logs)
                logs_mode=true
                logs_container=${2:-"kekeli-nextcloud-app"}
                shift 2 2>/dev/null || shift
                ;;
            --validate)
                validate_mode=true
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
    set_error_context "Nextcloud Deployment"

    # Handle specific modes
    if [ "$status_mode" = true ]; then
        show_deployment_summary
        exit 0
    fi

    if [ "$stop_mode" = true ]; then
        if stop_containers; then
            exit 0
        else
            exit 1
        fi
    fi

    if [ "$restart_mode" = true ]; then
        if restart_containers; then
            exit 0
        else
            exit 1
        fi
    fi

    if [ "$logs_mode" = true ]; then
        show_container_logs "$logs_container"
        exit 0
    fi

    if [ "$validate_mode" = true ]; then
        if validate_deployment; then
            print_status "pass" "Deployment validation successful"
            exit 0
        else
            print_status "fail" "Deployment validation failed"
            exit 1
        fi
    fi

    # Default: Deploy
    if [ "$deploy_mode" = true ] || [ $# -eq 0 ]; then
        if deploy_nextcloud; then
            echo ""
            show_deployment_summary
            exit 0
        else
            print_status "fail" "Nextcloud deployment failed"
            exit 1
        fi
    fi
}

# Run main function if script is executed directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    main "$@"
fi