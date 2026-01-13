# 🔴 Test Failed: Services Not Running

## What Happened

You ran `./test-api.sh` but got error code `000` which means **connection refused** - the services aren't running yet!

## ✅ How to Fix

### 🚀 **EASIEST SOLUTION** (Recommended)

Run the all-in-one script that starts services AND tests them:

```bash
chmod +x start-and-test.sh
./start-and-test.sh
```

This will:
1. Detect your environment (Docker or Kubernetes)
2. Start all services
3. Wait for them to be ready
4. Run tests automatically
5. Show you the results

---

### 📦 Alternative: Docker Compose

```bash
# 1. Start services
docker-compose up -d

# 2. Wait for services to start (they need time to boot up)
echo "Waiting for services to start..."
sleep 30

# 3. Check if they're running
docker-compose ps

# 4. Test a simple endpoint
curl http://localhost:8086/test

# 5. If that works, run full test suite
./test-api.sh
```

---

### ☸️ Alternative: Kubernetes

```bash
# 1. Deploy
kubectl apply -k k8s/environments/dev

# 2. Check pods are running
kubectl get pods -n ride-dev

# 3. Wait for all pods to be ready
kubectl wait --for=condition=ready pod -l app -n ride-dev --timeout=300s

# 4. Port forward services (run in background)
kubectl port-forward -n ride-dev svc/auth-SERVICE_NAME 8081:80 &
kubectl port-forward -n ride-dev svc/user-SERVICE_NAME 8086:80 &
kubectl port-forward -n ride-dev svc/booking-SERVICE_NAME 8082:80 &
kubectl port-forward -n ride-dev svc/payment-SERVICE_NAME 8083:80 &
kubectl port-forward -n ride-dev svc/mail-SERVICE_NAME 8084:80 &
kubectl port-forward -n ride-dev svc/pricing-SERVICE_NAME 8085:80 &
kubectl port-forward -n ride-dev svc/vehicle-SERVICE_NAME 8087:80 &
kubectl port-forward -n ride-dev svc/gateway-SERVICE_NAME 8080:80 &

# 5. Wait for port forwards to establish
sleep 5

# 6. Run tests
./test-api.sh
```

---

## 🧪 Quick Manual Test

Want to test manually first? Try this simple command:

```bash
# If services are running, this should work:
curl http://localhost:8086/test

# Expected output:
# "User Service is up and running!"
```

If that fails with "Connection refused", services aren't running yet.

---

## 📊 Service Startup Times

**Be patient!** Services need time to start:

- **Docker Compose**: 30-60 seconds
- **Kubernetes**: 2-5 minutes (first time)

Spring Boot applications are Java-based and take time to initialize.

---

## 🔍 Verify Services Are Running

### Docker Compose:
```bash
docker-compose ps

# Should show all services as "Up"
```

### Kubernetes:
```bash
kubectl get pods -n ride-dev

# Should show STATUS as "Running" and READY as "1/1"
```

---

## 💡 Pro Tip: Use the All-in-One Script

Instead of starting services manually, use:

```bash
./start-and-test.sh
```

It handles everything automatically! This is the recommended approach.

---

## 📝 Error Code Meanings

| Code | Meaning | Solution |
|------|---------|----------|
| 000 | Connection refused | Services not running - start them first |
| 401 | Unauthorized | Need to login first to get token |
| 404 | Not found | Endpoint doesn't exist or wrong URL |
| 500 | Server error | Check service logs |

---

## 🎯 Recommended Flow

1. **Start services**: `./start-and-test.sh`
2. **Or start manually**: `docker-compose up -d` → wait 30s → `./test-api.sh`
3. **For manual testing**: See `API_TESTING_GUIDE.md`
4. **For Postman**: Import `Ride-Platform-API.postman_collection.json`

---

## ✅ Once Services Are Running

After services are up and healthy, you can:

- ✅ Run automated tests: `./test-api.sh`
- ✅ Use curl commands from `API_TESTING_GUIDE.md`
- ✅ Import Postman collection and test
- ✅ Build your own integrations

---

## 🆘 Still Having Issues?

Check these files:
- `SERVICES_NOT_RUNNING.md` - Detailed troubleshooting
- `DEPLOYMENT_GUIDE.md` - Full deployment guide
- `QUICK_REFERENCE.md` - Command reference

Or check service logs:
```bash
# Docker
docker-compose logs auth-service

# Kubernetes
kubectl logs -n ride-dev -l app | grep auth
```

---

**The bottom line**: You need to start services **before** testing them! 🚀

Run `./start-and-test.sh` and you're good to go!

