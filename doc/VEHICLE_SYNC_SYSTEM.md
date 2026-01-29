# Vehicle Data Sync System - Complete Implementation Guide

## Overview

The Vehicle Service synchronizes car data from the external **carapi.app** API into our local PostgreSQL database on-demand. This ensures rental-relevant information is always available, up-to-date, and deduplicated.

## System Architecture

### Data Flow Hierarchy
```
CarAPI.app → Vehicle Service → PostgreSQL Database
    ↓              ↓                    ↓
  Makes        Sync Logic           makes table
    ↓          Parse/Enrich        car_models table
  Models       Deduplicate         vehicles table
    ↓
  Trims/Vehicles
```

### Database Schema

#### `makes` Table
- `id` (BIGINT, PK)
- `name` (VARCHAR, UNIQUE) - e.g., "Toyota", "BMW"

#### `car_models` Table
- `id` (UUID, PK)
- `name` (VARCHAR) - e.g., "Camry", "X5"
- `make_id` (FK → makes.id)

#### `vehicles` Table (Comprehensive Trim Data)
- `id` (UUID, PK)
- `make_id` (FK → makes.id)
- `model_id` (FK → car_models.id)
- `year` (INTEGER) - Model year
- `trim_name` (VARCHAR) - Full trim description
- `description` (TEXT) - Raw API description
- `color` (VARCHAR) - Default: "Unknown"
- `owner_id` (FK → vehicle_owners.id, nullable)

**Technical Specifications (Rental-Critical):**
- `transmission` (VARCHAR) - "Automatic" / "Manual"
- `fuel_type` (VARCHAR) - "Gasoline" / "Diesel" / "Electric" / "Hybrid"
- `seats` (INTEGER) - Number of passengers
- `doors` (INTEGER) - Number of doors
- `drivetrain` (VARCHAR) - "AWD" / "RWD" / "FWD" / "4WD"
- `engine_type` (VARCHAR) - e.g., "6.0L 12cyl Turbo"
- `engine_displacement` (DOUBLE) - Liters

**Media:**
- `high_resolution_image_url` (VARCHAR)
- `thumbnail_image_url` (VARCHAR)

**Audit:**
- `created_at` (TIMESTAMP)
- `updated_at` (TIMESTAMP)

---

## API Endpoints

### 1. **Sync Operations**

#### Sync All Makes & Models
```http
POST /carapi/sync/all-makes-models
```
**Purpose:** Fetches all makes from CarAPI and syncs their models.  
**Use Case:** Initial database population.  
**Response:**
```json
{
  "status": "success",
  "message": "All makes and models synced successfully"
}
```

---

#### Sync All Trims for a Make
```http
POST /carapi/sync/trims/{makeName}
```
**Example:**
```bash
curl -X POST http://localhost:8084/carapi/sync/trims/Toyota
```
**Purpose:** Syncs all vehicles/trims for every model of the specified make.  
**Process:**
1. Ensures models are synced for the make
2. Iterates through each model
3. Fetches trims from CarAPI
4. Parses specifications (doors, seats, fuel type, etc.)
5. Inserts only new vehicles (skips duplicates)

---

#### Get Sync Statistics
```http
GET /carapi/sync/stats
```
**Response:**
```json
{
  "totalMakes": 125,
  "totalModels": 3420,
  "totalVehicles": 45678
}
```

---

### 2. **Query Operations**

#### Fetch from CarAPI (Optional Sync)
```http
GET /carapi/makes?sync=true
GET /carapi/models?make=Toyota&sync=true
GET /carapi/trims?make=Toyota&model=Camry&sync=true
```
**Parameters:**
- `sync` (optional, default: false) - If `true`, syncs data to DB before returning API response

---

#### Query Vehicles from Local DB

**Get All Vehicles (Paginated):**
```http
GET /vehicles?page=0&size=20&sort=year,desc
```

**Get Vehicle by ID:**
```http
GET /vehicles/{vehicleId}
```

**Get Vehicles by Make:**
```http
GET /vehicles/make/Toyota
```

**Get Vehicles by Make & Model:**
```http
GET /vehicles/make/Toyota/model/Camry
```

**Get Vehicles by Year:**
```http
GET /vehicles/year/2024
```

---

## Core Components

### 1. **CarApiAuthService.java**
- **Purpose:** Manages JWT authentication with carapi.app
- **Features:**
  - Caches JWT tokens (30-minute TTL)
  - Auto-refreshes on expiry
  - Thread-safe token management

### 2. **CarApiClient.java**
- **Purpose:** HTTP client for CarAPI requests
- **Features:**
  - Injects JWT bearer tokens
  - Auto-retries on 401 (token refresh)
  - Error handling

### 3. **CarApiSyncService.java**
- **Purpose:** Core business logic for syncing data
- **Key Methods:**
  - `syncMakes()` - Syncs all makes
  - `syncModels(String make)` - Syncs models for a make
  - `syncTrims(String make, String model)` - Syncs trims/vehicles
  - `syncAllMakesWithModels()` - Cascade sync (makes → models)
  - `syncAllTrimsForMake(String make)` - Cascade sync (make → all models → all trims)

**Deduplication Strategy:**
```java
// Check if vehicle already exists
Optional<Vehicle> existing = vehicleRepository.findByMakeAndModelAndYearAndTrimName(
    make, model, year, trimName
);
if (existing.isPresent()) {
    // Skip - already synced
}
```

### 4. **TrimParser.java**
- **Purpose:** Extracts rental-critical specs from unstructured trim descriptions
- **Regex Patterns:**
  - Doors: `(\d+)dr` → "4dr SUV" → 4 doors
  - Drivetrain: `\b(AWD|RWD|FWD|4WD)\b`
  - Transmission: `\b(\d+[AM]A|Automatic|Manual)\b`
  - Fuel Type: `(hybrid|phev|electric|diesel)`
  - Engine: `\((\d+\.\d+L\s+\d+cyl[^)]+)\)`

**Example Parsing:**
```
Input: "4dr SUV AWD (6.0L 12cyl Turbo 8A)"
Output:
  doors: 4
  drivetrain: AWD
  transmission: Automatic
  engineType: "6.0L 12cyl Turbo"
  engineDisplacement: 6.0
  seats: 5 (heuristic: SUV = 5)
  fuelType: Gasoline (default)
```

### 5. **VehicleService.java**
- **Purpose:** Business logic for querying synced vehicles
- **Features:**
  - CRUD operations
  - Pagination support
  - Filters by make, model, year
  - DTO mapping

### 6. **Controllers**
- **CarApiController.java** - Sync triggers and CarAPI passthrough
- **VehicleController.java** - Query synced vehicles

---

## Usage Examples

### Scenario 1: Initial Database Population
```bash
# Step 1: Sync all makes and models
curl -X POST http://localhost:8084/carapi/sync/all-makes-models

# Step 2: Sync trims for specific popular makes
curl -X POST http://localhost:8084/carapi/sync/trims/Toyota
curl -X POST http://localhost:8084/carapi/sync/trims/Honda
curl -X POST http://localhost:8084/carapi/sync/trims/BMW

# Step 3: Check stats
curl http://localhost:8084/carapi/sync/stats
```

### Scenario 2: On-Demand Sync (User Searches for a Vehicle)
```bash
# User searches "2024 Ford Mustang"
# Backend calls:
curl "http://localhost:8084/carapi/trims?make=Ford&model=Mustang&sync=true"

# System:
# 1. Fetches trims from CarAPI
# 2. Parses specs
# 3. Inserts new 2024 Mustang trims
# 4. Returns API response
```

### Scenario 3: Query Synced Data
```bash
# Get all Toyota vehicles
curl http://localhost:8084/vehicles/make/Toyota

# Get all 2024 vehicles
curl http://localhost:8084/vehicles/year/2024

# Get specific model
curl "http://localhost:8084/vehicles/make/Toyota/model/Camry"
```

---

## Data Parsing & Enrichment

### Automatic Field Extraction
The `TrimParser` utility class extracts rental-critical fields from unstructured trim descriptions:

| Field | Source | Default | Example |
|-------|--------|---------|---------|
| **doors** | Regex: `(\d+)dr` | 4 | "4dr SUV" → 4 |
| **drivetrain** | Regex: `\b(AWD\|RWD\|FWD\|4WD)\b` | FWD | "AWD" |
| **transmission** | Regex: `\b(\d+[AM]A\|Automatic\|Manual)\b` | Automatic | "8A" → Automatic |
| **fuelType** | Keywords: electric, hybrid, diesel | Gasoline | "Hybrid" |
| **seats** | Heuristics (SUV/Coupe/Sedan) | 5 | SUV → 5, Coupe → 4 |
| **engineType** | Regex: `\((\d+\.\d+L\s+\d+cyl[^)]+)\)` | null | "6.0L 12cyl Turbo" |
| **engineDisplacement** | Regex: `(\d+\.\d+)L` | null | 6.0 |

### Heuristics
- **SUV/Truck/Van**: 5 or 7 seats (check for "7-seater")
- **Sedan/Wagon**: 5 seats
- **Coupe/Convertible**: 4 seats

---

## Design Principles

### 1. **Lazy Loading (On-Demand Sync)**
- Data is only fetched when needed (user search, admin trigger)
- Reduces API calls and DB storage

### 2. **Deduplication**
- Checks for existing records before inserting
- Query: `findByMakeAndModelAndYearAndTrimName()`
- Prevents duplicate trims

### 3. **Transactional Integrity**
- All sync operations use `@Transactional`
- Ensures data consistency

### 4. **Error Handling**
- Logs errors per make/model during bulk sync
- Continues processing even if one model fails

### 5. **Caching**
- JWT tokens cached for 30 minutes (Caffeine)
- Reduces authentication overhead

### 6. **Scalability**
- Bulk sync endpoints for admin operations
- Paginated vehicle queries

---

## Testing

### Unit Tests (TrimParser)
```bash
cd vehicle-service
mvn test -Dtest=TrimParserTest
```

### Integration Tests (Sync Flow)
```bash
# Start services
docker-compose up -d

# Sync test data
curl -X POST http://localhost:8084/carapi/sync/trims/Bentley

# Verify
curl http://localhost:8084/vehicles/make/Bentley
```

---

## Configuration

### application.yaml
```yaml
carapi:
  token: ${CARAPI_TOKEN}
  secret: ${CARAPI_SECRET}

spring:
  datasource:
    url: jdbc:postgresql://localhost:5437/vehicledb
    username: vehicleservice
    password: vehicleservice123
  jpa:
    hibernate:
      ddl-auto: update  # Auto-creates tables from entities
```

---

## Maintenance

### Refresh Data
```bash
# Re-sync all trims for a make (updates existing + adds new)
curl -X POST http://localhost:8084/carapi/sync/trims/Toyota
```

### Monitor JWT Cache
```java
// In CarApiAuthService
jwtCache.stats() // Returns hit rate, evictions, etc.
```

---

## Future Enhancements
1. **Scheduled Sync Jobs** - Daily cron to update popular makes
2. **Image Scraping** - Fetch vehicle images from external sources
3. **Pricing API Integration** - Add MSRP data
4. **User Favorites** - Track which vehicles users search for most
5. **Elastic Search** - Full-text search on trim descriptions
6. **GraphQL API** - For flexible client queries

---

## Support
For issues or questions, contact the Vehicle Service team or check the logs:
```bash
tail -f /var/log/vehicle-service/app.log
```

