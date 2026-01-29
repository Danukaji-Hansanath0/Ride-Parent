#!/bin/bash

# Ride Platform Management Script
# Provides common operations for managing the platform

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

NAMESPACE="ride-dev"

show_help() {
    cat << EOF
${BLUE}Ride Platform Management Script${NC}

Usage: ./manage.sh [COMMAND]

Commands:
    build               Build all Docker images
    deploy              Deploy to Kubernetes
    status              Show deployment status
    logs [SERVICE]      Show logs for a service
    restart [SERVICE]   Restart a service
    scale SERVICE N     Scale a service to N replicas
    port-forward SVC    Port forward a service to localhost
    clean               Delete all Kubernetes resources
    clean-images        Remove all Docker images
    exec SERVICE        Execute shell in service pod
    describe SERVICE    Describe service pod
    help                Show this help message

Examples:
    ./manage.sh build
    ./manage.sh deploy
    ./manage.sh status
    ./manage.sh logs auth-service
    ./manage.sh restart booking-service
    ./manage.sh scale user-service 3
    ./manage.sh port-forward gateway-service
    ./manage.sh exec auth-service

Services:
    - auth-service
    - booking-service
    - gateway-service
    - mail-service
    - payment-service
    - pricing-service
    - user-service
    - vehicle-service
EOF
}

build_images() {
    echo -e "${BLUE}📦 Building all Docker images...${NC}"
    ./build-all-images.sh
}

deploy() {
    echo -e "${BLUE}☸️  Deploying to Kubernetes (namespace: $NAMESPACE)...${NC}"
    kubectl apply -k k8s/environments/dev
    echo -e "${GREEN}✅ Deployed successfully!${NC}"
    echo ""
    echo "Waiting for pods to be ready..."
    kubectl wait --for=condition=ready pod -l app -n $NAMESPACE --timeout=300s || true
}

show_status() {
    echo -e "${BLUE}📊 Deployment Status${NC}"
    echo ""
    echo "=== PODS ==="
    kubectl get pods -n $NAMESPACE -o wide
    echo ""
    echo "=== SERVICES ==="
    kubectl get svc -n $NAMESPACE
    echo ""
    echo "=== DEPLOYMENTS ==="
    kubectl get deployments -n $NAMESPACE
}

show_logs() {
    local service=$1
    if [ -z "$service" ]; then
        echo -e "${RED}❌ Please specify a service name${NC}"
        echo "Usage: ./manage.sh logs [SERVICE]"
        exit 1
    fi

    # Find pod name
    local pod=$(kubectl get pods -n $NAMESPACE -l app | grep "$service" | head -n 1 | awk '{print $1}')

    if [ -z "$pod" ]; then
        echo -e "${RED}❌ No pod found for service: $service${NC}"
        exit 1
    fi

    echo -e "${BLUE}📜 Showing logs for $service (pod: $pod)${NC}"
    kubectl logs -n $NAMESPACE -f $pod
}

restart_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo -e "${RED}❌ Please specify a service name${NC}"
        echo "Usage: ./manage.sh restart [SERVICE]"
        exit 1
    fi

    echo -e "${BLUE}🔄 Restarting $service...${NC}"
    kubectl rollout restart deployment -n $NAMESPACE -l app | grep "$service"
    kubectl rollout status deployment -n $NAMESPACE -l app | grep "$service"
    echo -e "${GREEN}✅ Service restarted!${NC}"
}

scale_service() {
    local service=$1
    local replicas=$2

    if [ -z "$service" ] || [ -z "$replicas" ]; then
        echo -e "${RED}❌ Please specify service name and replica count${NC}"
        echo "Usage: ./manage.sh scale [SERVICE] [REPLICAS]"
        exit 1
    fi

    # Get deployment name
    local deployment=$(kubectl get deployments -n $NAMESPACE | grep "$service" | awk '{print $1}')

    if [ -z "$deployment" ]; then
        echo -e "${RED}❌ No deployment found for service: $service${NC}"
        exit 1
    fi

    echo -e "${BLUE}📏 Scaling $service to $replicas replicas...${NC}"
    kubectl scale deployment $deployment -n $NAMESPACE --replicas=$replicas
    echo -e "${GREEN}✅ Scaled successfully!${NC}"
}

port_forward_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo -e "${RED}❌ Please specify a service name${NC}"
        echo "Usage: ./manage.sh port-forward [SERVICE]"
        exit 1
    fi

    # Determine service port
    local port=8080
    case $service in
        auth-service) port=8081 ;;
        booking-service) port=8082 ;;
        payment-service) port=8083 ;;
        mail-service) port=8084 ;;
        pricing-service) port=8085 ;;
        user-service) port=8086 ;;
        vehicle-service) port=8087 ;;
        gateway-service) port=8080 ;;
    esac

    # Get service name
    local svc=$(kubectl get svc -n $NAMESPACE | grep "$service" | awk '{print $1}')

    if [ -z "$svc" ]; then
        echo -e "${RED}❌ No service found for: $service${NC}"
        exit 1
    fi

    echo -e "${BLUE}🔌 Port forwarding $service to localhost:$port${NC}"
    echo -e "${YELLOW}Press Ctrl+C to stop${NC}"
    kubectl port-forward -n $NAMESPACE svc/$svc $port:80
}

clean_k8s() {
    echo -e "${YELLOW}⚠️  This will delete all resources in namespace: $NAMESPACE${NC}"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" == "yes" ]; then
        echo -e "${BLUE}🧹 Cleaning up Kubernetes resources...${NC}"
        kubectl delete namespace $NAMESPACE
        echo -e "${GREEN}✅ Cleanup complete!${NC}"
    else
        echo "Cancelled."
    fi
}

clean_images() {
    echo -e "${YELLOW}⚠️  This will remove all service Docker images${NC}"
    read -p "Are you sure? (yes/no): " confirm

    if [ "$confirm" == "yes" ]; then
        echo -e "${BLUE}🧹 Removing Docker images...${NC}"
        docker rmi $(docker images | grep -E 'auth-service|booking-service|gateway-service|mail-service|payment-service|pricing-service|user-service|vehicle-service' | grep latest | awk '{print $3}') 2>/dev/null || true
        echo -e "${GREEN}✅ Images removed!${NC}"
    else
        echo "Cancelled."
    fi
}

exec_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo -e "${RED}❌ Please specify a service name${NC}"
        echo "Usage: ./manage.sh exec [SERVICE]"
        exit 1
    fi

    # Find pod name
    local pod=$(kubectl get pods -n $NAMESPACE | grep "$service" | grep Running | head -n 1 | awk '{print $1}')

    if [ -z "$pod" ]; then
        echo -e "${RED}❌ No running pod found for service: $service${NC}"
        exit 1
    fi

    echo -e "${BLUE}🔧 Executing shell in $service (pod: $pod)${NC}"
    kubectl exec -it -n $NAMESPACE $pod -- /bin/sh
}

describe_service() {
    local service=$1
    if [ -z "$service" ]; then
        echo -e "${RED}❌ Please specify a service name${NC}"
        echo "Usage: ./manage.sh describe [SERVICE]"
        exit 1
    fi

    # Find pod name
    local pod=$(kubectl get pods -n $NAMESPACE | grep "$service" | head -n 1 | awk '{print $1}')

    if [ -z "$pod" ]; then
        echo -e "${RED}❌ No pod found for service: $service${NC}"
        exit 1
    fi

    echo -e "${BLUE}📋 Describing $service (pod: $pod)${NC}"
    kubectl describe pod -n $NAMESPACE $pod
}

# Main command router
case "${1:-help}" in
    build)
        build_images
        ;;
    deploy)
        deploy
        ;;
    status)
        show_status
        ;;
    logs)
        show_logs "$2"
        ;;
    restart)
        restart_service "$2"
        ;;
    scale)
        scale_service "$2" "$3"
        ;;
    port-forward)
        port_forward_service "$2"
        ;;
    clean)
        clean_k8s
        ;;
    clean-images)
        clean_images
        ;;
    exec)
        exec_service "$2"
        ;;
    describe)
        describe_service "$2"
        ;;
    help|--help|-h)
        show_help
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        echo ""
        show_help
        exit 1
        ;;
esac

