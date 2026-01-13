#!/bin/bash

echo "🔍 RabbitMQ Connection Diagnostic Tool"
echo "======================================="
echo ""

# Check if RabbitMQ container is running
echo "1️⃣ Checking if RabbitMQ container is running..."
if docker ps | grep -q rabbitmq; then
    echo "   ✅ RabbitMQ container is running"
    CONTAINER_ID=$(docker ps | grep rabbitmq | awk '{print $1}')
    echo "   Container ID: $CONTAINER_ID"
else
    echo "   ❌ RabbitMQ container is NOT running"
    echo "   💡 Start it with: docker run -d --name rabbitmq -p 5672:5672 -p 15672:15672 rabbitmq:3.12-management"
    exit 1
fi

echo ""
echo "2️⃣ Checking RabbitMQ port accessibility..."
if nc -zv localhost 5672 2>&1 | grep -q succeeded; then
    echo "   ✅ Port 5672 is accessible"
else
    echo "   ❌ Port 5672 is NOT accessible"
    echo "   💡 Check if port is exposed: docker port rabbitmq"
fi

echo ""
echo "3️⃣ Checking RabbitMQ Management UI..."
if nc -zv localhost 15672 2>&1 | grep -q succeeded; then
    echo "   ✅ Management UI port 15672 is accessible"
    echo "   🌐 Access at: http://localhost:15672 (guest/guest)"
else
    echo "   ❌ Management UI port 15672 is NOT accessible"
fi

echo ""
echo "4️⃣ Checking RabbitMQ container health..."
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' $CONTAINER_ID 2>/dev/null)
if [ "$HEALTH" = "healthy" ]; then
    echo "   ✅ RabbitMQ is healthy"
elif [ "$HEALTH" = "starting" ]; then
    echo "   ⏳ RabbitMQ is still starting..."
    echo "   💡 Wait a few seconds and try again"
elif [ -z "$HEALTH" ]; then
    echo "   ⚠️  No health check configured"
else
    echo "   ❌ RabbitMQ is unhealthy: $HEALTH"
fi

echo ""
echo "5️⃣ Checking RabbitMQ logs..."
echo "   Last 10 lines of logs:"
docker logs --tail 10 $CONTAINER_ID 2>&1 | sed 's/^/   /'

echo ""
echo "6️⃣ Testing connection from host..."
timeout 5 telnet localhost 5672 < /dev/null 2>&1 | grep -q "Connected" && \
    echo "   ✅ Can connect to RabbitMQ" || \
    echo "   ❌ Cannot connect to RabbitMQ"

echo ""
echo "7️⃣ Checking RabbitMQ queues..."
if docker exec $CONTAINER_ID rabbitmqctl list_queues 2>/dev/null | grep -q "user.profile"; then
    echo "   ✅ User profile queues exist:"
    docker exec $CONTAINER_ID rabbitmqctl list_queues name messages 2>/dev/null | grep user.profile | sed 's/^/   /'
else
    echo "   ⚠️  User profile queues not created yet"
    echo "   💡 Queues will be created when auth-service first connects"
fi

echo ""
echo "📊 Summary:"
echo "=========="
if docker ps | grep -q rabbitmq && nc -zv localhost 5672 2>&1 | grep -q succeeded; then
    echo "✅ RabbitMQ is running and accessible"
    echo "🔗 Connection string: localhost:5672"
    echo "👤 Credentials: guest/guest"
    echo "🌐 Management UI: http://localhost:15672"
    echo ""
    echo "🚀 Your auth-service should be able to connect!"
else
    echo "❌ RabbitMQ has connection issues"
    echo ""
    echo "Quick fixes:"
    echo "1. Restart RabbitMQ: docker restart rabbitmq"
    echo "2. Check logs: docker logs rabbitmq"
    echo "3. Verify ports: docker port rabbitmq"
fi

