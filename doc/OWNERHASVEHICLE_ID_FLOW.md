# OwnerHasVehicle ID Flow - Quick Reference
## The Key Concept
**The `OwnerHasVehicle.id` from vehicle-service becomes the `vehicle_price.vehicle_id` in pricing-service**
This ensures each owner-vehicle relationship has unique pricing.
## Flow Diagram
```
1. Owner-BFF receives request
   ↓
2. Vehicle-Service creates OwnersHasVehicle record
   → Returns: { id: "abc-123", ownerId: "user-456", vehicleId: "vehicle-789" }
   ↓
3. Owner-BFF extracts OwnerHasVehicle.id = "abc-123"
   ↓
4. Owner-BFF calls Pricing-Service with:
   { userId: "user-456", vehicleId: "abc-123", perDay: 100 }
                                      ^^^^^^^^
                                      This is OwnerHasVehicle.id!
   ↓
5. Pricing-Service stores:
   vehicle_price.vehicle_id = "abc-123"
```
## Code Path
### 1. VehicleRegistrationWithPricingService.java (lines 56-64)
```java
// Step 1: Register vehicle
VehicleRegistrationResponseDto vehicleResponse = registerVehicle(vehicleWithPricingDto);
// Step 2: Extract OwnerHasVehicle ID
UUID ownerHasVehicleId = vehicleResponse.getId();  // ← THE KEY LINE!
log.info("OwnerHasVehicle ID: {}", ownerHasVehicleId);
// Step 3: Create pricing using OwnerHasVehicle ID
VehiclePriceDto pricingResponse = createPricing(vehicleWithPricingDto, ownerHasVehicleId.toString());
```
### 2. VehicleWithPricingDto.java (line 116)
```java
public VehiclePriceDto toPricingDto(String ownerHasVehicleId) {
    return VehiclePriceDto.builder()
            .userId(this.userId)
            .vehicleId(ownerHasVehicleId)  // ← Uses OwnerHasVehicle ID, not Vehicle ID!
            .vehicleBodyType(this.vehicleBodyType)
            .perDay(this.perDay)
            .perWeek(this.perWeek)
            .perMonth(this.perMonth)
            .build();
}
```
### 3. VehicleRegisterController.java (vehicle-service)
```java
@PostMapping
public ResponseEntity<VehicleRegistrationResponse> registerVehicle(...) {
    CommonResponse response = vehicleRegisterService.registerVehicleToOwners(registeringDto);
    OwnersHasVehicle ownersHasVehicle = (OwnersHasVehicle) response.getData();
    return ResponseEntity.ok(VehicleRegistrationResponse.builder()
        .id(ownersHasVehicle.getId())  // ← Returns OwnerHasVehicle ID
        .ownerId(ownersHasVehicle.getOwner().getId())
        .vehicleId(ownersHasVehicle.getVehicle().getId())
        .build());
}
```
### 4. PriceService.java (pricing-service, line 81)
```java
VehiclePrice vehiclePrice = vehiclePriceRepository.save(
    VehiclePrice.builder()
        .userId(requestDto.userId())
        .vehicleId(requestDto.vehicleId())  // ← Stores OwnerHasVehicle ID
        .priceRange(priceRange)
        .build()
);
```
## Database Verification
### Check the relationship
```sql
-- Vehicle Service DB
SELECT id as owner_has_vehicle_id, owner_id, vehicle_id 
FROM owners_has_vehicle 
WHERE owner_id = 'user-456';
-- Result: owner_has_vehicle_id = 'abc-123'
-- Pricing Service DB
SELECT id, user_id, vehicle_id 
FROM vehicle_price 
WHERE user_id = 'user-456';
-- Result: vehicle_id = 'abc-123' (matches OwnerHasVehicle.id!)
```
## Why This Matters
### ❌ Wrong Approach (using Vehicle.id):
```
Owner A registers Toyota Camry → Vehicle.id = "vehicle-789"
Owner B registers Toyota Camry → Vehicle.id = "vehicle-789"
Both share same pricing! ❌
```
### ✅ Correct Approach (using OwnerHasVehicle.id):
```
Owner A registers Toyota Camry → OwnerHasVehicle.id = "abc-123"
Owner B registers Toyota Camry → OwnerHasVehicle.id = "xyz-456"
Each has unique pricing! ✅
```
## Current Implementation Status
✅ VehicleWithPricingDto.toPricingDto() uses ownerHasVehicleId parameter  
✅ VehicleRegistrationWithPricingService extracts OwnerHasVehicle ID  
✅ VehicleRegisterController returns OwnerHasVehicle ID  
✅ PriceService stores OwnerHasVehicle ID as vehicle_id  
**Everything is correctly implemented!**
