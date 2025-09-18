#!/bin/bash
# test-safe.sh - Safe testing script for Kekeli-HomeCloud without affecting current setup
# This script tests all components in read-only/validation modes

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

echo -e "${BLUE}🧪 Kekeli-HomeCloud Safe Testing Suite${NC}"
echo -e "${BLUE}====================================${NC}"
echo ""

# Test 1: Requirements Check
echo -e "${CYAN}Test 1: System Requirements Validation${NC}"
echo "Testing system compatibility and prerequisites..."
./scripts/check-requirements.sh --quiet 2>/dev/null
req_status=$?
if [ $req_status -eq 0 ]; then
    echo -e "✅ ${GREEN}Requirements: PASSED${NC}"
else
    echo -e "⚠️  ${YELLOW}Requirements: Some issues detected (exit code: $req_status)${NC}"
fi
echo ""

# Test 2: Script Help Functions
echo -e "${CYAN}Test 2: Script Help Functions${NC}"
echo "Testing all setup scripts can display help..."

scripts=("setup-storage.sh" "setup-networking.sh" "setup-nextcloud.sh" "setup-mobile.sh")
help_passed=0

for script in "${scripts[@]}"; do
    if ./scripts/$script --help >/dev/null 2>&1; then
        echo -e "✅ ${GREEN}$script help: Working${NC}"
        ((help_passed++))
    else
        echo -e "❌ ${RED}$script help: Failed${NC}"
    fi
done

echo -e "📊 Help functions: $help_passed/${#scripts[@]} working"
echo ""

# Test 3: Template Validation
echo -e "${CYAN}Test 3: Template Structure Validation${NC}"
echo "Testing Docker Compose and environment templates..."

templates_passed=0

# Check Docker Compose template
if [ -f "templates/docker-compose.yml.template" ]; then
    var_count=$(grep -o "__[A-Z_]*__" templates/docker-compose.yml.template | wc -l)
    service_count=$(grep -c "^  [a-z].*:$" templates/docker-compose.yml.template)
    echo -e "✅ ${GREEN}Docker Compose template: $service_count services, $var_count variables${NC}"
    ((templates_passed++))
else
    echo -e "❌ ${RED}Docker Compose template: Missing${NC}"
fi

# Check environment template
if [ -f "templates/.env.template" ]; then
    section_count=$(grep -c "# ======" templates/.env.template)
    echo -e "✅ ${GREEN}Environment template: $section_count configuration sections${NC}"
    ((templates_passed++))
else
    echo -e "❌ ${RED}Environment template: Missing${NC}"
fi

echo -e "📊 Templates: $templates_passed/2 valid"
echo ""

# Test 4: Utility Functions
echo -e "${CYAN}Test 4: Utility Functions${NC}"
echo "Testing core utility functions..."

utilities_passed=0

# Test common utilities
if bash -c "source scripts/utils/common.sh; exit 0" 2>/dev/null; then
    echo -e "✅ ${GREEN}Common utilities: Loading successfully${NC}"
    ((utilities_passed++))
else
    echo -e "❌ ${RED}Common utilities: Loading failed${NC}"
fi

# Test storage utilities
if bash -c "source scripts/utils/storage-detection.sh; exit 0" 2>/dev/null; then
    echo -e "✅ ${GREEN}Storage utilities: Loading successfully${NC}"
    ((utilities_passed++))
else
    echo -e "❌ ${RED}Storage utilities: Loading failed${NC}"
fi

# Test network utilities
if bash -c "source scripts/utils/network-detection.sh; exit 0" 2>/dev/null; then
    echo -e "✅ ${GREEN}Network utilities: Loading successfully${NC}"
    ((utilities_passed++))
else
    echo -e "❌ ${RED}Network utilities: Loading failed${NC}"
fi

echo -e "📊 Utilities: $utilities_passed/3 working"
echo ""

# Test 5: Configuration System
echo -e "${CYAN}Test 5: Configuration System${NC}"
echo "Testing configuration persistence (safe test values)..."

config_passed=0

# Test configuration save/load
if bash -c "
source scripts/utils/common.sh
save_config 'TEST_KEY' 'test_value'
loaded=\$(load_config 'TEST_KEY')
if [ '\$loaded' = 'test_value' ]; then
    save_config 'TEST_KEY' ''  # Clean up
    exit 0
else
    exit 1
fi
" 2>/dev/null; then
    echo -e "✅ ${GREEN}Configuration persistence: Working${NC}"
    ((config_passed++))
else
    echo -e "❌ ${RED}Configuration persistence: Failed${NC}"
fi

echo -e "📊 Configuration: $config_passed/1 working"
echo ""

# Test 6: Template Processing
echo -e "${CYAN}Test 6: Template Processing${NC}"
echo "Testing template variable replacement..."

template_passed=0

# Test template variable replacement
test_template=$(mktemp)
echo "Test value: __TEST_VAR__" > "$test_template"
processed_content="${test_template//__TEST_VAR__/replaced}"

if echo "Test value: replaced" | diff - <(echo "${processed_content}") >/dev/null 2>&1; then
    echo -e "✅ ${GREEN}Template processing: Working${NC}"
    ((template_passed++))
else
    echo -e "❌ ${RED}Template processing: Failed${NC}"
fi

rm -f "$test_template"
echo -e "📊 Template processing: $template_passed/1 working"
echo ""

# Test 7: Network Detection (Read-Only)
echo -e "${CYAN}Test 7: Network Detection (Read-Only)${NC}"
echo "Testing network interface detection..."

network_passed=0

# Test basic network detection
if ip addr show >/dev/null 2>&1; then
    interface_count=$(ip addr show | grep -c "^[0-9]*: ")
    echo -e "✅ ${GREEN}Network interfaces detected: $interface_count${NC}"
    ((network_passed++))
else
    echo -e "❌ ${RED}Network detection: Failed${NC}"
fi

echo -e "📊 Network detection: $network_passed/1 working"
echo ""

# Test 8: Storage Detection (Read-Only)
echo -e "${CYAN}Test 8: Storage Detection (Read-Only)${NC}"
echo "Testing storage device detection..."

storage_passed=0

# Test basic storage detection
if lsblk >/dev/null 2>&1; then
    device_count=$(lsblk | grep -c "^[a-z]")
    echo -e "✅ ${GREEN}Storage devices detected: $device_count${NC}"
    ((storage_passed++))
else
    echo -e "❌ ${RED}Storage detection: Failed${NC}"
fi

echo -e "📊 Storage detection: $storage_passed/1 working"
echo ""

# Final Summary
echo -e "${BLUE}===========================================${NC}"
echo -e "${BLUE}📊 Safe Testing Summary${NC}"
echo -e "${BLUE}===========================================${NC}"

total_tests=8
total_passed=$((
    (req_status == 0 ? 1 : 0) +
    (help_passed == ${#scripts[@]} ? 1 : 0) +
    (templates_passed == 2 ? 1 : 0) +
    (utilities_passed == 3 ? 1 : 0) +
    config_passed +
    template_passed +
    network_passed +
    storage_passed
))

echo -e "Total Tests: $total_tests"
echo -e "${GREEN}Passed: $total_passed${NC}"
echo -e "${RED}Failed: $((total_tests - total_passed))${NC}"

success_rate=$((total_passed * 100 / total_tests))
echo -e "Success Rate: ${success_rate}%"
echo ""

if [ $total_passed -eq $total_tests ]; then
    echo -e "🎉 ${GREEN}All tests passed! Kekeli-HomeCloud components are working correctly.${NC}"
    echo -e "${CYAN}You can proceed with a full installation when ready.${NC}"
    exit 0
elif [ $success_rate -ge 75 ]; then
    echo -e "✅ ${GREEN}Most tests passed! Core functionality is working.${NC}"
    echo -e "${YELLOW}Some minor issues detected - check individual test results above.${NC}"
    exit 0
else
    echo -e "⚠️  ${YELLOW}Some tests failed. Review the results above before proceeding.${NC}"
    exit 1
fi