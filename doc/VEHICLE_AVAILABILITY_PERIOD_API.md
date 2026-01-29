# Vehicle Availability Period Management API

## Overview
This API manages vehicle availability periods for vehicle owners in the Ride platform. It allows owners to specify when their vehicles are available for booking, with automatic status management - vehicles automatically transition to `OUT_OF_SERVICE` after their availability period expires.

## Features
- ✅ Set vehicle availability time periods (From - To dates)
- ✅ Track available and unavailable vehicles
- ✅ Automatic OUT_OF_SERVICE status assignment after period expires
- ✅ Extend availability periods
- ✅ Get expiring vehicles notifications
- ✅ Scheduled automated processing of expired availabilities
- ✅ Days remaining calculation
- ✅ Full pagination and sorting support

---

## Database Schema

### `owners_has_vehicles` table

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| owner_id | UUID | Foreign key to vehicle_owners |
| vehicle_id | UUID | Foreign key to vehicles |
| status | ENUM | Vehicle status (AVAILABLE, IN_SERVICE, OUT_OF_SERVICE, RESERVED) |
| available_from | TIMESTAMP | When vehicle becomes available |
| available_until | TIMESTAMP | When vehicle expires (OUT_OF_SERVICE applied after) |
| is_available_period_active | BOOLEAN | Whether availability period is active |
| created_at | TIMESTAMP | Creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

---

## Status Workflow

```
AVAILABLE (within period) → [Time passes] → OUT_OF_SERVICE (after available_until)
           ↓
    Can transition to IN_SERVICE or RESERVED during bookings
           ↓
    Back to AVAILABLE when period is still active
```

---

## API Endpoints

### 1. Set Vehicle Availability Period
**Create or update the availability period for a vehicle**

```http
POST /api/v1/owners/{ownerId}/vehicles/{vehicleId}/availability/set
?availableFrom=2026-01-20T08:00:00
&availableUntil=2026-01-31T18:00:00
```

**Response:** `200 OK`
```json
{
  "id": "abc123...",
  "ownerId": "owner-uuid",
  "vehicleId": "vehicle-uuid",
  "status": "AVAILABLE",
  "availableFrom": "2026-01-20T08:00:00",
  "availableUntil": "2026-01-31T18:00:00",
  "isAvailablePeriodActive": true,
  "daysRemaining": 11,
  "createdAt": "2026-01-17T10:30:00",
  "updatedAt": "2026-01-17T10:30:00"
}
```

### 2. Get Vehicle Availability
**Retrieve current availability period for a vehicle**

```http
GET /api/v1/owners/{ownerId}/vehicles/{vehicleId}/availability
```

**Response:** `200 OK` (same as above)

### 3. Check If Vehicle Is Available
**Quick check if vehicle is currently available for booking**

```http
GET /api/v1/owners/{ownerId}/vehicles/{vehicleId}/availability/check-available
```

**Response:** `200 OK`
```json
true
```

### 4. Extend Vehicle Availability
**Extend the availability period to a new date**

```http
PUT /api/v1/owners/{ownerId}/vehicles/{vehicleId}/availability/extend
?newAvailableUntil=2026-02-15T18:00:00
```

**Response:** `200 OK` (updated availability)

**Use Case:** Owner wants to keep vehicle available longer
```
Before: available_until = 2026-01-31
After:  available_until = 2026-02-15
```

### 5. Mark Vehicle As Unavailable
**Immediately end availability and mark as OUT_OF_SERVICE**

```http
POST /api/v1/owners/{ownerId}/vehicles/{vehicleId}/availability/mark-unavailable
```

**Response:** `200 OK`
```json
{
  "id": "abc123...",
  "ownerId": "owner-uuid",
  "vehicleId": "vehicle-uuid",
  "status": "OUT_OF_SERVICE",
  "availableFrom": "2026-01-20T08:00:00",
  "availableUntil": "2026-01-17T10:30:00",
  "isAvailablePeriodActive": false,
  "daysRemaining": 0,
  "createdAt": "2026-01-17T10:30:00",
  "updatedAt": "2026-01-17T10:30:00"
}
```

### 6. Get All Owner Vehicles With Availability
**Get all vehicles owned by owner with pagination**

```http
GET /api/v1/owners/{ownerId}/vehicles/availability/owner/all
?page=0&size=10&sortBy=createdAt&direction=desc
```

**Response:** `200 OK`
```json
{
  "content": [
    {
      "id": "...",
      "ownerId": "owner-uuid",
      "vehicleId": "vehicle-uuid",
      "status": "AVAILABLE",
      "availableFrom": "2026-01-20T08:00:00",
      "availableUntil": "2026-01-31T18:00:00",
      "isAvailablePeriodActive": true,
      "daysRemaining": 11,
      "createdAt": "2026-01-17T10:30:00",
      "updatedAt": "2026-01-17T10:30:00"
    }
  ],
  "totalElements": 5,
  "totalPages": 1,
  "number": 0,
  "size": 10
}
```

### 7. Get Currently Available Vehicles
**Get only vehicles that are currently available for booking**

```http
GET /api/v1/owners/{ownerId}/vehicles/availability/owner/available
```

**Response:** `200 OK`
```json
[
  {
    "id": "...",
    "ownerId": "owner-uuid",
    "vehicleId": "vehicle-uuid",
    "status": "AVAILABLE",
    "availableFrom": "2026-01-20T08:00:00",
    "availableUntil": "2026-01-31T18:00:00",
    "isAvailablePeriodActive": true,
    "daysRemaining": 11,
    "createdAt": "2026-01-17T10:30:00",
    "updatedAt": "2026-01-17T10:30:00"
  }
]
```

### 8. Get Vehicles Expiring Soon
**Get vehicles that will expire within N days**

```http
GET /api/v1/owners/{ownerId}/vehicles/availability/expiring?daysThreshold=7
```

**Response:** `200 OK` (list of expiring vehicles)

**Use Case:** Notify owners about vehicles expiring in 7 days to extend them

---

## Automatic Processing

### Scheduled Task: Process Expired Availabilities
- **Runs:** Every 1 hour
- **Action:** Finds all vehicles with `available_until <= now` and status != OUT_OF_SERVICE
- **Sets:** Status to `OUT_OF_SERVICE` and `isAvailablePeriodActive` to false
- **Log:** All changes are logged for audit trail

```
Schedule: @Scheduled(fixedRate = 3600000) // 1 hour
```

### Scheduled Task: Check Expiring Vehicles
- **Runs:** Every 24 hours
- **Action:** Finds vehicles expiring within 7 days
- **Log:** Warning logs with vehicle and owner details
- **Future:** Can trigger notifications to owners

```
Schedule: @Scheduled(fixedRate = 86400000) // 24 hours
```

---

## Usage Examples

### Example 1: Owner Lists Their Vehicles and Availability

```bash
# Get all vehicles with availability
curl http://localhost:8087/api/v1/owners/owner-uuid/vehicles/availability/owner/all

# Get only currently available vehicles
curl http://localhost:8087/api/v1/owners/owner-uuid/vehicles/availability/owner/available

# Check if specific vehicle is available
curl http://localhost:8087/api/v1/owners/owner-uuid/vehicles/vehicle-uuid/availability/check-available
```

### Example 2: Owner Sets Availability for a Vehicle

```bash
# Vehicle will be available from Jan 20 to Jan 31
curl -X POST "http://localhost:8087/api/v1/owners/owner-uuid/vehicles/vehicle-uuid/availability/set" \
  -G \
  --data-urlencode "availableFrom=2026-01-20T08:00:00" \
  --data-urlencode "availableUntil=2026-01-31T18:00:00"
```

### Example 3: Owner Extends Availability Period

```bash
# Extend vehicle availability to Feb 15
curl -X PUT "http://localhost:8087/api/v1/owners/owner-uuid/vehicles/vehicle-uuid/availability/extend" \
  -G \
  --data-urlencode "newAvailableUntil=2026-02-15T18:00:00"
```

### Example 4: Owner Makes Vehicle Unavailable

```bash
# Immediately mark vehicle as OUT_OF_SERVICE
curl -X POST http://localhost:8087/api/v1/owners/owner-uuid/vehicles/vehicle-uuid/availability/mark-unavailable
```

### Example 5: Booking Service Checks Availability

```bash
# Check available vehicles before showing to customer
curl http://localhost:8087/api/v1/owners/owner-uuid/vehicles/availability/owner/available
```

---

## Business Rules

### Availability Period Logic
- **availableFrom:** Earliest date customer can book vehicle
- **availableUntil:** Latest date vehicle can be returned. After this time, status becomes OUT_OF_SERVICE
- **Current Status:** Status is AVAILABLE only if:
  - `now >= availableFrom` AND
  - `now <= availableUntil` AND
  - `isAvailablePeriodActive = true` AND
  - `status != OUT_OF_SERVICE`

### Status Transitions
```
Setting availability:
  → Sets status to AVAILABLE (if current time is within period)
  
Time passing (scheduled task):
  → availableUntil is reached → Status changed to OUT_OF_SERVICE
  
Extending availability:
  → If status is OUT_OF_SERVICE → Changes back to AVAILABLE
  → Extends the available_until date
  
Marking unavailable:
  → Immediately sets status to OUT_OF_SERVICE
  → Sets isAvailablePeriodActive to false
```

---

## Integration Points

### Booking Service
1. Query available vehicles: `GET /api/v1/owners/{ownerId}/vehicles/availability/owner/available`
2. Check specific vehicle: `GET /api/v1/owners/{ownerId}/vehicles/{vehicleId}/availability/check-available`
3. Should not allow booking after `availableUntil` date

### Notification System (Future)
1. Get expiring vehicles: `GET /api/v1/owners/{ownerId}/vehicles/availability/expiring?daysThreshold=7`
2. Send reminder emails to owners
3. Suggest extending availability periods

### Vehicle Service
1. Uses OwnersHasVehicle model to track availability
2. Automatic status updates via scheduler
3. Real-time availability checks

---

## Error Handling

### 400 Bad Request
```json
{
  "error": "Available until must be after available from"
}
```

### 404 Not Found
```json
{
  "error": "Vehicle availability not found for owner ..." 
}
```

### Invalid Date Format
```json
{
  "error": "Invalid date format. Use ISO 8601: 2026-01-20T08:00:00"
}
```

---

## Performance Considerations

### Indexes Recommended
```sql
CREATE INDEX idx_owner_vehicle ON owners_has_vehicles(owner_id, vehicle_id);
CREATE INDEX idx_available_until ON owners_has_vehicles(available_until);
CREATE INDEX idx_status_active ON owners_has_vehicles(status, is_available_period_active);
```

### Query Optimization
- `findExpiredAvailabilities()`: Uses index on available_until
- `findActiveAvailableVehicles()`: Uses index on status and availability
- `findVehiclesExpiringWithinDays()`: Scans upcoming dates efficiently

---

## Example Timeline

```
Jan 17, 2026 (Today)
  └─ Owner sets vehicle available: Jan 20 - Jan 31

Jan 20, 2026
  └─ AVAILABLE status active (within period)
  └─ Bookings can be created

Jan 25, 2026
  └─ Admin queries: daysRemaining = 6
  └─ Vehicles expiring within 7 days detected

Jan 31, 2026 @ 18:00:00
  └─ Period expires
  └─ Scheduler runs at 18:xx (next hour)
  └─ Status changed to OUT_OF_SERVICE
  └─ No more bookings allowed

Feb 1, 2026
  └─ Owner extends to Feb 15
  └─ Status changed back to AVAILABLE
  └─ Available until: Feb 15
```

---

## Summary

This system provides:
- ✅ **Time-Based Availability:** Set precise windows for vehicle availability
- ✅ **Automatic Management:** Scheduled tasks handle expiration automatically
- ✅ **Status Tracking:** Clear status transitions (AVAILABLE → OUT_OF_SERVICE)
- ✅ **Flexibility:** Extend or cancel availability at any time
- ✅ **Integration Ready:** Easy to integrate with booking and notification systems
- ✅ **Audit Trail:** All changes tracked with timestamps

**Key Feature:** After `availableUntil` date/time passes, vehicle is automatically marked as `OUT_OF_SERVICE` by the scheduled scheduler.
