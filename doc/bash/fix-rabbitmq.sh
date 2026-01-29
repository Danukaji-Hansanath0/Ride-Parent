#!/bin/bash

echo "🔧 Fixing RabbitMQ Connection Issues..."
echo "========================================"
echo ""

# Check if RabbitMQ is running
if ! docker ps | grep -q rabbitmq; then
    echo "❌ RabbitMQ container is not running!"
    echo "🚀 Starting RabbitMQ..."

    # Check if container exists but stopped
    if docker ps -a | grep -q rabbitmq; then
        docker start rabbitmq
    else
        # Create new RabbitMQ container
        docker run -d \
            --name rabbitmq \
            -p 5672:5672 \
            -p 15672:15672 \
            -e RABBITMQ_DEFAULT_USER=guest \
            -e RABBITMQ_DEFAULT_PASS=guest \
            rabbitmq:3.12-management
    fi
fi

echo "⏳ Waiting for RabbitMQ to be healthy (30 seconds)..."
sleep 30

# Check health
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' rabbitmq 2>/dev/null)

if [ "$HEALTH" = "healthy" ]; then
    echo "✅ RabbitMQ is healthy and ready!"
elif [ "$HEALTH" = "starting" ]; then
    echo "⏳ RabbitMQ is still starting, please wait another 30 seconds..."
    echo "   You can check status with: docker logs rabbitmq"
else
    echo "⚠️  RabbitMQ health status: $HEALTH"
    echo "   Check logs with: docker logs rabbitmq"
fi

# Test connection
echo ""
echo "🧪 Testing connection..."
if nc -zv localhost 5672 2>&1 | grep -q succeeded; then
    echo "✅ Port 5672 is accessible!"
else
    echo "❌ Port 5672 is not accessible"
    echo "   Checking logs..."
    docker logs rabbitmq --tail 20
fi

echo ""
echo "📊 RabbitMQ Status:"
docker ps | grep rabbitmq

echo ""
echo "🌐 Management UI: http://localhost:15672 (guest/guest)"
echo ""
echo "✅ Done! Your auth-service should now connect to RabbitMQ"
echo "   If RabbitMQ is still unavailable, the HTTP fallback will work automatically."

