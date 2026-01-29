#!/bin/bash

# Quick Start Guide for Ride Application
# This script helps you build and deploy your Spring Boot microservices to Kubernetes

set -e

echo "🚀 Ride Application - Deployment Guide"
echo "========================================"
echo ""

# Check prerequisites
echo "📋 Checking prerequisites..."
echo ""

# Check Docker
if ! command -v docker &> /dev/null; then
    echo "❌ Docker is not installed or not in PATH"
    echo "   Please install Docker: https://docs.docker.com/get-docker/"
    exit 1
fi
echo "✅ Docker found: $(docker --version)"

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed or not in PATH"
    echo "   Please install kubectl: https://kubernetes.io/docs/tasks/tools/"
    exit 1
fi
echo "✅ kubectl found: $(kubectl version --client --short 2>/dev/null || kubectl version --client)"

# Check Kubernetes cluster
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    echo "   Please ensure your Kubernetes cluster is running (minikube, kind, k3s, etc.)"
    exit 1
fi
echo "✅ Kubernetes cluster is accessible"
echo ""

# Detect Kubernetes environment
KUBE_CONTEXT=$(kubectl config current-context 2>/dev/null || echo "unknown")
echo "📍 Current Kubernetes context: $KUBE_CONTEXT"
echo ""

# Check if using minikube
if [[ "$KUBE_CONTEXT" == *"minikube"* ]] || command -v minikube &> /dev/null; then
    echo "🔍 Detected minikube environment"
    echo "   Setting Docker environment to use minikube's Docker daemon..."
    eval $(minikube docker-env)
    USE_MINIKUBE=true
elif [[ "$KUBE_CONTEXT" == *"kind"* ]] || command -v kind &> /dev/null; then
    echo "🔍 Detected kind environment"
    echo "   Images will need to be loaded into kind cluster..."
    USE_KIND=true
else
    echo "🔍 Using default Docker environment"
    USE_DEFAULT=true
fi
echo ""

# Build all services
SERVICES=(
    "auth-service"
    "booking-service"
    "gateway-service"
    "mail-service"
    "payment-service"
    "pricing-service"
    "user-service"
    "vehicle-service"
)

echo "🔨 Building Docker images for all services..."
echo "=============================================="
echo ""

BUILD_FAILED=false

for service in "${SERVICES[@]}"; do
    echo "📦 Building $service..."

    if [ ! -d "$service" ]; then
        echo "❌ Directory $service not found!"
        BUILD_FAILED=true
        continue
    fi

    cd "$service"

    # Build the Docker image
    if docker build -t "$service:latest" . > "/tmp/$service-build.log" 2>&1; then
        echo "✅ Successfully built $service:latest"

        # Load into kind if using kind
        if [ "$USE_KIND" = true ]; then
            echo "   Loading image into kind cluster..."
            kind load docker-image "$service:latest" 2>&1 | grep -v "^$" || true
        fi
    else
        echo "❌ Failed to build $service"
        echo "   Check log: /tmp/$service-build.log"
        BUILD_FAILED=true
    fi

    cd ..
    echo ""
done

if [ "$BUILD_FAILED" = true ]; then
    echo "❌ Some images failed to build. Please check the logs."
    exit 1
fi

echo "=============================================="
echo "✅ All images built successfully!"
echo ""

# Show built images
echo "📦 Built images:"
docker images | head -1
docker images | grep -E "$(IFS=\|; echo "${SERVICES[*]}")" | grep latest || echo "  (Images ready in cluster)"
echo ""

# Deploy to Kubernetes
echo "🚀 Deploying to Kubernetes..."
echo "=============================================="
echo ""

# Delete existing deployments to force recreation
echo "🗑️  Cleaning up existing deployments..."
kubectl delete deployments --all -n ride-dev 2>/dev/null || echo "  (No existing deployments to delete)"
echo ""

# Apply Kubernetes configurations
echo "📝 Applying Kubernetes configurations..."
if kubectl apply -k k8s/environments/dev; then
    echo "✅ Kubernetes configurations applied successfully!"
else
    echo "❌ Failed to apply Kubernetes configurations"
    exit 1
fi
echo ""

# Wait for pods to be ready
echo "⏳ Waiting for pods to be ready..."
kubectl wait --for=condition=ready pod --all -n ride-dev --timeout=300s 2>/dev/null || echo "  (Timeout or still starting)"
echo ""

# Show deployment status
echo "=============================================="
echo "📊 Deployment Status:"
echo "=============================================="
echo ""
kubectl get all -n ride-dev
echo ""

# Show pod status with details
echo "📦 Pod Details:"
kubectl get pods -n ride-dev -o wide
echo ""

# Check for any failing pods
FAILING_PODS=$(kubectl get pods -n ride-dev --field-selector=status.phase!=Running,status.phase!=Succeeded --no-headers 2>/dev/null | wc -l)
if [ "$FAILING_PODS" -gt 0 ]; then
    echo "⚠️  Some pods are not running. Checking logs..."
    echo ""
    kubectl get pods -n ride-dev | grep -v "Running" | grep -v "NAME" | awk '{print $1}' | while read pod; do
        echo "📋 Logs for $pod:"
        kubectl logs "$pod" -n ride-dev --tail=20 2>&1 || echo "  (Could not fetch logs)"
        echo ""
    done
fi

echo "=============================================="
echo "✅ Deployment Complete!"
echo "=============================================="
echo ""
echo "🔗 Access your services:"
echo ""
echo "  1. Port-forward to access services locally:"
echo "     kubectl port-forward -n ride-dev service/gateway-service 8080:80"
echo "     Then open: http://localhost:8080"
echo ""
echo "  2. Check service endpoints:"
echo "     kubectl get endpoints -n ride-dev"
echo ""
echo "  3. View logs:"
echo "     kubectl logs -n ride-dev deployment/gateway-service -f"
echo ""
echo "  4. Check all resources:"
echo "     kubectl get all -n ride-dev"
echo ""
echo "  5. Delete deployment:"
echo "     kubectl delete -k k8s/environments/dev"
echo ""

