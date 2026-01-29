# Vehicle Sync System - Quick Start Guide

## Prerequisites
- PostgreSQL 13+ running on port 5437
- Java 17+
- Maven 3.8+
- CarAPI.app credentials (token & secret)

## Setup

### 1. Configure Database
```bash
# Create database (if not exists)
psql -U postgres -p 5437
CREATE DATABASE vehicledb;
CREATE USER vehicleservice WITH PASSWORD 'vehicleservice123';
GRANT ALL PRIVILEGES ON DATABASE vehicledb TO vehicleservice;
```

### 2. Configure Application
Edit `src/main/resources/application.yaml`:
```yaml
carapi:
  token: YOUR_CARAPI_TOKEN
  secret: YOUR_CARAPI_SECRET
```

### 3. Start Service
```bash
cd vehicle-service
mvn clean install
mvn spring-boot:run
```

The service will be available at: http://localhost:8084

---

## Quick Operations

### Initial Data Population (Recommended)

**Step 1: Sync All Makes and Models**
```bash
curl -X POST http://localhost:8084/carapi/sync/all-makes-models
```
*Time: ~2-3 minutes*  
*Result: ~125 makes, ~3500 models*

**Step 2: Sync Trims for Popular Makes**
```bash
# Sync Toyota vehicles (all models)
curl -X POST http://localhost:8084/carapi/sync/trims/Toyota

# Sync Honda vehicles
curl -X POST http://localhost:8084/carapi/sync/trims/Honda

# Sync BMW vehicles
curl -X POST http://localhost:8084/carapi/sync/trims/BMW
```
*Time: ~5-10 minutes per make*  
*Result: ~500-2000 vehicles per make*

**Step 3: Verify Sync**
```bash
curl http://localhost:8084/carapi/sync/stats
```

**Expected Response:**
```json
{
  "totalMakes": 125,
  "totalModels": 3420,
  "totalVehicles": 15000
}
```

---

## Common Use Cases

### 1. User Searches for a Vehicle
**Scenario:** User searches "2024 Tesla Model 3"

**Backend Operation:**
```bash
curl "http://localhost:8084/carapi/trims?make=Tesla&model=Model%203&sync=true"
```

**What Happens:**
1. Fetches trims from CarAPI
2. Parses specifications (doors, seats, fuel type, etc.)
3. Inserts new vehicles into DB (skips duplicates)
4. Returns API response

---

### 2. Admin Adds New Vehicle Make
**Scenario:** CarAPI adds "Rivian" as a new electric vehicle make

**Operation:**
```bash
# Sync the new make and all its models/trims
curl -X POST http://localhost:8084/carapi/sync/trims/Rivian
```

---

### 3. Query Synced Vehicles

**Get All Toyota Vehicles:**
```bash
curl http://localhost:8084/vehicles/make/Toyota
```

**Get All 2024 Vehicles:**
```bash
curl http://localhost:8084/vehicles/year/2024
```

**Get Specific Model:**
```bash
curl http://localhost:8084/vehicles/make/Tesla/model/Model%203
```

**Get with Pagination:**
```bash
curl "http://localhost:8084/vehicles?page=0&size=20&sort=year,desc"
```

---

## Testing the System

### 1. Test TrimParser
```java
// Run unit tests
mvn test -Dtest=TrimParserTest
```

### 2. Test Sync Flow
```bash
# Sync a small make (Bentley has ~50 trims)
curl -X POST http://localhost:8084/carapi/sync/trims/Bentley

# Verify
curl http://localhost:8084/vehicles/make/Bentley | jq .
```

**Expected Output:**
```json
[
  {
    "id": "abc-123-uuid",
    "makeName": "Bentley",
    "modelName": "Bentayga",
    "year": 2020,
    "trimName": "4dr SUV AWD (6.0L 12cyl Turbo 8A)",
    "transmission": "Automatic",
    "fuelType": "Gasoline",
    "seats": 5,
    "doors": 4,
    "drivetrain": "AWD",
    "engineType": "6.0L 12cyl Turbo",
    "engineDisplacement": 6.0
  }
]
```

---

## API Endpoints Cheat Sheet

| Endpoint | Method | Purpose | Example |
|----------|--------|---------|---------|
| `/carapi/sync/all-makes-models` | POST | Sync all makes & models | Initial setup |
| `/carapi/sync/trims/{make}` | POST | Sync all trims for a make | `POST /sync/trims/Toyota` |
| `/carapi/sync/stats` | GET | Get sync statistics | Check DB status |
| `/vehicles` | GET | Get all vehicles (paginated) | Query with pagination |
| `/vehicles/make/{make}` | GET | Get vehicles by make | `GET /vehicles/make/Toyota` |
| `/vehicles/make/{make}/model/{model}` | GET | Get vehicles by make & model | `GET /vehicles/make/Toyota/model/Camry` |
| `/vehicles/year/{year}` | GET | Get vehicles by year | `GET /vehicles/year/2024` |

---

## Troubleshooting

### Issue: JWT Authentication Fails
**Error:** `Authentication rejected by carapi.app`

**Solution:**
1. Check your `carapi.token` and `carapi.secret` in `application.yaml`
2. Verify credentials at https://carapi.app/
3. Check logs: `tail -f logs/vehicle-service.log`

---

### Issue: Duplicate Vehicles
**Error:** Database constraint violation

**Solution:**
The system automatically skips duplicates. If you see this error:
1. Check the unique constraint: `make_id, model_id, year, trim_name`
2. Review logs for the specific conflict
3. Run: `SELECT * FROM vehicles WHERE make_id = ? AND model_id = ? AND year = ?`

---

### Issue: Slow Sync Operations
**Problem:** Syncing a make takes too long

**Solutions:**
1. **Increase Connection Pool:**
   ```yaml
   spring:
     datasource:
       hikari:
         maximum-pool-size: 20  # Increase from 10
   ```

2. **Batch Inserts:** (Already optimized in code)

3. **Sync Incrementally:**
   ```bash
   # Instead of syncing all trims at once, sync by model
   curl "http://localhost:8084/carapi/trims?make=Toyota&model=Camry&sync=true"
   curl "http://localhost:8084/carapi/trims?make=Toyota&model=Corolla&sync=true"
   ```

---

## Performance Benchmarks

| Operation | Avg Time | Records |
|-----------|----------|---------|
| Sync All Makes | ~2 min | ~125 makes |
| Sync All Models (1 make) | ~30 sec | ~50 models |
| Sync All Trims (1 model) | ~3 sec | ~20 trims |
| Sync All Trims (1 make) | ~5 min | ~1000 trims |

---

## Database Maintenance

### View Table Sizes
```sql
SELECT 
    schemaname, tablename, 
    pg_size_pretty(pg_total_relation_size(schemaname||'.'||tablename)) AS size
FROM pg_tables 
WHERE schemaname = 'public'
ORDER BY pg_total_relation_size(schemaname||'.'||tablename) DESC;
```

### Clean Orphaned Vehicles (No Owner)
```sql
-- Find vehicles not assigned to any owner
SELECT COUNT(*) FROM vehicles WHERE owner_id IS NULL;

-- Optional: Delete unassigned vehicles older than 90 days
DELETE FROM vehicles 
WHERE owner_id IS NULL 
  AND created_at < NOW() - INTERVAL '90 days';
```

---

## Next Steps

1. ✅ Sync initial data (makes, models, popular trims)
2. ✅ Test API endpoints
3. 📊 Integrate with booking system
4. 🖼️ Add vehicle images (image scraping service)
5. 💰 Integrate pricing data
6. 🔍 Implement search/filtering (Elasticsearch)

---

## Support

**Logs:**
```bash
tail -f logs/vehicle-service.log
```

**Database Access:**
```bash
psql -U vehicleservice -d vehicledb -h localhost -p 5437
```

**API Documentation:**
- Swagger UI: http://localhost:8084/swagger-ui.html
- API Docs: http://localhost:8084/v3/api-docs

**Contact:** vehicle-service-team@yourcompany.com

