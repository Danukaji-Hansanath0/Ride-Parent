#!/bin/bash

# Complete Testing Guide - Ride Platform API Endpoints
# This script demonstrates all the curl commands you can use to test the endpoints

echo "🧪 Ride Platform API Testing Guide"
echo "===================================="
echo ""

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${BLUE}📋 Available API Endpoints${NC}"
echo "=========================="
echo ""

echo -e "${YELLOW}🔐 Auth Service (Port 8081)${NC}"
echo "curl http://localhost:8081/actuator/health"
echo "curl -X POST http://localhost:8081/api/auth/register -H 'Content-Type: application/json' -d '{\"email\":\"user@example.com\",\"password\":\"Pass123!\",\"firstName\":\"John\",\"lastName\":\"Doe\"}'"
echo "curl -X POST http://localhost:8081/api/auth/login -H 'Content-Type: application/json' -d '{\"email\":\"user@example.com\",\"password\":\"Pass123!\"}'"
echo ""

echo -e "${YELLOW}👤 User Service (Port 8086)${NC}"
echo "curl http://localhost:8086/actuator/health"
echo "curl http://localhost:8086/test"
echo "curl http://localhost:8086/all"
echo ""

echo -e "${YELLOW}🚕 Booking Service (Port 8082)${NC}"
echo "curl http://localhost:8082/actuator/health"
echo ""

echo -e "${YELLOW}💳 Payment Service (Port 8083)${NC}"
echo "curl http://localhost:8083/actuator/health"
echo ""

echo -e "${YELLOW}📧 Mail Service (Port 8084)${NC}"
echo "curl http://localhost:8084/actuator/health"
echo ""

echo -e "${YELLOW}💰 Pricing Service (Port 8085)${NC}"
echo "curl http://localhost:8085/actuator/health"
echo ""

echo -e "${YELLOW}🚗 Vehicle Service (Port 8087)${NC}"
echo "curl http://localhost:8087/actuator/health"
echo ""

echo -e "${YELLOW}🌐 Gateway Service (Port 8080)${NC}"
echo "curl http://localhost:8080/actuator/health"
echo ""

echo "=========================="
echo -e "${BLUE}📝 Testing Instructions${NC}"
echo "=========================="
echo ""
echo "1. First, ensure your services are running:"
echo "   - For Kubernetes: kubectl get pods -n ride-dev"
echo "   - For Docker Compose: docker-compose ps"
echo "   - For manual Docker: docker ps"
echo ""
echo "2. If using Kubernetes, set up port forwarding:"
echo "   kubectl port-forward -n ride-dev svc/auth-service 8081:80 &"
echo "   kubectl port-forward -n ride-dev svc/user-service 8086:80 &"
echo "   # ... for other services"
echo ""
echo "3. Test the simplest endpoint first:"
echo "   curl http://localhost:8086/test"
echo "   # Should return: 'User Service is up and running!'"
echo ""
echo "4. Test health endpoints:"
echo "   curl http://localhost:8081/actuator/health"
echo "   curl http://localhost:8086/actuator/health"
echo ""
echo "5. Register and login to test authenticated endpoints:"
echo ""
echo "   # Register a user"
echo "   curl -X POST http://localhost:8081/api/auth/register \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{"
echo "       \"email\": \"testuser@example.com\","
echo "       \"password\": \"TestPass123!\","
echo "       \"firstName\": \"Test\","
echo "       \"lastName\": \"User\""
echo "     }'"
echo ""
echo "   # Login and get token"
echo "   TOKEN=\$(curl -s -X POST http://localhost:8081/api/auth/login \\"
echo "     -H 'Content-Type: application/json' \\"
echo "     -d '{"
echo "       \"email\": \"testuser@example.com\","
echo "       \"password\": \"TestPass123!\""
echo "     }' | jq -r '.accessToken')"
echo ""
echo "   # Use token for authenticated requests"
echo "   curl -H \"Authorization: Bearer \$TOKEN\" \\"
echo "     http://localhost:8086/all"
echo ""

echo "=========================="
echo -e "${BLUE}🚀 Complete Test Example${NC}"
echo "=========================="
echo ""

# Simple test function
test_endpoint() {
    local url=$1
    local description=$2
    echo -ne "Testing $description... "

    response=$(curl -s -o /dev/null -w "%{http_code}" "$url" 2>/dev/null || echo "000")

    if [ "$response" = "200" ]; then
        echo -e "${GREEN}✓ OK${NC}"
        return 0
    elif [ "$response" = "000" ]; then
        echo -e "${RED}✗ Connection refused${NC}"
        return 1
    else
        echo -e "${YELLOW}⚠ HTTP $response${NC}"
        return 1
    fi
}

echo "Running basic connectivity tests..."
echo ""

test_endpoint "http://localhost:8081/actuator/health" "Auth Service Health"
test_endpoint "http://localhost:8082/actuator/health" "Booking Service Health"
test_endpoint "http://localhost:8083/actuator/health" "Payment Service Health"
test_endpoint "http://localhost:8084/actuator/health" "Mail Service Health"
test_endpoint "http://localhost:8085/actuator/health" "Pricing Service Health"
test_endpoint "http://localhost:8086/actuator/health" "User Service Health"
test_endpoint "http://localhost:8087/actuator/health" "Vehicle Service Health"
test_endpoint "http://localhost:8080/actuator/health" "Gateway Service Health"

echo ""
echo "Special endpoint test:"
response=$(curl -s http://localhost:8086/test 2>/dev/null || echo "ERROR")
if [[ "$response" == *"User Service is up and running"* ]]; then
    echo -e "${GREEN}✓${NC} User Service /test endpoint works!"
    echo "  Response: $response"
else
    echo -e "${RED}✗${NC} User Service /test endpoint failed"
    echo "  Response: $response"
fi

echo ""
echo "=========================="
echo -e "${BLUE}🔧 Troubleshooting${NC}"
echo "=========================="
echo ""
echo "If you get 'Connection refused' errors:"
echo "1. Services are not running - start them first"
echo "2. Wrong ports - check service configuration"
echo "3. Port forwarding not set up (for Kubernetes)"
echo ""
echo "Common solutions:"
echo "• Start services: docker-compose up -d"
echo "• Or deploy to K8s: kubectl apply -k k8s/environments/dev"
echo "• Check logs: docker-compose logs <service-name>"
echo "• Check K8s logs: kubectl logs -n ride-dev <pod-name>"
echo ""
echo "For successful testing, ensure:"
echo "• Services are running (docker ps or kubectl get pods)"
echo "• Correct ports are exposed"
echo "• No firewall blocking connections"
echo ""

if command -v jq &> /dev/null; then
    echo -e "${GREEN}✓${NC} jq is available for JSON parsing"
else
    echo -e "${YELLOW}⚠${NC} Install jq for better JSON handling: sudo pacman -S jq"
fi

echo ""
echo "=========================="
echo -e "${GREEN}✅ Ready to Test!${NC}"
echo "=========================="
echo ""
echo "Copy and paste the curl commands above to test your endpoints."
echo "Start with simple health checks, then move to more complex endpoints."
echo ""
