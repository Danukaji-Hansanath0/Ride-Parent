# OWNER BFF - QUICK REFERENCE CARD

## 🎯 ONE-PAGE SUMMARY

### What is Owner BFF?
A service that **registers vehicles and sets pricing in ONE API call** instead of two.

---

## 📡 Services Being Used

| Service | URL | Method | Purpose |
|---------|-----|--------|---------|
| **Keycloak** | https://auth.rydeflexi.com/ | POST /token | Get access token |
| **Vehicle Service** | http://vehicle-service:8087 | POST /api/v1/vehicles | Register vehicle |
| **Pricing Service** | http://pricing-service:8085 | POST /api/v1/price | Create pricing |

---

## 🔄 The Process (3 Steps)

### Step 1: Get Token
```
Owner BFF → Keycloak
Client ID: ownerbff
Client Secret: EQ4uAyz2stawcDGiSBzCWVZTVCn82Qh7
Returns: access_token (valid 1 hour)
```

### Step 2: Register Vehicle
```
Owner BFF → Vehicle Service (with token)
POST /api/v1/vehicles
Returns: ownerhasvehicle-id
```

### Step 3: Create Pricing
```
Owner BFF → Pricing Service (with token)
POST /api/v1/price
Uses vehicleId = ownerhasvehicle-id from Step 2
```

---

## 📮 Test The API

```bash
curl -X POST http://localhost:8088/api/v1/vehicles \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "owner-123",
    "vehicleId": "vehicle-456",
    "bodyTypeId": "1",
    "availableFrom": "2026-02-01",
    "availableUntil": "2026-12-31",
    "vehicleBodyType": "SUV",
    "currencyCode": "LKR",
    "perDay": 5000.0,
    "perWeek": 30000.0,
    "perMonth": 100000.0
  }'
```

---

## ✅ Success Response

```json
{
  "success": true,
  "vehicleRegistration": {
    "id": "ownerhasvehicle-uuid",
    "status": "ACTIVE"
  },
  "pricing": {
    "vehicleId": "ownerhasvehicle-uuid",
    "perDay": 5000.0,
    "perWeek": 30000.0,
    "perMonth": 100000.0
  },
  "overallMessage": "Vehicle and pricing created successfully"
}
```

---

## ❌ Error Responses

### 400 Bad Request (Invalid Input)
```json
{
  "success": false,
  "errorMessage": "Request validation failed",
  "overallMessage": "Vehicle registration and pricing creation failed"
}
```

### 500 Internal Server Error (Service Down)
```json
{
  "success": false,
  "errorMessage": "Failed to connect to Vehicle Service",
  "overallMessage": "An unexpected error occurred"
}
```

---

## 🔑 Key Databases

| Service | Database | Host | Port | Name |
|---------|----------|------|------|------|
| Vehicle | PostgreSQL | localhost | 5437 | vehicledb |
| Pricing | PostgreSQL | localhost | 5435 | pricingdb |

---

## ⏱️ Response Time
**Expected:** ~1.5-2 seconds
- Token generation: ~400-600ms
- Vehicle registration: ~500ms
- Pricing creation: ~400ms

---

## 🐛 Debugging

### Check if services are running:
```bash
curl http://localhost:8761/eureka/apps
```

### View Owner BFF logs:
```bash
docker logs owner-bff -f
```

### Direct test to Vehicle Service:
```bash
# Get token first, then:
curl -X POST http://localhost:8087/api/v1/vehicles \
  -H "Authorization: Bearer {token}" \
  -H "Content-Type: application/json" \
  -d '{...}'
```

---

## 📍 Endpoints

| Endpoint | Port | Status |
|----------|------|--------|
| Owner BFF | 8088 | ✅ Running |
| Vehicle Service | 8087 | ✅ Running |
| Pricing Service | 8085 | ✅ Running |
| Keycloak | HTTPS | ✅ External |
| Eureka | 8761 | ✅ Running |

---

## 📖 Full Guides

- **OWNER_BFF_TESTING_GUIDE.md** - Complete technical guide
- **OWNER_BFF_PRACTICAL_TESTING.md** - Step-by-step curl/Postman examples
- **OWNER_BFF_SERVICE_INTEGRATION_OVERVIEW.md** - Architecture diagrams

---

## 💡 Important Concept

**OwnerHasVehicle ID** = The relationship between owner and vehicle
- Returned from Vehicle Service registration
- Used as vehicleId in Pricing Service
- Unique per owner-vehicle pair
- Same vehicle with different owners = different IDs = different prices

---

## 🚀 Quick Start (30 seconds)

1. Ensure all services running: `docker-compose up -d`
2. Check Eureka: http://localhost:8761
3. Run curl command above
4. Verify response contains `"success": true`
5. ✅ Done!

---

**Last Updated:** January 22, 2026  
**Status:** ✅ Production Ready  
**Questions?** See full guides above

