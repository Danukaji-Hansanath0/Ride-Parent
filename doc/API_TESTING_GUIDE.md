# 🧪 API Testing Guide - Curl Examples

This guide provides curl commands to test all endpoints in your Ride Platform.

## 🚀 Quick Setup

### 1. Deploy the Application
```bash
# Deploy to Kubernetes
kubectl apply -k k8s/environments/dev

# OR run with Docker Compose
docker-compose up -d
```

### 2. Port Forward Gateway (if using Kubernetes)
```bash
kubectl port-forward -n ride-dev svc/gateway-SERVICE_NAME 8080:80
```

### 3. Set Base URLs
```bash
# If using Kubernetes with port-forward
export GATEWAY_URL="http://localhost:8080"
export AUTH_URL="http://localhost:8081"
export USER_URL="http://localhost:8086"
export BOOKING_URL="http://localhost:8082"
export PAYMENT_URL="http://localhost:8083"

# If using Docker Compose
export GATEWAY_URL="http://localhost:8080"
export AUTH_URL="http://localhost:8081"
export USER_URL="http://localhost:8086"
export BOOKING_URL="http://localhost:8082"
export PAYMENT_URL="http://localhost:8083"
```

---

## 📋 Available Endpoints

### 🔐 Auth Service (Port 8081)

#### 1. Health Check
```bash
curl -X GET http://localhost:8081/actuator/health
```

**Expected Response:**
```json
{
  "status": "UP"
}
```

---

#### 2. User Registration
```bash
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!",
    "firstName": "John",
    "lastName": "Doe",
    "phone": "+1234567890"
  }'
```

**Expected Response:**
```json
{
  "userId": "abc123...",
  "email": "user@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "message": "User registered successfully"
}
```

---

#### 3. User Login
```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "user@example.com",
    "password": "SecurePass123!"
  }'
```

**Expected Response:**
```json
{
  "accessToken": "eyJhbGciOiJSUzI1NiIsInR5cCI...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cCI...",
  "tokenType": "Bearer",
  "expiresIn": 3600,
  "userId": "abc123..."
}
```

**Save the token:**
```bash
export ACCESS_TOKEN="<your-access-token-here>"
```

---

#### 4. Refresh Token
```bash
curl -X POST http://localhost:8081/api/auth/refresh-token \
  -H "Content-Type: application/json" \
  -d '"<your-refresh-token-here>"'
```

---

#### 5. Check Email Verification Status
```bash
curl -X GET http://localhost:8081/api/auth/verify-email/{userId}
```

**Example:**
```bash
curl -X GET http://localhost:8081/api/auth/verify-email/abc123
```

**Expected Response:**
```json
true
```
or
```json
false
```

---

#### 6. Send Verification Email
```bash
curl -X GET http://localhost:8081/api/auth/send-verification-email/{userId}
```

**Example:**
```bash
curl -X GET http://localhost:8081/api/auth/send-verification-email/abc123
```

---

#### 7. Google OAuth - Get Authorization URL (Mobile)
```bash
curl -X GET "http://localhost:8081/api/login/google/mobile?codeVerifier=YOUR_CODE_VERIFIER&redirectUri=http://localhost:8081/callback"
```

**Expected Response:**
```json
{
  "authorizationUrl": "https://accounts.google.com/o/oauth2/v2/auth?...",
  "state": "random-state-string"
}
```

---

#### 8. Google OAuth - Handle Callback (Mobile)
```bash
curl -X POST "http://localhost:8081/api/google/callback/mobile" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "code=AUTH_CODE&codeVerifier=YOUR_CODE_VERIFIER&redirectUri=http://localhost:8081/callback"
```

---

### 👤 User Service (Port 8086)

#### 1. Health Check
```bash
curl -X GET http://localhost:8086/actuator/health
```

---

#### 2. Test Endpoint
```bash
curl -X GET http://localhost:8086/test
```

**Expected Response:**
```
User Service is up and running!
```

---

#### 3. Get All Users (Paginated)
```bash
curl -X GET "http://localhost:8086/all?page=0&size=15" \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

**Expected Response:**
```json
{
  "content": [
    {
      "userId": "abc123",
      "email": "user@example.com",
      "firstName": "John",
      "lastName": "Doe"
    }
  ],
  "pageable": {
    "pageNumber": 0,
    "pageSize": 15
  },
  "totalElements": 10,
  "totalPages": 1
}
```

---

#### 4. Create User
```bash
curl -X POST http://localhost:8086 \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $ACCESS_TOKEN" \
  -d '{
    "email": "newuser@example.com",
    "firstName": "Jane",
    "lastName": "Smith",
    "phone": "+1987654321"
  }'
```

---

### 🚕 Booking Service (Port 8082)

#### 1. Health Check
```bash
curl -X GET http://localhost:8082/actuator/health
```

---

### 💳 Payment Service (Port 8083)

#### 1. Health Check
```bash
curl -X GET http://localhost:8083/actuator/health
```

---

### 📧 Mail Service (Port 8084)

#### 1. Health Check
```bash
curl -X GET http://localhost:8084/actuator/health
```

---

### 💰 Pricing Service (Port 8085)

#### 1. Health Check
```bash
curl -X GET http://localhost:8085/actuator/health
```

---

### 🚗 Vehicle Service (Port 8087)

#### 1. Health Check
```bash
curl -X GET http://localhost:8087/actuator/health
```

---

## 🎯 Complete Testing Flow

### Step-by-Step Test Scenario

```bash
#!/bin/bash

echo "🧪 Starting Ride Platform API Tests"
echo "===================================="
echo ""

# 1. Check Auth Service Health
echo "1️⃣  Checking Auth Service Health..."
curl -s http://localhost:8081/actuator/health | jq .
echo ""

# 2. Register a New User
echo "2️⃣  Registering new user..."
REGISTER_RESPONSE=$(curl -s -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPass123!",
    "firstName": "Test",
    "lastName": "User",
    "phone": "+1234567890"
  }')
echo $REGISTER_RESPONSE | jq .
USER_ID=$(echo $REGISTER_RESPONSE | jq -r '.userId')
echo "User ID: $USER_ID"
echo ""

# 3. Login
echo "3️⃣  Logging in..."
LOGIN_RESPONSE=$(curl -s -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPass123!"
  }')
echo $LOGIN_RESPONSE | jq .
ACCESS_TOKEN=$(echo $LOGIN_RESPONSE | jq -r '.accessToken')
echo "Access Token: ${ACCESS_TOKEN:0:50}..."
echo ""

# 4. Check User Service
echo "4️⃣  Checking User Service..."
curl -s http://localhost:8086/test
echo ""
echo ""

# 5. Get All Users
echo "5️⃣  Getting all users..."
curl -s -X GET "http://localhost:8086/all?page=0&size=15" \
  -H "Authorization: Bearer $ACCESS_TOKEN" | jq .
echo ""

# 6. Check All Service Health
echo "6️⃣  Checking all services health..."
for port in 8081 8082 8083 8084 8085 8086 8087; do
  SERVICE=$(curl -s http://localhost:$port/actuator/health 2>/dev/null || echo '{"status":"DOWN"}')
  STATUS=$(echo $SERVICE | jq -r '.status')
  echo "   Port $port: $STATUS"
done
echo ""

echo "✅ All tests completed!"
```

**Save as `test-api.sh` and run:**
```bash
chmod +x test-api.sh
./test-api.sh
```

---

## 🔑 Authentication Header Examples

### Using Bearer Token
```bash
curl -X GET http://localhost:8086/all \
  -H "Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI..."
```

### Using Environment Variable
```bash
export ACCESS_TOKEN="your-token-here"

curl -X GET http://localhost:8086/all \
  -H "Authorization: Bearer $ACCESS_TOKEN"
```

---

## 📊 Response Status Codes

| Code | Meaning | Example |
|------|---------|---------|
| 200  | OK | Successful GET/PUT/PATCH |
| 201  | Created | Successful POST (resource created) |
| 204  | No Content | Successful DELETE |
| 400  | Bad Request | Invalid request data |
| 401  | Unauthorized | Missing/invalid authentication |
| 403  | Forbidden | Insufficient permissions |
| 404  | Not Found | Resource doesn't exist |
| 409  | Conflict | Duplicate resource (e.g., email exists) |
| 500  | Server Error | Internal server error |

---

## 🐛 Troubleshooting

### Connection Refused
```bash
# Check if service is running
kubectl get pods -n ride-dev
# OR
docker-compose ps

# Check port forwarding
kubectl port-forward -n ride-dev svc/auth-SERVICE_NAME 8081:80
```

### 401 Unauthorized
```bash
# Get a new token
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{"email":"user@example.com","password":"password"}'
```

### 500 Internal Server Error
```bash
# Check service logs
kubectl logs -n ride-dev -l app | grep auth
# OR
docker-compose logs auth-service
```

---

## 📝 Pretty Print JSON Responses

### Install jq (if not installed)
```bash
# macOS
brew install jq

# Ubuntu/Debian
sudo apt-get install jq

# Arch Linux
sudo pacman -S jq
```

### Use with curl
```bash
curl -s http://localhost:8081/actuator/health | jq .
curl -s http://localhost:8081/actuator/health | jq '.status'
```

---

## 🚀 Advanced Testing with HTTPie

HTTPie is a more user-friendly alternative to curl:

```bash
# Install HTTPie
pip install httpie

# Examples
http GET http://localhost:8081/actuator/health
http POST http://localhost:8081/api/auth/login email=user@example.com password=pass
http GET http://localhost:8086/all "Authorization: Bearer $ACCESS_TOKEN"
```

---

## 📦 Postman Collection

Create a Postman collection with these requests:

1. Import as cURL commands
2. Set base URL as variable: `{{base_url}}`
3. Set token as variable: `{{access_token}}`
4. Use pre-request scripts to auto-refresh tokens

---

## ✅ Health Check All Services

Quick script to check all services:

```bash
#!/bin/bash
echo "Service Health Check"
echo "===================="
services=("auth:8081" "booking:8082" "payment:8083" "mail:8084" "pricing:8085" "user:8086" "vehicle:8087" "gateway:8080")

for service in "${services[@]}"; do
  name="${service%:*}"
  port="${service#*:}"
  status=$(curl -s http://localhost:$port/actuator/health | jq -r '.status' 2>/dev/null || echo "DOWN")
  printf "%-12s (:%s) %s\n" "$name" "$port" "$status"
done
```

---

## 🎉 Ready to Test!

Your API endpoints are ready to test. Start with:

1. **Health checks** - Ensure all services are running
2. **Registration** - Create a test user
3. **Login** - Get an access token
4. **Authenticated requests** - Use the token for protected endpoints

Happy testing! 🚀

