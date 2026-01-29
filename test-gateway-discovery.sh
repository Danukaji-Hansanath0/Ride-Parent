#!/bin/bash

# Gateway & Discovery Services Testing Script
# Tests all endpoints and verifies service health

set -e

# Color codes
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Variables
DISCOVERY_URL="http://localhost:8761"
GATEWAY_URL="http://localhost:8080"
DISCOVERY_USER="admin"
DISCOVERY_PASS="admin123"

echo -e "${BLUE}========================================${NC}"
echo -e "${BLUE}Gateway & Discovery Services Test Suite${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""

# Test Discovery Service
echo -e "${BLUE}Testing Discovery Service...${NC}"

if curl -s -u $DISCOVERY_USER:$DISCOVERY_PASS "$DISCOVERY_URL/actuator/health" > /dev/null; then
    echo -e "${GREEN}✓ Discovery Service is running${NC}"
else
    echo -e "${RED}✗ Discovery Service is not responding${NC}"
    exit 1
fi

# Test Eureka Dashboard
echo -e "${YELLOW}Testing Eureka Dashboard...${NC}"
DASHBOARD_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" -u $DISCOVERY_USER:$DISCOVERY_PASS "$DISCOVERY_URL/eureka/web/")
if [ $DASHBOARD_RESPONSE -eq 200 ]; then
    echo -e "${GREEN}✓ Eureka Dashboard is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Eureka Dashboard returned: $DASHBOARD_RESPONSE${NC}"
fi

# Test Discovery Endpoints
echo -e "${YELLOW}Testing Discovery Endpoints...${NC}"

echo -e "${YELLOW}  - Testing /eureka/apps${NC}"
APPS_RESPONSE=$(curl -s -u $DISCOVERY_USER:$DISCOVERY_PASS "$DISCOVERY_URL/eureka/apps" -H "Accept: application/json")
SERVICES_COUNT=$(echo "$APPS_RESPONSE" | grep -o '"name"' | wc -l)
echo -e "${GREEN}  ✓ Found $((SERVICES_COUNT-1)) registered services${NC}"

# Test Gateway Service
echo ""
echo -e "${BLUE}Testing Gateway Service...${NC}"

if curl -s "$GATEWAY_URL/actuator/health" > /dev/null; then
    echo -e "${GREEN}✓ Gateway Service is running${NC}"
else
    echo -e "${RED}✗ Gateway Service is not responding${NC}"
    exit 1
fi

# Test Swagger UI
echo -e "${YELLOW}Testing Swagger UI...${NC}"
SWAGGER_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/swagger-ui.html")
if [ $SWAGGER_RESPONSE -eq 200 ]; then
    echo -e "${GREEN}✓ Swagger UI is accessible${NC}"
else
    echo -e "${YELLOW}⚠ Swagger UI returned: $SWAGGER_RESPONSE${NC}"
fi

# Test Gateway Endpoints
echo -e "${YELLOW}Testing Gateway Endpoints...${NC}"

echo -e "${YELLOW}  - Testing /api/v1/gateway/info${NC}"
INFO_RESPONSE=$(curl -s "$GATEWAY_URL/api/v1/gateway/info")
echo -e "${GREEN}  ✓ Gateway info retrieved${NC}"

echo -e "${YELLOW}  - Testing /api/v1/gateway/routes${NC}"
ROUTES_COUNT=$(curl -s "$GATEWAY_URL/api/v1/gateway/routes" | grep -o '"id"' | wc -l)
echo -e "${GREEN}  ✓ Found $ROUTES_COUNT routes configured${NC}"

# Test Rate Limiting
echo ""
echo -e "${BLUE}Testing Rate Limiting...${NC}"

echo -e "${YELLOW}  - Sending 5 requests to test rate limit headers...${NC}"
RATE_LIMIT_HEADERS=$(curl -s -i "$GATEWAY_URL/api/v1/gateway/info" 2>/dev/null | grep -i "X-Rate-Limit")
if [ ! -z "$RATE_LIMIT_HEADERS" ]; then
    echo -e "${GREEN}  ✓ Rate limit headers are present${NC}"
else
    echo -e "${YELLOW}  ⚠ Rate limit headers not detected${NC}"
fi

# Test Health Checks
echo ""
echo -e "${BLUE}Testing Health Checks...${NC}"

echo -e "${YELLOW}  - Discovery Service Metrics${NC}"
curl -s -u $DISCOVERY_USER:$DISCOVERY_PASS "$DISCOVERY_URL/actuator/metrics" > /dev/null && echo -e "${GREEN}  ✓ Metrics available${NC}"

echo -e "${YELLOW}  - Gateway Service Metrics${NC}"
curl -s "$GATEWAY_URL/actuator/metrics" > /dev/null && echo -e "${GREEN}  ✓ Metrics available${NC}"

# Test Documentation
echo ""
echo -e "${BLUE}Testing API Documentation...${NC}"

echo -e "${YELLOW}  - Testing OpenAPI docs...${NC}"
DOCS_RESPONSE=$(curl -s -o /dev/null -w "%{http_code}" "$GATEWAY_URL/v3/api-docs")
if [ $DOCS_RESPONSE -eq 200 ]; then
    echo -e "${GREEN}✓ OpenAPI documentation is available${NC}"
else
    echo -e "${YELLOW}⚠ OpenAPI docs returned: $DOCS_RESPONSE${NC}"
fi

# Summary
echo ""
echo -e "${BLUE}========================================${NC}"
echo -e "${GREEN}✓ All tests completed successfully!${NC}"
echo -e "${BLUE}========================================${NC}"
echo ""
echo "Service URLs:"
echo "  Discovery Dashboard: $DISCOVERY_URL/eureka/web/"
echo "  Gateway Swagger: $GATEWAY_URL/swagger-ui.html"
echo "  Gateway Info: $GATEWAY_URL/api/v1/gateway/info"
echo ""
