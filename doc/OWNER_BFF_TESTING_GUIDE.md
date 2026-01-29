# OWNER BFF - SERVICE INTEGRATION & TESTING GUIDE

## 📋 Overview

The Owner BFF (Backend-for-Frontend) is a **coordination layer** that orchestrates vehicle registration and pricing creation. It acts as a **single endpoint** for owners to register vehicles and set pricing in one operation.

---

## 🔄 Service Architecture

```
┌─────────────────────────────────────────────────────────────┐
│                  OWNER BFF (8088)                           │
│            Vehicle Registration Controller                  │
└───────────────┬─────────────────────────────────────────────┘
                │
    ┌───────────┴────────────┬──────────────┐
    │                        │              │
    ▼                        ▼              ▼
┌──────────────┐      ┌──────────────┐  ┌──────────────┐
│ Keycloak     │      │ Vehicle      │  │ Pricing      │
│ (Auth)       │      │ Service      │  │ Service      │
│ 51.75...     │      │ (8087)       │  │ (8085)       │
└──────────────┘      └──────────────┘  └──────────────┘
                             │                 │
                      ┌──────▼────────┐   ┌───▼──────────┐
                      │PostgreSQL     │   │PostgreSQL    │
                      │(5437)         │   │(5435)        │
                      │vehicledb      │   │pricingdb     │
                      └───────────────┘   └──────────────┘
```

---

## 🔌 Services Used

### 1. **Keycloak (OAuth2 Authentication)**
**Purpose:** Generate access tokens for service-to-service communication
- **URL:** `https://auth.rydeflexi.com/`
- **Endpoint:** `/realms/service-authentication/protocol/openid-connect/token`
- **Authentication:** Client Credentials Grant
- **Used By:** `ServiceTokenService`

### 2. **Vehicle Service (8087)**
**Purpose:** Register vehicle and associate with owner
- **URL:** `http://vehicle-service:8087`
- **Endpoint:** `POST /api/v1/vehicles`
- **Input:** Vehicle registration details (userId, vehicleId, bodyTypeId)
- **Output:** OwnerHasVehicle ID
- **Authentication:** Bearer Token (from Keycloak)
- **Used By:** `VehicleServiceClient`

### 3. **Pricing Service (8085)**
**Purpose:** Create pricing for the registered vehicle
- **URL:** `http://pricing-service:8085`
- **Endpoint:** `POST /api/v1/price`
- **Input:** Pricing details (vehicleId=OwnerHasVehicleId, perDay, perWeek, perMonth)
- **Output:** Pricing confirmation
- **Authentication:** Bearer Token (from Keycloak)
- **Used By:** `PriceServiceClient`

---

## 📊 Service Interaction Flow

```
1. CLIENT SENDS REQUEST
   POST /api/v1/vehicles (Owner BFF)
   {
     "userId": "owner-123",
     "vehicleId": "vehicle-456",
     "bodyTypeId": "1",
     "availableFrom": "2026-02-01",
     "availableUntil": "2026-12-31",
     "vehicleBodyType": "SUV",
     "currencyCode": "LKR",
     "perDay": 5000,
     "perWeek": 30000,
     "perMonth": 100000
   }

2. OWNER BFF → KEYCLOAK
   GET /token
   Authorization: Client Credentials
   ↓ Returns: access_token

3. OWNER BFF → VEHICLE SERVICE
   POST /api/v1/vehicles
   Authorization: Bearer {access_token}
   Body: Vehicle data
   ↓ Returns: 
   {
     "id": "ownerhasvehicle-789",  ← This is the KEY!
     "status": "ACTIVE",
     "message": "Vehicle registered"
   }

4. OWNER BFF → KEYCLOAK
   GET /token (if expired, else reuse)
   ↓ Returns: access_token

5. OWNER BFF → PRICING SERVICE
   POST /api/v1/price
   Authorization: Bearer {access_token}
   Body: {
     "vehicleId": "ownerhasvehicle-789",  ← From step 3!
     "perDay": 5000,
     "perWeek": 30000,
     "perMonth": 100000,
     "bodyType": "SUV",
     "currencyCode": "LKR"
   }
   ↓ Returns: Success response

6. OWNER BFF → CLIENT
   Returns combined response:
   {
     "success": true,
     "vehicleRegistration": {...},
     "pricing": {...},
     "message": "Vehicle and pricing created successfully"
   }
```

---

## 🧪 Testing Guide

### Prerequisites
1. ✅ All services running (auth, vehicle, pricing, owner-bff)
2. ✅ Databases initialized (PostgreSQL for vehicle and pricing services)
3. ✅ Keycloak configured with credentials
4. ✅ `.env` file loaded with all configurations

### Start Services in Order

```bash
# 1. Start Discovery Service (Eureka)
docker-compose up -d discovery-service

# 2. Start Databases
docker-compose up -d postgres mongodb

# 3. Start Auth Service
docker-compose up -d auth-service

# 4. Start Vehicle Service
docker-compose up -d vehicle-service

# 5. Start Pricing Service
docker-compose up -d pricing-service

# 6. Start Owner BFF
docker-compose up -d owner-bff

# Verify all services are running
curl http://localhost:8761/eureka/apps | jq
```

---

## 📮 Test Cases

### Test Case 1: Register Vehicle with Pricing (Happy Path)

**Endpoint:** `POST http://localhost:8088/api/v1/vehicles`

**Request Body:**
```json
{
  "userId": "owner-uuid-123",
  "vehicleId": "vehicle-uuid-456",
  "bodyTypeId": "1",
  "availableFrom": "2026-02-01",
  "availableUntil": "2026-12-31",
  "vehicleBodyType": "SUV",
  "currencyCode": "LKR",
  "perDay": 5000.0,
  "perWeek": 30000.0,
  "perMonth": 100000.0
}
```

**Expected Response (200 OK):**
```json
{
  "success": true,
  "vehicleRegistration": {
    "id": "ownerhasvehicle-789",
    "status": "ACTIVE",
    "message": "Vehicle registered successfully"
  },
  "pricing": {
    "vehicleId": "ownerhasvehicle-789",
    "perDay": 5000.0,
    "perWeek": 30000.0,
    "perMonth": 100000.0,
    "currencyCode": "LKR",
    "commission": 500.0
  },
  "overallMessage": "Vehicle and pricing created successfully",
  "operationId": "op-123"
}
```

**cURL Command:**
```bash
curl -X POST http://localhost:8088/api/v1/vehicles \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "owner-uuid-123",
    "vehicleId": "vehicle-uuid-456",
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

### Test Case 2: Register Vehicle with Invalid Body (Bad Request)

**Request Body:**
```json
{}
```

**Expected Response (400 Bad Request):**
```json
{
  "success": false,
  "errorMessage": "Request validation failed: required fields missing",
  "overallMessage": "Vehicle registration and pricing creation failed"
}
```

---

### Test Case 3: Vehicle Service Unavailable (Failure Handling)

**Scenario:** Vehicle Service is down

**Expected Response (500 Internal Server Error):**
```json
{
  "success": false,
  "errorMessage": "Failed to connect to Vehicle Service",
  "overallMessage": "Error in vehicle registration with pricing: Connection refused"
}
```

**Logs Expected:**
```
[owner-bff] ERROR - Vehicle registration failed: Vehicle Service connection error
[owner-bff] ERROR - Error in vehicle registration with pricing workflow: Connection refused
```

---

### Test Case 4: Keycloak Token Generation Fails

**Scenario:** Keycloak service is unreachable

**Expected Response (500 Internal Server Error):**
```json
{
  "success": false,
  "errorMessage": "Failed to retrieve access token from Keycloak",
  "overallMessage": "Error in vehicle registration with pricing: Authentication failed"
}
```

**Logs Expected:**
```
[owner-bff] ERROR - Failed to obtain access token from Keycloak
[owner-bff] ERROR - Error retrieving access token or calling vehicle service
```

---

## 🔍 Detailed Service Interactions

### Step 1: Get Access Token

**Service:** Owner BFF → Keycloak

**Code Flow:**
```java
// ServiceTokenService.getAccessToken()
POST https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token
Body:
  grant_type=client_credentials
  client_id=ownerbff
  client_secret=EQ4uAyz2stawcDGiSBzCWVZTVCn82Qh7

Response:
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
  "token_type": "Bearer",
  "expires_in": 3600
}
```

---

### Step 2: Register Vehicle

**Service:** Owner BFF → Vehicle Service

**Code Flow:**
```java
// VehicleServiceClient.registerVehicle(vehicleDto)
POST http://vehicle-service:8087/api/v1/vehicles
Header: Authorization: Bearer {access_token}
Header: Content-Type: application/json
Body:
{
  "userId": "owner-uuid-123",
  "vehicleId": "vehicle-uuid-456",
  "bodyTypeId": "1",
  "availableFrom": "2026-02-01",
  "availableUntil": "2026-12-31"
}

Response:
{
  "id": "ownerhasvehicle-789",
  "status": "ACTIVE",
  "message": "Vehicle registered with owner"
}
```

**Database Operation:**
```sql
INSERT INTO owners_has_vehicles (
  id, owner_id, vehicle_id, available_from, available_until, status, created_at
) VALUES (
  'ownerhasvehicle-789', 'owner-uuid-123', 'vehicle-uuid-456', 
  '2026-02-01', '2026-12-31', 'ACTIVE', NOW()
)
```

---

### Step 3: Create Pricing

**Service:** Owner BFF → Pricing Service

**Code Flow:**
```java
// PriceServiceClient.createPrice(priceDto)
POST http://pricing-service:8085/api/v1/price
Header: Authorization: Bearer {access_token}
Header: Content-Type: application/json
Body:
{
  "vehicleId": "ownerhasvehicle-789",  ← ⚠️ KEY: Use OwnerHasVehicle ID!
  "perDay": 5000.0,
  "perWeek": 30000.0,
  "perMonth": 100000.0,
  "vehicleBodyType": "SUV",
  "currencyCode": "LKR"
}

Response:
"Pricing created successfully"
```

**Database Operation:**
```sql
INSERT INTO vehicle_prices (
  vehicle_id, price_per_day, price_per_week, price_per_month, 
  currency_code, commission_percentage, created_at
) VALUES (
  'ownerhasvehicle-789', 5000.0, 30000.0, 100000.0,
  'LKR', 10.0, NOW()
)
```

---

## 📊 Data Flow Summary

| Step | From | To | Data | Purpose |
|------|------|----|----|---------|
| 1 | Owner BFF | Keycloak | Client ID + Secret | Get access token |
| 2 | Owner BFF | Vehicle Service | Vehicle details + Token | Register vehicle |
| 3 | Vehicle Service | Vehicle DB | Vehicle + Owner link | Store registration |
| 4 | Vehicle Service | Owner BFF | **OwnerHasVehicle ID** | **Return unique ID** |
| 5 | Owner BFF | Pricing Service | Pricing + **ID** + Token | Create pricing |
| 6 | Pricing Service | Pricing DB | Pricing data | Store prices |
| 7 | Pricing Service | Owner BFF | Success response | Confirm creation |
| 8 | Owner BFF | Client | Combined response | Return complete result |

---

## 🔐 Security Flow

```
Client Request
  ↓
  [Owner BFF Validates Request]
  ├─ Check if VehicleWithPricingDto is null ✓
  ├─ Check if required fields are present ✓
  │
  ↓
  [Get Access Token from Keycloak]
  ├─ Client Credentials Flow
  ├─ Client ID: ownerbff
  ├─ Client Secret: EQ4uAyz2stawcDGiSBzCWVZTVCn82Qh7
  ├─ Scope: service-to-service
  │
  ↓
  [Call Vehicle Service with Bearer Token]
  ├─ Validate token is present
  ├─ Validate token is not expired
  ├─ Send with Authorization header
  │
  ↓
  [Vehicle Service Validates Token]
  ├─ Verify JWT signature
  ├─ Verify token not expired
  ├─ Verify claims
  │
  ↓
  [Call Pricing Service with same Token]
  ├─ Reuse token if not expired
  ├─ Get new token if expired
  │
  ↓
  [Return Combined Response to Client]
```

---

## 📝 Service Dependencies Summary

| Service | Endpoint | Method | Purpose | Auth | Timeout |
|---------|----------|--------|---------|------|---------|
| **Keycloak** | `/token` | POST | Get access token | Basic | 10s |
| **Vehicle Service** | `/api/v1/vehicles` | POST | Register vehicle | Bearer | 30s |
| **Pricing Service** | `/api/v1/price` | POST | Create pricing | Bearer | 30s |

---

## ⚠️ Error Handling

### Exception Types:

1. **IllegalArgumentException** → 400 Bad Request
   - Null DTO
   - Missing required fields
   
2. **IOException** → 500 Internal Server Error
   - Network connectivity issues
   - Service unreachable
   
3. **JsonProcessingException** → 500 Internal Server Error
   - Response mapping failed
   - Invalid JSON response
   
4. **RuntimeException** → 500 Internal Server Error
   - Any unexpected error
   - Database error
   - Keycloak error

---

## 🎯 Test Checklist

- [ ] Keycloak service running and accessible
- [ ] Vehicle Service running and accessible
- [ ] Pricing Service running and accessible
- [ ] Owner BFF running and accessible
- [ ] PostgreSQL databases initialized
- [ ] All .env variables loaded
- [ ] Bearer token generation working
- [ ] Vehicle registration working
- [ ] Pricing creation working
- [ ] Error handling working
- [ ] Response mapping working

---

## 🔧 Configuration Required

### In `.env` file:

```bash
# Keycloak
KEYCLOAK_SERVER_URL=https://auth.rydeflexi.com/
OWNERBFF_CLIENT_ID=ownerbff
OWNERBFF_CLIENT_SECRET=EQ4uAyz2stawcDGiSBzCWVZTVCn82Qh7

# Services
VEHICLE_SERVICE_URL=http://vehicle-service:8087
PRICING_SERVICE_URL=http://pricing-service:8085

# Database
VEHICLE_DATASOURCE_URL=jdbc:postgresql://localhost:5437/vehicledb
PRICING_DATASOURCE_URL=jdbc:postgresql://localhost:5435/pricingdb

# Service Discovery
EUREKA_CLIENT_SERVICE_URL_DEFAULT_ZONE=http://localhost:8761/eureka
```

---

## 📞 Support

For issues with:
- **Keycloak:** Check auth logs in Keycloak container
- **Vehicle Service:** Check vehicle-service logs
- **Pricing Service:** Check pricing-service logs
- **Network:** Check if services are registered in Eureka (http://localhost:8761)

