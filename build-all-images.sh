#!/bin/bash
set -euo pipefail

SERVICES=(
  auth-service
  booking-service
  gateway-service
  mail-service
  payment-service
  pricing-service
  user-service
  vehicle-service
)

REGISTRY="registry.ride.com"   # change this
TAG="$(git rev-parse --short HEAD)"

echo "🚀 Building Docker images"
echo "========================="

for service in "${SERVICES[@]}"; do
  echo ""
  echo "📦 Building $service"

  docker build \
    -t "$REGISTRY/$service:$TAG" \
    -t "$REGISTRY/$service:latest" \
    "./$service"

  echo "✅ $service built"
done

echo ""
echo "========================="
echo "✅ All images built"
