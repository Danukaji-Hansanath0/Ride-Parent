# Vehicle Submodel API Testing Guide

## Quick Start

This guide shows how to test the new submodel integration for the Vehicle Service.

## Prerequisites

1. Vehicle Service running on port 8087
2. External Car API accessible (carapi.app)
3. PostgreSQL database running

## Test Scenarios

### 1. Check API Health

Before testing, verify the external Car API is accessible:

```bash
curl -X GET http://localhost:8087/api/v1/vehicles/makes/api/health
```

**Expected Response:**
```json
{
  "status": "UP",
  "apiAvailable": true
}
```

### 2. Get Vehicle with Specific Year (Database-First)

This will check the database first, then fetch from API if not found:

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles?make=Toyota&model=Avalon&year=2020"
```

**Expected Response (First Call - From API):**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "make": "Toyota",
  "model": "Avalon",
  "submodel": "XSE",
  "year": "2020",
  "transmission": "8-speed automatic",
  "fuelType": "gasoline",
  "seats": 5,
  "doors": 4,
  "drivetrain": "front wheel drive",
  "engineType": "gas"
}
```

**Expected Response (Subsequent Calls - From Database):**
Same as above but retrieved from local database (faster)

### 3. Get Vehicle with Latest Year

When year is not specified, returns the latest available year:

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles?make=Toyota&model=Avalon"
```

**Expected Response:**
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "make": "Toyota",
  "model": "Avalon",
  "submodel": "XSE",
  "year": "2020",
  "transmission": "8-speed automatic",
  "fuelType": "gasoline",
  "seats": 5,
  "doors": 4,
  "drivetrain": "front wheel drive",
  "engineType": "gas"
}
```

### 4. Import Vehicles with Color Variants

This creates 3 vehicles (white, blue, red) with the same specifications:

```bash
curl -X POST http://localhost:8087/api/v1/vehicles/import \
  -H "Content-Type: application/json" \
  -d '{
    "make": "Toyota",
    "model": "Avalon",
    "year": "2020"
  }'
```

**Expected Response:**
```json
[
  {
    "id": "uuid-1",
    "make": "Toyota",
    "model": "Avalon",
    "submodel": "XSE",
    "year": "2020",
    "color": "white",
    "highResolutionImageUrl": "https://example.com/images/vehicles/toyota/avalon/2020/white.jpg",
    "thumbnailImageUrl": "https://example.com/images/vehicles/toyota/avalon/2020/white_thumb.jpg",
    "transmission": "8-speed automatic",
    "fuelType": "gasoline",
    "seats": 5,
    "doors": 4,
    "drivetrain": "front wheel drive",
    "engineType": "gas"
  },
  {
    "id": "uuid-2",
    "make": "Toyota",
    "model": "Avalon",
    "submodel": "XSE",
    "year": "2020",
    "color": "blue",
    "highResolutionImageUrl": "https://example.com/images/vehicles/toyota/avalon/2020/blue.jpg",
    "thumbnailImageUrl": "https://example.com/images/vehicles/toyota/avalon/2020/blue_thumb.jpg",
    "transmission": "8-speed automatic",
    "fuelType": "gasoline",
    "seats": 5,
    "doors": 4,
    "drivetrain": "front wheel drive",
    "engineType": "gas"
  },
  {
    "id": "uuid-3",
    "make": "Toyota",
    "model": "Avalon",
    "submodel": "XSE",
    "year": "2020",
    "color": "red",
    "highResolutionImageUrl": "https://example.com/images/vehicles/toyota/avalon/2020/red.jpg",
    "thumbnailImageUrl": "https://example.com/images/vehicles/toyota/avalon/2020/red_thumb.jpg",
    "transmission": "8-speed automatic",
    "fuelType": "gasoline",
    "seats": 5,
    "doors": 4,
    "drivetrain": "front wheel drive",
    "engineType": "gas"
  }
]
```

### 5. Test Duplicate Prevention

Run the import command again with the same data:

```bash
curl -X POST http://localhost:8087/api/v1/vehicles/import \
  -H "Content-Type: application/json" \
  -d '{
    "make": "Toyota",
    "model": "Avalon",
    "year": "2020"
  }'
```

**Expected Response:**
Same 3 vehicles as before (no duplicates created)

**Check Logs:**
```
Vehicle already exists: make=Toyota, model=Avalon, year=2020, color=white, id=uuid-1
Vehicle already exists: make=Toyota, model=Avalon, year=2020, color=blue, id=uuid-2
Vehicle already exists: make=Toyota, model=Avalon, year=2020, color=red, id=uuid-3
Async import completed: 3 total vehicles (New: 0, Existing: 3)
```

### 6. Get All Vehicles (Paginated)

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles?page=0&size=10"
```

**Expected Response:**
```json
{
  "content": [
    {
      "id": "uuid-1",
      "make": "Toyota",
      "model": "Avalon",
      "submodel": "XSE",
      "year": "2020",
      "color": "white",
      ...
    },
    ...
  ],
  "pageable": {
    "pageNumber": 0,
    "pageSize": 10
  },
  "totalElements": 3,
  "totalPages": 1
}
```

### 7. Get Vehicles by Make

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles/make/Toyota"
```

**Expected Response:**
```json
[
  {
    "id": "uuid-1",
    "make": "Toyota",
    "model": "Avalon",
    "submodel": "XSE",
    "year": "2020",
    "color": "white",
    ...
  },
  ...
]
```

### 8. Get Vehicles by Year

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles/year/2020"
```

**Expected Response:**
```json
[
  {
    "id": "uuid-1",
    "make": "Toyota",
    "model": "Avalon",
    "submodel": "XSE",
    "year": "2020",
    "color": "white",
    ...
  },
  ...
]
```

## Test Different Vehicles

### Test Case 1: Honda Accord

```bash
# Get latest Accord
curl -X GET "http://localhost:8087/api/v1/vehicles?make=Honda&model=Accord"

# Import with color variants
curl -X POST http://localhost:8087/api/v1/vehicles/import \
  -H "Content-Type: application/json" \
  -d '{
    "make": "Honda",
    "model": "Accord",
    "year": "2019"
  }'
```

### Test Case 2: Ford F-150

```bash
# Get specific year
curl -X GET "http://localhost:8087/api/v1/vehicles?make=Ford&model=F-150&year=2018"

# Import with color variants
curl -X POST http://localhost:8087/api/v1/vehicles/import \
  -H "Content-Type: application/json" \
  -d '{
    "make": "Ford",
    "model": "F-150",
    "year": "2018"
  }'
```

### Test Case 3: Tesla Model 3

```bash
# Get latest Model 3
curl -X GET "http://localhost:8087/api/v1/vehicles?make=Tesla&model=Model%203"

# Import with color variants
curl -X POST http://localhost:8087/api/v1/vehicles/import \
  -H "Content-Type: application/json" \
  -d '{
    "make": "Tesla",
    "model": "Model 3",
    "year": "2020"
  }'
```

## Database Verification

### Check Created Vehicles

```sql
SELECT 
    v.id,
    m.name as make,
    cm.name as model,
    v.submodel,
    v.year,
    v.color,
    v.transmission,
    v.fuel_type,
    v.seats,
    v.doors
FROM vehicles v
JOIN makes m ON v.make_id = m.id
JOIN car_models cm ON v.model_id = cm.id
ORDER BY m.name, cm.name, v.year, v.color;
```

### Check for Duplicates

```sql
SELECT 
    make_id, 
    model_id, 
    year, 
    color, 
    COUNT(*) as count
FROM vehicles
GROUP BY make_id, model_id, year, color
HAVING COUNT(*) > 1;
```

**Expected Result:** No rows (no duplicates)

### Check Submodel Data

```sql
SELECT 
    m.name as make,
    cm.name as model,
    v.year,
    v.submodel,
    COUNT(*) as variant_count
FROM vehicles v
JOIN makes m ON v.make_id = m.id
JOIN car_models cm ON v.model_id = cm.id
GROUP BY m.name, cm.name, v.year, v.submodel
ORDER BY m.name, cm.name, v.year;
```

## Error Scenarios

### Test 1: Invalid Vehicle

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles?make=InvalidMake&model=InvalidModel&year=2020"
```

**Expected Response:**
```json
{
  "error": "ResourceNotFoundException",
  "message": "No vehicle found for make=InvalidMake, model=InvalidModel, year=2020",
  "status": 404
}
```

### Test 2: API Unavailable

Stop the Car API or use invalid credentials:

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles?make=Toyota&model=Avalon&year=2020"
```

**Expected Response:**
```json
{
  "error": "RuntimeException",
  "message": "External Car API is currently unavailable",
  "status": 500
}
```

### Test 3: Invalid Year Format

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles?make=Toyota&model=Avalon&year=invalid"
```

**Expected Response:**
Vehicle with latest available year or error depending on API response

## Performance Testing

### Test 1: Database vs API Response Time

First call (API):
```bash
time curl -X GET "http://localhost:8087/api/v1/vehicles?make=Toyota&model=Camry&year=2020"
```
Expected: ~1-2 seconds (API call)

Second call (Database):
```bash
time curl -X GET "http://localhost:8087/api/v1/vehicles?make=Toyota&model=Camry&year=2020"
```
Expected: ~50-200ms (database lookup)

### Test 2: Async Import Performance

```bash
time curl -X POST http://localhost:8087/api/v1/vehicles/import \
  -H "Content-Type: application/json" \
  -d '{
    "make": "Toyota",
    "model": "Camry",
    "year": "2020"
  }'
```
Expected: ~1-3 seconds (single API call, 3 database inserts)

## Automated Test Script

Save this as `test-submodels.sh`:

```bash
#!/bin/bash

BASE_URL="http://localhost:8087/api/v1/vehicles"

echo "Testing Vehicle Submodel Integration"
echo "====================================="
echo ""

# Test 1: API Health
echo "1. Testing API Health..."
curl -s "$BASE_URL/makes/api/health" | jq .
echo ""

# Test 2: Get Vehicle (Database-First)
echo "2. Getting Toyota Avalon 2020..."
curl -s "$BASE_URL?make=Toyota&model=Avalon&year=2020" | jq .
echo ""

# Test 3: Get Latest Vehicle
echo "3. Getting Latest Toyota Avalon..."
curl -s "$BASE_URL?make=Toyota&model=Avalon" | jq .
echo ""

# Test 4: Import Vehicles
echo "4. Importing Toyota Avalon 2020 (3 colors)..."
curl -s -X POST "$BASE_URL/import" \
  -H "Content-Type: application/json" \
  -d '{"make":"Toyota","model":"Avalon","year":"2020"}' | jq .
echo ""

# Test 5: Test Duplicate Prevention
echo "5. Testing Duplicate Prevention..."
curl -s -X POST "$BASE_URL/import" \
  -H "Content-Type: application/json" \
  -d '{"make":"Toyota","model":"Avalon","year":"2020"}' | jq .
echo ""

# Test 6: Get All Vehicles
echo "6. Getting All Vehicles..."
curl -s "$BASE_URL?page=0&size=10" | jq '.content | length'
echo ""

echo "Tests completed!"
```

Run with:
```bash
chmod +x test-submodels.sh
./test-submodels.sh
```

## Monitoring and Logs

### Important Log Messages

**Successful Import:**
```
INFO: Async import started: make=Toyota, model=Avalon, year=2020 (duplicate prevention enabled)
INFO: Selected submodel: id=73591, name=XSE, year=2020
INFO: Vehicle synced successfully from API: id=uuid, make=Toyota, model=Avalon, submodel=XSE, year=2020
INFO: Async import completed: 3 total vehicles (New: 3, Existing: 0)
```

**Duplicate Prevention:**
```
INFO: Make 'Toyota' not found, creating new make
INFO: Model 'Avalon' for make 'Toyota' not found, creating new model
DEBUG: Vehicle already exists: make=Toyota, model=Avalon, year=2020, color=white, id=uuid-1
INFO: Async import completed: 3 total vehicles (New: 0, Existing: 3)
```

**API Error:**
```
ERROR: Error syncing vehicle from API: External Car API is currently unavailable
WARN: Car API is not available: Connection refused
```

## Summary

✅ **Database-First Strategy**: Checks database before API  
✅ **Smart Year Selection**: Latest year when not specified  
✅ **Submodel Support**: Full trim/submodel details stored  
✅ **Duplicate Prevention**: No duplicate makes/models/vehicles  
✅ **Color Variants**: Multiple colors per vehicle  
✅ **Async Processing**: Better performance for bulk imports  
✅ **Comprehensive Data**: Engine, body, and drivetrain specs  

All test cases should pass successfully with the new implementation!
