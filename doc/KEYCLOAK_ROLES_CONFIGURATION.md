# 🔐 Keycloak Roles Configuration Guide

## Overview

Keycloak comes with default roles that are automatically assigned to users. Understanding these roles is crucial for proper security configuration in your microservices.

---

## 📋 Default Keycloak Roles

### Realm Roles (Global)

These are the roles that appear in every Keycloak realm:

| Role | Description | Scope | Auto-Assigned |
|------|-------------|-------|----------------|
| `offline_access` | Allows offline token refresh | Realm-wide | ✅ Yes |
| `uma_authorization` | User-Managed Access authorization | Realm-wide | ✅ Yes |
| `default-roles-<realm-name>` | Default composite role | Realm-wide | ✅ Yes |

### Client Roles (Account Client)

These are available on the `account` client for user self-service:

| Role | Permissions | Purpose |
|------|-------------|---------|
| `manage-account` | read, write | Manage own account settings |
| `manage-account-links` | read, write | Link external identities |
| `view-profile` | read | View own profile |

---

## 🎯 Custom Roles for Your Application

### Recommended Role Hierarchy

```
Realm Roles (Global):
├── PLATFORM_ADMIN          # Super admin - full system access
├── FRANCHISE_ADMIN         # Franchise-level admin
├── CUSTOMER                # Regular customer/user
├── DRIVER                  # Driver user
├── CAR_OWNER               # Vehicle owner
└── SUPPORT_STAFF           # Support team member

Client Roles (per service):
├── user-service:
│   ├── VIEW_PROFILE
│   ├── EDIT_PROFILE
│   ├── DELETE_PROFILE
│   └── MANAGE_USERS
├── auth-service:
│   ├── LOGIN
│   ├── REGISTER
│   ├── RESET_PASSWORD
│   └── UPDATE_EMAIL
└── booking-service:
    ├── VIEW_BOOKING
    ├── CREATE_BOOKING
    ├── CANCEL_BOOKING
    └── MANAGE_BOOKINGS
```

---

## ⚙️ Configuration in Keycloak

### Step 1: Create Realm Roles

**Via Keycloak Admin Console:**

1. Navigate to: **Realm Settings → Roles → Create role**
2. Create custom roles:
   - `PLATFORM_ADMIN`
   - `FRANCHISE_ADMIN`
   - `CUSTOMER`
   - `DRIVER`
   - `CAR_OWNER`
   - `SUPPORT_STAFF`

**Via Keycloak API:**

```bash
# Get admin token
ADMIN_TOKEN=$(curl -s -X POST https://auth.rydeflexi.com/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=YOUR_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

# Create CUSTOMER role
curl -X POST https://auth.rydeflexi.com/admin/realms/service-authentication/roles \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "CUSTOMER",
    "description": "Regular customer role"
  }'

# Create DRIVER role
curl -X POST https://auth.rydeflexi.com/admin/realms/service-authentication/roles \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "DRIVER",
    "description": "Driver role"
  }'

# Create PLATFORM_ADMIN role
curl -X POST https://auth.rydeflexi.com/admin/realms/service-authentication/roles \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "PLATFORM_ADMIN",
    "description": "Platform administrator with full access"
  }'
```

### Step 2: Create Client Roles

**For user-service client:**

```bash
# Get the client ID
CLIENT_ID=$(curl -s https://auth.rydeflexi.com/admin/realms/service-authentication/clients \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[] | select(.clientId=="user-service") | .id')

# Create client roles
curl -X POST https://auth.rydeflexi.com/admin/realms/service-authentication/clients/$CLIENT_ID/roles \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "VIEW_PROFILE",
    "description": "View user profile"
  }'

curl -X POST https://auth.rydeflexi.com/admin/realms/service-authentication/clients/$CLIENT_ID/roles \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "name": "EDIT_PROFILE",
    "description": "Edit user profile"
  }'
```

### Step 3: Assign Roles to Users

**During Registration (in auth-service):**

```java
@Override
public RegisterResponse registerUser(RegisterRequest request) {
    // ... create user in Keycloak ...
    
    String userId = response.getLocation().getPath().replaceAll(".*/([^/]+)$", "$1");
    
    // Assign role based on request
    if (request.role() == CustomRole.DRIVER) {
        assignRoleToUser(userId, CustomRole.DRIVER);
    } else if (request.role() == CustomRole.CUSTOMER) {
        assignRoleToUser(userId, CustomRole.CUSTOMER);
    }
    
    return new RegisterResponse(...);
}

private void assignRoleToUser(String userId, CustomRole role) {
    RealmResource realmResource = keycloak.realm(realm);
    UserResource userResource = realmResource.users().get(userId);
    
    // Get the role
    RoleRepresentation roleRep = realmResource.roles().get(role.name()).toRepresentation();
    
    // Assign it to user
    userResource.roles().realmLevel().add(List.of(roleRep));
}
```

**Via Keycloak API:**

```bash
# Get user ID
USER_ID=$(curl -s https://auth.rydeflexi.com/admin/realms/service-authentication/users?search=testuser@example.com \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.[0].id')

# Get role ID
ROLE_ID=$(curl -s https://auth.rydeflexi.com/admin/realms/service-authentication/roles/CUSTOMER \
  -H "Authorization: Bearer $ADMIN_TOKEN" | jq -r '.id')

# Assign role to user
curl -X POST https://auth.rydeflexi.com/admin/realms/service-authentication/users/$USER_ID/role-mappings/realm \
  -H "Authorization: Bearer $ADMIN_TOKEN" \
  -H "Content-Type: application/json" \
  -d "[{\"id\":\"$ROLE_ID\",\"name\":\"CUSTOMER\"}]"
```

---

## 🔐 Role-Based Access Control in Spring

### JWT Token with Roles

```json
{
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
    "user-service": {
      "roles": ["VIEW_PROFILE", "EDIT_PROFILE"]
    },
    "account": {
      "roles": ["manage-account", "view-profile"]
    }
  }
}
```

### Controller with Role-Based Authorization

```java
@RestController
@RequestMapping("/api/v1/users")
public class UserController {
    
    /**
     * Get all users - only PLATFORM_ADMIN or FRANCHISE_ADMIN
     */
    @GetMapping("/all")
    @PreAuthorize("hasAnyRole('PLATFORM_ADMIN', 'FRANCHISE_ADMIN')")
    public ResponseEntity<Page<UserResponse>> getAllUsers(Pageable pageable) {
        return ResponseEntity.ok(userService.getAllUsers(pageable));
    }
    
    /**
     * Get user profile by email - only authenticated users
     */
    @GetMapping("/profile/{email}")
    @PreAuthorize("hasAnyRole('CUSTOMER', 'DRIVER', 'CAR_OWNER', 'PLATFORM_ADMIN', 'SUPPORT_STAFF')")
    public ResponseEntity<ProfileResponse> getUserProfile(@PathVariable String email) {
        return ResponseEntity.ok(userService.getUserProfile(email));
    }
    
    /**
     * Update own profile - only CUSTOMER, DRIVER, CAR_OWNER
     */
    @PutMapping("/secure-update")
    @PreAuthorize("hasAnyRole('CUSTOMER', 'DRIVER', 'CAR_OWNER')")
    public ResponseEntity<UserResponse> updateUserWithPassword(
            @RequestBody UpdateUserWithPasswordRequest request) {
        return ResponseEntity.ok(userService.updateUserWithPassword(request));
    }
    
    /**
     * Delete user - only PLATFORM_ADMIN
     */
    @DeleteMapping("/{email}")
    @PreAuthorize("hasRole('PLATFORM_ADMIN')")
    public ResponseEntity<UserResponse> deleteUser(@PathVariable String email) {
        return ResponseEntity.ok(userService.deleteUser(email));
    }
}
```

### Enable @PreAuthorize Annotation

In your SecurityConfig:

```java
@Configuration
@EnableGlobalMethodSecurity(prePostEnabled = true)
public class SecurityConfig {
    // ... existing config ...
}
```

---

## 📊 Understanding uma_authorization

### What is UMA (User-Managed Access)?

UMA is an OAuth2 extension that allows:
- Users to manage access to their own resources
- Dynamic permission delegation
- Client applications to request permissions on behalf of users

### Why It's Default

Keycloak includes `uma_authorization` by default because:
- ✅ Enables advanced permission management
- ✅ Allows resource servers to make authorization decisions
- ✅ Supports delegated access patterns
- ✅ Required for token introspection

### Should You Remove It?

**No!** Keep it because:
- ✅ It's lightweight and doesn't affect basic authentication
- ✅ Many Keycloak features depend on it
- ✅ It doesn't grant actual permissions, just enables the framework
- ✅ Removing it may break Keycloak features

---

## 🚀 Complete Setup Example

### 1. Create Roles in Keycloak

```bash
#!/bin/bash
ADMIN_TOKEN=$(curl -s -X POST https://auth.rydeflexi.com/realms/master/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=admin-cli" \
  -d "username=admin" \
  -d "password=$KEYCLOAK_ADMIN_PASSWORD" \
  -d "grant_type=password" | jq -r '.access_token')

echo "Creating realm roles..."

for ROLE in PLATFORM_ADMIN FRANCHISE_ADMIN CUSTOMER DRIVER CAR_OWNER SUPPORT_STAFF; do
  curl -X POST https://auth.rydeflexi.com/admin/realms/service-authentication/roles \
    -H "Authorization: Bearer $ADMIN_TOKEN" \
    -H "Content-Type: application/json" \
    -d "{\"name\":\"$ROLE\",\"description\":\"$ROLE role\"}"
  echo "Created role: $ROLE"
done

echo "Role creation completed!"
```

### 2. Register User with Role

```bash
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "driver@example.com",
    "password": "SecurePassword123!",
    "firstName": "John",
    "lastName": "Driver",
    "role": "DRIVER"
  }'
```

### 3. Login and Extract Token

```bash
# Login
RESPONSE=$(curl -s -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "driver@example.com",
    "password": "SecurePassword123!"
  }')

TOKEN=$(echo $RESPONSE | jq -r '.access_token')

# Decode token to see roles
echo $TOKEN | jq -R 'split(".")[1] | @base64d | fromjson' | jq '.realm_access.roles'

# Output:
# [
#   "default-roles-service-authentication",
#   "offline_access",
#   "uma_authorization",
#   "DRIVER",
#   "user"
# ]
```

### 4. Call Protected Endpoint with Token

```bash
# This will work (DRIVER has permission)
curl -X GET http://localhost:8086/api/v1/users/profile/driver@example.com \
  -H "Authorization: Bearer $TOKEN"

# Response 200 - Success

# This will fail (DRIVER doesn't have PLATFORM_ADMIN role)
curl -X GET http://localhost:8086/api/v1/users/all \
  -H "Authorization: Bearer $TOKEN"

# Response 403 - Forbidden
# {
#   "error": "Forbidden",
#   "message": "Access Denied"
# }
```

---

## 📝 Role Assignment Workflow

```
┌─────────────────────────────────────────────────────────┐
│ 1. User Registration                                    │
│    POST /api/auth/register                              │
│    Body: { role: "DRIVER", ... }                        │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 2. Create User in Keycloak                              │
│    - User created in Keycloak realm                     │
│    - Automatic default roles assigned                   │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 3. Assign Custom Role                                   │
│    - Get DRIVER role from Keycloak                      │
│    - Assign DRIVER role to user                         │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 4. User Logs In                                         │
│    POST /api/auth/login                                 │
│    Response: { access_token: JWT, ... }                │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 5. JWT Token Contains Roles                             │
│    realm_access.roles: [                                │
│      "offline_access",                                  │
│      "uma_authorization",                               │
│      "DRIVER",                                          │
│      "default-roles-service-authentication"             │
│    ]                                                    │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 6. Call Protected Endpoint                              │
│    GET /api/v1/users/profile/{email}                    │
│    Headers: Authorization: Bearer JWT                   │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 7. Spring Security Validation                           │
│    @PreAuthorize("hasAnyRole('CUSTOMER', 'DRIVER')")   │
│    - Extract roles from JWT                             │
│    - Check if DRIVER is in allowed roles                │
│    - Allow or deny request                              │
└──────────────────┬──────────────────────────────────────┘
                   │
                   ▼
┌─────────────────────────────────────────────────────────┐
│ 8. Response (200 OK or 403 Forbidden)                   │
└─────────────────────────────────────────────────────────┘
```

---

## ✅ Best Practices

### DO:
- ✅ Use role names that clearly indicate purpose (CUSTOMER, DRIVER, ADMIN)
- ✅ Keep `offline_access` and `uma_authorization` enabled
- ✅ Assign roles during user registration based on request
- ✅ Use `@PreAuthorize` annotations on sensitive endpoints
- ✅ Extract roles from JWT for Spring Security integration
- ✅ Log role assignments for audit trails
- ✅ Use role hierarchies (admin > support > user)

### DON'T:
- ❌ Remove default Keycloak roles
- ❌ Create roles with spaces or special characters
- ❌ Assign all roles to all users
- ❌ Store roles in local database instead of Keycloak
- ❌ Bypass role checks in critical operations
- ❌ Use hardcoded role names (use enums instead)

---

## 🔗 Related Files

- `/mnt/projects/Ride/auth-service/src/main/java/com/ride/authservice/service/impl/KeycloakAdminServiceImpl.java` - Role assignment logic
- `/mnt/projects/Ride/user-service/src/main/java/com/ride/userservice/config/SecurityConfig.java` - JWT role extraction
- `/mnt/projects/Ride/user-service/src/main/java/com/ride/userservice/controller/UserController.java` - Role-based authorization examples

---

## 📚 References

- [Keycloak Roles Documentation](https://www.keycloak.org/docs/latest/server_admin/#roles)
- [User-Managed Access (UMA) 2.0](https://docs.kantarainitiative.org/uma/rec-uma-core.html)
- [Spring Security PreAuthorize](https://docs.spring.io/spring-security/reference/servlet/authorization/method-security.html)
- [JWT.io - Decode tokens](https://jwt.io)

