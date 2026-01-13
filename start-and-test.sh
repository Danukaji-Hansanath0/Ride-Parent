#!/bin/bash

# Complete Startup and Test Script for Ride Platform
# This script starts services and then tests them

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo ""
echo "🚀 Ride Platform - Complete Startup & Test"
echo "==========================================="
echo ""

# Check if kubectl is available
if command -v kubectl &> /dev/null; then
    DEPLOYMENT_METHOD="kubernetes"
    echo -e "${BLUE}Detected: Kubernetes${NC}"
elif command -v docker-compose &> /dev/null || command -v docker &> /dev/null; then
    DEPLOYMENT_METHOD="docker-compose"
    echo -e "${BLUE}Detected: Docker${NC}"
else
    echo -e "${RED}❌ Neither kubectl nor docker found!${NC}"
    echo "Please install Docker or Kubernetes first."
    exit 1
fi

echo ""
echo "==========================================="
echo ""

# Function to check if port is open
check_port() {
    local port=$1
    nc -z localhost $port 2>/dev/null || curl -s -o /dev/null http://localhost:$port 2>/dev/null
    return $?
}

# Function to wait for service
wait_for_service() {
    local name=$1
    local port=$2
    local max_attempts=60
    local attempt=0

    echo -ne "${BLUE}Waiting for $name (port $port)...${NC} "

    while [ $attempt -lt $max_attempts ]; do
        if check_port $port; then
            # Try to get health status
            health=$(curl -s http://localhost:$port/actuator/health 2>/dev/null || echo "")
            if [ ! -z "$health" ]; then
                echo -e "${GREEN}✓ Ready${NC}"
                return 0
            fi
        fi

        echo -n "."
        sleep 2
        ((attempt++))
    done

    echo -e "${YELLOW}⚠ Timeout (may still be starting)${NC}"
    return 1
}

# Step 1: Deploy/Start Services
echo -e "${BLUE}Step 1: Starting Services${NC}"
echo "-------------------------"

if [ "$DEPLOYMENT_METHOD" = "kubernetes" ]; then
    echo "Deploying to Kubernetes..."

    # Check if cluster is accessible
    if ! kubectl cluster-info &>/dev/null; then
        echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
        echo "Please start your cluster (minikube start / kind create cluster)"
        exit 1
    fi

    # Deploy
    echo "Applying Kubernetes manifests..."
    kubectl apply -k k8s/environments/dev

    echo ""
    echo "Waiting for pods to be ready (this may take a few minutes)..."
    kubectl wait --for=condition=ready pod -l app -n ride-dev --timeout=300s 2>/dev/null || true

    echo ""
    echo "Setting up port forwards..."
    echo "(This will run in the background)"

    # Kill existing port forwards
    pkill -f "kubectl port-forward" 2>/dev/null || true
    sleep 2

    # Port forward all services
    kubectl port-forward -n ride-dev svc/auth-SERVICE_NAME 8081:80 &>/dev/null &
    kubectl port-forward -n ride-dev svc/booking-SERVICE_NAME 8082:80 &>/dev/null &
    kubectl port-forward -n ride-dev svc/payment-SERVICE_NAME 8083:80 &>/dev/null &
    kubectl port-forward -n ride-dev svc/mail-SERVICE_NAME 8084:80 &>/dev/null &
    kubectl port-forward -n ride-dev svc/pricing-SERVICE_NAME 8085:80 &>/dev/null &
    kubectl port-forward -n ride-dev svc/user-SERVICE_NAME 8086:80 &>/dev/null &
    kubectl port-forward -n ride-dev svc/vehicle-SERVICE_NAME 8087:80 &>/dev/null &
    kubectl port-forward -n ride-dev svc/gateway-SERVICE_NAME 8080:80 &>/dev/null &

    echo "Port forwards started in background"
    sleep 5

else
    echo "Starting with Docker Compose..."

    # Check if docker-compose file exists
    if [ ! -f "docker-compose.yml" ]; then
        echo -e "${RED}❌ docker-compose.yml not found${NC}"
        exit 1
    fi

    # Start services
    docker-compose up -d

    echo ""
    echo "Waiting for containers to start..."
    sleep 10
fi

echo ""
echo "==========================================="
echo ""

# Step 2: Wait for Services to be Ready
echo -e "${BLUE}Step 2: Checking Service Health${NC}"
echo "-------------------------------"

wait_for_service "Auth Service" 8081
wait_for_service "Booking Service" 8082
wait_for_service "Payment Service" 8083
wait_for_service "Mail Service" 8084
wait_for_service "Pricing Service" 8085
wait_for_service "User Service" 8086
wait_for_service "Vehicle Service" 8087
wait_for_service "Gateway Service" 8080

echo ""
echo "==========================================="
echo ""

# Step 3: Run API Tests
echo -e "${BLUE}Step 3: Running API Tests${NC}"
echo "------------------------"
echo ""

# Run the test script
if [ -f "./test-api.sh" ]; then
    bash ./test-api.sh
else
    echo -e "${YELLOW}⚠ test-api.sh not found, running basic tests...${NC}"

    # Basic health checks
    for port in 8081 8082 8083 8084 8085 8086 8087 8080; do
        echo -ne "Port $port: "
        status=$(curl -s http://localhost:$port/actuator/health 2>/dev/null | grep -o '"status":"[^"]*"' | cut -d'"' -f4 || echo "DOWN")
        if [ "$status" = "UP" ]; then
            echo -e "${GREEN}$status${NC}"
        else
            echo -e "${RED}$status${NC}"
        fi
    done
fi

echo ""
echo "==========================================="
echo ""
echo -e "${GREEN}✅ Startup and testing complete!${NC}"
echo ""
echo "Your services are now running on:"
echo "  Auth:    http://localhost:8081"
echo "  User:    http://localhost:8086"
echo "  Booking: http://localhost:8082"
echo "  Payment: http://localhost:8083"
echo "  Mail:    http://localhost:8084"
echo "  Pricing: http://localhost:8085"
echo "  Vehicle: http://localhost:8087"
echo "  Gateway: http://localhost:8080"
echo ""
echo "Try these commands:"
echo "  curl http://localhost:8086/test"
echo "  curl http://localhost:8081/actuator/health"
echo ""
echo "To stop services:"
if [ "$DEPLOYMENT_METHOD" = "kubernetes" ]; then
    echo "  kubectl delete namespace ride-dev"
    echo "  pkill -f 'kubectl port-forward'"
else
    echo "  docker-compose down"
fi
echo ""

