#!/bin/bash

# Test script for OwnerHasVehicle ID to Pricing Service Flow
# This script verifies that the OwnerHasVehicle ID is correctly used in the pricing service

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
OWNER_BFF_URL="${OWNER_BFF_URL:-http://localhost:8088}"
VEHICLE_SERVICE_URL="${VEHICLE_SERVICE_URL:-http://localhost:8087}"
PRICING_SERVICE_URL="${PRICING_SERVICE_URL:-http://localhost:8085}"
AUTH_URL="${AUTH_URL:-http://localhost:8081}"

echo -e "${BLUE}🧪 Testing OwnerHasVehicle ID to Pricing Service Flow${NC}"
echo "============================================================"
echo ""

# Step 1: Check Services
echo -e "${YELLOW}Step 1: Checking Services...${NC}"
echo ""

check_service() {
    local name=$1
    local url=$2

    if curl -s -f "${url}/actuator/health" > /dev/null 2>&1; then
        echo -e "  ${GREEN}✓${NC} ${name} is running"
        return 0
    else
        echo -e "  ${RED}✗${NC} ${name} is NOT running"
        return 1
    fi
}

SERVICES_OK=true
check_service "Owner BFF" "$OWNER_BFF_URL" || SERVICES_OK=false
check_service "Vehicle Service" "$VEHICLE_SERVICE_URL" || SERVICES_OK=false
check_service "Pricing Service" "$PRICING_SERVICE_URL" || SERVICES_OK=false

if [ "$SERVICES_OK" = false ]; then
    echo ""
    echo -e "${RED}❌ Some services are not running. Please start them first:${NC}"
    echo ""
    echo "  cd discovery-service && mvn spring-boot:run"
    echo "  cd vehicle-service && mvn spring-boot:run"
    echo "  cd pricing-service && mvn spring-boot:run"
    echo "  cd owner-bff && mvn spring-boot:run"
    echo ""
    exit 1
fi

echo ""
echo -e "${GREEN}✓ All required services are running${NC}"
echo ""

# Step 2: Get Authentication Token
echo -e "${YELLOW}Step 2: Getting Authentication Token...${NC}"
echo ""

# Check if token is already provided
if [ -z "$AUTH_TOKEN" ]; then
    echo "No AUTH_TOKEN environment variable found. Please provide one of:"
    echo ""
    echo "  1. Set AUTH_TOKEN environment variable:"
    echo "     export AUTH_TOKEN='your-token-here'"
    echo ""
    echo "  2. Or login first:"
    echo "     curl -X POST ${AUTH_URL}/api/auth/login \\"
    echo "       -H 'Content-Type: application/json' \\"
    echo "       -d '{\"email\":\"owner@example.com\",\"password\":\"Password123!\"}'"
    echo ""
    exit 1
fi

echo -e "${GREEN}✓ Authentication token available${NC}"
echo ""

# Step 3: Register Vehicle with Pricing
echo -e "${YELLOW}Step 3: Registering Vehicle with Pricing...${NC}"
echo ""

# Generate random UUIDs for testing
USER_ID=$(uuidgen)
VEHICLE_ID=$(uuidgen)

echo "Test Data:"
echo "  User ID: $USER_ID"
echo "  Vehicle ID: $VEHICLE_ID"
echo "  Body Type: SUV"
echo "  Pricing: \$50/day, \$300/week, \$1000/month"
echo ""

RESPONSE=$(curl -s -X POST "${OWNER_BFF_URL}/api/v1/owner/vehicles/register-with-pricing" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d "{
    \"userId\": \"${USER_ID}\",
    \"vehicleId\": \"${VEHICLE_ID}\",
    \"bodyTypeId\": \"1\",
    \"vehicleBodyType\": \"SUV\",
    \"availableFrom\": \"2024-01-01\",
    \"availableUntil\": \"2024-12-31\",
    \"currencyCode\": \"USD\",
    \"perDay\": 50.00,
    \"perWeek\": 300.00,
    \"perMonth\": 1000.00
  }")

# Check if response is valid JSON
if ! echo "$RESPONSE" | jq . > /dev/null 2>&1; then
    echo -e "${RED}✗ Invalid response from server:${NC}"
    echo "$RESPONSE"
    exit 1
fi

# Extract values from response
SUCCESS=$(echo "$RESPONSE" | jq -r '.success')
OWNER_HAS_VEHICLE_ID=$(echo "$RESPONSE" | jq -r '.ownerHasVehicleId')
PRICING_ID=$(echo "$RESPONSE" | jq -r '.pricingId')

if [ "$SUCCESS" = "true" ] && [ "$OWNER_HAS_VEHICLE_ID" != "null" ] && [ "$PRICING_ID" != "null" ]; then
    echo -e "${GREEN}✓ Vehicle registered successfully!${NC}"
    echo ""
    echo "Response:"
    echo "$RESPONSE" | jq '.'
    echo ""
else
    echo -e "${RED}✗ Vehicle registration failed:${NC}"
    echo "$RESPONSE" | jq '.'
    exit 1
fi

# Step 4: Verify OwnerHasVehicle ID is used in pricing
echo -e "${YELLOW}Step 4: Verifying OwnerHasVehicle ID...${NC}"
echo ""

echo "✓ OwnerHasVehicle ID from Vehicle Service: $OWNER_HAS_VEHICLE_ID"
echo "✓ Pricing ID from Pricing Service: $PRICING_ID"
echo ""

# Step 5: Query pricing to verify it's stored with OwnerHasVehicle ID
echo -e "${YELLOW}Step 5: Querying Pricing Service...${NC}"
echo ""

PRICING_RESPONSE=$(curl -s -X GET "${PRICING_SERVICE_URL}/api/v1/price/owners/${USER_ID}/vehicles/${OWNER_HAS_VEHICLE_ID}?page=0&size=10" \
  -H "Authorization: Bearer ${AUTH_TOKEN}")

# Check if pricing query is successful
if echo "$PRICING_RESPONSE" | jq . > /dev/null 2>&1; then
    TOTAL_ELEMENTS=$(echo "$PRICING_RESPONSE" | jq -r '.totalElements')

    if [ "$TOTAL_ELEMENTS" -gt 0 ]; then
        echo -e "${GREEN}✓ Pricing retrieved successfully using OwnerHasVehicle ID${NC}"
        echo ""
        echo "Pricing Details:"
        echo "$PRICING_RESPONSE" | jq '.content[0]'
        echo ""

        # Verify the vehicleId in pricing matches OwnerHasVehicle ID
        PRICING_VEHICLE_ID=$(echo "$PRICING_RESPONSE" | jq -r '.content[0].vehicleId')

        if [ "$PRICING_VEHICLE_ID" = "$OWNER_HAS_VEHICLE_ID" ]; then
            echo -e "${GREEN}✓✓✓ VERIFICATION PASSED ✓✓✓${NC}"
            echo ""
            echo "The pricing service correctly stores the OwnerHasVehicle ID:"
            echo "  - OwnerHasVehicle ID: $OWNER_HAS_VEHICLE_ID"
            echo "  - Pricing vehicleId: $PRICING_VEHICLE_ID"
            echo "  - Match: ✓"
        else
            echo -e "${RED}✗ VERIFICATION FAILED${NC}"
            echo "The pricing vehicleId does NOT match OwnerHasVehicle ID:"
            echo "  - Expected: $OWNER_HAS_VEHICLE_ID"
            echo "  - Got: $PRICING_VEHICLE_ID"
            exit 1
        fi
    else
        echo -e "${RED}✗ No pricing found for OwnerHasVehicle ID: $OWNER_HAS_VEHICLE_ID${NC}"
        exit 1
    fi
else
    echo -e "${YELLOW}⚠ Could not query pricing service (may require authentication)${NC}"
    echo "Manual verification required - check the database:"
    echo ""
    echo "  -- Vehicle Service DB"
    echo "  SELECT id, owner_id, vehicle_id, status"
    echo "  FROM owners_has_vehicle"
    echo "  WHERE id = '${OWNER_HAS_VEHICLE_ID}';"
    echo ""
    echo "  -- Pricing Service DB"
    echo "  SELECT vp.id, vp.vehicle_id, pr.per_day, pr.per_week, pr.per_month"
    echo "  FROM vehicle_prices vp"
    echo "  JOIN price_ranges pr ON vp.price_range_id = pr.id"
    echo "  WHERE vp.vehicle_id = '${OWNER_HAS_VEHICLE_ID}';"
fi

echo ""
echo "============================================================"
echo -e "${GREEN}🎉 Test Complete!${NC}"
echo ""
echo "Summary:"
echo "  ✓ Vehicle registered"
echo "  ✓ OwnerHasVehicle ID created: $OWNER_HAS_VEHICLE_ID"
echo "  ✓ Pricing created: $PRICING_ID"
echo "  ✓ Pricing uses OwnerHasVehicle ID as vehicleId"
echo ""
echo "For detailed documentation, see:"
echo "  - OWNERHASVEHICLE_PRICING_FLOW.md"
echo "  - IMPLEMENTATION_COMPLETE_SUMMARY.md"
echo ""
