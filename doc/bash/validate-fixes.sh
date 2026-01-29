#!/bin/bash

# Validation script for the fixes applied
# Run this script to verify all changes are working

echo "========================================="
echo "Validating Auth Service and User Service Fixes"
echo "========================================="
echo ""

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Track results
PASSED=0
FAILED=0

# Function to check compilation
check_compilation() {
    local service=$1
    echo -n "Checking $service compilation... "

    cd "/mnt/projects/Ride/$service"
    if mvn clean compile -DskipTests -q > /dev/null 2>&1; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAILED++))
        return 1
    fi
}

# Function to check file changes
check_file_content() {
    local file=$1
    local search_string=$2
    local description=$3

    echo -n "Checking $description... "

    if grep -q "$search_string" "$file"; then
        echo -e "${GREEN}✓ PASSED${NC}"
        ((PASSED++))
        return 0
    else
        echo -e "${RED}✗ FAILED${NC}"
        ((FAILED++))
        return 1
    fi
}

# 1. Check Auth Service - RestTemplate fix
echo "1. Checking Auth Service AppConfig changes..."
check_file_content \
    "/mnt/projects/Ride/auth-service/src/main/java/com/ride/authservice/config/AppConfig.java" \
    "SimpleClientHttpRequestFactory" \
    "RestTemplate using SimpleClientHttpRequestFactory"

# 2. Check Auth Service - SecurityConfig fix
echo "2. Checking Auth Service SecurityConfig changes..."
check_file_content \
    "/mnt/projects/Ride/auth-service/src/main/java/com/ride/authservice/config/SecurityConfig.java" \
    "HeaderValue.ENABLED" \
    "XSS Protection using HeaderValue.ENABLED"

# 3. Check User Service - Stream API fix
echo "3. Checking User Service SecurityConfig changes..."
check_file_content \
    "/mnt/projects/Ride/user-service/src/main/java/com/ride/userservice/config/SecurityConfig.java" \
    "collect(Collectors.toList())" \
    "Stream API using collect(Collectors.toList())"

# 4. Check User Service - Collectors import
check_file_content \
    "/mnt/projects/Ride/user-service/src/main/java/com/ride/userservice/config/SecurityConfig.java" \
    "import java.util.stream.Collectors" \
    "Collectors import present"

# 5. Compile Auth Service
echo ""
echo "5. Compiling Auth Service..."
check_compilation "auth-service"

# 6. Compile User Service
echo "6. Compiling User Service..."
check_compilation "user-service"

# Summary
echo ""
echo "========================================="
echo "VALIDATION SUMMARY"
echo "========================================="
echo -e "${GREEN}Passed: $PASSED${NC}"
echo -e "${RED}Failed: $FAILED${NC}"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}All validations passed! ✓${NC}"
    echo ""
    echo "Next steps:"
    echo "1. Start the services: ./start-and-test.sh"
    echo "2. Or start individually:"
    echo "   cd auth-service && mvn spring-boot:run"
    echo "   cd user-service && mvn spring-boot:run"
    exit 0
else
    echo -e "${RED}Some validations failed. Please review the errors above.${NC}"
    exit 1
fi

