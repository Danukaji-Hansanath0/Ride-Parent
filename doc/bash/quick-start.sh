#!/bin/bash

# Quick Start Script for Ride Platform
# This script builds all images and deploys to Kubernetes

set -e

echo "🚀 Ride Platform - Quick Start"
echo "================================"
echo ""

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check prerequisites
echo "📋 Checking prerequisites..."

if ! command -v docker &> /dev/null; then
    echo -e "${RED}❌ Docker is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ Docker is installed${NC}"

if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi
echo -e "${GREEN}✅ kubectl is installed${NC}"

# Check if Kubernetes cluster is accessible
if ! kubectl cluster-info &> /dev/null; then
    echo -e "${RED}❌ Cannot connect to Kubernetes cluster${NC}"
    echo "Please start your Kubernetes cluster (minikube, kind, etc.)"
    exit 1
fi
echo -e "${GREEN}✅ Kubernetes cluster is accessible${NC}"

echo ""
echo "================================"
echo ""

# Step 1: Build Docker images
echo "📦 Step 1: Building Docker images..."
echo "This may take several minutes on first run..."
echo ""

./build-all-images.sh

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to build Docker images${NC}"
    exit 1
fi

echo ""
echo "================================"
echo ""

# Step 2: Deploy to Kubernetes
echo "☸️  Step 2: Deploying to Kubernetes..."
echo ""

# Create namespace if it doesn't exist
kubectl create namespace ride-dev --dry-run=client -o yaml | kubectl apply -f -

# Apply kustomization
kubectl apply -k k8s/environments/dev

if [ $? -ne 0 ]; then
    echo -e "${RED}❌ Failed to deploy to Kubernetes${NC}"
    exit 1
fi

echo ""
echo "================================"
echo ""

# Step 3: Wait for pods to be ready
echo "⏳ Step 3: Waiting for pods to be ready..."
echo "This may take a few minutes..."
echo ""

kubectl wait --for=condition=ready pod -l app -n ride-dev --timeout=300s || true

echo ""
echo "================================"
echo ""

# Show deployment status
echo "📊 Deployment Status:"
echo ""
kubectl get pods -n ride-dev
echo ""
kubectl get svc -n ride-dev

echo ""
echo "================================"
echo ""
echo -e "${GREEN}✅ Deployment completed!${NC}"
echo ""
echo "To check logs for a service:"
echo "  kubectl logs -n ride-dev <pod-name>"
echo ""
echo "To port-forward a service (e.g., gateway):"
echo "  kubectl port-forward -n ride-dev svc/gateway-SERVICE_NAME 8080:80"
echo ""
echo "To delete all resources:"
echo "  kubectl delete namespace ride-dev"
echo ""

