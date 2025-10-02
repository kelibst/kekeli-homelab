#!/bin/bash
# check-docker-status.sh - Check Docker container status and display available routes
# Part of the Kekeli-HomeCloud Easy Installer Project

set -euo pipefail

# Get script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities
source "$SCRIPT_DIR/utils/common.sh" 2>/dev/null || {
    echo "Error: Cannot find required utility files. Please run from project root."
    exit 1
}

# Container names
readonly CONTAINER_APP="kekeli-nextcloud-app"
readonly CONTAINER_DB="kekeli-nextcloud-db"
readonly CONTAINER_REDIS="kekeli-nextcloud-redis"

# =============================================================================
# DOCKER STATUS CHECKING FUNCTIONS
# =============================================================================

# Function to check if a specific container is running
check_container_status() {
    local container_name=$1

    if docker ps --format "table {{.Names}}" | grep -q "^$container_name$" 2>/dev/null; then
        echo "running"
    elif docker ps -a --format "table {{.Names}}" | grep -q "^$container_name$" 2>/dev/null; then
        echo "stopped"
    else
        echo "missing"
    fi
}

# Function to get container health status
get_container_health() {
    local container_name=$1

    if ! docker ps --format "table {{.Names}}" | grep -q "^$container_name$" 2>/dev/null; then
        echo "not_running"
        return
    fi

    local health_status=$(docker inspect --format='{{.State.Health.Status}}' "$container_name" 2>/dev/null || echo "no_health_check")

    case $health_status in
        "healthy") echo "healthy" ;;
        "unhealthy") echo "unhealthy" ;;
        "starting") echo "starting" ;;
        "no_health_check")
            # For containers without health checks, check if they're running
            if docker ps --format "table {{.Names}}" | grep -q "^$container_name$" 2>/dev/null; then
                echo "running"
            else
                echo "not_running"
            fi
            ;;
        *) echo "unknown" ;;
    esac
}

# Function to get container uptime
get_container_uptime() {
    local container_name=$1

    if ! docker ps --format "table {{.Names}}" | grep -q "^$container_name$" 2>/dev/null; then
        echo "N/A"
        return
    fi

    docker ps --format "table {{.Status}}" --filter "name=$container_name" | tail -1 | sed 's/Up //' | awk '{print $1 " " $2}'
}

# Function to check overall Kekeli-HomeCloud status
check_kekeli_status() {
    local app_status=$(check_container_status "$CONTAINER_APP")
    local db_status=$(check_container_status "$CONTAINER_DB")
    local redis_status=$(check_container_status "$CONTAINER_REDIS")

    if [[ "$app_status" == "running" && "$db_status" == "running" && "$redis_status" == "running" ]]; then
        echo "fully_running"
    elif [[ "$app_status" == "running" || "$db_status" == "running" || "$redis_status" == "running" ]]; then
        echo "partially_running"
    elif [[ "$app_status" == "stopped" || "$db_status" == "stopped" || "$redis_status" == "stopped" ]]; then
        echo "stopped"
    else
        echo "not_deployed"
    fi
}

# =============================================================================
# ROUTE DISCOVERY FUNCTIONS
# =============================================================================

# Function to discover available access routes
discover_access_routes() {
    local routes=()

    # Load configuration
    local host_ip=$(load_config "HOST_IP" "")
    local primary_domain=$(load_config "PRIMARY_DOMAIN" "")
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")
    local protocol=$(load_config "PROTOCOL" "http")

    # Get local IPs
    local local_ips=($(get_local_ips))

    # Priority 1: HOST_IP (static IP) - always first if configured
    if [[ -n "$host_ip" ]]; then
        routes+=("$protocol://$host_ip:$nextcloud_port")
    fi

    # Priority 2: Primary configured domain (if different from HOST_IP)
    if [[ -n "$primary_domain" && "$primary_domain" != "$host_ip" ]]; then
        if [[ "$primary_domain" =~ :[0-9]+$ ]]; then
            routes+=("$protocol://$primary_domain")
        else
            routes+=("$protocol://$primary_domain:$nextcloud_port")
        fi
    fi

    # Priority 3: Other local IP routes
    for ip in "${local_ips[@]}"; do
        # Skip if this IP is already added as HOST_IP or primary_domain
        if [[ "$ip" != "$host_ip" && "$ip" != "${primary_domain%:*}" ]]; then
            routes+=("$protocol://$ip:$nextcloud_port")
        fi
    done

    # Localhost routes
    routes+=("$protocol://localhost:$nextcloud_port")
    routes+=("$protocol://127.0.0.1:$nextcloud_port")

    # Remove duplicates and print (already prioritized)
    printf '%s\n' "${routes[@]}" | awk '!seen[$0]++'
}

# Function to test route accessibility
test_route_accessibility() {
    local url=$1
    local timeout=5

    if curl -s --max-time $timeout "$url/status.php" >/dev/null 2>&1; then
        echo "accessible"
    elif curl -s --max-time $timeout "$url" >/dev/null 2>&1; then
        echo "partial"
    else
        echo "unreachable"
    fi
}

# =============================================================================
# DISPLAY FUNCTIONS
# =============================================================================

# Function to show Docker status header
show_status_header() {
    local status=$1

    echo -e "${BLUE}┌─────────────────────────────────────────────────────────────┐${NC}"
    echo -e "${BLUE}│${NC}                 ${GREEN}🐳 Docker Status Check${NC}                    ${BLUE}│${NC}"
    echo -e "${BLUE}│${NC}                  ${CYAN}Kekeli-HomeCloud${NC}                        ${BLUE}│${NC}"
    echo -e "${BLUE}└─────────────────────────────────────────────────────────────┘${NC}"
    echo ""

    case $status in
        "fully_running")
            echo -e "${GREEN}✅ Status: All services running${NC}"
            ;;
        "partially_running")
            echo -e "${YELLOW}⚠️  Status: Some services running${NC}"
            ;;
        "stopped")
            echo -e "${YELLOW}⏹️  Status: Services deployed but stopped${NC}"
            ;;
        "not_deployed")
            echo -e "${RED}❌ Status: Services not deployed${NC}"
            ;;
        *)
            echo -e "${RED}❓ Status: Unknown${NC}"
            ;;
    esac
    echo ""
}

# Function to show detailed container status
show_container_details() {
    echo -e "${CYAN}📦 Container Status:${NC}"
    echo ""

    local containers=("$CONTAINER_APP:Nextcloud App" "$CONTAINER_DB:PostgreSQL Database" "$CONTAINER_REDIS:Redis Cache")

    for container_info in "${containers[@]}"; do
        local container_name=$(echo "$container_info" | cut -d':' -f1)
        local container_desc=$(echo "$container_info" | cut -d':' -f2)

        local status=$(check_container_status "$container_name")
        local health=$(get_container_health "$container_name")
        local uptime=$(get_container_uptime "$container_name")

        case $status in
            "running")
                local status_icon="✅"
                local status_color="${GREEN}"
                ;;
            "stopped")
                local status_icon="⏹️"
                local status_color="${YELLOW}"
                ;;
            "missing")
                local status_icon="❌"
                local status_color="${RED}"
                ;;
        esac

        printf "  %s ${status_color}%s${NC}\n" "$status_icon" "$container_desc"
        printf "     ${CYAN}Status:${NC} $status"

        if [[ "$status" == "running" ]]; then
            printf " | ${CYAN}Health:${NC} $health"
            if [[ "$uptime" != "N/A" ]]; then
                printf " | ${CYAN}Uptime:${NC} $uptime"
            fi
        fi
        printf "\n"

        # Show ports for running containers
        if [[ "$status" == "running" ]]; then
            local ports=$(docker port "$container_name" 2>/dev/null | head -3 | sed 's/^/       /')
            if [[ -n "$ports" ]]; then
                echo -e "     ${CYAN}Ports:${NC}"
                echo "$ports"
            fi
        fi
        echo ""
    done
}

# Function to show access routes
show_access_routes() {
    local overall_status=$1

    if [[ "$overall_status" != "fully_running" && "$overall_status" != "partially_running" ]]; then
        echo -e "${CYAN}🌐 Access Routes: ${YELLOW}Service not running${NC}"
        echo ""
        return
    fi

    # Check for HOST_IP configuration
    local host_ip=$(load_config "HOST_IP" "")
    local nextcloud_port=$(load_config "NEXTCLOUD_HTTP_PORT" "8080")

    if [[ -n "$host_ip" ]]; then
        echo -e "${GREEN}🎯 Static IP Configured!${NC}"
        echo -e "${CYAN}Recommended URL (consistent after reboots):${NC}"
        echo -e "  ✅ ${GREEN}http://$host_ip:$nextcloud_port${NC} ${BLUE}(Static IP)${NC}"
        echo ""
        echo -e "${CYAN}🌐 Alternative Routes:${NC}"
    else
        echo -e "${CYAN}🌐 Access Routes:${NC}"
    fi

    echo ""

    local routes=($(discover_access_routes))
    local primary_found=false

    for route in "${routes[@]}"; do
        # Skip HOST_IP route if already shown above
        if [[ -n "$host_ip" && "$route" == "http://$host_ip:$nextcloud_port" ]]; then
            continue
        fi

        local accessibility=$(test_route_accessibility "$route")
        local is_primary=""

        # Check if this is the primary configured route
        local primary_domain=$(load_config "PRIMARY_DOMAIN" "")
        if [[ -n "$primary_domain" && "$route" =~ "$primary_domain" ]]; then
            is_primary=" ${BLUE}(Primary)${NC}"
            primary_found=true
        fi

        case $accessibility in
            "accessible")
                echo -e "  ✅ ${GREEN}$route${NC}$is_primary"
                ;;
            "partial")
                echo -e "  ⚠️  ${YELLOW}$route${NC} (Limited access)$is_primary"
                ;;
            "unreachable")
                echo -e "  ❌ ${RED}$route${NC} (Unreachable)$is_primary"
                ;;
        esac
    done

    echo ""

    # Show mobile access instructions if service is running
    if [[ "$overall_status" == "fully_running" ]]; then
        echo -e "${CYAN}📱 Mobile Access:${NC}"
        local protocol=$(load_config "PROTOCOL" "http")

        if [[ -n "$host_ip" ]]; then
            echo -e "  📲 Server URL: ${GREEN}$protocol://$host_ip:$nextcloud_port${NC} ${YELLOW}(Use this - it won't change)${NC}"
        else
            local primary_domain=$(load_config "PRIMARY_DOMAIN" "")
            if [[ -n "$primary_domain" ]]; then
                if [[ "$primary_domain" =~ :[0-9]+$ ]]; then
                    echo -e "  📲 Server URL: ${GREEN}$protocol://$primary_domain${NC}"
                else
                    echo -e "  📲 Server URL: ${GREEN}$protocol://$primary_domain:$nextcloud_port${NC}"
                fi
            else
                local first_ip=$(get_local_ips | head -1)
                if [[ -n "$first_ip" ]]; then
                    echo -e "  📲 Server URL: ${GREEN}$protocol://$first_ip:$nextcloud_port${NC}"
                fi
            fi
            echo -e "  ${YELLOW}💡 Tip:${NC} Set HOST_IP in .env for a consistent URL"
        fi

        local admin_user=$(load_config "ADMIN_USER" "admin")
        echo -e "  👤 Username: ${CYAN}$admin_user${NC}"
        echo -e "  🔑 Password: ${CYAN}(From your .env file)${NC}"
        echo ""
    fi
}

# Function to show available actions
show_available_actions() {
    local overall_status=$1

    echo -e "${CYAN}📌 Available Actions:${NC}"
    echo ""

    case $overall_status in
        "fully_running")
            echo -e "  ${GREEN}[R]${NC} Restart all services"
            echo -e "  ${GREEN}[S]${NC} Stop all services"
            echo -e "  ${GREEN}[L]${NC} View container logs"
            echo -e "  ${GREEN}[M]${NC} Open mobile setup guide"
            ;;
        "partially_running"|"stopped")
            echo -e "  ${GREEN}[S]${NC} Start all services"
            echo -e "  ${GREEN}[R]${NC} Restart all services"
            echo -e "  ${GREEN}[L]${NC} View container logs"
            ;;
        "not_deployed")
            echo -e "  ${GREEN}[I]${NC} Run full installation"
            echo -e "  ${GREEN}[D]${NC} Deploy services only"
            ;;
    esac

    echo -e "  ${GREEN}[C]${NC} Check configuration"
    echo -e "  ${GREEN}[U]${NC} Update IP configuration"
    echo -e "  ${GREEN}[H]${NC} Help & troubleshooting"
    echo -e "  ${GREEN}[Q]${NC} Quit"
    echo ""
}

# =============================================================================
# ACTION FUNCTIONS
# =============================================================================

# Function to handle user actions
handle_action() {
    local action=$1
    local overall_status=$2

    case $action in
        "R"|"r")
            echo -e "${BLUE}🔄 Restarting all services...${NC}"
            docker-compose restart 2>/dev/null || echo -e "${RED}Error: Could not restart services${NC}"
            ;;
        "S"|"s")
            if [[ "$overall_status" == "fully_running" || "$overall_status" == "partially_running" ]]; then
                echo -e "${BLUE}⏹️  Stopping all services...${NC}"
                docker-compose stop 2>/dev/null || echo -e "${RED}Error: Could not stop services${NC}"
            else
                echo -e "${BLUE}▶️  Starting all services...${NC}"
                docker-compose up -d 2>/dev/null || echo -e "${RED}Error: Could not start services${NC}"
            fi
            ;;
        "L"|"l")
            echo -e "${BLUE}📋 Container Logs:${NC}"
            echo ""
            docker-compose logs --tail=20 2>/dev/null || echo -e "${RED}Error: Could not retrieve logs${NC}"
            ;;
        "M"|"m")
            if [[ "$overall_status" == "fully_running" ]]; then
                "$SCRIPT_DIR/setup-mobile.sh" --show-guide 2>/dev/null || echo -e "${RED}Mobile setup not available${NC}"
            else
                echo -e "${YELLOW}Mobile setup requires running services${NC}"
            fi
            ;;
        "I"|"i")
            echo -e "${BLUE}🚀 Starting full installation...${NC}"
            "$SCRIPT_DIR/../install.sh"
            ;;
        "D"|"d")
            echo -e "${BLUE}🐳 Deploying services...${NC}"
            "$SCRIPT_DIR/setup-nextcloud.sh" 2>/dev/null || echo -e "${RED}Error: Could not deploy services${NC}"
            ;;
        "C"|"c")
            echo -e "${BLUE}📝 Configuration:${NC}"
            echo ""
            if [[ -f "$KEKELI_CONFIG_FILE" ]]; then
                cat "$KEKELI_CONFIG_FILE" | grep -E "(PRIMARY_DOMAIN|NEXTCLOUD_HTTP_PORT|ADMIN_USER)" | sed 's/^/  /'
            else
                echo -e "${YELLOW}No configuration file found${NC}"
            fi
            ;;
        "U"|"u")
            echo -e "${BLUE}🔧 Updating IP configuration...${NC}"
            "$SCRIPT_DIR/setup-networking.sh" --update-ip 2>/dev/null || echo -e "${RED}Error: Could not update IP configuration${NC}"
            ;;
        "H"|"h")
            show_help
            ;;
        "Q"|"q")
            echo -e "${CYAN}Thanks for using Kekeli-HomeCloud!${NC}"
            exit 0
            ;;
        *)
            echo -e "${RED}Invalid choice: $action${NC}"
            ;;
    esac
}

# Function to show help
show_help() {
    echo -e "${BLUE}📚 Help & Troubleshooting${NC}"
    echo -e "${BLUE}=========================${NC}"
    echo ""

    echo -e "${CYAN}🔧 Common Issues:${NC}"
    echo ""
    echo -e "${YELLOW}• Services won't start:${NC}"
    echo -e "  Check Docker daemon: sudo systemctl status docker"
    echo -e "  Check port availability: netstat -tlnp | grep 8080"
    echo ""

    echo -e "${YELLOW}• Cannot access web interface:${NC}"
    echo -e "  Verify firewall settings: sudo ufw status"
    echo -e "  Check container health: docker ps"
    echo ""

    echo -e "${YELLOW}• Mobile app connection issues:${NC}"
    echo -e "  Use exact server URL with port number"
    echo -e "  Check network connectivity from mobile device"
    echo ""

    echo -e "${CYAN}📖 Quick Commands:${NC}"
    echo -e "  • Check logs: docker-compose logs"
    echo -e "  • Restart services: docker-compose restart"
    echo -e "  • Update containers: docker-compose pull && docker-compose up -d"
    echo ""
}

# =============================================================================
# MAIN FUNCTIONS
# =============================================================================

# Interactive mode function
run_interactive() {
    while true; do
        clear
        local overall_status=$(check_kekeli_status)

        show_status_header "$overall_status"
        show_container_details
        show_access_routes "$overall_status"
        show_available_actions "$overall_status"

        echo -ne "${GREEN}Enter your choice: ${NC}"
        read -r choice
        echo ""

        if [[ "$choice" == "Q" || "$choice" == "q" ]]; then
            echo -e "${CYAN}Thanks for using Kekeli-HomeCloud!${NC}"
            break
        fi

        handle_action "$choice" "$overall_status"

        echo ""
        echo -e "${CYAN}Press Enter to continue...${NC}"
        read -r
    done
}

# Status-only mode function
run_status_only() {
    local overall_status=$(check_kekeli_status)

    # Simple text output for status-only mode
    case $overall_status in
        "fully_running")
            echo "All Kekeli-HomeCloud services are running"
            echo ""
            echo "Access Routes:"
            local routes=($(discover_access_routes))
            for route in "${routes[@]}"; do
                echo "  $route"
            done
            exit 0
            ;;
        "partially_running")
            echo "Some Kekeli-HomeCloud services are running"
            exit 1
            ;;
        "stopped")
            echo "Kekeli-HomeCloud services are deployed but stopped"
            exit 2
            ;;
        "not_deployed")
            echo "Kekeli-HomeCloud services are not deployed"
            exit 3
            ;;
        *)
            echo "Unknown Docker status"
            exit 4
            ;;
    esac
}

# Main function
main() {
    local mode="interactive"

    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --status-only|--status)
                mode="status_only"
                shift
                ;;
            --help|-h)
                echo "Kekeli-HomeCloud Docker Status Checker"
                echo ""
                echo "Usage: $0 [OPTIONS]"
                echo ""
                echo "Options:"
                echo "  --status-only    Show status and exit (non-interactive)"
                echo "  --help, -h       Show this help message"
                echo ""
                echo "Exit codes (status-only mode):"
                echo "  0 - All services running"
                echo "  1 - Some services running"
                echo "  2 - Services deployed but stopped"
                echo "  3 - Services not deployed"
                echo "  4 - Unknown status"
                exit 0
                ;;
            *)
                echo "Unknown option: $1"
                echo "Use --help for usage information"
                exit 1
                ;;
        esac
    done

    # Check if Docker is available
    if ! docker_installed; then
        print_status "error" "Docker is not installed"
        exit 1
    fi

    if ! docker_running; then
        print_status "error" "Docker daemon is not running"
        exit 1
    fi

    # Run in specified mode
    case $mode in
        "interactive")
            run_interactive
            ;;
        "status_only")
            run_status_only
            ;;
    esac
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi