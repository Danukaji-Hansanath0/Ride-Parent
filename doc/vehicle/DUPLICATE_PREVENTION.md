# Vehicle Service - Duplicate Prevention System

## Overview

The Vehicle Service implements a comprehensive duplicate prevention system to ensure that:
- **Makes** (e.g., Toyota, Honda) are never duplicated
- **Models** (e.g., Camry, Accord) are never duplicated for the same make
- **Vehicles** are never duplicated for the same make/model/year/color combination

## Architecture

### Database Level Protection

#### 1. Makes Table
```sql
-- Unique constraint on make name
ALTER TABLE makes ADD CONSTRAINT uk_makes_name UNIQUE (name);
```

- **Column**: `name` (VARCHAR(100))
- **Constraint**: UNIQUE
- **Protection**: Database-level duplicate prevention

#### 2. Car Models Table
```sql
-- Unique constraint on model name + make combination
ALTER TABLE car_models ADD CONSTRAINT uk_model_name_make UNIQUE (name, make_id);
```

- **Columns**: `name` (VARCHAR(100)) + `make_id` (Foreign Key)
- **Constraint**: UNIQUE on combination
- **Protection**: Same model name can exist for different makes, but not duplicated within the same make

#### 3. Vehicles Table
The vehicle table uses repository methods to check for duplicates before insertion.

### Application Level Protection

#### Repository Layer

**MakesRepository**
```java
Optional<Makes> findByName(String name);
```
- Retrieves existing make by name
- Returns `Optional.empty()` if not found

**CarModelsRepository**
```java
Optional<CarModels> findByNameAndMake(String name, Makes make);
```
- Retrieves existing model by name and make
- Returns `Optional.empty()` if not found

**VehicleRepository**
```java
Optional<Vehicle> findByMakeAndModelAndYearAndColor(Makes make, CarModels model, String year, String color);
```
- Retrieves existing vehicle by make, model, year, and color
- Returns `Optional.empty()` if not found

#### Service Layer

### 1. Make Service (`MakeServiceImpl`)

#### `getOrCreateMake(String name)`
**Duplicate Prevention Strategy:**
```
1. Check database for existing make
   └─ If found: Return existing make (no duplication)
   └─ If not found:
      2. Fetch from external API
      3. Double-check database (race condition prevention)
      4. Create new make only if still not found
```

**Code Flow:**
```java
// Step 1: Check existing
Optional<Makes> existingMake = makesRepository.findByName(name);
if (existingMake.isPresent()) {
    return existingMake; // No duplication
}

// Step 2: Fetch from API
// ... API call ...

// Step 3: Double-check (race condition protection)
Optional<Makes> raceCheck = makesRepository.findByName(makeName);
if (raceCheck.isPresent()) {
    return raceCheck; // Another thread created it
}

// Step 4: Create only if still not found
Makes newMake = makesRepository.save(newMake);
```

#### `syncMakesFromApi()`
**Bulk Sync with Duplicate Prevention:**
```
For each make from API:
1. Check if make exists in database
   └─ If exists: Skip creation, use existing
   └─ If not exists: Create new make
2. Track statistics (new vs existing)
```

### 2. Model Service (`ModelServiceImpl`)

#### `getOrCreateModel(String modelName, String makeName)`
**Duplicate Prevention Strategy:**
```
1. Get or create make (prevents duplicate makes)
2. Check database for existing model for this make
   └─ If found: Return existing model (no duplication)
   └─ If not found:
      3. Fetch from external API
      4. Double-check database (race condition prevention)
      5. Create new model only if still not found
```

**Code Flow:**
```java
// Step 1: Ensure make exists (no duplicate makes)
Makes make = makesRepository.findByName(makeName)
    .orElseGet(() -> makesRepository.save(new Make(makeName)));

// Step 2: Check existing model
Optional<CarModels> existingModel = carModelsRepository.findByNameAndMake(modelName, make);
if (existingModel.isPresent()) {
    return existingModel; // No duplication
}

// Step 3: Fetch from API
// ... API call ...

// Step 4: Double-check (race condition protection)
Optional<CarModels> raceCheck = carModelsRepository.findByNameAndMake(apiModelName, make);
if (raceCheck.isPresent()) {
    return raceCheck; // Another thread created it
}

// Step 5: Create only if still not found
CarModels newModel = carModelsRepository.save(newModel);
```

#### `syncModelsFromApi(String makeName)`
**Bulk Sync with Duplicate Prevention:**
```
1. Get or create make (prevents duplicate makes)
2. For each model from API:
   - Check if model exists for this make
   - If exists: Skip creation, use existing
   - If not exists: Create new model
3. Track statistics (new vs existing)
```

### 3. Vehicle Service (`VehicleServiceImpl`)

#### `createVehicle(VehicleDto vehicleDto)`
**Duplicate Prevention Strategy:**
```
1. Get or create make (prevents duplicate makes)
2. Get or create model (prevents duplicate models)
3. Check if vehicle exists with same make/model/year/color
   └─ If found: Return existing vehicle (no duplication)
   └─ If not found: Create new vehicle
```

**Code Flow:**
```java
// Step 1: Ensure make exists (no duplicate makes)
Makes make = makesRepository.findByName(makeName)
    .orElseGet(() -> makesRepository.save(new Make(makeName)));

// Step 2: Ensure model exists (no duplicate models)
CarModels model = carModelsRepository.findByNameAndMake(modelName, make)
    .orElseGet(() -> carModelsRepository.save(new Model(modelName, make)));

// Step 3: Check for existing vehicle
if (color != null) {
    Optional<Vehicle> existing = vehicleRepository
        .findByMakeAndModelAndYearAndColor(make, model, year, color);
    if (existing.isPresent()) {
        return existing; // No duplication
    }
}

// Step 4: Create only if not found
Vehicle newVehicle = vehicleRepository.save(vehicle);
```

#### `syncVehicleFromApi(String make, String model, String year)`
**API Sync with Duplicate Prevention:**
```
1. Fetch vehicle data from external API
2. Get or create make (prevents duplicate makes)
3. Get or create model (prevents duplicate models)
4. Create vehicle with API data
```

#### `importVehiclesAsync(String make, String model, String year)`
**Bulk Import with Duplicate Prevention:**
```
1. Get or create make (prevents duplicate makes)
2. Get or create model (prevents duplicate models)
3. Fetch vehicle data from API once
4. For each color variant:
   - Check if vehicle exists for this color
   - If exists: Skip creation, use existing
   - If not exists: Create new vehicle
5. Return all vehicles (existing + newly created)
6. Track statistics (new vs existing)
```

## Benefits

### 1. Data Integrity
- No duplicate makes in database
- No duplicate models per make
- No duplicate vehicles per make/model/year/color

### 2. Performance
- Reduces database storage
- Faster queries (no duplicate results)
- Efficient caching possible

### 3. Consistency
- Single source of truth for each make/model
- Consistent vehicle data across the system

### 4. API Efficiency
- Reduces API calls (check database first)
- Bulk sync operations are idempotent (can be run multiple times safely)

### 5. Concurrent Safety
- Race condition prevention with double-check pattern
- Database constraints as final safety net

## Usage Examples

### Example 1: Creating a Vehicle
```java
// Request 1: Create Toyota Camry 2023
VehicleDto vehicle1 = vehicleService.createVehicle(
    new VehicleDto("Toyota", "Camry", "2023", "white")
);
// Result: Creates new make "Toyota", new model "Camry", new vehicle

// Request 2: Create Toyota Corolla 2023
VehicleDto vehicle2 = vehicleService.createVehicle(
    new VehicleDto("Toyota", "Corolla", "2023", "blue")
);
// Result: Reuses existing make "Toyota", creates new model "Corolla", new vehicle

// Request 3: Create Toyota Camry 2023 (duplicate attempt)
VehicleDto vehicle3 = vehicleService.createVehicle(
    new VehicleDto("Toyota", "Camry", "2023", "white")
);
// Result: Returns existing vehicle, no duplication
```

### Example 2: Syncing from API
```java
// First sync
List<MakeDto> makes1 = makeService.syncMakesFromApi();
// Result: Creates 50 makes (new: 50, existing: 0)

// Second sync (idempotent)
List<MakeDto> makes2 = makeService.syncMakesFromApi();
// Result: Returns 50 makes (new: 0, existing: 50)
```

### Example 3: Async Import
```java
// First import
CompletableFuture<List<VehicleDto>> future1 = 
    vehicleService.importVehiclesAsync("Honda", "Accord", "2023");
// Result: Creates 3 vehicles (one per color: white, blue, red)

// Second import (idempotent)
CompletableFuture<List<VehicleDto>> future2 = 
    vehicleService.importVehiclesAsync("Honda", "Accord", "2023");
// Result: Returns 3 existing vehicles, no duplication
```

## Testing Duplicate Prevention

### Unit Tests
```java
@Test
void testMakeNotDuplicated() {
    // Create make twice
    MakeDto make1 = makeService.getOrCreateMake("Toyota");
    MakeDto make2 = makeService.getOrCreateMake("Toyota");
    
    // Assert same ID (no duplication)
    assertEquals(make1.getId(), make2.getId());
}

@Test
void testModelNotDuplicated() {
    // Create model twice for same make
    ModelDto model1 = modelService.getOrCreateModel("Camry", "Toyota");
    ModelDto model2 = modelService.getOrCreateModel("Camry", "Toyota");
    
    // Assert same ID (no duplication)
    assertEquals(model1.getId(), model2.getId());
}

@Test
void testVehicleNotDuplicated() {
    // Create vehicle twice
    VehicleDto v1 = vehicleService.createVehicle(
        new VehicleDto("Toyota", "Camry", "2023", "white")
    );
    VehicleDto v2 = vehicleService.createVehicle(
        new VehicleDto("Toyota", "Camry", "2023", "white")
    );
    
    // Assert same ID (no duplication)
    assertEquals(v1.getId(), v2.getId());
}
```

### Integration Tests
```java
@Test
void testConcurrentMakeCreation() {
    // Simulate concurrent requests
    ExecutorService executor = Executors.newFixedThreadPool(10);
    List<Future<MakeDto>> futures = new ArrayList<>();
    
    for (int i = 0; i < 10; i++) {
        futures.add(executor.submit(() -> 
            makeService.getOrCreateMake("Toyota")
        ));
    }
    
    // Wait for all threads
    Set<Long> ids = futures.stream()
        .map(f -> f.get().getId())
        .collect(Collectors.toSet());
    
    // Assert only one make created
    assertEquals(1, ids.size());
}
```

## Monitoring and Logging

The system logs duplicate prevention actions:

```
INFO  - Make 'Toyota' found in database, returning existing record
INFO  - Model 'Camry' for make 'Toyota' found in database, returning existing record
INFO  - Vehicle already exists: make=Toyota, model=Camry, year=2023, color=white, id=abc-123
INFO  - Successfully synced 50 makes from API (New: 10, Existing: 40)
INFO  - Successfully synced 200 models for make 'Toyota' (New: 50, Existing: 150)
INFO  - Async import completed: 3 total vehicles (New: 1, Existing: 2)
```

## Troubleshooting

### Issue: Duplicate Makes/Models in Database
**Cause**: Database created before unique constraints were added
**Solution**: 
1. Run data cleanup script to merge duplicates
2. Add unique constraints
3. Restart application

### Issue: Concurrent Creation Failures
**Cause**: Race condition between threads
**Solution**: Already handled by double-check pattern in service layer

### Issue: API Sync Creating Duplicates
**Cause**: Case sensitivity mismatch (e.g., "Toyota" vs "TOYOTA")
**Solution**: Use case-insensitive comparison in repository queries

## Future Enhancements

1. **Soft Delete**: Add deleted flag instead of hard delete to maintain referential integrity
2. **Audit Trail**: Track creation/modification history for makes and models
3. **Batch Processing**: Optimize bulk operations with batch inserts
4. **Cache Layer**: Add Redis cache for frequently accessed makes/models
5. **Event Sourcing**: Emit events when makes/models are created for other services

---

**Last Updated**: January 16, 2026
**Version**: 1.0.0
