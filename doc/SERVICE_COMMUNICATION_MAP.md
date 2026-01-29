# RIDE FLEX - SERVICE COMMUNICATION MAP

## Service Dependency Graph

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                        CLIENT APPLICATIONS                                  │
│              (Web, Mobile, Admin Dashboard)                                 │
└───────────────────────────────┬─────────────────────────────────────────────┘
                                │
                ┌───────────────┴──────────────┐
                │                              │
                ▼                              ▼
        ┌──────────────┐              ┌──────────────┐
        │   GATEWAY    │              │  KEYCLOAK    │
        │  SERVICE     │◄─────────────┤  OAUTH2      │
        │   (8080)     │              │  (51.75...)  │
        └──────┬───────┘              └──────────────┘
               │
    ┌──────────┼──────────┬──────────┬──────────┬──────────┐
    │          │          │          │          │          │
    ▼          ▼          ▼          ▼          ▼          ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐
│CLIENT  │ │OWNER   │ │ADMIN   │ │DISCOVERY
│  BFF   │ │  BFF   │ │  BFF   │ │SERVICE │ (API Router)
│ (8089) │ │ (8088) │ │ (8090) │ │(8761)  │
└───┬────┘ └────┬───┘ └────┬───┘ └────┬───┘
    │           │          │          │
    └───────────┼──────────┼──────────┘
                │
    ┌───────────┼───────────┬───────────┬───────────┬──────────────┬───────────┐
    │           │           │           │           │              │           │
    ▼           ▼           ▼           ▼           ▼              ▼           ▼
┌────────┐ ┌────────┐ ┌────────┐ ┌────────┐ ┌──────────┐ ┌──────────┐ ┌──────────┐
│ USER   │ │VEHICLE │ │BOOKING │ │PAYMENT │ │ PRICING  │ │  MAIL    │ │  AUTH    │
│SERVICE │ │SERVICE │ │SERVICE │ │SERVICE │ │SERVICE   │ │SERVICE   │ │SERVICE   │
│(8086)  │ │(8087)  │ │(8082)  │ │(8083)  │ │(8085)    │ │(8084)    │ │(8081)    │
└───┬────┘ └────┬───┘ └───┬────┘ └────┬───┘ └────┬─────┘ └────┬─────┘ └───┬──────┘
    │           │         │           │          │            │           │
    │           │         │           │          │            │           │
    └─────┬─────┴─┬───────┴────┬──────┴──────────┼────────────┼───────────┘
          │       │            │                 │            │
          ▼       ▼            ▼                 ▼            ▼
      ┌────────────────────────────────────────────────────────────┐
      │              MESSAGE BROKERS & CACHES                      │
      │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐    │
      │  │  RabbitMQ    │  │    Kafka     │  │    Redis     │    │
      │  │   (5672)     │  │   (9092)     │  │   (6379)     │    │
      │  └──────────────┘  └──────────────┘  └──────────────┘    │
      └────────────────────────────────────────────────────────────┘
          │                  │                      │
          ▼                  ▼                      ▼
    ┌─────────────────────────────────────────────────────────┐
    │              DATA STORES                                │
    │  ┌──────────────┐  ┌──────────────┐  ┌──────────────┐  │
    │  │PostgreSQL    │  │  MongoDB     │  │    Redis     │  │
    │  │(5433-5437)   │  │   (27017)    │  │   (6379)     │  │
    │  └──────────────┘  └──────────────┘  └──────────────┘  │
    └─────────────────────────────────────────────────────────┘
```

---

## Service-to-Service Communication Details

### 1. CLIENT BFF (8089)
**Dependencies:**
- ✅ Gateway Service (8080) - For routing
- ✅ Vehicle Service (8087) - Search vehicles
- ✅ Pricing Service (8085) - Get pricing
- ✅ Booking Service (8082) - Create/manage bookings
- ✅ Keycloak (Auth) - OAuth2 token validation
- ✅ User Service (8086) - User profile info
- ✅ Payment Service (8083) - Payment processing

**Communication Protocols:**
- REST/HTTP with Bearer Token authentication
- WebClient for async calls

**Data Exchange:**
```
Request: Vehicle search with location, dates, filters
↓
Response: Available vehicles with pricing, paginated results
```

---

### 2. OWNER BFF (8088)
**Dependencies:**
- ✅ Vehicle Service (8087) - Manage vehicles
- ✅ Pricing Service (8085) - Set pricing
- ✅ Booking Service (8082) - View bookings
- ✅ Payment Service (8083) - Track payments
- ✅ User Service (8086) - Owner profile
- ✅ Keycloak (Auth) - OAuth2 authentication

**Communication Protocols:**
- REST/HTTP
- Service-to-service OAuth2 (client_credentials)

**Endpoints Exposed:**
```
GET  /api/vehicles - List owner's vehicles
POST /api/vehicles - Add new vehicle
PUT  /api/vehicles/{id} - Update vehicle
GET  /api/bookings - View owner's bookings
GET  /api/pricing - View pricing
POST /api/pricing - Set pricing
```

---

### 3. ADMIN BFF (8090)
**Dependencies:**
- ✅ All core services for management
- ✅ Pricing Service - Commission management
- ✅ Vehicle Service - Body type management
- ✅ Keycloak - User/role management
- ✅ Mail Service - Notification management

**Admin Functions:**
```
Commission Management:
  - Create commission per body type
  - Update commission percentage
  - View commission reports

Vehicle Management:
  - Approve/reject vehicles
  - Manage body types
  - System-wide vehicle reports

User Management:
  - Create users/roles
  - Manage permissions
  - View user activity
```

---

### 4. AUTH SERVICE (8081)
**Dependencies:**
- ✅ Keycloak (External) - Token issuance
- ✅ RabbitMQ - Event distribution
- ✅ User Service (8086) - User validation
- ✅ Mail Service (8084) - Send auth emails

**Responsibilities:**
```
1. OAuth2 Token Generation
   - User authentication (password flow)
   - Service authentication (client credentials)
   - Token refresh

2. JWT Token Validation
   - Issue JWTs
   - Validate tokens
   - Manage token lifecycle

3. Authentication Events
   - Login events → RabbitMQ
   - Logout events → RabbitMQ
   - Failed attempts → RabbitMQ
```

---

### 5. USER SERVICE (8086)
**Dependencies:**
- ✅ Auth Service (8081) - JWT validation
- ✅ Keycloak - User sync
- ✅ Mail Service (8084) - Welcome emails
- ✅ PostgreSQL (5433) - User data
- ✅ RabbitMQ - User events

**Database:**
```
Users (userdb - PostgreSQL 5433)
  - user_id (PK)
  - email
  - first_name
  - last_name
  - phone_number
  - location (new - for driver location)
  - created_at
```

---

### 6. VEHICLE SERVICE (8087)
**Dependencies:**
- ✅ Auth Service (8081) - Token validation
- ✅ Pricing Service (8085) - Get pricing
- ✅ User Service (8086) - Owner info
- ✅ PostgreSQL (5437) - Vehicle data
- ✅ RabbitMQ - Vehicle events

**Database:**
```
vehicles (vehicledb - PostgreSQL 5437)
  - vehicle_id (PK)
  - body_type_id
  - registration_number
  - make
  - model
  - year
  
owners_has_vehicles (owner-vehicle relationship)
  - id (PK)
  - owner_id (FK → vehicle_owners)
  - vehicle_id (FK → vehicles)
  - location (PK for search)
  - available_from
  - available_until
  - status
  - created_at
```

**Search Endpoints:**
```
GET /api/v1/vehicles/available
  - Query: location, pickupDate, dropOffDate
  - Returns: Available vehicles with OwnersHasVehicle ID

GET /api/v1/vehicles/{id}
  - Returns: Vehicle details with pricing
```

---

### 7. BOOKING SERVICE (8082)
**Dependencies:**
- ✅ Auth Service (8081) - Token validation
- ✅ Vehicle Service (8087) - Vehicle details
- ✅ Pricing Service (8085) - Calculate cost
- ✅ User Service (8086) - User info
- ✅ Payment Service (8083) - Payment processing
- ✅ Mail Service (8084) - Booking confirmations
- ✅ MongoDB (27017) - Booking documents
- ✅ Kafka - Event streaming

**Database:**
```
MongoDB (ridedb)
  Collections:
  - bookings: Booking documents with full details
  - booking_status_history: Status transitions
  - booking_events: Event log
```

**Booking Lifecycle:**
```
Pending → Confirmed → In-Transit → Completed
   ↓                      ↓
Cancelled           Ongoing
```

---

### 8. PRICING SERVICE (8085)
**Dependencies:**
- ✅ Vehicle Service (8087) - Vehicle info
- ✅ Auth Service (8081) - Token validation
- ✅ PostgreSQL (5435) - Pricing data

**Database:**
```
PostgreSQL (pricingdb - 5435)
  Tables:
  - vehicle_prices: OwnersHasVehicle ID → pricing
    - vehicle_id (FK → OwnersHasVehicle.id)
    - price_per_day
    - price_per_week
    - price_per_month
    - commission_percentage
    - currency_code
    
  - commissions: Admin-set commission by body type
    - body_type_id
    - commission_percentage
    - applicable_from
    - applicable_until
```

**Pricing Lookup:**
```
Client BFF requests pricing:
  GET /api/v1/prices/{ownerHasVehicleId}
  ↓
Pricing Service calculates:
  Base price × (1 + commission%)
  ↓
Returns: daily, weekly, monthly rates with commission applied
```

---

### 9. PAYMENT SERVICE (8083)
**Dependencies:**
- ✅ Booking Service (8082) - Booking details
- ✅ Auth Service (8081) - Token validation
- ✅ Mail Service (8084) - Payment receipts
- ✅ PostgreSQL (5436) - Payment records

**Database:**
```
PostgreSQL (paymentdb - 5436)
  - payments: Payment transactions
  - payment_methods: Stored cards
  - payment_status_history: Transaction log
  - refunds: Refund records
```

**Payment Flow:**
```
Booking Created
  ↓
Payment Service processes:
  - Deduct commission
  - Transfer to owner
  - Keep platform fees
  ↓
Mail notification sent
```

---

### 10. MAIL SERVICE (8084)
**Dependencies:**
- ✅ Auth Service (8081) - Auth emails
- ✅ User Service (8086) - User emails
- ✅ Booking Service (8082) - Booking emails
- ✅ Payment Service (8083) - Payment emails
- ✅ PostgreSQL (5434) - Email templates
- ✅ External SMTP (51.75.119.133:1025)

**Email Templates:**
```
1. User Registration
2. Email Verification
3. Password Reset
4. Booking Confirmation
5. Booking Cancellation
6. Payment Receipt
7. Invoice
8. Admin Notifications
```

---

### 11. DISCOVERY SERVICE (8761) - Eureka
**Purpose:**
- Service registration and discovery
- Health check monitoring
- Load balancing

**Services Registered:**
```
- gateway-service
- auth-service
- user-service
- vehicle-service
- booking-service
- payment-service
- pricing-service
- mail-service
- client-bff
- owner-bff
- admin-bff
```

---

### 12. GATEWAY SERVICE (8080)
**Purpose:**
- API Gateway
- Request routing
- Load balancing
- Rate limiting
- Authentication (optional filter)

**Routes:**
```
/auth/**          → Auth Service (8081)
/users/**         → User Service (8086)
/vehicles/**      → Vehicle Service (8087)
/bookings/**      → Booking Service (8082)
/payments/**      → Payment Service (8083)
/pricing/**       → Pricing Service (8085)
/mail/**          → Mail Service (8084)

/client/**        → Client BFF (8089)
/owner/**         → Owner BFF (8088)
/admin/**         → Admin BFF (8090)
```

---

## Database Communication Map

```
PostgreSQL Databases (5433-5437):
├─ User Service DB (5433)      - Users, profiles, locations
├─ Vehicle Service DB (5437)   - Vehicles, OwnersHasVehicles
├─ Pricing Service DB (5435)   - Prices, commissions
├─ Payment Service DB (5436)   - Payments, transactions
└─ Mail Service DB (5434)      - Email templates, logs

MongoDB:
└─ Booking Service DB          - Bookings, documents

Caching (Redis):
└─ All services              - Session, token, query caching

Message Brokers:
├─ RabbitMQ (5672)           - Event distribution (Auth, User, Vehicle)
└─ Kafka (9092)              - Stream processing (Booking, Payment)
```

---

## Event Flow Examples

### Example 1: Vehicle Search Process

```
1. Client BFF receives search request
   POST /api/v1/search/advanced/vehicles
   {
     pickupLocation: "Colombo",
     pickupDate: "2026-02-01",
     userLocation: "Colombo"
   }

2. Client BFF calls Vehicle Service
   GET /api/v1/vehicles/available
   ?location=Colombo&pickupDate=2026-02-01&dropOffDate=2026-02-03

3. Vehicle Service queries PostgreSQL
   SELECT o FROM OwnersHasVehicle o
   WHERE o.owner.location = 'Colombo'
   AND o.availableFrom <= '2026-02-01'

4. Vehicle Service returns vehicles with OwnersHasVehicle IDs
   [
     {ownerHasVehicleId: "uuid1", vehicleId: "uuid", location: "Colombo"},
     {ownerHasVehicleId: "uuid2", vehicleId: "uuid", location: "Colombo"},
     {ownerHasVehicleId: "uuid3", vehicleId: "uuid", location: "Kandy"}
   ]

5. Client BFF enriches with pricing
   For each vehicle:
     GET /api/v1/prices/{ownerHasVehicleId}
     ↓
     Pricing Service returns per-day, per-week, per-month rates

6. Client BFF applies filters/sorting/pagination
   - Prioritize Colombo vehicles first
   - Filter by price range
   - Sort by price

7. Client sends response with:
   {
     success: true,
     vehicles: [
       {ownerHasVehicleId, location, pricePerDay, totalCost, ...}
     ],
     pagination: {pageNumber, totalPages, ...}
   }
```

### Example 2: Booking Creation Process

```
1. User creates booking
   POST /api/v1/bookings
   {
     vehicleId: "ownerHasVehicleId",
     pickupDate, dropOffDate,
     userId, location
   }

2. Booking Service:
   a. Get vehicle details from Vehicle Service
   b. Get pricing from Pricing Service
   c. Calculate total cost
   d. Create booking in MongoDB
   e. Publish booking-created event to RabbitMQ/Kafka

3. Events triggered:
   - Mail Service: Send confirmation email
   - Payment Service: Create payment record
   - User Service: Update user booking count

4. Payment Processing:
   - Deduct amount from user
   - Transfer to owner (after commission)
   - Keep platform fee
   - Log transaction

5. Notifications sent via Mail Service
   - Booking confirmation to user
   - New booking notification to owner
   - Admin notification if high-value booking
```

---

## Summary

✅ **13 services** with clear communication patterns
✅ **3 message brokers** for event-driven architecture
✅ **5 databases** for polyglot persistence
✅ **OAuth2/Keycloak** for centralized authentication
✅ **Microservice mesh** ready for production

**All service dependencies documented and configured!** 🚀

