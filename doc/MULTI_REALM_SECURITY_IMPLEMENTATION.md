# Multi-Realm Security Implementation Guide

## Overview

This document describes the standardized security configuration implemented across all Ride services.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         Keycloak Server                         │
│  https://auth.rydeflexi.com                                     │
├─────────────────────────────────────────────────────────────────┤
│                                                                 │
│  ┌─────────────────────────────┐  ┌───────────────────────────┐│
│  │  user-authentication realm  │  │ service-authentication    ││
│  │  - For end users            │  │ realm                     ││
│  │  - Web/Mobile clients       │  │ - For service-to-service  ││
│  │  - Roles: CUSTOMER, DRIVER, │  │ - Roles: SERVICE, SYSTEM  ││
│  │    CAR_OWNER, ADMIN         │  │                           ││
│  └─────────────────────────────┘  └───────────────────────────┘│
└─────────────────────────────────────────────────────────────────┘
                            │
                            │ Issues JWT tokens
                            ▼
┌─────────────────────────────────────────────────────────────────┐
│                      API Gateway (8080)                         │
│  - Validates JWT from BOTH realms                               │
│  - Routes to appropriate services                               │
│  - Adds user context headers (X-User-Id, X-Username, etc.)     │
└─────────────────────────────────────────────────────────────────┘
                            │
        ┌───────────────────┼───────────────────┐
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│ auth-service │   │ user-service │   │vehicle-service│
│   (8081)     │   │   (8086)     │   │   (8087)     │
│ Multi-realm  │   │ Multi-realm  │   │ Multi-realm  │
└──────────────┘   └──────────────┘   └──────────────┘
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│booking-service│  │pricing-service│  │payment-service│
│   (8082)     │   │   (8083)     │   │   (8084)     │
│ Multi-realm  │   │ Multi-realm  │   │ Multi-realm  │
└──────────────┘   └──────────────┘   └──────────────┘
        ▼                   ▼                   ▼
┌──────────────┐   ┌──────────────┐   ┌──────────────┐
│  owner-bff   │   │  client-bff  │   │  admin-bff   │
│   (8088)     │   │   (8089)     │   │   (8090)     │
│ Multi-realm  │   │ Multi-realm  │   │ Multi-realm  │
└──────────────┘   └──────────────┘   └──────────────┘
        ▼
┌──────────────┐
│ mail-service │
│   (8085)     │
│ Multi-realm  │
└──────────────┘
```

## Components

### 1. MultiRealmJwtDecoder
- Decodes and validates JWT tokens from multiple Keycloak realms
- Supports both user-authentication and service-authentication realms
- Handles token expiration and validation errors gracefully

### 2. SecurityConfig
- Configures HTTP security for each service
- Defines public and protected endpoints
- Enables OAuth2 Resource Server with JWT
- Adds role extraction from JWT claims

### 3. MultiJwtProps
- Configuration properties for JWT issuers
- Reads from environment variables or application.yml

### 4. Method Security
- `@PreAuthorize` annotations on controller methods
- Role-based access control (RBAC)
- Authority-based permissions

## Realms

### user-authentication Realm
**Purpose**: End-user authentication (web/mobile clients)
**Issuer**: `https://auth.rydeflexi.com/realms/user-authentication`
**Roles**:
- `CUSTOMER` - Regular customers who book rides
- `DRIVER` - Drivers who provide rides
- `CAR_OWNER` - Vehicle owners who rent out vehicles
- `FRANCHISE_ADMIN` - Franchise administrators
- `ADMIN` - System administrators
- `SUPER_ADMIN` - Super administrators

**Use Cases**:
- User registration and login
- Profile updates
- Booking rides
- Managing vehicles
- Admin operations

### service-authentication Realm
**Purpose**: Service-to-service communication
**Issuer**: `https://auth.rydeflexi.com/realms/service-authentication`
**Roles**:
- `SERVICE` - Standard service account
- `SYSTEM` - System-level service account
- `INTERNAL` - Internal service communication

**Use Cases**:
- Auth-service calling User-service
- Booking-service calling Vehicle-service
- Pricing-service calling Vehicle-service
- Payment-service calling Booking-service

## Standard Security Configuration

### Public Endpoints (No Authentication)
All services should allow these without JWT:
- `/actuator/**` - Health checks and metrics
- `/v3/api-docs/**` - OpenAPI documentation
- `/swagger-ui/**` - Swagger UI
- `/swagger-ui.html` - Swagger UI HTML
- `/swagger-resources/**` - Swagger resources
- `/webjars/**` - Webjars for Swagger

Service-specific public endpoints:
- **auth-service**: Registration, login, password reset, OAuth2 callbacks
- **user-service**: User creation (called by auth-service via RabbitMQ)

### Protected Endpoints (Require JWT)
All other endpoints require valid JWT from either realm.

## Role Hierarchy

```
SUPER_ADMIN
    ├─ ADMIN (all admin permissions)
    │   ├─ FRANCHISE_ADMIN (franchise management)
    │   ├─ CAR_OWNER (vehicle management)
    │   ├─ DRIVER (ride operations)
    │   └─ CUSTOMER (booking rides)
    └─ SERVICE (service-to-service)
        └─ SYSTEM (system operations)
```

## Method Security Examples

### Customer Operations
```java
@PreAuthorize("hasAnyRole('CUSTOMER', 'DRIVER', 'CAR_OWNER', 'ADMIN')")
public ResponseEntity<?> getUserProfile() { ... }
```

### Admin Operations
```java
@PreAuthorize("hasAnyRole('ADMIN', 'SUPER_ADMIN')")
public ResponseEntity<?> getAllUsers() { ... }
```

### Service Operations
```java
@PreAuthorize("hasAnyRole('SERVICE', 'SYSTEM', 'ADMIN')")
public ResponseEntity<?> internalOperation() { ... }
```

## Configuration Properties

### Environment Variables
```bash
# User Authentication Realm
USER_AUTH_ISSUER_URI=https://auth.rydeflexi.com/realms/user-authentication

# Service Authentication Realm
SERVICE_AUTH_ISSUER_URI=https://auth.rydeflexi.com/realms/service-authentication
```

### application.yml
```yaml
spring:
  security:
    oauth2:
      client:
        provider:
          user-auth:
            issuer-uri: ${USER_AUTH_ISSUER_URI:https://auth.rydeflexi.com/realms/user-authentication}
          service-auth:
            issuer-uri: ${SERVICE_AUTH_ISSUER_URI:https://auth.rydeflexi.com/realms/service-authentication}
      resourceserver:
        jwt:
          # Primary issuer (used by single-realm decoders)
          issuer-uri: ${USER_AUTH_ISSUER_URI:https://auth.rydeflexi.com/realms/user-authentication}
```

## Services Configuration

| Service | Port | Primary Realm | Supports Multi-Realm | Method Security |
|---------|------|---------------|---------------------|-----------------|
| gateway-service | 8080 | Both | ✅ | N/A |
| auth-service | 8081 | Both | ✅ | ✅ |
| booking-service | 8082 | user-auth | ✅ | ✅ |
| pricing-service | 8083 | user-auth | ✅ | ✅ |
| payment-service | 8084 | user-auth | ✅ | ✅ |
| mail-service | 8085 | service-auth | ✅ | ❌ |
| user-service | 8086 | Both | ✅ | ✅ |
| vehicle-service | 8087 | Both | ✅ | ✅ |
| owner-bff | 8088 | user-auth | ✅ | ✅ |
| client-bff | 8089 | user-auth | ✅ | ✅ |
| admin-bff | 8090 | user-auth | ✅ | ✅ |
| discovery-service | 8761 | N/A | ❌ | ❌ |

## Security Features

### ✅ Implemented
- Multi-realm JWT validation
- Role extraction from JWT claims
- Method-level security annotations
- CSRF disabled (stateless)
- Stateless session management
- Security headers (XSS, CSP, HSTS)
- Public endpoint configuration
- Protected endpoint authentication

### 🚀 Recommended Enhancements
- Rate limiting per user/service
- IP whitelisting for service realm
- Audit logging of security events
- Token refresh mechanism
- OAuth2 login flow for BFF services
- Circuit breaker for auth failures

## Testing

### Get User Token
```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "customer@example.com",
    "password": "password123"
  }'
```

### Get Service Token
```bash
curl -X POST https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token \
  -d "grant_type=client_credentials" \
  -d "client_id=your-service" \
  -d "client_secret=your-secret"
```

### Call Protected Endpoint
```bash
TOKEN="your-jwt-token"

curl -X GET http://localhost:8086/api/v1/users/profile/user@example.com \
  -H "Authorization: Bearer $TOKEN"
```

## Troubleshooting

### Token Validation Fails
1. Check issuer URI matches Keycloak realm
2. Verify Keycloak is accessible
3. Check token expiration
4. Validate token signature

### Role Not Found
1. Check Keycloak role assignment
2. Verify role name in JWT claims
3. Check `JwtAuthenticationConverter` configuration
4. Ensure `ROLE_` prefix is added

### Public Endpoint Requires Auth
1. Check `SecurityConfig` matchers
2. Verify request path matches pattern
3. Check HTTP method (GET, POST, etc.)
4. Review security filter chain order

## References
- [Spring Security OAuth2 Resource Server](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/)
- [Keycloak Documentation](https://www.keycloak.org/documentation)
- [JWT.io](https://jwt.io) - Token debugger
