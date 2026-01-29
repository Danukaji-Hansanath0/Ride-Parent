# Extra Equipment Management API Documentation

## Overview
This document describes the complete CRUD system for managing extra equipment (GPS, baby seats, etc.) and their relationships with vehicle owners in the Ride platform.

**Important:** This service manages equipment catalog and availability. **All pricing is handled by the dedicated Pricing Service** for better separation of concerns and centralized price management.

## Features
- ✅ Complete CRUD operations for equipment management
- ✅ Owner-Equipment relationship management (many-to-many)
- ✅ Enable/disable equipment per owner
- ✅ Automatic database seeding with 16 common equipment items
- ✅ Equipment categorization (SAFETY, COMFORT, ENTERTAINMENT, etc.)
- ✅ Equipment codes for pricing service integration
- ✅ Pagination and sorting support
- ✅ Full Swagger/OpenAPI documentation
- ✅ **Pricing Service Integration** via equipment codes

---

## Architecture: Separation of Concerns

### Vehicle Service (This Service)
- Manages equipment **catalog** (what equipment exists)
- Manages equipment **availability**
- Manages **owner-equipment relationships** (who has what equipment enabled)
- Provides equipment codes for pricing lookups

### Pricing Service (Separate Service)
- Manages all **pricing logic** for equipment
- Handles dynamic pricing, discounts, seasonal rates
- Calculates equipment costs based on duration
- Uses equipment codes to identify items

### Integration Flow
```
1. Customer books vehicle → Booking Service
2. Booking Service queries Vehicle Service: GET /api/v1/owners/{ownerId}/equipment/enabled
3. Customer selects equipment → Booking Service
4. Booking Service queries Pricing Service with equipment codes
5. Pricing Service returns calculated prices
6. Total booking cost = vehicle cost + equipment costs
```

---

## Database Schema

### Tables

#### 1. `extra_equipment`
Main equipment table storing all available equipment types.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| name | VARCHAR(100) | Equipment name (unique) |
| description | VARCHAR(500) | Equipment description |
| equipment_code | VARCHAR(50) | Code for pricing service (unique) |
| category | VARCHAR(50) | Equipment category |
| is_available | BOOLEAN | Availability status |
| icon_url | VARCHAR(255) | Icon/image URL |
| created_at | TIMESTAMP | Creation timestamp |
| updated_at | TIMESTAMP | Last update timestamp |

**Categories:**
- `SAFETY` - Safety equipment (chains, emergency kits, dash cams)
- `CHILD_SAFETY` - Child seats and boosters
- `COMFORT` - Comfort items (USB chargers, coolers, pet carriers)
- `ENTERTAINMENT` - Entertainment (WiFi, Bluetooth)
- `NAVIGATION` - Navigation (GPS, toll pass)
- `STORAGE` - Storage (roof boxes, racks)
- `OTHER` - Other equipment

#### 2. `owner_equipment`
Join table for many-to-many relationship between owners and equipment.

| Column | Type | Description |
|--------|------|-------------|
| id | UUID | Primary key |
| owner_id | UUID | Foreign key to vehicle_owners |
| equipment_id | UUID | Foreign key to extra_equipment |
| is_enabled | BOOLEAN | Whether equipment is enabled |
| enabled_at | TIMESTAMP | When equipment was enabled |

**Unique Constraint:** `(owner_id, equipment_id)` - Each owner can have each equipment only once.

---

## API Endpoints

### Equipment Management

#### 1. Create Equipment
```http
POST /api/v1/equipment
Content-Type: application/json

{
  "name": "GPS Navigation System",
  "description": "Advanced GPS with real-time traffic",
  "equipmentCode": "GPS_NAV_001",
  "category": "NAVIGATION",
  "isAvailable": true,
  "iconUrl": "https://example.com/icon.png"
}
```

**Response:** `201 Created`
```json
{
  "id": "123e4567-e89b-12d3-a456-426614174000",
  "name": "GPS Navigation System",
  "description": "Advanced GPS with real-time traffic",
  "equipmentCode": "GPS_NAV_001",
  "category": "NAVIGATION",
  "isAvailable": true,
  "iconUrl": "https://example.com/icon.png",
  "createdAt": "2026-01-17T10:30:00",
  "updatedAt": "2026-01-17T10:30:00"
}
```

**Note:** Use the `equipmentCode` when querying the Pricing Service for costs.

#### 2. Update Equipment
```http
PUT /api/v1/equipment/{equipmentId}
Content-Type: application/json

{
  "name": "GPS Navigation System Pro",
  "description": "Premium GPS with voice guidance",
  "equipmentCode": "GPS_NAV_001",
  "category": "NAVIGATION",
  "isAvailable": true,
  "iconUrl": "https://example.com/icon.png"
}
```

**Response:** `200 OK` (same structure as create)

#### 3. Get Equipment by ID
```http
GET /api/v1/equipment/{equipmentId}
```

**Response:** `200 OK` (equipment details)

#### 4. Get All Equipment (Paginated)
```http
GET /api/v1/equipment?page=0&size=10&sortBy=name&direction=asc
```

**Query Parameters:**
- `page`: Page number (0-based)
- `size`: Items per page
- `sortBy`: Sort field (name, category, equipmentCode, createdAt, etc.)
- `direction`: Sort direction (asc/desc)

**Response:** `200 OK`
```json
{
  "content": [
    {
      "id": "...",
      "name": "Additional Driver",
      "description": "...",
      "equipmentCode": "ADD_DRIVER_001",
      "category": "OTHER",
      "isAvailable": true,
      "iconUrl": "...",
      "createdAt": "...",
      "updatedAt": "..."
    }
  ],
  "pageable": {...},
  "totalElements": 16,
  "totalPages": 2,
  "last": false,
  "size": 10,
  "number": 0
}
```

#### 5. Get Available Equipment Only
```http
GET /api/v1/equipment/available
```

**Response:** `200 OK` (list of available equipment)

#### 6. Toggle Equipment Availability
```http
PATCH /api/v1/equipment/{equipmentId}/toggle-availability
```

**Response:** `200 OK` (updated equipment with toggled availability)

#### 7. Delete Equipment
```http
DELETE /api/v1/equipment/{equipmentId}
```

**Response:** `204 No Content`

---

### Owner Equipment Management

#### 1. Enable Equipment for Owner
```http
POST /api/v1/owners/{ownerId}/equipment/{equipmentId}/enable
```

**Response:** `200 OK`
```json
{
  "id": "abc123...",
  "ownerId": "owner-uuid",
  "equipmentId": "equipment-uuid",
  "equipment": {
    "id": "equipment-uuid",
    "name": "GPS Navigation System",
    "description": "...",
    "equipmentCode": "GPS_NAV_001",
    "category": "NAVIGATION",
    "isAvailable": true,
    "iconUrl": "..."
  },
  "isEnabled": true,
  "enabledAt": "2026-01-17T10:30:00"
}
```

**Note:** To get pricing for this equipment, query the Pricing Service using `equipmentCode`.

#### 2. Disable Equipment for Owner
```http
POST /api/v1/owners/{ownerId}/equipment/{equipmentId}/disable
```

**Response:** `200 OK` (same structure, isEnabled: false)

#### 3. Toggle Equipment for Owner
```http
POST /api/v1/owners/{ownerId}/equipment/{equipmentId}/toggle
```

**Response:** `200 OK` (toggles isEnabled status)

#### 4. Remove Equipment from Owner
```http
DELETE /api/v1/owners/{ownerId}/equipment/{equipmentId}
```

**Response:** `204 No Content`

#### 5. Get All Owner Equipment
```http
GET /api/v1/owners/{ownerId}/equipment
```

**Response:** `200 OK` (list of all equipment for owner, enabled and disabled)

#### 6. Get Enabled Owner Equipment
```http
GET /api/v1/owners/{ownerId}/equipment/enabled
```

**Response:** `200 OK` (list of only enabled equipment)

#### 7. Check Equipment Status for Owner
```http
GET /api/v1/owners/{ownerId}/equipment/{equipmentId}/status
```

**Response:** `200 OK`
```json
true
```

#### 8. Enable Multiple Equipment Items
```http
POST /api/v1/owners/{ownerId}/equipment/enable-multiple
Content-Type: application/json

[
  "equipment-uuid-1",
  "equipment-uuid-2",
  "equipment-uuid-3"
]
```

**Response:** `200 OK` (list of created/updated relationships)

---

## Seeded Equipment

The system automatically seeds 16 equipment items on startup with the following equipment codes:

| Equipment | Code | Category |
|-----------|------|----------|
| GPS Navigation System | `GPS_NAV_001` | NAVIGATION |
| Child Safety Seat (0-4 years) | `CHILD_SEAT_001` | CHILD_SAFETY |
| Booster Seat (4-12 years) | `BOOSTER_SEAT_001` | CHILD_SAFETY |
| Additional Driver | `ADD_DRIVER_001` | OTHER |
| Ski Rack | `SKI_RACK_001` | STORAGE |
| Bike Rack | `BIKE_RACK_001` | STORAGE |
| Roof Storage Box | `ROOF_BOX_001` | STORAGE |
| Snow Chains | `SNOW_CHAIN_001` | SAFETY |
| Portable WiFi Hotspot | `WIFI_HOTSPOT_001` | ENTERTAINMENT |
| Automatic Toll Pass | `TOLL_PASS_001` | NAVIGATION |
| Multi-Port USB Charger | `USB_CHARGER_001` | COMFORT |
| Bluetooth Audio Adapter | `BT_AUDIO_001` | ENTERTAINMENT |
| Dashboard Camera | `DASH_CAM_001` | SAFETY |
| Emergency Roadside Kit | `EMERGENCY_KIT_001` | SAFETY |
| Pet Travel Carrier | `PET_CARRIER_001` | COMFORT |
| Electric Cooler Box | `COOLER_BOX_001` | COMFORT |

**Note:** Use these equipment codes when querying the **Pricing Service** for cost calculations.

---

## Usage Examples

### Example 1: Vehicle Owner Enables GPS for Their Vehicles

```bash
# 1. Get owner ID (from authentication or user service)
OWNER_ID="123e4567-e89b-12d3-a456-426614174000"

# 2. Get available equipment
curl http://localhost:8087/api/v1/equipment/available

# 3. Enable GPS for owner
curl -X POST http://localhost:8087/api/v1/owners/$OWNER_ID/equipment/gps-uuid/enable

# 4. Get all enabled equipment for owner
curl http://localhost:8087/api/v1/owners/$OWNER_ID/equipment/enabled
```

### Example 2: Admin Creates New Equipment

```bash
curl -X POST http://localhost:8087/api/v1/equipment \
  -H "Content-Type: application/json" \
  -d '{
    "name": "Satellite Radio",
    "description": "Premium satellite radio subscription",
    "equipmentCode": "SAT_RADIO_001",
    "category": "ENTERTAINMENT",
    "isAvailable": true,
    "iconUrl": "https://example.com/radio.png"
  }'
```

**Note:** After creating the equipment, add pricing in the Pricing Service using code `SAT_RADIO_001`.

### Example 3: Owner Enables Multiple Equipment at Once

```bash
curl -X POST http://localhost:8087/api/v1/owners/$OWNER_ID/equipment/enable-multiple \
  -H "Content-Type: application/json" \
  -d '[
    "gps-uuid",
    "wifi-uuid",
    "dashcam-uuid"
  ]'
```

---

## Error Handling

### Common Error Responses

#### 400 Bad Request
```json
"Equipment with name 'GPS Navigation System' already exists"
```

#### 404 Not Found
```json
"Equipment not found with ID: 123e4567..."
```

#### 409 Conflict
```json
"Equipment is not available: GPS Navigation System"
```

---

## Business Logic

### Equipment Availability
- Equipment marked as `isAvailable: false` cannot be enabled for new owners
- Existing owner-equipment relationships remain valid even if equipment becomes unavailable
- Owners can toggle their enabled equipment without affecting other owners

### Owner Equipment Relationships
- Each owner can have each equipment item only once (enforced by unique constraint)
- Enabling equipment that already exists will update the existing record
- Disabling equipment sets `isEnabled: false` but keeps the relationship
- Removing equipment deletes the relationship entirely

### Equipment Codes & Pricing Service Integration
- Each equipment has a unique `equipmentCode` (e.g., `GPS_NAV_001`)
- Equipment codes are used by the Pricing Service to look up prices
- Pricing Service handles: base prices, dynamic pricing, discounts, seasonal rates
- This separation allows flexible pricing without changing equipment catalog

---

## Integration with Booking System

When a booking is created:

1. **Get Available Equipment:** `GET /api/v1/equipment/available`
2. **Check Owner's Equipment:** `GET /api/v1/owners/{ownerId}/equipment/enabled`
3. **Customer Selects Equipment** from owner's enabled list
4. **Query Pricing Service:** Send equipment codes to pricing service
   ```
   POST /api/v1/pricing/calculate-equipment
   {
     "equipmentCodes": ["GPS_NAV_001", "WIFI_HOTSPOT_001"],
     "startDate": "2026-01-20",
     "endDate": "2026-01-25",
     "vehicleType": "LUXURY"
   }
   ```
5. **Pricing Service Returns:** Calculated costs for each equipment
6. **Calculate Total:** `vehicle_cost + equipment_costs`

---

## Testing with curl

```bash
# Set base URL
BASE_URL="http://localhost:8087/api/v1"

# Test equipment CRUD
curl $BASE_URL/equipment/available
curl $BASE_URL/equipment?page=0&size=5

# Test owner equipment (replace UUIDs with actual values)
curl -X POST $BASE_URL/owners/{ownerId}/equipment/{equipmentId}/enable
curl $BASE_URL/owners/{ownerId}/equipment/enabled
curl $BASE_URL/owners/{ownerId}/equipment/{equipmentId}/status
```

---

## Notes

- All IDs are UUIDs (Version 4)
- Timestamps are in ISO 8601 format
- All endpoints return JSON
- Pagination uses 0-based page numbers
- Sort fields must match entity property names
- The seeder only runs once (checks if data exists before seeding)

---

## Future Enhancements

Potential future features:
- Equipment images/gallery (multiple images per equipment)
- Equipment reviews and ratings from customers
- Equipment maintenance tracking and service history
- Equipment insurance options
- Bulk operations for admin (enable/disable multiple items)
- Equipment analytics (most popular items, usage statistics)
- Equipment availability by location/region
- Equipment condition tracking (new, good, fair)
- Equipment age and lifecycle management
- Multi-language support for equipment descriptions

---

## Summary

This equipment management system provides:
- ✅ **Separation of Concerns**: Equipment catalog separate from pricing
- ✅ **Flexibility**: Owners can enable/disable equipment independently
- ✅ **Scalability**: Easy to add new equipment types
- ✅ **Integration Ready**: Equipment codes for seamless pricing service integration
- ✅ **Clean Architecture**: RESTful API with proper domain modeling

For pricing queries, always use the **Pricing Service** with equipment codes from this service.
