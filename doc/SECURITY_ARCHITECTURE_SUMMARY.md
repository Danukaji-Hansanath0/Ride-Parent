# Security Architecture Summary - Ride Flexi Microservices

## Overview
This document provides a comprehensive overview of the security architecture implemented across all Ride Flexi microservices.

**Last Updated:** January 26, 2026

---

## Table of Contents
1. [Authentication Architecture](#authentication-architecture)
2. [Service Security Configurations](#service-security-configurations)
3. [Role-Based Access Control (RBAC)](#role-based-access-control-rbac)
4. [Gateway Security](#gateway-security)
5. [Multi-Realm JWT Support](#multi-realm-jwt-support)
6. [Testing Security](#testing-security)

---

## Authentication Architecture

### Keycloak Realms

#### 1. **user-authentication** Realm
- **Purpose:** End-user authentication (web/mobile clients)
- **Users:** CUSTOMER, DRIVER, CAR_OWNER
- **Token Issuer:** `http://57.128.201.210:8083/realms/user-authentication`
- **JWKS Endpoint:** `http://57.128.201.210:8083/realms/user-authentication/protocol/openid-connect/certs`

#### 2. **service-authentication** Realm  
- **Purpose:** Service-to-service authentication
- **Users:** ADMIN, FRANCHISE_ADMIN, SERVICE, SYSTEM
- **Token Issuer:** `http://57.128.201.210:8083/realms/service-authentication`
- **JWKS Endpoint:** `http://57.128.201.210:8083/realms/service-authentication/protocol/openid-connect/certs`

### JWT Token Flow

```
┌─────────────┐         ┌──────────────┐         ┌─────────────┐
│   Client    │  Login  │   Keycloak   │  Token  │   Gateway   │
│  (Web/App)  │────────>│    Realm     │────────>│   Service   │
└─────────────┘         └──────────────┘         └─────────────┘
                              │                          │
                              │                    JWT Validation
                              │                    (JWKS Public Key)
                              │                          │
                              ▼                          ▼
                        ┌──────────────┐         ┌─────────────┐
                        │  JWT Token   │         │ Downstream  │
                        │  with Roles  │         │  Services   │
                        └──────────────┘         └─────────────┘
```

---

## Service Security Configurations

### 1. **Discovery Service** (Port: 8761)

#### Security Features:
- ✅ Basic Authentication for Eureka Dashboard
- ✅ Role-based access for service registration
- ✅ No JWT required (infrastructure service)

#### Configuration:
```yaml
spring:
  security:
    user:
      name: eureka
      password: eureka-secret
```

#### Access:
- **Dashboard:** http://localhost:8761 (requires basic auth)
- **Public Endpoints:** `/actuator/health`

---

### 2. **Gateway Service** (Port: 8080)

#### Security Features:
- ✅ JWT Authentication (Multi-Realm)
- ✅ JWKS-based public key validation
- ✅ Rate Limiting (Token Bucket)
- ✅ Request routing with auth propagation
- ✅ CORS Support
- ✅ Dynamic JWKS refresh

#### Key Components:
```java
AuthorizationFilter.java
├── Multi-realm JWT validation
├── JWKS endpoint fetching
├── Public key caching (by kid)
├── User context propagation
└── Graceful degradation (dev mode)
```

#### Request Headers Added:
- `X-User-Id`: User's unique identifier
- `X-Username`: Preferred username
- `X-Email`: User's email
- `X-Token`: Original JWT token
- `X-Auth-Realm`: Source realm (user-authentication or service-authentication)

#### Public Endpoints:
- `/actuator/**` - Health checks
- `/swagger-ui/**` - API documentation
- `/v3/api-docs/**` - OpenAPI specs

---

### 3. **Pricing Service** (Port: 8085)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Multi-realm JWT decoder
    // Role extraction from realm_access and resource_access
}
```

#### Protected Endpoints:

| Endpoint | Method | Roles Required |
|----------|--------|----------------|
| `/api/v1/price/getPrice` | POST | CUSTOMER, DRIVER, CAR_OWNER, ADMIN, SERVICE |
| `/api/v1/price/currencyPair` | POST | Authenticated |
| `/api/v1/price/owners/{userId}/vehicles/{vehicleId}` | GET | CAR_OWNER, ADMIN, SERVICE |
| `/api/v1/price` | POST | CAR_OWNER, ADMIN, SERVICE |
| `/api/v1/commissions` | POST | ADMIN, FRANCHISE_ADMIN, SERVICE |
| `/api/v1/commissions/{id}` | GET | Authenticated |
| `/api/v1/commissions/{id}` | PUT | ADMIN, FRANCHISE_ADMIN, SERVICE |
| `/api/v1/commissions/{id}` | DELETE | ADMIN, SYSTEM |

#### Role-Based Method Security:
```java
@PreAuthorize("hasAnyRole('CAR_OWNER', 'ADMIN', 'SERVICE')")
public ResponseEntity<VehiclePriceDto> addPrice(...)

@PreAuthorize("hasAnyRole('ADMIN', 'FRANCHISE_ADMIN', 'SERVICE')")
public ResponseEntity<CommissionDto> createCommission(...)
```

---

### 4. **User Service** (Port: 8081)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Multi-realm JWT decoder
    // Role extraction with user-service client roles
}
```

#### Protected Endpoints:

| Endpoint | Method | Roles Required | Notes |
|----------|--------|----------------|-------|
| `/api/v1/users` | POST | Public | Used by auth-service via RabbitMQ |
| `/api/v1/users/all` | GET | ADMIN, FRANCHISE_ADMIN, SERVICE | Admin only |
| `/api/v1/users/profile/{email}` | GET | Authenticated | Own profile or admin |
| `/api/v1/users` | PUT | Authenticated | Own profile or admin |
| `/api/v1/users/{email}` | DELETE | ADMIN or Own Profile | Soft delete |

#### Role-Based Method Security:
```java
@PreAuthorize("hasAnyRole('ADMIN', 'FRANCHISE_ADMIN', 'SERVICE')")
public ResponseEntity<Page<UserResponse>> getAllUsers(...)

@PreAuthorize("isAuthenticated()")
public ResponseEntity<ProfileResponse> getUserProfile(...)

@PreAuthorize("hasAnyRole('ADMIN', 'SYSTEM') or #email == authentication.principal.claims['email']")
public ResponseEntity<UserResponse> deleteUser(@PathVariable String email)
```

---

### 5. **Vehicle Service** (Port: 8087)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Multi-realm JWT decoder
    // Role extraction from realm_access and resource_access
}
```

#### Protected Endpoints:

| Endpoint | Method | Roles Required | Notes |
|----------|--------|----------------|-------|
| `/api/v1/vehicles/register` | POST | CAR_OWNER, ADMIN, SERVICE | Register vehicle |
| `/api/v1/vehicles/search` | POST | CUSTOMER, DRIVER, CAR_OWNER | Search vehicles |
| `/api/v1/vehicles/{id}` | GET | Authenticated | View vehicle details |
| `/api/v1/vehicles/{id}` | PUT | CAR_OWNER (owner), ADMIN | Update vehicle |
| `/api/v1/vehicles/{id}` | DELETE | CAR_OWNER (owner), ADMIN, SYSTEM | Soft delete |

#### Key Features:
- ✅ Elasticsearch integration for vehicle search
- ✅ Kafka event streaming for vehicle updates
- ✅ RabbitMQ for image processing events
- ✅ Owner-vehicle relationship validation

---

### 6. **Booking Service** (Port: 8083)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Multi-realm JWT decoder
    // Role extraction for booking operations
}
```

#### Protected Endpoints:

| Endpoint | Method | Roles Required | Notes |
|----------|--------|----------------|-------|
| `/api/v1/bookings` | POST | CUSTOMER | Create booking |
| `/api/v1/bookings/{id}` | GET | CUSTOMER (own), DRIVER, CAR_OWNER, ADMIN | View booking |
| `/api/v1/bookings/{id}/accept` | POST | CAR_OWNER (vehicle owner) | Accept booking |
| `/api/v1/bookings/{id}/cancel` | POST | CUSTOMER (own), CAR_OWNER, ADMIN | Cancel booking |
| `/api/v1/bookings/customer/{id}` | GET | CUSTOMER (own), ADMIN | View customer bookings |
| `/api/v1/bookings/owner/{id}` | GET | CAR_OWNER (own), ADMIN | View owner bookings |

---

### 7. **Payment Service** (Port: 8086)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Multi-realm JWT decoder
    // Role extraction for payment operations
}
```

#### Protected Endpoints:

| Endpoint | Method | Roles Required | Notes |
|----------|--------|----------------|-------|
| `/api/v1/payments` | POST | CUSTOMER | Create payment |
| `/api/v1/payments/{id}` | GET | CUSTOMER (own), CAR_OWNER, ADMIN | View payment |
| `/api/v1/payments/{id}/status` | PUT | SERVICE, SYSTEM | Update payment status |
| `/api/v1/payments/booking/{bookingId}` | GET | CUSTOMER, CAR_OWNER, ADMIN | Get booking payments |

---

### 8. **Auth Service** (Port: 8082)

#### Security Configuration:
- **Public Endpoints:** Login, Register, Password Reset
- **Protected Endpoints:** Token refresh, User management

#### Key Features:
- ✅ Keycloak integration for authentication
- ✅ RabbitMQ integration for user creation events
- ✅ OAuth2/OpenID Connect flows
- ✅ Multi-realm support

#### Public Endpoints:
- `/api/v1/auth/register`
- `/api/v1/auth/login`
- `/api/v1/auth/forgot-password`

---

### 9. **Mail Service** (Port: 8084)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Service-to-service authentication only
}
```

#### Protected Endpoints:

| Endpoint | Method | Roles Required | Notes |
|----------|--------|----------------|-------|
| `/api/v1/mail/send` | POST | SERVICE, SYSTEM | Send email |
| `/api/v1/mail/template/{id}` | POST | SERVICE, SYSTEM | Send templated email |

---

### 10. **Admin BFF** (Port: 8089)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Admin-only authentication
}
```

#### Protected Endpoints:
- All endpoints require **ADMIN** or **FRANCHISE_ADMIN** role
- Dashboard analytics
- User management
- System configuration

---

### 11. **Owner BFF** (Port: 8088)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Car owner authentication
}
```

#### Protected Endpoints:
- All endpoints require **CAR_OWNER** role
- Vehicle registration with pricing
- Booking management
- Revenue analytics

---

### 12. **Client BFF** (Port: 8090)

#### Security Configuration:
```java
@EnableMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // Customer authentication
}
```

#### Protected Endpoints:
- All endpoints require **CUSTOMER** role
- Vehicle search and booking
- Payment processing
- Booking history

---

## Role-Based Access Control (RBAC)

### Roles Hierarchy

```
┌─────────────────────────────────────────────────────────┐
│                     SYSTEM (Highest)                     │
│  - Full system access                                    │
│  - Service-to-service operations                         │
│  - Critical data operations                              │
└─────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────┐
│                        ADMIN                             │
│  - All user management                                   │
│  - System configuration                                  │
│  - View all data                                         │
└─────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────────────────────────────────────┐
│                   FRANCHISE_ADMIN                        │
│  - Franchise management                                  │
│  - Vehicle owner management                              │
│  - Franchise analytics                                   │
└─────────────────────────────────────────────────────────┘
                           │
┌─────────────────────────┬───────────────┬───────────────┐
│       CAR_OWNER         │    DRIVER     │   CUSTOMER    │
│  - Vehicle management   │ - Trip mgmt   │ - Bookings    │
│  - Booking acceptance   │ - Earnings    │ - Payments    │
│  - Revenue analytics    │ - Ratings     │ - Reviews     │
└─────────────────────────┴───────────────┴───────────────┘
```

### Role Permissions Matrix

| Operation | CUSTOMER | DRIVER | CAR_OWNER | ADMIN | FRANCHISE_ADMIN | SERVICE | SYSTEM |
|-----------|----------|--------|-----------|-------|-----------------|---------|--------|
| Create Booking | ✅ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Accept Booking | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Register Vehicle | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| View All Users | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Manage Pricing | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ | ✅ |
| Update Commission | ❌ | ❌ | ❌ | ✅ | ✅ | ✅ | ✅ |
| Process Payment | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| Send Email | ❌ | ❌ | ❌ | ❌ | ❌ | ✅ | ✅ |
| View Own Profile | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ | ✅ |

---

## Gateway Security

### AuthorizationFilter Implementation

#### Key Features:
1. **Multi-Realm Support:** Validates tokens from both user-authentication and service-authentication realms
2. **JWKS Integration:** Fetches and caches RSA public keys from Keycloak
3. **Dynamic Key Rotation:** Automatically refetches JWKS when unknown 'kid' is encountered
4. **Token Validation:** Verifies JWT signature using appropriate public key
5. **User Context Propagation:** Adds user information to downstream request headers

#### Token Validation Flow:

```
1. Extract JWT from Authorization header
2. Parse token to get issuer and kid
3. Determine realm (user-authentication or service-authentication)
4. Get public key from cache or fetch from JWKS endpoint
5. Validate JWT signature
6. Extract user claims
7. Add user context to request headers
8. Forward to downstream service
```

#### JWKS Caching Strategy:

```java
// Separate caches for each realm
Map<String, PublicKey> userAuthPublicKeyCache = new ConcurrentHashMap<>();
Map<String, PublicKey> serviceAuthPublicKeyCache = new ConcurrentHashMap<>();

// Pre-fetch on startup
@PostConstruct
public void init() {
    fetchJwks(userAuthJwksUri, userAuthPublicKeyCache);
    fetchJwks(serviceAuthJwksUri, serviceAuthPublicKeyCache);
}

// Refresh on unknown kid
if (!keyCache.containsKey(kid)) {
    fetchJwks(jwksUri, keyCache);
}
```

---

## Multi-Realm JWT Support

### MultiRealmJwtDecoder Configuration

Each service implements a `MultiRealmJwtDecoder` that:
1. Accepts tokens from multiple issuers
2. Validates tokens using appropriate JWKS endpoint
3. Extracts roles from both realm_access and resource_access claims

#### Example Configuration:

```java
@Configuration
public class MultiRealmJwtDecoder implements JwtDecoder {
    
    @Value("${spring.security.oauth2.client.provider.user-auth.issuer-uri}")
    private String userAuthIssuerUri;
    
    @Value("${spring.security.oauth2.client.provider.service-auth.issuer-uri}")
    private String serviceAuthIssuerUri;
    
    @Override
    public Jwt decode(String token) throws JwtException {
        // Try user-authentication realm
        // Try service-authentication realm
        // Throw exception if both fail
    }
}
```

### Application Properties Template:

```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          user-auth:
            issuer-uri: http://57.128.201.210:8083/realms/user-authentication
          service-auth:
            issuer-uri: http://57.128.201.210:8083/realms/service-authentication
      resourceserver:
        jwt:
          issuer-uri: http://57.128.201.210:8083/realms/user-authentication
```

---

## Testing Security

### 1. Get JWT Token from Keycloak

#### User Authentication:
```bash
curl -X POST http://57.128.201.210:8083/realms/user-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=ride-flexi-client" \
  -d "username=customer@example.com" \
  -d "password=password123"
```

#### Service Authentication:
```bash
curl -X POST http://57.128.201.210:8083/realms/service-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=client_credentials" \
  -d "client_id=pricing-service" \
  -d "client_secret=<client-secret>"
```

### 2. Test Protected Endpoint

```bash
# Get token
TOKEN=$(curl -s -X POST http://57.128.201.210:8083/realms/user-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "grant_type=password" \
  -d "client_id=ride-flexi-client" \
  -d "username=customer@example.com" \
  -d "password=password123" | jq -r '.access_token')

# Use token
curl -X GET http://localhost:8080/api/v1/users/profile/customer@example.com \
  -H "Authorization: Bearer $TOKEN"
```

### 3. Test Role-Based Access

```bash
# Admin endpoint (should succeed with ADMIN role)
curl -X GET http://localhost:8080/api/v1/users/all \
  -H "Authorization: Bearer $ADMIN_TOKEN"

# Admin endpoint (should fail with CUSTOMER role)
curl -X GET http://localhost:8080/api/v1/users/all \
  -H "Authorization: Bearer $CUSTOMER_TOKEN"
# Expected: 403 Forbidden
```

---

## Security Best Practices

### 1. **Token Management**
- ✅ Short-lived access tokens (5-15 minutes)
- ✅ Refresh token rotation
- ✅ Token revocation support
- ✅ Secure token storage (HttpOnly cookies)

### 2. **JWKS Management**
- ✅ Public key caching
- ✅ Automatic key rotation support
- ✅ Multiple key support (kid-based)
- ✅ Fallback mechanisms

### 3. **Rate Limiting**
- ✅ Token bucket algorithm
- ✅ Per-user rate limits
- ✅ IP-based rate limits
- ✅ Endpoint-specific limits

### 4. **CORS Configuration**
- ✅ Whitelist allowed origins
- ✅ Credential support
- ✅ Preflight caching
- ✅ Method restrictions

### 5. **Audit Logging**
- ✅ Authentication attempts
- ✅ Authorization failures
- ✅ Sensitive data access
- ✅ Administrative operations

---

## Deployment Checklist

### Pre-Production
- [ ] Update Keycloak realm configurations
- [ ] Generate and secure client secrets
- [ ] Configure HTTPS for all services
- [ ] Set up certificate management
- [ ] Enable audit logging
- [ ] Configure rate limiting
- [ ] Set up monitoring and alerts
- [ ] Test all authentication flows
- [ ] Verify role-based access control
- [ ] Test token rotation
- [ ] Review security headers
- [ ] Enable CORS restrictions

### Production
- [ ] Use production Keycloak instance
- [ ] Enable token encryption
- [ ] Configure session management
- [ ] Set up DDoS protection
- [ ] Enable WAF (Web Application Firewall)
- [ ] Configure intrusion detection
- [ ] Set up security monitoring
- [ ] Regular security audits
- [ ] Penetration testing
- [ ] Compliance verification

---

## Troubleshooting

### Common Issues

#### 1. **401 Unauthorized - Invalid Token**
```
Possible causes:
- Expired token
- Invalid signature
- Wrong issuer
- Missing roles

Solution:
- Verify token expiration
- Check JWKS endpoint
- Verify realm configuration
- Check role assignments in Keycloak
```

#### 2. **403 Forbidden - Insufficient Permissions**
```
Possible causes:
- Missing required role
- Incorrect role mapping
- Token from wrong realm

Solution:
- Verify user roles in Keycloak
- Check @PreAuthorize annotations
- Verify role extraction in JwtAuthenticationConverter
```

#### 3. **Failed to Fetch JWKS**
```
Possible causes:
- Keycloak server down
- Network connectivity issues
- Incorrect JWKS URI

Solution:
- Verify Keycloak server status
- Check network connectivity
- Verify issuer-uri configuration
```

---

## Monitoring and Metrics

### Key Metrics to Monitor:
1. **Authentication Success/Failure Rate**
2. **Token Validation Duration**
3. **JWKS Cache Hit Rate**
4. **Authorization Denials by Endpoint**
5. **Rate Limit Triggers**
6. **Suspicious Activity Patterns**

### Recommended Tools:
- **Prometheus:** Metrics collection
- **Grafana:** Metrics visualization
- **ELK Stack:** Log aggregation and analysis
- **Jaeger:** Distributed tracing

---

## Conclusion

This security architecture provides:
- ✅ Enterprise-grade authentication and authorization
- ✅ Multi-realm support for different user types
- ✅ Fine-grained access control
- ✅ Scalable and maintainable design
- ✅ Production-ready security features

For questions or support, contact: support@rydeflexi.com

---

**Document Version:** 1.0.0  
**Last Updated:** January 26, 2026  
**Maintained By:** Ride Flexi Security Team
