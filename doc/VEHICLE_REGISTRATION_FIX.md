# Vehicle Registration Fix - Detached Entity Issue

## Problem
When registering a vehicle with an owner, the system was throwing:
```
org.hibernate.StaleObjectStateException: Row was updated or deleted by another transaction 
(or unsaved-value mapping was incorrect): [com.ride.vehicleservice.model.VehicleOwners#...]
```

## Root Cause
The issue occurred when:
1. Checking if an owner exists using `existsById()`
2. Then fetching the owner using `findById()`
3. This caused Hibernate to treat the entity as detached
4. When trying to save the relationship, Hibernate's merge operation failed

## Solution
Changed from:
```java
// ❌ OLD - Causes detached entity issue
if (!vehicleOwners.existsById(ownerUuid)) {
    owner = vehicleOwners.save(newOwner);
} else {
    owner = vehicleOwners.findById(ownerUuid).orElseThrow();
}
```

To:
```java
// ✅ NEW - Uses proper managed entity
VehicleOwners owner = vehicleOwners.findById(ownerUuid).orElseGet(() -> {
    log.info("Owner not found with ID: {}. Creating new owner record.", ownerUuid);
    VehicleOwners newOwner = VehicleOwners.builder()
            .id(ownerUuid)
            .isFranchiseOwner(false)
            .build();
    VehicleOwners savedOwner = vehicleOwners.save(newOwner);
    log.info("Created new vehicle owner with ID: {}", savedOwner.getId());
    return savedOwner;
});
```

## Benefits
1. **Single Database Query**: Instead of two queries (`existsById` + `findById`), we now use one
2. **No Detached Entities**: Entities are always managed by the persistence context
3. **Cleaner Code**: More idiomatic Java with `orElseGet()` pattern
4. **Transaction Safety**: Avoids optimistic locking issues

## Files Modified
- `/vehicle-service/src/main/java/com/ride/vehicleservice/service/impl/VehicleRegisterService.java`
- `/vehicle-service/src/main/java/com/ride/vehicleservice/repository/OwnersHasVehicleRepository.java`
  - Added `Optional<OwnersHasVehicle> findByOwnerAndVehicle(VehicleOwners owner, Vehicle vehicle)`

## Testing
After this fix, you should be able to:
1. Register a new vehicle with a new owner ✅
2. Register a new vehicle with an existing owner ✅
3. Attempt to register the same vehicle-owner combination (returns existing relationship) ✅

## Flow
```
1. Owner-BFF receives vehicle registration request
   ↓
2. Calls Vehicle-Service register endpoint
   ↓
3. Vehicle-Service:
   - Gets or creates VehicleOwners entity
   - Gets or creates Vehicle entity
   - Checks if relationship exists (returns existing if found)
   - Creates OwnersHasVehicle relationship
   - Returns OwnerHasVehicle ID
   ↓
4. Owner-BFF uses OwnerHasVehicle ID as vehicleId for Pricing-Service
   ↓
5. Pricing-Service stores pricing with OwnerHasVehicle ID
```

## Date: January 22, 2026
