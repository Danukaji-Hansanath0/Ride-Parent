# OWNER BFF - PRACTICAL TESTING WITH CURL & POSTMAN

## 🚀 Quick Start Testing

### Prerequisites Check

```bash
# 1. Check if all services are running
curl -s http://localhost:8761/eureka/apps | jq '.applications.application[].name'

# Expected output:
# "DISCOVERY-SERVICE"
# "AUTH-SERVICE"
# "VEHICLE-SERVICE"
# "PRICING-SERVICE"
# "OWNER-BFF"

# 2. Check Owner BFF is ready
curl -s http://localhost:8088/actuator/health | jq '.status'
# Expected: "UP"

# 3. Check Vehicle Service is ready
curl -s http://localhost:8087/actuator/health | jq '.status'
# Expected: "UP"

# 4. Check Pricing Service is ready
curl -s http://localhost:8085/actuator/health | jq '.status'
# Expected: "UP"
```

---

## 📮 Test 1: Complete Vehicle Registration with Pricing

### Using cURL

```bash
#!/bin/bash

# Register vehicle with pricing
curl -X POST http://localhost:8088/api/v1/vehicles \
  -H "Content-Type: application/json" \
  -H "Accept: application/json" \
  -d '{
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "vehicleId": "660e8400-e29b-41d4-a716-446655440111",
    "bodyTypeId": "1",
    "availableFrom": "2026-02-01",
    "availableUntil": "2026-12-31",
    "vehicleBodyType": "SUV",
    "currencyCode": "LKR",
    "perDay": 5000.0,
    "perWeek": 30000.0,
    "perMonth": 100000.0
  }' | jq '.'
```

### Expected Response:

```json
{
  "success": true,
  "vehicleRegistration": {
    "id": "ownerhasvehicle-uuid-here",
    "status": "ACTIVE",
    "message": "Vehicle registered with owner successfully"
  },
  "pricing": {
    "vehicleId": "ownerhasvehicle-uuid-here",
    "perDay": 5000.0,
    "perWeek": 30000.0,
    "perMonth": 100000.0,
    "currencyCode": "LKR",
    "commission": 500.0,
    "pricePerDayAfterCommission": 5500.0
  },
  "overallMessage": "Vehicle and pricing created successfully",
  "operationId": "op-xyz-123"
}
```

---

## 📮 Test 2: Get Keycloak Access Token

### Using cURL

```bash
#!/bin/bash

# Get access token for service-to-service communication
TOKEN=$(curl -s -X POST \
  https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=ownerbff" \
  -d "client_secret=EQ4uAyz2stawcDGiSBzCWVZTVCn82Qh7" | jq -r '.access_token')

echo "Access Token: $TOKEN"

# Decode token (optional, for inspection)
echo "Token Claims:"
echo $TOKEN | cut -d'.' -f2 | base64 -d | jq '.'
```

### Expected Response:

```json
{
  "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIsImtpZCI6IjEifQ...",
  "expires_in": 3600,
  "refresh_expires_in": 1800,
  "token_type": "Bearer",
  "not-before-policy": 0,
  "scope": "openid"
}
```

---

## 📮 Test 3: Direct Vehicle Service Call (Advanced)

### Purpose: Verify Vehicle Service is receiving requests correctly

```bash
#!/bin/bash

# Get token first
TOKEN=$(curl -s -X POST \
  https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=ownerbff" \
  -d "client_secret=EQ4uAyz2stawcDGiSBzCWVZTVCn82Qh7" | jq -r '.access_token')

# Now call Vehicle Service directly
curl -X POST http://localhost:8087/api/v1/vehicles \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "vehicleId": "660e8400-e29b-41d4-a716-446655440111",
    "bodyTypeId": "1",
    "availableFrom": "2026-02-01",
    "availableUntil": "2026-12-31"
  }' | jq '.'
```

### Expected Response:

```json
{
  "id": "ownerhasvehicle-uuid-here",
  "status": "ACTIVE",
  "message": "Vehicle registered with owner successfully"
}
```

---

## 📮 Test 4: Direct Pricing Service Call (Advanced)

### Purpose: Verify Pricing Service is receiving requests correctly

```bash
#!/bin/bash

# Get token first
TOKEN=$(curl -s -X POST \
  https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=ownerbff" \
  -d "client_secret=EQ4uAyz2stawcDGiSBzCWVZTVCn82Qh7" | jq -r '.access_token')

# Get OwnerHasVehicle ID from previous test
VEHICLE_ID="ownerhasvehicle-uuid-from-step3"

# Now call Pricing Service directly
curl -X POST http://localhost:8085/api/v1/price \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "vehicleId": "'$VEHICLE_ID'",
    "perDay": 5000.0,
    "perWeek": 30000.0,
    "perMonth": 100000.0,
    "vehicleBodyType": "SUV",
    "currencyCode": "LKR"
  }' | jq '.'
```

### Expected Response:

```
"Pricing created successfully"
```

---

## 📮 Test 5: Error Handling - Null Request Body

```bash
curl -X POST http://localhost:8088/api/v1/vehicles \
  -H "Content-Type: application/json" \
  -d 'null'
```

### Expected Response (400):

```json
{
  "success": false,
  "errorMessage": "Request body cannot be null",
  "overallMessage": "Vehicle registration and pricing creation failed"
}
```

---

## 📮 Test 6: Error Handling - Missing Required Fields

```bash
curl -X POST http://localhost:8088/api/v1/vehicles \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "550e8400-e29b-41d4-a716-446655440000"
  }'
```

### Expected Response (400):

```json
{
  "success": false,
  "errorMessage": "Invalid input provided",
  "overallMessage": "Vehicle registration and pricing creation failed"
}
```

---

## 📮 Test 7: Error Handling - Service Unavailable

### Stop Vehicle Service first:

```bash
docker-compose stop vehicle-service
```

### Then try to register:

```bash
curl -X POST http://localhost:8088/api/v1/vehicles \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "550e8400-e29b-41d4-a716-446655440000",
    "vehicleId": "660e8400-e29b-41d4-a716-446655440111",
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

### Expected Response (500):

```json
{
  "success": false,
  "errorMessage": "Failed to connect to Vehicle Service",
  "overallMessage": "An unexpected error occurred"
}
```

### Restart Vehicle Service:

```bash
docker-compose up -d vehicle-service
```

---

## 🔵 Postman Collection

### Create a new Postman Collection:

#### Request 1: Register Vehicle with Pricing

```
POST http://localhost:8088/api/v1/vehicles
Content-Type: application/json

Body (raw JSON):
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "vehicleId": "660e8400-e29b-41d4-a716-446655440111",
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

#### Request 2: Health Check - Owner BFF

```
GET http://localhost:8088/actuator/health
```

#### Request 3: Health Check - Vehicle Service

```
GET http://localhost:8087/actuator/health
```

#### Request 4: Health Check - Pricing Service

```
GET http://localhost:8085/actuator/health
```

#### Request 5: Check Service Registry (Eureka)

```
GET http://localhost:8761/eureka/apps
```

---

## 📊 Service Communication Flow (with timing)

```
Timeline:
─────────────────────────────────────────────────────────────

1. Client sends request
   Time: T+0ms
   Owner BFF receives POST /api/v1/vehicles

2. Validation
   Time: T+5ms
   Owner BFF validates VehicleWithPricingDto

3. Get token from Keycloak
   Time: T+10ms → T+500ms
   ServiceTokenService.getAccessToken()
   Network delay to Keycloak: ~400ms

4. Call Vehicle Service
   Time: T+510ms → T+1200ms
   VehicleServiceClient.registerVehicle()
   Vehicle Service processes: ~500ms
   Database insert: ~190ms

5. Get OwnerHasVehicle ID
   Time: T+1200ms
   Extract ID from response: ~10ms

6. Get token (reuse or new)
   Time: T+1210ms
   Token still valid (5 minute expiry), reuse: ~5ms

7. Call Pricing Service
   Time: T+1215ms → T+1800ms
   PriceServiceClient.createPrice()
   Pricing Service processes: ~500ms
   Database insert: ~85ms

8. Build response
   Time: T+1810ms → T+1820ms
   Combine vehicle and pricing responses

9. Return to client
   Time: T+1820ms
   Total time: ~1.8 seconds

─────────────────────────────────────────────────────────────
Total Time: ~1800ms (1.8 seconds)
```

---

## 📈 Performance Testing

### Test with Load

```bash
#!/bin/bash

# Send 10 concurrent requests
for i in {1..10}; do
  curl -X POST http://localhost:8088/api/v1/vehicles \
    -H "Content-Type: application/json" \
    -d '{
      "userId": "user-'$i'",
      "vehicleId": "vehicle-'$i'",
      "bodyTypeId": "1",
      "availableFrom": "2026-02-01",
      "availableUntil": "2026-12-31",
      "vehicleBodyType": "SUV",
      "currencyCode": "LKR",
      "perDay": 5000.0,
      "perWeek": 30000.0,
      "perMonth": 100000.0
    }' &
done

wait
echo "Load test complete!"
```

---

## 🔍 Debugging Tips

### 1. Check Owner BFF Logs

```bash
docker logs owner-bff -f

# Look for:
# - "Received request to register vehicle with pricing"
# - "Successfully obtained access token"
# - "Vehicle registered successfully"
# - "Pricing created successfully"
```

### 2. Check Vehicle Service Logs

```bash
docker logs vehicle-service -f

# Look for:
# - "Registering new vehicle"
# - "INSERT INTO owners_has_vehicles"
# - "Vehicle saved successfully"
```

### 3. Check Pricing Service Logs

```bash
docker logs pricing-service -f

# Look for:
# - "Creating price for vehicle"
# - "INSERT INTO vehicle_prices"
# - "Pricing saved successfully"
```

### 4. Check Keycloak Logs

```bash
docker logs keycloak -f

# Look for:
# - "Token issued successfully"
# - "Token validation successful"
```

### 5. Check Network Connectivity

```bash
# From Owner BFF container
docker exec owner-bff curl -v http://vehicle-service:8087/actuator/health

# From Owner BFF container to Pricing Service
docker exec owner-bff curl -v http://pricing-service:8085/actuator/health

# From Owner BFF container to Keycloak
docker exec owner-bff curl -v https://auth.rydeflexi.com/
```

---

## ✅ Testing Checklist

- [ ] All services started successfully
- [ ] All services registered in Eureka
- [ ] Keycloak token generation working
- [ ] Vehicle registration test passed
- [ ] Pricing creation test passed
- [ ] Combined operation test passed
- [ ] Error handling (null request) working
- [ ] Error handling (missing fields) working
- [ ] Service unavailability handling working
- [ ] Response mapping correct
- [ ] Database inserts verified
- [ ] Logs show correct flow
- [ ] Performance acceptable (<2 seconds)
- [ ] Load test successful

---

## 🎯 Next Steps

1. **Verify data in databases:**
   ```bash
   # Connect to vehicle database
   psql -h localhost -p 5437 -U vehicleservice -d vehicledb
   SELECT * FROM owners_has_vehicles;
   
   # Connect to pricing database
   psql -h localhost -p 5435 -U pricingservice -d pricingdb
   SELECT * FROM vehicle_prices;
   ```

2. **Monitor Swagger UI:**
   - Owner BFF: http://localhost:8088/swagger-ui.html
   - Vehicle Service: http://localhost:8087/swagger-ui.html
   - Pricing Service: http://localhost:8085/swagger-ui.html

3. **Check Metrics:**
   - http://localhost:8088/actuator/metrics
   - http://localhost:8087/actuator/metrics
   - http://localhost:8085/actuator/metrics

