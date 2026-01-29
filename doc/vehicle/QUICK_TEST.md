# Quick Test Guide - Vehicle API Integration Fix

## Problem Fixed
✅ **404 Error**: "No trim details found for trim ID: 8858" - RESOLVED

## Quick Test Commands

### 1. Start the Service
```bash
cd /mnt/projects/Ride/vehicle-service
./mvnw spring-boot:run
```

### 2. Test Vehicle Sync (Single Vehicle)
```bash
# Test with Toyota Avalon 2020
curl -X POST 'http://localhost:8087/api/v1/vehicles/sync?make=toyota&model=avalon&year=2020' \
  -H 'accept: application/json' | jq .
```

**Expected Response:**
```json
{
  "id": "uuid",
  "make": "Toyota",
  "model": "Avalon",
  "submodel": "Hybrid Limited",
  "year": "2020",
  "transmission": "continuously variable-speed automatic",
  "fuelType": "regular unleaded",
  "drivetrain": "front wheel drive",
  "engineType": "hybrid",
  "seats": 5,
  "doors": 4
}
```

### 3. Test Vehicle Import (3 Color Variants)
```bash
curl -X POST 'http://localhost:8087/api/v1/vehicles/import' \
  -H 'Content-Type: application/json' \
  -d '{
    "make": "Toyota",
    "model": "Avalon",
    "year": "2020"
  }' | jq .
```

**Expected Response:**
```json
[
  {
    "id": "uuid-1",
    "make": "Toyota",
    "model": "Avalon",
    "submodel": "Hybrid Limited",
    "year": "2020",
    "color": "white",
    "transmission": "continuously variable-speed automatic",
    "fuelType": "regular unleaded",
    "drivetrain": "front wheel drive",
    "engineType": "hybrid",
    "seats": 5,
    "doors": 4,
    "highResolutionImageUrl": "https://example.com/images/vehicles/toyota/avalon/2020/white.jpg",
    "thumbnailImageUrl": "https://example.com/images/vehicles/toyota/avalon/2020/white_thumb.jpg"
  },
  {
    "id": "uuid-2",
    "make": "Toyota",
    "model": "Avalon",
    "year": "2020",
    "color": "blue",
    ...
  },
  {
    "id": "uuid-3",
    "make": "Toyota",
    "model": "Avalon",
    "year": "2020",
    "color": "red",
    ...
  }
]
```

### 4. Get Vehicle (Database-First)
```bash
# After sync, this should be fast (from database)
curl -X GET 'http://localhost:8087/api/v1/vehicles?make=Toyota&model=Avalon&year=2020' \
  -H 'accept: application/json' | jq .
```

### 5. Test Different Vehicles

#### Honda Accord
```bash
curl -X POST 'http://localhost:8087/api/v1/vehicles/sync?make=honda&model=accord&year=2019' \
  -H 'accept: application/json' | jq .
```

#### Ford F-150
```bash
curl -X POST 'http://localhost:8087/api/v1/vehicles/sync?make=ford&model=f-150&year=2018' \
  -H 'accept: application/json' | jq .
```

#### Tesla Model 3
```bash
curl -X POST 'http://localhost:8087/api/v1/vehicles/sync?make=tesla&model=model%203&year=2020' \
  -H 'accept: application/json' | jq .
```

## Verify Data in Database

```bash
# Connect to PostgreSQL
docker exec -it vehicle-db psql -U postgres -d ride_vehicle_db

# Check synced vehicles
SELECT 
    m.name as make,
    cm.name as model,
    v.submodel,
    v.year,
    v.color,
    v.transmission,
    v.fuel_type,
    v.drivetrain,
    v.engine_type,
    v.seats,
    v.doors
FROM vehicles v
JOIN makes m ON v.make_id = m.id
JOIN car_models cm ON v.model_id = cm.id
ORDER BY m.name, cm.name, v.year;
```

## Expected Database Result
```
  make  |  model  |     submodel     | year | color |          transmission           |    fuel_type     |    drivetrain     | engine_type | seats | doors
--------+---------+------------------+------+-------+---------------------------------+------------------+-------------------+-------------+-------+-------
 Toyota | Avalon  | Hybrid Limited   | 2020 | white | continuously variable-speed...  | regular unleaded | front wheel drive | hybrid      |     5 |     4
 Toyota | Avalon  | Hybrid Limited   | 2020 | blue  | continuously variable-speed...  | regular unleaded | front wheel drive | hybrid      |     5 |     4
 Toyota | Avalon  | Hybrid Limited   | 2020 | red   | continuously variable-speed...  | regular unleaded | front wheel drive | hybrid      |     5 |     4
```

## Troubleshooting

### If Service Won't Start (Port in Use)
```bash
# Find process using port 8087
sudo lsof -i :8087
# or
sudo netstat -tlnp | grep 8087

# Kill the process
kill -9 <PID>
```

### Check Logs
```bash
# Real-time logs
tail -f /mnt/projects/Ride/vehicle-service/logs/application.log

# Or with mvn
./mvnw spring-boot:run | grep -i "vehicle"
```

### Verify API Health
```bash
curl http://localhost:8087/actuator/health | jq .
```

Expected:
```json
{
  "status": "UP"
}
```

### Check Car API Connectivity
```bash
curl http://localhost:8087/api/v1/vehicles/makes/api/health | jq .
```

Expected:
```json
{
  "status": "UP",
  "apiAvailable": true
}
```

## Success Indicators

✅ No 404 errors  
✅ Vehicle data includes `submodel` field  
✅ `transmission` shows actual value (not null)  
✅ `drivetrain` shows actual value (not null)  
✅ `fuelType` shows actual value  
✅ `engineType` shows actual value  
✅ `seats` and `doors` have values > 0  

## What Was Fixed

1. ✅ API response parsing (removed incorrect `.path("data")`)
2. ✅ Transmission extraction (from `transmissions` array)
3. ✅ Drive type extraction (from `drive_types` array)
4. ✅ Proper null checks
5. ✅ Submodel field support in database and DTO

## Files Changed

- `VehicleServiceImpl.java` - Main service implementation
- `Vehicle.java` - Added submodel field
- `VehicleDto.java` - Added submodel field
- `03-add-submodel-column.sql` - Database migration

## Build Verification

```bash
cd /mnt/projects/Ride/vehicle-service
./mvnw clean compile -DskipTests
```

Expected: `BUILD SUCCESS`

---

**Status**: ✅ **READY TO TEST**  
**Last Updated**: January 16, 2026  
**Issue**: Fixed trim details API response parsing
