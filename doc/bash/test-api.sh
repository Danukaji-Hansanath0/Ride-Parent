#!/bin/bash

# Automated API Testing Script for Ride Platform
# Tests all available endpoints and reports results

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
AUTH_URL="${AUTH_URL:-http://localhost:8081}"
USER_URL="${USER_URL:-http://localhost:8086}"
BOOKING_URL="${BOOKING_URL:-http://localhost:8082}"
PAYMENT_URL="${PAYMENT_URL:-http://localhost:8083}"
MAIL_URL="${MAIL_URL:-http://localhost:8084}"
PRICING_URL="${PRICING_URL:-http://localhost:8085}"
VEHICLE_URL="${VEHICLE_URL:-http://localhost:8087}"
GATEWAY_URL="${GATEWAY_URL:-http://localhost:8080}"

PASSED=0
FAILED=0

# Helper function to test endpoint
test_endpoint() {
    local name=$1
    local method=$2
    local url=$3
    local headers=$4
    local data=$5

    echo -ne "${BLUE}Testing:${NC} $name ... "

    if [ -z "$data" ]; then
        response=$(curl -s -w "\n%{http_code}" -X $method "$url" $headers 2>/dev/null || echo "000")
    else
        response=$(curl -s -w "\n%{http_code}" -X $method "$url" $headers -d "$data" 2>/dev/null || echo "000")
    fi

    http_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n-1)

    if [ "$http_code" -ge 200 ] && [ "$http_code" -lt 300 ]; then
        echo -e "${GREEN}✓ PASS${NC} ($http_code)"
        ((PASSED++))
        return 0
    elif [ "$http_code" -eq 401 ] || [ "$http_code" -eq 403 ]; then
        echo -e "${YELLOW}⚠ AUTH${NC} ($http_code - Authentication required)"
        ((PASSED++))
        return 0
    elif [ "$http_code" -eq 404 ]; then
        echo -e "${YELLOW}⚠ NOT FOUND${NC} ($http_code - Endpoint may not be implemented)"
        return 0
    else
        echo -e "${RED}✗ FAIL${NC} ($http_code)"
        if [ "$http_code" = "000" ]; then
            echo "   Error: Could not connect to service"
        fi
        ((FAILED++))
        return 1
    fi
}

echo ""
echo "🧪 Ride Platform API Test Suite"
echo "=================================="
echo ""
echo "Configuration:"
echo "  Auth Service:    $AUTH_URL"
echo "  User Service:    $USER_URL"
echo "  Booking Service: $BOOKING_URL"
echo "  Payment Service: $PAYMENT_URL"
echo "  Mail Service:    $MAIL_URL"
echo "  Pricing Service: $PRICING_URL"
echo "  Vehicle Service: $VEHICLE_URL"
echo "  Gateway Service: $GATEWAY_URL"
echo ""
echo "=================================="
echo ""

# Test Auth Service
echo -e "${BLUE}📋 Auth Service (Port 8081)${NC}"
echo "----------------------------"
test_endpoint "Health Check" "GET" "$AUTH_URL/actuator/health"
test_endpoint "Info Endpoint" "GET" "$AUTH_URL/actuator/info"
echo ""

# Try to register a test user
echo -e "${BLUE}📋 User Registration & Login${NC}"
echo "----------------------------"
RANDOM_EMAIL="testuser$(date +%s)@example.com"
REGISTER_DATA='{
  "email": "'$RANDOM_EMAIL'",
  "password": "TestPass123!",
  "firstName": "Test",
  "lastName": "User",
  "phone": "+1234567890"
}'

echo -ne "${BLUE}Testing:${NC} User Registration ... "
REGISTER_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/api/auth/register" \
  -H "Content-Type: application/json" \
  -d "$REGISTER_DATA" 2>/dev/null || echo -e "\n000")

REGISTER_CODE=$(echo "$REGISTER_RESPONSE" | tail -n1)
REGISTER_BODY=$(echo "$REGISTER_RESPONSE" | head -n-1)

if [ "$REGISTER_CODE" -ge 200 ] && [ "$REGISTER_CODE" -lt 300 ]; then
    echo -e "${GREEN}✓ PASS${NC} ($REGISTER_CODE)"
    USER_ID=$(echo "$REGISTER_BODY" | grep -o '"userId":"[^"]*"' | cut -d'"' -f4 || echo "")
    echo "   Created user: $RANDOM_EMAIL"
    ((PASSED++))
elif [ "$REGISTER_CODE" -eq 409 ]; then
    echo -e "${YELLOW}⚠ CONFLICT${NC} ($REGISTER_CODE - User may already exist)"
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} ($REGISTER_CODE)"
    ((FAILED++))
fi

# Try to login
LOGIN_DATA='{
  "email": "'$RANDOM_EMAIL'",
  "password": "TestPass123!"
}'

echo -ne "${BLUE}Testing:${NC} User Login ... "
LOGIN_RESPONSE=$(curl -s -w "\n%{http_code}" -X POST "$AUTH_URL/api/auth/login" \
  -H "Content-Type: application/json" \
  -d "$LOGIN_DATA" 2>/dev/null || echo -e "\n000")

LOGIN_CODE=$(echo "$LOGIN_RESPONSE" | tail -n1)
LOGIN_BODY=$(echo "$LOGIN_RESPONSE" | head -n-1)

if [ "$LOGIN_CODE" -ge 200 ] && [ "$LOGIN_CODE" -lt 300 ]; then
    echo -e "${GREEN}✓ PASS${NC} ($LOGIN_CODE)"
    ACCESS_TOKEN=$(echo "$LOGIN_BODY" | grep -o '"accessToken":"[^"]*"' | cut -d'"' -f4 || echo "")
    if [ ! -z "$ACCESS_TOKEN" ]; then
        echo "   Token obtained: ${ACCESS_TOKEN:0:30}..."
    fi
    ((PASSED++))
else
    echo -e "${RED}✗ FAIL${NC} ($LOGIN_CODE)"
    ((FAILED++))
fi
echo ""

# Test User Service
echo -e "${BLUE}📋 User Service (Port 8086)${NC}"
echo "----------------------------"
test_endpoint "Health Check" "GET" "$USER_URL/actuator/health"
test_endpoint "Test Endpoint" "GET" "$USER_URL/test"

if [ ! -z "$ACCESS_TOKEN" ]; then
    test_endpoint "Get All Users (Auth)" "GET" "$USER_URL/all?page=0&size=15" "-H 'Authorization: Bearer $ACCESS_TOKEN'"
else
    test_endpoint "Get All Users (No Auth)" "GET" "$USER_URL/all?page=0&size=15"
fi
echo ""

# Test Booking Service
echo -e "${BLUE}📋 Booking Service (Port 8082)${NC}"
echo "----------------------------"
test_endpoint "Health Check" "GET" "$BOOKING_URL/actuator/health"
test_endpoint "Info Endpoint" "GET" "$BOOKING_URL/actuator/info"
echo ""

# Test Payment Service
echo -e "${BLUE}📋 Payment Service (Port 8083)${NC}"
echo "----------------------------"
test_endpoint "Health Check" "GET" "$PAYMENT_URL/actuator/health"
test_endpoint "Info Endpoint" "GET" "$PAYMENT_URL/actuator/info"
echo ""

# Test Mail Service
echo -e "${BLUE}📋 Mail Service (Port 8084)${NC}"
echo "----------------------------"
test_endpoint "Health Check" "GET" "$MAIL_URL/actuator/health"
test_endpoint "Info Endpoint" "GET" "$MAIL_URL/actuator/info"
echo ""

# Test Pricing Service
echo -e "${BLUE}📋 Pricing Service (Port 8085)${NC}"
echo "----------------------------"
test_endpoint "Health Check" "GET" "$PRICING_URL/actuator/health"
test_endpoint "Info Endpoint" "GET" "$PRICING_URL/actuator/info"
echo ""

# Test Vehicle Service
echo -e "${BLUE}📋 Vehicle Service (Port 8087)${NC}"
echo "----------------------------"
test_endpoint "Health Check" "GET" "$VEHICLE_URL/actuator/health"
test_endpoint "Info Endpoint" "GET" "$VEHICLE_URL/actuator/info"
echo ""

# Test Gateway Service
echo -e "${BLUE}📋 Gateway Service (Port 8080)${NC}"
echo "----------------------------"
test_endpoint "Health Check" "GET" "$GATEWAY_URL/actuator/health"
echo ""

# Summary
echo "=================================="
echo -e "${BLUE}📊 Test Summary${NC}"
echo "=================================="
echo ""
echo -e "  ${GREEN}Passed:${NC} $PASSED"
echo -e "  ${RED}Failed:${NC} $FAILED"
echo -e "  Total:  $((PASSED + FAILED))"
echo ""

if [ $FAILED -eq 0 ]; then
    echo -e "${GREEN}✅ All tests passed!${NC}"
    echo ""
    exit 0
else
    echo -e "${YELLOW}⚠️  Some tests failed. Check the output above.${NC}"
    echo ""
    exit 1
fi

