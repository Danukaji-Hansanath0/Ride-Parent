# Vehicle Submodel Integration Guide

## Overview

This document describes the implementation of the Car API submodels integration for the Vehicle Service. The implementation uses a two-stage API approach to fetch detailed vehicle information.

## Architecture

### API Flow

1. **Fetch Submodels** (`GET /api/submodels/v2`)
   - Returns list of submodels for a given make, model, and year
   - Contains submodel ID, name, and year information
   
2. **Fetch Trim Details** (`GET /api/trims/v2/{id}`)
   - Uses submodel ID from step 1
   - Returns comprehensive vehicle data including:
     - Engine specifications (transmission, fuel type, engine type)
     - Body specifications (seats, doors, dimensions)
     - Mileage information
     - Color options

### Database-First Approach

The service follows a **database-first strategy** with external API fallback:

1. **Check Local Database**: First attempts to find vehicle in local database
2. **API Fallback**: If not found locally, fetches from external Car API
3. **Cache Results**: Stores fetched data in database for future use
4. **Duplicate Prevention**: Ensures no duplicate makes, models, or vehicles are created

## Implementation Details

### New Components

#### 1. Updated CarApiUrlBuilder

Added new method for submodels endpoint:

```java
public static String submodelsUrl(String make, String model, String year) {
    String url = String.format("%s/submodels/v2?make=%s&model=%s", BASE_URL, make.trim(), model.trim());
    if (StringUtils.hasText(year)) {
        url += "&year=" + year.trim();
    }
    return url;
}
```

#### 2. Updated ICarApiClient Interface

Added new method:

```java
String getSubmodels(String make, String model, String year);
```

#### 3. Vehicle Entity Enhancement

Added submodel field:

```java
private String submodel; // Submodel/trim information (e.g., "XLE Premium", "Limited")
```

#### 4. VehicleServiceImpl Updates

##### Submodel Selection Logic

The service intelligently selects the appropriate submodel based on year:

```java
private JsonNode selectSubmodel(JsonNode dataArray, String targetYear) {
    // Priority:
    // 1. If year is provided, find exact match for that year
    // 2. If year is provided but no match, find closest year
    // 3. If year is null, use the latest available year
}
```

##### Vehicle Data Extraction

Extracts detailed data from trim API response:

```java
private Vehicle buildVehicleFromTrimData(Makes makeEntity, CarModels modelEntity,
                                          String year, String submodel, JsonNode trimData) {
    // Extract engine data
    JsonNode engines = trimData.path("engines");
    JsonNode firstEngine = engines.isArray() && !engines.isEmpty() ? engines.get(0) : null;
    
    // Extract body data
    JsonNode bodies = trimData.path("bodies");
    JsonNode firstBody = bodies.isArray() && !bodies.isEmpty() ? bodies.get(0) : null;
    
    // Build vehicle with extracted data
}
```

### API Methods

#### 1. Sync Single Vehicle

```java
@Transactional
public VehicleDto syncVehicleFromApi(String make, String model, String year)
```

**Features:**
- Fetches submodels from API
- Selects appropriate submodel by year (latest if year is null)
- Retrieves detailed trim data
- Prevents duplicate makes/models/vehicles
- Returns single vehicle DTO

**Usage:**
```bash
# Get vehicle with specific year
GET /api/v1/vehicles?make=Toyota&model=Avalon&year=2020

# Get vehicle with latest year (if not in DB)
GET /api/v1/vehicles?make=Toyota&model=Avalon
```

#### 2. Async Bulk Import

```java
@Async
@Transactional
public CompletableFuture<List<VehicleDto>> importVehiclesAsync(String make, String model, String year)
```

**Features:**
- Fetches single submodel/trim data
- Creates multiple color variants (white, blue, red)
- Prevents duplicates for each color
- Returns list of all vehicles (new + existing)
- Runs asynchronously for better performance

**Usage:**
```bash
POST /api/v1/vehicles/import
{
  "make": "Toyota",
  "model": "Avalon",
  "year": "2020"
}
```

## Database Schema

### New Column

```sql
ALTER TABLE vehicles 
ADD COLUMN IF NOT EXISTS submodel VARCHAR(255);
```

### Indexes

```sql
-- Index on submodel
CREATE INDEX idx_vehicles_submodel ON vehicles(submodel);

-- Composite index for common queries
CREATE INDEX idx_vehicles_make_model_year_submodel 
ON vehicles(make_id, model_id, year, submodel);
```

## API Response Examples

### Submodels API Response

```json
{
  "collection": {
    "url": "/api/submodels/v2?make=toyota&model=avalon",
    "count": 47,
    "total": 47
  },
  "data": [
    {
      "id": 65321,
      "oem_make_model_id": 5689,
      "year": 2015,
      "make": "Toyota",
      "model": "Avalon",
      "submodel": "Hybrid Limited"
    },
    {
      "id": 73591,
      "oem_make_model_id": 5689,
      "year": 2020,
      "make": "Toyota",
      "model": "Avalon",
      "submodel": "XSE"
    }
  ]
}
```

### Trim Details API Response

```json
{
  "id": 73591,
  "make": "Toyota",
  "model": "Avalon",
  "submodel": "XSE",
  "year": 2020,
  "trim": "XSE",
  "engines": [
    {
      "engine_type": "gas",
      "fuel_type": "gasoline",
      "transmission": "8-speed automatic",
      "drive_type": "front wheel drive",
      "cylinders": "V6",
      "horsepower_hp": 301
    }
  ],
  "bodies": [
    {
      "type": "Sedan",
      "doors": 4,
      "seats": 5,
      "length": 195.9,
      "width": 72.8,
      "height": 56.5
    }
  ]
}
```

## Usage Examples

### Example 1: Get Vehicle by Make/Model/Year

```bash
# Request
GET /api/v1/vehicles?make=Toyota&model=Avalon&year=2020

# Response
{
  "id": "uuid-here",
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

### Example 2: Get Latest Vehicle (No Year Specified)

```bash
# Request
GET /api/v1/vehicles?make=Toyota&model=Avalon

# Response - Returns latest available year (e.g., 2020)
{
  "id": "uuid-here",
  "make": "Toyota",
  "model": "Avalon",
  "submodel": "XSE",
  "year": "2020",
  ...
}
```

### Example 3: Import Vehicles with Color Variants

```bash
# Request
POST /api/v1/vehicles/import
Content-Type: application/json

{
  "make": "Toyota",
  "model": "Avalon",
  "year": "2020"
}

# Response - Returns 3 vehicles (white, blue, red)
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
  {
    "id": "uuid-2",
    "make": "Toyota",
    "model": "Avalon",
    "submodel": "XSE",
    "year": "2020",
    "color": "blue",
    ...
  },
  {
    "id": "uuid-3",
    "make": "Toyota",
    "model": "Avalon",
    "submodel": "XSE",
    "year": "2020",
    "color": "red",
    ...
  }
]
```

## Duplicate Prevention

The implementation includes comprehensive duplicate prevention:

1. **Makes**: Checks if make exists before creating
2. **Models**: Checks if model exists for the make before creating
3. **Vehicles**: Checks if vehicle exists with same make/model/year/color before creating

### Logging

Duplicate prevention is logged at INFO level:

```
Make 'Toyota' not found, creating new make
Model 'Avalon' for make 'Toyota' not found, creating new model
Vehicle already exists: make=Toyota, model=Avalon, year=2020, color=white, id=uuid-here
```

## Error Handling

### API Unavailable

```java
if (!carApiClient.isApiAvailable()) {
    throw new RuntimeException("External Car API is currently unavailable");
}
```

### Vehicle Not Found

```java
if (dataNode.isEmpty() || !dataNode.isArray()) {
    throw new ResourceNotFoundException(
        String.format("No vehicle found for make=%s, model=%s, year=%s", make, model, year));
}
```

### No Trim Details

```java
if (trimData.isEmpty() || trimData.isMissingNode()) {
    throw new ResourceNotFoundException(
        String.format("No trim details found for submodel ID: %s", submodelId));
}
```

## Performance Considerations

1. **Async Processing**: Bulk imports run asynchronously
2. **Database Indexing**: Indexes on submodel and composite columns
3. **Single API Call**: Reuses trim data for multiple color variants
4. **Caching**: Database acts as cache for API responses

## Testing

### Test Endpoints

```bash
# Check API health
GET /api/v1/vehicles/makes/api/health

# Sync all makes
POST /api/v1/vehicles/makes/sync

# Get specific vehicle
GET /api/v1/vehicles?make=Toyota&model=Avalon&year=2020

# Import vehicles
POST /api/v1/vehicles/import
{
  "make": "Toyota",
  "model": "Avalon",
  "year": "2020"
}
```

### Expected Behavior

1. **First Request**: Fetches from API, stores in database
2. **Subsequent Requests**: Returns from database (fast)
3. **Color Variants**: Creates 3 vehicles per import (white, blue, red)
4. **Duplicates**: Prevents duplicate creation, returns existing entities

## Migration Path

### Existing Data

For existing vehicles without submodel data:

```sql
-- Existing vehicles will have NULL submodel
-- They can be updated by re-importing from API
```

### Manual Update

```sql
-- Update submodel for existing vehicle
UPDATE vehicles 
SET submodel = 'XLE Premium' 
WHERE make_id = (SELECT id FROM makes WHERE name = 'Toyota')
  AND model_id = (SELECT id FROM car_models WHERE name = 'Avalon')
  AND year = '2020';
```

## Future Enhancements

1. **Batch Processing**: Process multiple vehicles in parallel
2. **Smart Caching**: Cache expiration for API data
3. **Submodel Search**: Filter vehicles by submodel
4. **Trim Comparison**: Compare different trims/submodels
5. **Historical Data**: Track submodel changes over years

## Troubleshooting

### Issue: API Returns No Data

**Solution**: Check API rate limits and authentication

```bash
GET /api/v1/vehicles/makes/api/health
# Should return: {"status": "UP", "apiAvailable": true}
```

### Issue: Duplicate Vehicles Created

**Solution**: Check database constraints and repository methods

```sql
-- Check for duplicates
SELECT make_id, model_id, year, color, COUNT(*) 
FROM vehicles 
GROUP BY make_id, model_id, year, color 
HAVING COUNT(*) > 1;
```

### Issue: Wrong Year Selected

**Solution**: Specify exact year in request

```bash
# Instead of
GET /api/v1/vehicles?make=Toyota&model=Avalon

# Use
GET /api/v1/vehicles?make=Toyota&model=Avalon&year=2020
```

## Conclusion

The submodel integration provides:
- ✅ Comprehensive vehicle data from Car API
- ✅ Smart year selection (latest or specified)
- ✅ Duplicate prevention
- ✅ Database-first with API fallback
- ✅ Async bulk import with color variants
- ✅ Full database persistence

The implementation is production-ready and follows best practices for external API integration.
