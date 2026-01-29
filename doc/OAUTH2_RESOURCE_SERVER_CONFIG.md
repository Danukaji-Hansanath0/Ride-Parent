# 🔐 OAuth2 Resource Server Security Configuration

## Overview

Both **auth-service** and **user-service** are configured as **OAuth2 Resource Servers** that validate JWT tokens from Keycloak.

```
┌──────────────┐
│  Keycloak    │ Issues JWT tokens
│   (IdP)      │
└──────┬───────┘
       │
       │ Issues JWT
       ▼
┌──────────────────────────────────────────┐
│  Client (Mobile/Web App)                 │
│  - Logs in via auth-service              │
│  - Gets JWT token                        │
└──────┬───────────────────────────────────┘
       │
       ├─ Calls auth-service endpoints (with JWT)
       │  Protected endpoints:
       │  - PUT /api/auth/update-email (with JWT)
       │  - PUT /api/auth/update-profile (with JWT)
       │
       └─ Calls user-service endpoints (with JWT)
          Protected endpoints:
          - GET /api/v1/users/all (requires JWT)
          - GET /api/v1/users/profile/{email} (requires JWT)
          - PUT /api/v1/users (requires JWT)
          - PUT /api/v1/users/secure-update (requires JWT)
          - DELETE /api/v1/users/{email} (requires JWT)
```

---

## 🔑 Authentication Flow

### 1. User Registration & Login (auth-service)

**Public Endpoints (No JWT Required):**
- `POST /api/auth/register` - User registration
- `POST /api/auth/login` - Get JWT token
- `GET /api/auth/verify-email/{userId}` - Check email verification
- `GET /api/auth/send-verification-email/{userId}` - Send verification email
- `POST /api/auth/password-reset?email=...` - Password reset

**Protected Endpoints (JWT Required):**
- `PUT /api/auth/update-email` - Change email address
- `PUT /api/auth/update-profile` - Update firstName/lastName (called by user-service)

### 2. User Profile Management (user-service)

**Public Endpoints (No JWT Required):**
- `POST /api/v1/users` - Create user (called by RabbitMQ consumer)
- `/swagger-ui/**`, `/v3/api-docs/**` - Swagger UI & docs
- `/actuator/**` - Health checks

**Protected Endpoints (JWT Required):**
- `GET /api/v1/users/all` - Get all users
- `GET /api/v1/users/profile/{email}` - Get user profile by email
- `PUT /api/v1/users` - Update user (without password verification)
- `PUT /api/v1/users/secure-update` - Update user (with password verification)
- `DELETE /api/v1/users/{email}` - Delete user

---

## 🏗️ Architecture

### JWT Token Flow

```
1. User logs in to auth-service
   POST /api/auth/login
   Request: { email: "user@example.com", password: "password" }
   Response: 
   {
     "access_token": "eyJhbGc...",
     "refresh_token": "...",
     "expires_in": 3600,
     "user_id": "keycloak-user-id",
     "email": "user@example.com"
   }

2. Client stores JWT token

3. Client calls protected endpoints with JWT
   Headers: Authorization: Bearer eyJhbGc...

4. Services validate JWT signature & issuer
   - Keycloak URL: https://auth.rydeflexi.com/realms/service-authentication
   - Public key endpoint: /.well-known/openid-configuration
   - Validates: signature, issuer, audience, expiry

5. If valid, extract claims:
   - realm_access.roles - User's roles (CUSTOMER, DRIVER, ADMIN, etc.)
   - sub - Subject ID (Keycloak user ID)
   - email - User email
   - preferred_username - Username
   - exp - Token expiry
```

---

## 🔒 Role-Based Access Control (RBAC)

### Extract Roles from JWT

Both services extract roles from JWT token claims:

```java
// From JWT claims:
{
  "realm_access": {
    "roles": ["user", "customer", "ROLE_CUSTOMER"]
  },
  "resource_access": {
    "user-service": {
      "roles": ["VIEW_PROFILE", "EDIT_PROFILE"]
    }
  }
}

// Converted to Spring authorities:
- ROLE_user
- ROLE_customer
- ROLE_ROLE_CUSTOMER
- ROLE_VIEW_PROFILE
- ROLE_EDIT_PROFILE
```

### Usage in Controllers

```java
@GetMapping("/api/v1/users/all")
@PreAuthorize("hasAnyRole('ADMIN', 'FRANCHISE_ADMIN')")  // Only admins can list all users
public ResponseEntity<Page<UserResponse>> getAllUsers(...) {
    // ...
}

@PutMapping("/api/v1/users/secure-update")
@PreAuthorize("hasAnyRole('CUSTOMER', 'DRIVER', 'CAR_OWNER')")  // Authenticated users
public ResponseEntity<UserResponse> updateUserWithPassword(...) {
    // ...
}
```

---

## 📋 Endpoints Summary

### auth-service

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/auth/register` | None | Register new user |
| POST | `/api/auth/login` | None | Login & get JWT |
| GET | `/api/auth/verify-email/{userId}` | None | Check email verified |
| GET | `/api/auth/send-verification-email/{userId}` | None | Send verify email |
| POST | `/api/auth/password-reset` | None | Send password reset |
| PUT | `/api/auth/update-email` | **JWT** | Change email |
| PUT | `/api/auth/update-profile` | **JWT** | Update profile in Keycloak |

### user-service

| Method | Endpoint | Auth | Description |
|--------|----------|------|-------------|
| POST | `/api/v1/users` | None | Create user (RabbitMQ) |
| GET | `/api/v1/users/all` | **JWT** | List all users |
| GET | `/api/v1/users/profile/{email}` | **JWT** | Get user profile |
| PUT | `/api/v1/users` | **JWT** | Update user (no pwd) |
| PUT | `/api/v1/users/secure-update` | **JWT** | Update user (with pwd) |
| DELETE | `/api/v1/users/{email}` | **JWT** | Delete user |

---

## 🔄 Secure Update Flow

### User Updates Their Profile (email, firstName, lastName)

```
Step 1: User calls user-service secure-update endpoint
POST /api/v1/users/secure-update
Headers: Authorization: Bearer <JWT_TOKEN>
Body: {
  "email": "user@example.com",
  "password": "currentPassword",
  "firstName": "New",
  "lastName": "Name",
  "phoneNumber": "123456789",
  "profilePictureUrl": null,
  "isActive": true
}

Step 2: user-service validates JWT token
- Checks: signature, issuer, expiry

Step 3: user-service calls auth-service to verify password
POST /api/auth/login
Body: { "email": "user@example.com", "password": "currentPassword" }
- If fails: return 401 "Invalid credentials"
- If succeeds: continue

Step 4: user-service calls auth-service to update Keycloak
PUT /api/auth/update-profile
Headers: Authorization: Bearer <JWT_TOKEN>
Body: {
  "email": "user@example.com",
  "firstName": "New",
  "lastName": "Name"
}

Step 5: user-service updates local database
- Updates Users table with new data

Step 6: Return updated user to client
Response 200: {
  "userId": "keycloak-id",
  "email": "user@example.com",
  "firstName": "New",
  "lastName": "Name",
  "phoneNumber": "123456789",
  "isActive": true
}
```

---

## 🧪 Testing with cURL

### 1. Register User

```bash
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPassword123!",
    "firstName": "Test",
    "lastName": "User",
    "role": "CUSTOMER"
  }'

# Response:
# {
#   "userId": "abc-123-def",
#   "email": "testuser@example.com",
#   "firstName": "Test",
#   "lastName": "User",
#   "success": true,
#   "message": "USER_CREATED"
# }
```

### 2. Login & Get JWT

```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPassword123!"
  }'

# Response:
# {
#   "access_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "refresh_token": "eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9...",
#   "expires_in": 3600,
#   "refresh_expires_in": 86400,
#   "token_type": "Bearer",
#   "scope": "openid profile email",
#   "firstName": "Test",
#   "lastName": "User",
#   "email": "testuser@example.com",
#   "uid": "abc-123-def",
#   "userAvailability": "AVAILABLE",
#   "isActive": true
# }
```

### 3. Call Protected Endpoint (Get User Profile)

```bash
# Store JWT token
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

# Call protected endpoint
curl -X GET http://localhost:8086/api/v1/users/profile/testuser@example.com \
  -H "Authorization: Bearer $TOKEN"

# Response 200:
# {
#   "uid": "abc-123-def",
#   "firstName": "Test",
#   "lastName": "User",
#   "email": "testuser@example.com",
#   "phoneNumber": null,
#   "userAvailability": "AVAILABLE",
#   "isActive": true
# }

# If token is missing or invalid:
# Response 401:
# {
#   "error": "Unauthorized",
#   "message": "Full authentication is required to access this resource"
# }
```

### 4. Update User Profile (Secure)

```bash
TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCJ9..."

curl -X PUT http://localhost:8086/api/v1/users/secure-update \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "testuser@example.com",
    "password": "TestPassword123!",
    "firstName": "Updated",
    "lastName": "Name",
    "phoneNumber": "555-1234",
    "profilePictureUrl": "https://example.com/avatar.jpg",
    "isActive": true
  }'

# Response 200:
# {
#   "userId": "abc-123-def",
#   "email": "testuser@example.com",
#   "firstName": "Updated",
#   "lastName": "Name",
#   "phoneNumber": "555-1234",
#   "profilePictureUrl": "https://example.com/avatar.jpg",
#   "isActive": true
# }

# Both Keycloak and local database are updated!
```

---

## ⚙️ Configuration

### auth-service (application.yml)

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${RD_AUTH_ISSUER_URI:https://auth.rydeflexi.com/realms/service-authentication}
```

### user-service (application.yml)

```yaml
spring:
  security:
    oauth2:
      resourceserver:
        jwt:
          issuer-uri: ${OAUTH2_ISSUER_URI:https://auth.rydeflexi.com/realms/service-authentication}
```

---

## 🔍 JWT Token Claims (Example)

```json
{
  "jti": "abc-123",
  "exp": 1737370000,
  "nbf": 0,
  "iat": 1737366400,
  "iss": "https://auth.rydeflexi.com/realms/service-authentication",
  "aud": "account",
  "sub": "keycloak-user-id-123",
  "typ": "Bearer",
  "azp": "user-service",
  "session_state": "xyz789",
  "acr": "1",
  "allowed-origins": ["http://localhost:3000"],
  "realm_access": {
    "roles": [
      "default-roles-service-authentication",
      "offline_access",
      "uma_authorization",
      "CUSTOMER",
      "user"
    ]
  },
  "resource_access": {
    "account": {
      "roles": ["manage-account", "manage-account-links", "view-profile"]
    },
    "user-service": {
      "roles": ["EDIT_PROFILE", "VIEW_PROFILE"]
    }
  },
  "name": "Test User",
  "preferred_username": "testuser@example.com",
  "given_name": "Test",
  "family_name": "User",
  "email": "testuser@example.com",
  "email_verified": false
}
```

---

## ✅ Security Checklist

- ✅ CSRF disabled (stateless JWT authentication)
- ✅ CORS configured for specific origins
- ✅ JWT signature validation enabled
- ✅ Token expiry checked
- ✅ Issuer validation enabled
- ✅ Roles extracted from JWT claims
- ✅ Protected endpoints require authentication
- ✅ Public endpoints clearly marked
- ✅ HTTPS recommended for production
- ✅ Sensitive endpoints require roles

---

## 🚀 Deployment

### Production Environment Variables

```bash
# For both services
export OAUTH2_ISSUER_URI=https://auth.prod.example.com/realms/production
export RD_AUTH_ISSUER_URI=https://auth.prod.example.com/realms/production

# For user-service
export AUTH_SERVICE_BASE_URL=http://auth-service-internal:8081

# For auth-service
export KEYCLOAK_ADMIN_USER=admin
export KEYCLOAK_ADMIN_PASSWORD=secure_password_here
```

---

## 📚 References

- [Spring Security OAuth2 Resource Server](https://spring.io/projects/spring-security-oauth2-resource-server)
- [Keycloak OpenID Connect Discovery](https://auth.rydeflexi.com/realms/service-authentication/.well-known/openid-configuration)
- [JWT.io Token Debugger](https://jwt.io)

