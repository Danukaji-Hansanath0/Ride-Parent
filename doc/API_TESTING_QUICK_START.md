# 🧪 API Testing - Quick Start

## ⚠️ IMPORTANT: Start Services First!

Before testing, you **MUST** start the services:

```bash
# Easiest: All-in-one script (starts services + runs tests)
chmod +x start-and-test.sh
./start-and-test.sh

# OR: Start manually with Docker Compose
docker-compose up -d
sleep 30  # Wait for services to start
./test-api.sh

# OR: Start with Kubernetes (see SERVICES_NOT_RUNNING.md for details)
kubectl apply -k k8s/environments/dev
```

**If you get "Connection Refused" errors, see: `SERVICES_NOT_RUNNING.md`**

---

## ✅ Available Testing Methods

You now have **3 ways** to test your Ride Platform APIs:

### 1. 🤖 Automated Testing Script
```bash
chmod +x test-api.sh
./test-api.sh
```

**What it does:**
- Tests all service health endpoints
- Registers a test user
- Logs in and obtains token
- Tests authenticated endpoints
- Reports pass/fail status

---

### 2. 📝 Manual Curl Commands
See: **`API_TESTING_GUIDE.md`**

**Quick examples:**
```bash
# Health check
curl http://localhost:8081/actuator/health

# Register user
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!",
    "firstName": "John",
    "lastName": "Doe"
  }'

# Login
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"SecurePass123!"}'

# Test endpoint
curl http://localhost:8086/test
```

---

### 3. 📬 Postman Collection
**Import file:** `Ride-Platform-API.postman_collection.json`

**Features:**
- Pre-configured requests
- Auto-saves access token
- Variables for base URLs
- Test scripts included

**To use:**
1. Open Postman
2. Import > Upload Files > Select `Ride-Platform-API.postman_collection.json`
3. Run requests in order (Register → Login → Test endpoints)

---

## 🎯 Available Endpoints

### Auth Service (8081)
- `POST /api/auth/register` - Register new user
- `POST /api/auth/login` - User login
- `POST /api/auth/refresh-token` - Refresh access token
- `GET /api/auth/verify-email/{userId}` - Check email verification
- `GET /api/auth/send-verification-email/{userId}` - Send verification email
- `GET /api/login/google/mobile` - Google OAuth URL
- `POST /api/google/callback/mobile` - OAuth callback

### User Service (8086)
- `GET /test` - Simple test endpoint
- `GET /all` - Get all users (paginated, requires auth)
- `POST /` - Create user (requires auth)

### All Services
- `GET /actuator/health` - Health check
- `GET /actuator/info` - Service info

---

## 🚀 Quick Test Flow

1. **Start services** (if not running):
   ```bash
   kubectl apply -k k8s/environments/dev
   # OR
   docker-compose up -d
   ```

2. **Port forward** (if using Kubernetes):
   ```bash
   kubectl port-forward -n ride-dev svc/auth-SERVICE_NAME 8081:80 &
   kubectl port-forward -n ride-dev svc/user-SERVICE_NAME 8086:80 &
   ```

3. **Run automated tests**:
   ```bash
   ./test-api.sh
   ```

4. **Or test manually**:
   ```bash
   # Health check
   curl http://localhost:8081/actuator/health | jq .
   
   # User service test
   curl http://localhost:8086/test
   ```

---

## 📊 Service Ports Reference

| Service | Port | Test Endpoint |
|---------|------|---------------|
| Gateway | 8080 | `/actuator/health` |
| Auth | 8081 | `/api/auth/login` |
| Booking | 8082 | `/actuator/health` |
| Payment | 8083 | `/actuator/health` |
| Mail | 8084 | `/actuator/health` |
| Pricing | 8085 | `/actuator/health` |
| User | 8086 | `/test` |
| Vehicle | 8087 | `/actuator/health` |

---

## 🐛 Troubleshooting

### Connection Refused
```bash
# Check if services are running
kubectl get pods -n ride-dev
# OR
docker-compose ps

# Check port forwarding
lsof -i :8081
```

### Service Not Ready
```bash
# Check logs
kubectl logs -n ride-dev -l app | grep auth
# OR
docker-compose logs auth-service
```

### 401 Unauthorized
You need to login first and get an access token:
```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"pass"}'
```

---

## 📚 Documentation Files

- **API_TESTING_GUIDE.md** - Complete curl examples and documentation
- **test-api.sh** - Automated test script
- **Ride-Platform-API.postman_collection.json** - Postman collection
- **QUICK_REFERENCE.md** - Quick command reference

---

## ✨ Example Test Session

```bash
# 1. Check all services are healthy
for port in 8081 8082 8083 8084 8085 8086 8087; do
  echo "Port $port:"
  curl -s http://localhost:$port/actuator/health | jq -r '.status'
done

# 2. Test user service
curl http://localhost:8086/test

# 3. Register a user
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPass123!",
    "firstName": "Test",
    "lastName": "User"
  }' | jq .

# 4. Login
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPass123!"
  }' | jq .

# 5. Save token and use it
export TOKEN="<your-access-token>"
curl -H "Authorization: Bearer $TOKEN" \
  http://localhost:8086/all | jq .
```

---

## 🎉 You're Ready!

All testing tools are set up and ready to use. Choose your preferred method:

- **Quick automated test**: `./test-api.sh`
- **Manual exploration**: Check `API_TESTING_GUIDE.md`
- **GUI testing**: Import Postman collection

Happy testing! 🚀

