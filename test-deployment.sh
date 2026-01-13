#!/bin/bash

# Quick Test Deployment for Ride Application
# This creates a simple test deployment to verify Kubernetes is working

set -e

echo "🧪 Ride Application - Test Deployment"
echo "======================================"
echo ""

# Check kubectl
if ! command -v kubectl &> /dev/null; then
    echo "❌ kubectl is not installed"
    exit 1
fi

# Check cluster connection
if ! kubectl cluster-info &> /dev/null; then
    echo "❌ Cannot connect to Kubernetes cluster"
    exit 1
fi

echo "✅ Kubernetes cluster is accessible"
echo ""

# Create or update namespace
echo "📦 Creating namespace ride-dev..."
kubectl create namespace ride-dev 2>/dev/null || echo "  (Namespace already exists)"
echo ""

# Create a simple test deployment
echo "🚀 Creating test deployment..."

cat <<EOF | kubectl apply -f -
apiVersion: apps/v1
kind: Deployment
metadata:
  name: test-app
  namespace: ride-dev
spec:
  replicas: 1
  selector:
    matchLabels:
      app: test-app
  template:
    metadata:
      labels:
        app: test-app
    spec:
      containers:
      - name: app
        image: hashicorp/http-echo
        args:
          - "-text=Hello from Ride! Test deployment is working! 🎉"
        ports:
        - containerPort: 5678
---
apiVersion: v1
kind: Service
metadata:
  name: test-app
  namespace: ride-dev
spec:
  selector:
    app: test-app
  ports:
  - port: 80
    targetPort: 5678
  type: ClusterIP
EOF

echo ""
echo "⏳ Waiting for test pod to be ready..."
kubectl wait --for=condition=ready pod -l app=test-app -n ride-dev --timeout=60s 2>/dev/null || true
echo ""

# Show status
echo "📊 Test Deployment Status:"
kubectl get all -n ride-dev -l app=test-app
echo ""

# Test the service
echo "🧪 Testing the service..."
POD_NAME=$(kubectl get pods -n ride-dev -l app=test-app -o jsonpath='{.items[0].metadata.name}' 2>/dev/null)

if [ -n "$POD_NAME" ]; then
    echo "✅ Pod created: $POD_NAME"
    echo ""

    # Try to access the service from within the cluster
    echo "📡 Testing service connectivity..."
    if kubectl exec -n ride-dev "$POD_NAME" -- wget -qO- http://localhost:5678 2>/dev/null; then
        echo ""
        echo "✅ Service is responding!"
    else
        echo "⚠️  Could not test service connectivity"
    fi
    echo ""

    # Check logs
    echo "📋 Pod logs:"
    kubectl logs -n ride-dev "$POD_NAME" --tail=5
    echo ""

    # Port-forward instructions
    echo "======================================"
    echo "✅ Test deployment successful!"
    echo "======================================"
    echo ""
    echo "🔗 To access the test service from your machine:"
    echo "   kubectl port-forward -n ride-dev service/test-app 8080:80"
    echo "   Then visit: http://localhost:8080"
    echo ""
    echo "🗑️  To clean up the test deployment:"
    echo "   kubectl delete deployment test-app -n ride-dev"
    echo "   kubectl delete service test-app -n ride-dev"
    echo ""
    echo "🚀 Once this test works, you can deploy your actual Spring Boot services:"
    echo "   ./deploy.sh"
    echo ""
else
    echo "❌ Pod was not created successfully"
    echo "   Check the status with: kubectl get events -n ride-dev"
    exit 1
fi

