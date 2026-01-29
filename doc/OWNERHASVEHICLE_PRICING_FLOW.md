# OwnerHasVehicle ID to Pricing Service Flow

## Overview

This document explains how the `OwnerHasVehicle` ID from the vehicle service is used as the `vehicleId` in the pricing service. This design ensures that pricing is tied to the specific owner-vehicle relationship, not just the vehicle itself.

## Architecture Flow

```
┌─────────────┐         ┌──────────────┐         ┌──────────────┐         ┌──────────────┐
│   Client    │────────▶│  Owner BFF   │────────▶│   Vehicle    │────────▶│   Pricing    │
│             │         │              │         │   Service    │         │   Service    │
└─────────────┘         └──────────────┘         └──────────────┘         └──────────────┘
      │                        │                         │                        │
      │  POST /register        │                         │                        │
      │  with pricing          │                         │                        │
      │───────────────────────▶│                         │                        │
      │                        │                         │                        │
      │                        │  1. Register Vehicle    │                        │
      │                        │  POST /register         │                        │
      │                        │────────────────────────▶│                        │
      │                        │                         │                        │
      │                        │  Returns:               │                        │
      │                        │  - OwnerHasVehicle ID   │                        │
      │                        │  - Owner ID             │                        │
      │                        │  - Vehicle ID           │                        │
      │                        │◀────────────────────────┤                        │
      │                        │                         │                        │
      │                        │  2. Create Pricing                               │
      │                        │  POST /api/v1/price                              │
      │                        │  vehicleId = OwnerHasVehicle ID                  │
      │                        │─────────────────────────────────────────────────▶│
      │                        │                                                  │
      │                        │  Stores pricing with OwnerHasVehicle ID          │
      │                        │◀─────────────────────────────────────────────────┤
      │                        │                                                  │
      │  Combined Response     │                                                  │
      │◀───────────────────────┤                                                  │
      │                        │                                                  │
```

## Database Schema Relationship

### Vehicle Service - owners_has_vehicle Table
```sql
CREATE TABLE owners_has_vehicle (
    id UUID PRIMARY KEY,                    -- This ID is used in pricing service
    owner_id UUID REFERENCES owners(id),
    vehicle_id UUID REFERENCES vehicles(id),
    status VARCHAR(20),
    body_type_id BIGINT,
    available_from DATE,
    available_until DATE,
    created_at TIMESTAMP
);
```

### Pricing Service - vehicle_prices Table
```sql
CREATE TABLE vehicle_prices (
    id UUID PRIMARY KEY,
    vehicle_id VARCHAR(255) NOT NULL,       -- This stores the OwnerHasVehicle ID
    user_id VARCHAR(255) NOT NULL,
    price_range_id UUID,
    discount_id UUID,
    created_at TIMESTAMP
);
```

**Important:** The `vehicle_id` column in `vehicle_prices` table stores the `id` from `owners_has_vehicle` table, NOT the `id` from the `vehicles` table.

## Implementation Details

### 1. Vehicle Service - Returns OwnerHasVehicle ID

**File:** `vehicle-service/src/main/java/com/ride/vehicleservice/controller/VehicleRegisterController.java`

```java
@PostMapping
public ResponseEntity<VehicleRegistrationResponse> registerVehicle(@RequestBody VehicleRegisteringDto registeringDto) {
    log.info("Registering vehicle for userId: {}, vehicleId: {}", 
             registeringDto.getUserId(), registeringDto.getVehicleId());

    CommonResponse response = vehicleRegisterService.registerVehicleToOwners(registeringDto);

    if (response.getData() == null) {
        return ResponseEntity.badRequest().body(/* error response */);
    }

    // Extract OwnersHasVehicle from response data
    OwnersHasVehicle ownersHasVehicle = (OwnersHasVehicle) response.getData();

    // Build response DTO with OwnerHasVehicle ID for pricing service
    VehicleRegistrationResponse responseDto = VehicleRegistrationResponse.builder()
        .id(ownersHasVehicle.getId())              // ✅ OwnerHasVehicle ID
        .ownerId(ownersHasVehicle.getOwner().getId())
        .vehicleId(ownersHasVehicle.getVehicle().getId())
        .status(ownersHasVehicle.getStatus().name())
        .bodyType(ownersHasVehicle.getBodyType().getName())
        .message(response.getMessage())
        .build();

    log.info("Vehicle registered successfully. OwnerHasVehicleId: {}", ownersHasVehicle.getId());

    return ResponseEntity.ok(responseDto);
}
```

**Key Point:** The `id` field in the response contains the `OwnerHasVehicle` ID, which is what the pricing service needs.

### 2. Owner BFF - Orchestrates the Flow

**File:** `owner-bff/src/main/java/com/ride/ownerbff/service/impl/VehicleRegistrationWithPricingService.java`

```java
@Override
public VehicleRegistrationWithPricingResponseDto registerVehicleWithPricing(
        VehicleWithPricingDto vehicleWithPricingDto) {

    // Step 1: Register vehicle and get OwnerHasVehicle ID
    VehicleRegistrationResponseDto vehicleResponse = registerVehicle(vehicleWithPricingDto);

    if (vehicleResponse == null || vehicleResponse.getId() == null) {
        return buildFailureResponse("Vehicle registration failed: No OwnerHasVehicle ID returned");
    }

    log.info("Vehicle registered successfully with OwnerHasVehicleId: {}", vehicleResponse.getId());

    // Step 2: Create pricing using the OwnerHasVehicle ID
    VehiclePriceDto pricingResponse = createPricing(
        vehicleWithPricingDto, 
        vehicleResponse.getId().toString()  // ✅ Using OwnerHasVehicle ID
    );

    // Step 3: Build combined response
    return buildSuccessResponse(vehicleResponse, pricingResponse);
}
```

**File:** `owner-bff/src/main/java/com/ride/ownerbff/dto/VehicleWithPricingDto.java`

```java
/**
 * Creates a VehiclePriceDto using the provided OwnerHasVehicle ID.
 */
public VehiclePriceDto toPricingDto(String ownerHasVehicleId) {
    return VehiclePriceDto.builder()
            .userId(this.userId)
            .vehicleId(ownerHasVehicleId)  // ✅ Use OwnerHasVehicle ID as vehicleId
            .vehicleBodyType(this.vehicleBodyType)
            .currencyCode(this.currencyCode)
            .perDay(this.perDay)
            .perWeek(this.perWeek)
            .perMonth(this.perMonth)
            .build();
}
```

### 3. Pricing Service - Stores with OwnerHasVehicle ID

**File:** `pricing-service/src/main/java/com/ride/pricingservice/service/impl/PriceService.java`

```java
@Override
@Transactional
public VehiclePriceDto addPrice(PriceRequestDto requestDto) {
    try {
        String bodyTypeIdOrName = requestDto.vehicleBodyType();
        double percentage = commissionRepository.findCommissionByVehicleTypeId(bodyTypeIdOrName);

        double perDayPrice = applyCommission(percentage, requestDto.perDay());
        double perWeekPrice = applyCommission(percentage, requestDto.perWeek());
        double perMonthPrice = applyCommission(percentage, requestDto.perMonth());

        PriceRange priceRange = priceRangeRepository.save(
                PriceRange.builder()
                        .perDay(perDayPrice)
                        .perWeek(perWeekPrice)
                        .perMonth(perMonthPrice)
                        .build()
        );

        VehiclePrice vehiclePrice = vehiclePriceRepository.save(
                VehiclePrice.builder()
                        .userId(requestDto.userId())
                        .vehicleId(requestDto.vehicleId())  // ✅ This is OwnerHasVehicle ID
                        .priceRange(priceRange)
                        .build()
        );

        return VehiclePriceDto.builder()
                .id(vehiclePrice.getId())
                .discount(null)
                .priceRange(PriceRangeDto.builder()
                        .perDay(priceRange.getPerDay())
                        .perWeek(priceRange.getPerWeek())
                        .perMonth(priceRange.getPerMonth())
                        .build())
                .vehicleId(vehiclePrice.getVehicleId())
                .build();

    } catch (Exception e) {
        log.error("Error while adding vehicle price", e);
        throw new RuntimeException("Error while adding vehicle price", e);
    }
}
```

## API Request/Response Examples

### Request to Owner BFF

**Endpoint:** `POST http://localhost:8088/api/v1/owner/vehicles/register-with-pricing`

**Request Body:**
```json
{
  "userId": "123e4567-e89b-12d3-a456-426614174000",
  "vehicleId": "98765432-e89b-12d3-a456-426614174001",
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

**Response:**
```json
{
  "ownerHasVehicleId": "aaaabbbb-cccc-dddd-eeee-ffffffffffff",
  "ownerId": "123e4567-e89b-12d3-a456-426614174000",
  "vehicleId": "98765432-e89b-12d3-a456-426614174001",
  "vehicleStatus": "AVAILABLE",
  "bodyType": "SUV",
  "vehicleMessage": "Vehicle registered successfully",
  "pricingId": "aaaabbbb-cccc-dddd-eeee-ffffffffffff",
  "perDay": 50.00,
  "perWeek": 300.00,
  "perMonth": 1000.00,
  "currencyCode": "USD",
  "pricingMessage": "Pricing created successfully",
  "overallMessage": "Vehicle registered and pricing created successfully",
  "success": true,
  "errorMessage": null
}
```

### Internal Request to Pricing Service

**Endpoint:** `POST http://localhost:8085/api/v1/price`

**Request Body:**
```json
{
  "userId": "123e4567-e89b-12d3-a456-426614174000",
  "vehicleId": "aaaabbbb-cccc-dddd-eeee-ffffffffffff",  // ✅ OwnerHasVehicle ID
  "vehicleBodyType": "SUV",
  "currencyCode": "USD",
  "perDay": 50.00,
  "perWeek": 300.00,
  "perMonth": 1000.00
}
```

## Benefits of This Design

### 1. **Owner-Specific Pricing**
Multiple owners can have the same vehicle model with different pricing:
- Owner A's Honda Civic: $40/day
- Owner B's Honda Civic: $50/day
- Owner C's Honda Civic: $35/day

### 2. **Clear Ownership Tracking**
The pricing is directly linked to who owns the vehicle, not just what vehicle it is.

### 3. **Flexible Pricing Strategies**
Different owners can:
- Set different prices for the same vehicle type
- Apply different discounts
- Have different availability periods

### 4. **Data Integrity**
The relationship between owner, vehicle, and pricing is maintained through the OwnerHasVehicle ID.

## Querying Prices

### Get Pricing for a Specific Owner's Vehicle

**Endpoint:** `GET /api/v1/price/owners/{userId}/vehicles/{ownerHasVehicleId}?page=0&size=10`

```bash
curl -X GET "http://localhost:8085/api/v1/price/owners/123e4567-e89b-12d3-a456-426614174000/vehicles/aaaabbbb-cccc-dddd-eeee-ffffffffffff?page=0&size=10" \
  -H "Authorization: Bearer ${TOKEN}"
```

**Response:**
```json
{
  "content": [
    {
      "id": "11111111-2222-3333-4444-555555555555",
      "vehicleId": "aaaabbbb-cccc-dddd-eeee-ffffffffffff",
      "discount": null,
      "priceRange": {
        "perDay": 52.50,
        "perWeek": 315.00,
        "perMonth": 1050.00
      }
    }
  ],
  "pageable": {
    "pageNumber": 0,
    "pageSize": 10
  },
  "totalElements": 1,
  "totalPages": 1
}
```

## Testing the Flow

### 1. Start All Services

```bash
# Start Discovery Service
cd discovery-service && mvn spring-boot:run

# Start Vehicle Service
cd vehicle-service && mvn spring-boot:run

# Start Pricing Service
cd pricing-service && mvn spring-boot:run

# Start Owner BFF
cd owner-bff && mvn spring-boot:run
```

### 2. Register a Vehicle with Pricing

```bash
# Get authentication token
TOKEN=$(curl -X POST "http://localhost:8081/api/auth/login" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "owner@example.com",
    "password": "Password123!"
  }' | jq -r '.token')

# Register vehicle with pricing
curl -X POST "http://localhost:8088/api/v1/owner/vehicles/register-with-pricing" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${TOKEN}" \
  -d '{
    "userId": "123e4567-e89b-12d3-a456-426614174000",
    "vehicleId": "98765432-e89b-12d3-a456-426614174001",
    "bodyTypeId": "1",
    "vehicleBodyType": "SUV",
    "availableFrom": "2024-01-01",
    "availableUntil": "2024-12-31",
    "currencyCode": "USD",
    "perDay": 50.00,
    "perWeek": 300.00,
    "perMonth": 1000.00
  }'
```

### 3. Verify in Database

```sql
-- Check the OwnerHasVehicle record in vehicle service database
SELECT id, owner_id, vehicle_id, status 
FROM owners_has_vehicle 
WHERE owner_id = '123e4567-e89b-12d3-a456-426614174000';

-- Check the pricing record in pricing service database
-- Note: vehicle_id here should match the id from owners_has_vehicle
SELECT vp.id, vp.vehicle_id, vp.user_id, pr.per_day, pr.per_week, pr.per_month
FROM vehicle_prices vp
JOIN price_ranges pr ON vp.price_range_id = pr.id
WHERE vp.user_id = '123e4567-e89b-12d3-a456-426614174000';
```

## Troubleshooting

### Issue: Pricing not created

**Check:**
1. Verify the vehicle registration returned an `OwnerHasVehicle` ID
2. Check the Owner BFF logs for the ID being passed to pricing service
3. Verify the pricing service received the correct `vehicleId`

**Logs to check:**
```
owner-bff: "Vehicle registered successfully with OwnerHasVehicleId: aaaabbbb-cccc-dddd-eeee-ffffffffffff"
owner-bff: "Creating pricing for vehicle using OwnerHasVehicleId: aaaabbbb-cccc-dddd-eeee-ffffffffffff"
pricing-service: "Successfully added vehicle price for vehicleId: aaaabbbb-cccc-dddd-eeee-ffffffffffff"
```

### Issue: Wrong vehicleId in pricing

**Symptoms:**
- Pricing uses the `vehicles.id` instead of `owners_has_vehicle.id`
- Multiple owners can't have different prices for the same vehicle

**Solution:**
- Ensure the Owner BFF is using `vehicleResponse.getId()` (which is the OwnerHasVehicle ID)
- Check that `VehicleWithPricingDto.toPricingDto()` is using the `ownerHasVehicleId` parameter

## Summary

✅ **Vehicle Service** creates `OwnersHasVehicle` record and returns its ID
✅ **Owner BFF** receives the `OwnerHasVehicle` ID and passes it to Pricing Service
✅ **Pricing Service** stores pricing with `OwnerHasVehicle` ID as `vehicleId`
✅ **Result:** Pricing is correctly linked to the owner-vehicle relationship

This design ensures that:
- Each owner can set their own prices
- Pricing is tied to ownership, not just the vehicle
- The system supports multiple owners with the same vehicle type
- Data integrity is maintained across services

## Additional Resources

- [Vehicle Service Documentation](./vehicle-service/README.md)
- [Pricing Service Documentation](./pricing-service/README.md)
- [Owner BFF Documentation](./owner-bff/README.md)
- [API Testing Guide](API_TESTING_GUIDE.md)
