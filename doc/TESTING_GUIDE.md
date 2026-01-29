# Testing Guide for Vehicle Registration with Pricing

## Quick Start

### Prerequisites
1. All required services must be running:
   - Discovery Service (port 8761)
   - Vehicle Service (port 8087)
   - Pricing Service (port 8085)
   - Owner BFF (port 8088)
   - Auth Service (port 8081)

2. You need a valid authentication token

### Running the Automated Test

```bash
# Make the script executable
chmod +x test-ownerhasvehicle-flow.sh

# Get your auth token first
export AUTH_TOKEN="your-jwt-token-here"

# Run the test
./test-ownerhasvehicle-flow.sh
```

The script will:
1. ✅ Check all services are running
2. ✅ Generate valid UUIDs for testing
3. ✅ Register a vehicle with pricing
4. ✅ Verify the OwnerHasVehicle ID is used in pricing
5. ✅ Display complete test results

---

## Manual Testing

### ⚠️ IMPORTANT: UUID Format Requirement

Both `userId` and `vehicleId` **MUST** be valid UUIDs (format: `xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx`).

**❌ WRONG:**
```json
{
  "userId": "1233",           // Invalid: not a UUID
  "vehicleId": "abc-123"      // Invalid: not a UUID
}
```

**✅ CORRECT:**
```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",
  "vehicleId": "4d620334-cc5e-47ed-b417-27b0b4f913a3"
}
```

### Generating UUIDs

**Linux/Mac:**
```bash
uuidgen
# Output: 550e8400-e29b-41d4-a716-446655440000
```

**Online:**
- https://www.uuidgenerator.net/
- https://www.guidgenerator.com/

**Programming:**
- Java: `UUID.randomUUID().toString()`
- Python: `import uuid; str(uuid.uuid4())`
- JavaScript: `crypto.randomUUID()` or use npm package `uuid`

---

## Test Endpoint

### Register Vehicle with Pricing

**Endpoint:** `POST /api/v1/owner/vehicles/register-with-pricing`

**Headers:**
```
Content-Type: application/json
Authorization: Bearer YOUR_JWT_TOKEN
```

**Request Body:**
```json
{
  "userId": "550e8400-e29b-41d4-a716-446655440000",      // MUST be UUID
  "vehicleId": "4d620334-cc5e-47ed-b417-27b0b4f913a3",   // MUST be UUID
  "bodyTypeId": "1",
  "vehicleBodyType": "SUV",
  "availableFrom": "2024-01-01",
  "availableUntil": "2024-12-31",
  "currencyCode": "USD",
  "perDay": 50.00,
  "perWeek": 300.00,
  "perMonth": 1000.00
}
```

**Success Response (200 OK):**
```json
{
  "success": true,
  "ownerHasVehicleId": "abc12345-6789-...",    // This ID is used in pricing
  "pricingId": "def67890-1234-...",
  "vehicleRegistrationMessage": "Vehicle registered successfully",
  "pricingCreationMessage": "Pricing created successfully",
  "overallMessage": "Vehicle registered and pricing created successfully"
}
```

**Error Response (400 Bad Request) - Invalid UUID:**
```json
{
  "timestamp": "2026-01-22T16:14:04.614Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Invalid owner ID format. Expected UUID format (e.g., '123e4567-e89b-12d3-a456-426614174000'), but got: '1233'. Please provide a valid UUID."
}
```

---

## Complete cURL Example

### 1. Generate UUIDs
```bash
USER_ID=$(uuidgen)
VEHICLE_ID=$(uuidgen)

echo "User ID: $USER_ID"
echo "Vehicle ID: $VEHICLE_ID"
```

### 2. Get Auth Token
```bash
# Login to get token
TOKEN_RESPONSE=$(curl -s -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "owner@example.com",
    "password": "Password123!"
  }')

# Extract token
AUTH_TOKEN=$(echo $TOKEN_RESPONSE | jq -r '.token')
```

### 3. Register Vehicle with Pricing
```bash
curl -X POST http://localhost:8088/api/v1/owner/vehicles/register-with-pricing \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d "{
    \"userId\": \"${USER_ID}\",
    \"vehicleId\": \"${VEHICLE_ID}\",
    \"bodyTypeId\": \"1\",
    \"vehicleBodyType\": \"SUV\",
    \"availableFrom\": \"2024-01-01\",
    \"availableUntil\": \"2024-12-31\",
    \"currencyCode\": \"USD\",
    \"perDay\": 50.00,
    \"perWeek\": 300.00,
    \"perMonth\": 1000.00
  }" | jq '.'
```

---

## Common Errors and Solutions

### Error: "Invalid owner ID format"

**Cause:** `userId` is not a valid UUID

**Solution:** 
```bash
# Generate a valid UUID
USER_ID=$(uuidgen)
echo "Use this UUID: $USER_ID"
```

### Error: "Invalid vehicle ID format"

**Cause:** `vehicleId` is not a valid UUID

**Solution:**
```bash
# Generate a valid UUID
VEHICLE_ID=$(uuidgen)
echo "Use this UUID: $VEHICLE_ID"
```

### Error: "401 Unauthorized"

**Cause:** Missing or invalid authentication token

**Solution:**
1. Login to get a fresh token
2. Set the Authorization header: `Authorization: Bearer YOUR_TOKEN`

### Error: "Failed to resolve 'vehicle-service'"

**Cause:** Services are not registered with Eureka Discovery

**Solution:**
1. Ensure Discovery Service is running (port 8761)
2. Wait 30-60 seconds for services to register
3. Check: http://localhost:8761

---

## Verifying Results

### 1. Check Vehicle Registration
```bash
# Query vehicle service (requires service-to-service auth)
curl -X GET "http://localhost:8087/api/v1/vehicles/owners/${USER_ID}" \
  -H "Authorization: Bearer ${SERVICE_TOKEN}"
```

### 2. Check Pricing
```bash
# Query pricing service
curl -X GET "http://localhost:8085/api/v1/price/owners/${USER_ID}/vehicles/${OWNER_HAS_VEHICLE_ID}?page=0&size=10" \
  -H "Authorization: Bearer ${AUTH_TOKEN}"
```

### 3. Verify Database (PostgreSQL)

**Vehicle Service Database:**
```sql
-- Check owners_has_vehicle table
SELECT ohv.id, ohv.owner_id, ohv.vehicle_id, ohv.status, bt.name as body_type
FROM owners_has_vehicle ohv
LEFT JOIN body_types bt ON ohv.body_type_id = bt.id
WHERE ohv.owner_id = 'YOUR-USER-UUID';
```

**Pricing Service Database:**
```sql
-- Check vehicle_prices table
SELECT vp.id, vp.vehicle_id, vp.owner_id, 
       pr.per_day, pr.per_week, pr.per_month,
       pr.currency_code
FROM vehicle_prices vp
JOIN price_ranges pr ON vp.price_range_id = pr.id
WHERE vp.owner_id = 'YOUR-USER-UUID';
```

**Key Verification:**
- The `owners_has_vehicle.id` from Vehicle Service
- Should match `vehicle_prices.vehicle_id` in Pricing Service
- This ensures pricing is linked to the owner-vehicle relationship

---

## Flow Diagram

```
┌─────────────┐
│  Client/UI  │
└──────┬──────┘
       │ POST /register-with-pricing
       │ {userId: UUID, vehicleId: UUID, pricing: {...}}
       v
┌──────────────────┐
│   Owner BFF      │
│   (port 8088)    │
└────────┬─────────┘
         │
         │ 1. Register Vehicle
         │    {userId, vehicleId, bodyTypeId, ...}
         v
┌──────────────────────┐
│  Vehicle Service     │
│   (port 8087)        │
│                      │
│ Creates:             │
│  - VehicleOwners     │
│  - Vehicle           │
│  - OwnersHasVehicle  │◄─── Returns OwnerHasVehicle.id
└──────────────────────┘
         │
         │ 2. Create Pricing
         │    {vehicleId: OwnerHasVehicle.id, pricing: {...}}
         v
┌──────────────────────┐
│  Pricing Service     │
│   (port 8085)        │
│                      │
│ Creates:             │
│  - PriceRange        │
│  - VehiclePrice      │
│    (vehicleId =      │
│     OwnerHasVehicle  │
│     .id)             │
└──────────────────────┘
```

---

## Troubleshooting

### Check Service Health
```bash
# Discovery Service
curl http://localhost:8761/actuator/health

# Vehicle Service
curl http://localhost:8087/actuator/health

# Pricing Service
curl http://localhost:8085/actuator/health

# Owner BFF
curl http://localhost:8088/actuator/health
```

### Check Service Registration
```bash
# Open Eureka Dashboard
open http://localhost:8761
```

### Enable Debug Logging

**Vehicle Service (`application.yml`):**
```yaml
logging:
  level:
    com.ride.vehicleservice: DEBUG
```

**Pricing Service (`application.yml`):**
```yaml
logging:
  level:
    com.ride.pricingservice: DEBUG
```

**Owner BFF (`application.yml`):**
```yaml
logging:
  level:
    com.ride.ownerbff: DEBUG
```

---

## Additional Resources

- **Main Documentation:** `OWNERHASVEHICLE_PRICING_FLOW.md`
- **Implementation Summary:** `IMPLEMENTATION_COMPLETE_SUMMARY.md`
- **Flow Verification:** `OWNERHASVEHICLE_FLOW_VERIFICATION.md`

---

## Support

If you encounter issues not covered here:

1. Check service logs for detailed error messages
2. Verify all services are running and registered with Eureka
3. Ensure you're using valid UUIDs for userId and vehicleId
4. Verify your authentication token is valid and not expired
5. Check database connections and schemas are correct
