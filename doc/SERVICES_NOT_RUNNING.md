# ⚠️ Services Not Running - Quick Fix

## The Problem

The test script is failing because the services aren't running yet. You need to start them first!

## 🚀 Quick Solution

### Option 1: Use the All-in-One Script (Easiest)

```bash
chmod +x start-and-test.sh
./start-and-test.sh
```

This script will:
1. ✅ Detect your environment (Kubernetes or Docker)
2. ✅ Start all services
3. ✅ Wait for them to be ready
4. ✅ Run the test suite automatically

---

### Option 2: Docker Compose (Recommended for Testing)

```bash
# Start all services
docker-compose up -d

# Wait for services to start (30 seconds)
sleep 30

# Now run tests
chmod +x test-api.sh
./test-api.sh
```

---

### Option 3: Kubernetes

```bash
# Deploy to Kubernetes
kubectl apply -k k8s/environments/dev

# Wait for pods
kubectl wait --for=condition=ready pod -l app -n ride-dev --timeout=300s

# Port forward all services (in separate terminals or background)
kubectl port-forward -n ride-dev svc/auth-SERVICE_NAME 8081:80 &
kubectl port-forward -n ride-dev svc/user-SERVICE_NAME 8086:80 &
kubectl port-forward -n ride-dev svc/booking-SERVICE_NAME 8082:80 &
kubectl port-forward -n ride-dev svc/payment-SERVICE_NAME 8083:80 &
kubectl port-forward -n ride-dev svc/mail-SERVICE_NAME 8084:80 &
kubectl port-forward -n ride-dev svc/pricing-SERVICE_NAME 8085:80 &
kubectl port-forward -n ride-dev svc/vehicle-SERVICE_NAME 8087:80 &
kubectl port-forward -n ride-dev svc/gateway-SERVICE_NAME 8080:80 &

# Wait a bit for port forwards to establish
sleep 5

# Now run tests
./test-api.sh
```

---

## 🔍 Check If Services Are Running

### For Docker Compose:
```bash
docker-compose ps
```

### For Kubernetes:
```bash
kubectl get pods -n ride-dev
kubectl get svc -n ride-dev
```

---

## 🧪 Manual Test (Without Script)

Once services are running, try these simple tests:

```bash
# Test user service (simplest endpoint)
curl http://localhost:8086/test

# Expected output: "User Service is up and running!"

# Test health endpoints
curl http://localhost:8081/actuator/health
curl http://localhost:8086/actuator/health

# Register a user
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "test@example.com",
    "password": "Test123!",
    "firstName": "Test",
    "lastName": "User"
  }'
```

---

## ⚡ Fastest Way to Get Started

Run this one command:

```bash
chmod +x start-and-test.sh && ./start-and-test.sh
```

This handles everything automatically! 🚀

---

## 🐛 Still Having Issues?

### Service won't start?
```bash
# Check logs (Docker)
docker-compose logs auth-service

# Check logs (Kubernetes)
kubectl logs -n ride-dev -l app | grep auth
```

### Port already in use?
```bash
# Find what's using the port
lsof -i :8081

# Kill the process
kill -9 <PID>
```

### Connection refused?
Make sure you:
1. Started the services first
2. Waited for them to be ready (30-60 seconds)
3. Port forwarding is active (if using Kubernetes)

---

## 📊 Expected Timeline

- **Docker Compose**: ~30-60 seconds to be ready
- **Kubernetes**: ~2-5 minutes for first deployment

Be patient! Java Spring Boot applications take time to start up.

---

## ✅ Once Running

After services are up, you can use:
- `./test-api.sh` - Automated tests
- `API_TESTING_GUIDE.md` - Manual curl commands
- Postman collection - GUI testing

---

**TIP**: Always start services before running tests! 💡

