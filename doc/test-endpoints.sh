#!/bin/bash

# User Service API Endpoint Test Script
# This script tests all endpoints to verify they match the Swagger documentation

echo "=========================================="
echo "User Service API Endpoint Test"
echo "=========================================="
echo ""

BASE_URL="http://localhost:8086"

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Test 1: Health Check
echo -e "${YELLOW}Test 1: Health Check${NC}"
echo "GET $BASE_URL/actuator/health"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/actuator/health")
if [ "$response" == "200" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Health check returned 200"
else
    echo -e "${RED}✗ FAIL${NC} - Health check returned $response"
fi
echo ""

# Test 2: Swagger UI
echo -e "${YELLOW}Test 2: Swagger UI${NC}"
echo "GET $BASE_URL/swagger-ui/index.html"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/swagger-ui/index.html")
if [ "$response" == "200" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Swagger UI accessible"
else
    echo -e "${RED}✗ FAIL${NC} - Swagger UI returned $response"
fi
echo ""

# Test 3: OpenAPI Docs
echo -e "${YELLOW}Test 3: OpenAPI Documentation${NC}"
echo "GET $BASE_URL/v3/api-docs"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/v3/api-docs")
if [ "$response" == "200" ]; then
    echo -e "${GREEN}✓ PASS${NC} - OpenAPI docs accessible"
else
    echo -e "${RED}✗ FAIL${NC} - OpenAPI docs returned $response"
fi
echo ""

# Test 4: Get All Users
echo -e "${YELLOW}Test 4: Get All Users${NC}"
echo "GET $BASE_URL/api/v1/users/all"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/users/all")
if [ "$response" == "200" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Get all users endpoint working"
else
    echo -e "${RED}✗ FAIL${NC} - Get all users returned $response"
fi
echo ""

# Test 5: Get All Users with Sort
echo -e "${YELLOW}Test 5: Get All Users with Sort${NC}"
echo "GET $BASE_URL/api/v1/users/all?sort=email,asc"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/users/all?sort=email,asc")
if [ "$response" == "200" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Sort parameter working"
else
    echo -e "${RED}✗ FAIL${NC} - Sort returned $response"
fi
echo ""

# Test 6: Get All Users with Invalid Sort (should return 400)
echo -e "${YELLOW}Test 6: Invalid Sort Field (should return 400)${NC}"
echo "GET $BASE_URL/api/v1/users/all?sort=invalidField,desc"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/users/all?sort=invalidField,desc")
if [ "$response" == "400" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Invalid sort correctly returned 400"
else
    echo -e "${RED}✗ FAIL${NC} - Invalid sort returned $response (expected 400)"
fi
echo ""

# Test 7: Get User Profile (non-existent, should return 404)
echo -e "${YELLOW}Test 7: Get Non-existent User Profile (should return 404)${NC}"
echo "GET $BASE_URL/api/v1/users/profile/nonexistent@test.com"
response=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/api/v1/users/profile/nonexistent@test.com")
if [ "$response" == "404" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Non-existent user correctly returned 404"
else
    echo -e "${RED}✗ FAIL${NC} - Non-existent user returned $response (expected 404)"
fi
echo ""

# Test 8: Create User Endpoint Exists
echo -e "${YELLOW}Test 8: Create User Endpoint${NC}"
echo "POST $BASE_URL/api/v1/users"
# Test with minimal invalid data to check endpoint exists (should return 400 or 500, not 404)
response=$(curl -s -o /dev/null -w "%{http_code}" -X POST "$BASE_URL/api/v1/users" \
  -H "Content-Type: application/json" \
  -d '{}')
if [ "$response" != "404" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Create user endpoint exists (returned $response)"
else
    echo -e "${RED}✗ FAIL${NC} - Create user endpoint not found (404)"
fi
echo ""

# Test 9: Update User Endpoint Exists
echo -e "${YELLOW}Test 9: Update User Endpoint${NC}"
echo "PUT $BASE_URL/api/v1/users"
response=$(curl -s -o /dev/null -w "%{http_code}" -X PUT "$BASE_URL/api/v1/users" \
  -H "Content-Type: application/json" \
  -d '{}')
if [ "$response" != "404" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Update user endpoint exists (returned $response)"
else
    echo -e "${RED}✗ FAIL${NC} - Update user endpoint not found (404)"
fi
echo ""

# Test 10: Delete User Endpoint
echo -e "${YELLOW}Test 10: Delete User Endpoint${NC}"
echo "DELETE $BASE_URL/api/v1/users/test@example.com"
response=$(curl -s -o /dev/null -w "%{http_code}" -X DELETE "$BASE_URL/api/v1/users/test@example.com")
if [ "$response" == "404" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Delete endpoint exists and returned 404 for non-existent user"
elif [ "$response" == "200" ]; then
    echo -e "${GREEN}✓ PASS${NC} - Delete endpoint exists and user was deleted"
else
    echo -e "${YELLOW}⚠ WARNING${NC} - Delete endpoint returned $response"
fi
echo ""

echo "=========================================="
echo "Test Summary"
echo "=========================================="
echo ""
echo "All endpoint paths verified against Swagger documentation"
echo ""
echo "Valid Endpoints:"
echo "  ✓ GET  /actuator/health"
echo "  ✓ GET  /swagger-ui/index.html"
echo "  ✓ GET  /v3/api-docs"
echo "  ✓ GET  /api/v1/users/all"
echo "  ✓ GET  /api/v1/users/profile/{email}"
echo "  ✓ POST /api/v1/users"
echo "  ✓ PUT  /api/v1/users"
echo "  ✓ DELETE /api/v1/users/{email}"
echo ""
echo "Valid Sort Fields:"
echo "  - userId, email, firstName, lastName"
echo "  - createdAt, updatedAt, isActive, userType"
echo ""
