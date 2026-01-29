# Multi-Realm Authentication Guide

## Overview

The Ride Flexi API Gateway implements a sophisticated multi-realm JWT authentication system that supports both user-facing and service-to-service authentication through separate Keycloak realms.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                         API Gateway                              │
│                      (Port 8080)                                │
├─────────────────────────────────────────────────────────────────┤
│  ┌───────────────────────────────────────────────────────────┐  │
│  │         Multi-Realm JWT Authentication                    │  │
│  ├───────────────────────────────────────────────────────────┤  │
│  │  • MultiRealmJwtDecoder                                   │  │
│  │  • AuthorizationFilter (JWKS-based)                       │  │
│  │  • SecurityConfig (OAuth2 Resource Server)                │  │
│  └───────────────────────────────────────────────────────────┘  │
│                           │                                      │
│        ┌──────────────────┴──────────────────┐                  │
│        │                                     │                  │
│   ┌────▼─────┐                        ┌─────▼────┐             │
│   │User Auth │                        │Service   │             │
│   │Realm     │                        │Auth Realm│             │
│   │(End Users)                        │(Services)│             │
│   └──────────┘                        └──────────┘             │
└─────────────────────────────────────────────────────────────────┘
                           │
        ┌──────────────────┴──────────────────┐
        │                                     │
   ┌────▼─────┐                        ┌─────▼────┐
   │Keycloak  │                        │Keycloak  │
   │User Auth │                        │Service   │
   │Realm     │                        │Auth Realm│
   │(JWKS)    │                        │(JWKS)    │
   └──────────┘                        └──────────┘
```

## Authentication Realms

### 1. User Authentication Realm (`user-authentication`)

**Purpose**: Authenticates end-users (web and mobile applications)

**Configuration**:
- **Issuer URI**: `https://auth.rydeflexi.com/realms/user-authentication`
- **JWKS URI**: `https://auth.rydeflexi.com/realms/user-authentication/protocol/openid-connect/certs`
- **Token URI**: `https://auth.rydeflexi.com/realms/user-authentication/protocol/openid-connect/token`

**Grant Types Supported**:
- Authorization Code (with PKCE)
- Refresh Token
- Password (development only)

**Token Claims**:
```json
{
  "sub": "user-uuid",
  "iss": "https://auth.rydeflexi.com/realms/user-authentication",
  "preferred_username": "user@example.com",
  "email": "user@example.com",
  "realm_access": {
    "roles": ["USER", "OWNER", "ADMIN"]
  },
  "exp": 1706234567,
  "iat": 1706230967
}
```

### 2. Service Authentication Realm (`service-authentication`)

**Purpose**: Service-to-service authentication

**Configuration**:
- **Issuer URI**: `https://auth.rydeflexi.com/realms/service-authentication`
- **JWKS URI**: `https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/certs`
- **Token URI**: `https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token`

**Grant Types Supported**:
- Client Credentials

**Token Claims**:
```json
{
  "sub": "service-account-service-name",
  "iss": "https://auth.rydeflexi.com/realms/service-authentication",
  "azp": "service-name",
  "scope": "openid profile",
  "client_id": "service-name",
  "exp": 1706234567,
  "iat": 1706230967
}
```

## Components

### 1. MultiRealmJwtDecoder

**Location**: `gateway-service/src/main/java/com/ride/gatewayservice/security/MultiRealmJwtDecoder.java`

**Purpose**: Routes JWT validation to the appropriate realm based on the token's issuer.

**How It Works**:
1. Extracts the `iss` (issuer) claim from the token without validation
2. Determines which realm the token belongs to
3. Routes to the appropriate NimbusReactiveJwtDecoder
4. Validates the token signature using JWKS from the correct realm
5. Returns validated JWT or throws exception

**Key Methods**:
- `decode(String token)`: Main validation entry point
- `extractIssuer(String token)`: Safely extracts issuer without validation

### 2. AuthorizationFilter

**Location**: `gateway-service/src/main/java/com/ride/gatewayservice/filter/AuthorizationFilter.java`

**Purpose**: JWKS-based JWT validation and user context propagation.

**Features**:
- Separate JWKS caches for each realm
- Automatic key rotation handling
- Token signature verification using RSA public keys
- User context propagation via HTTP headers
- Realm identification and tagging

**Request Headers Added**:
- `X-User-Id`: User's unique identifier (sub claim)
- `X-Username`: User's preferred username
- `X-Email`: User's email address
- `X-Token`: Original JWT token
- `X-Auth-Realm`: Source realm (`user-authentication` or `service-authentication`)

**Initialization Flow**:
1. Constructs JWKS URIs for both realms
2. Pre-fetches public keys on startup
3. Caches keys in realm-specific ConcurrentHashMaps
4. Maintains separate caches for performance

**Request Processing Flow**:
1. Extracts JWT from Authorization header
2. Parses token to extract issuer
3. Determines realm and selects appropriate cache
4. Extracts key ID (kid) from token header
5. Retrieves public key from cache or fetches JWKS
6. Validates token signature
7. Adds user context headers
8. Forwards request to downstream service

### 3. SecurityConfig

**Location**: `gateway-service/src/main/java/com/ride/gatewayservice/config/SecurityConfig.java`

**Purpose**: Configures Spring Security with multi-realm support.

**Security Rules**:
- Public endpoints: `/actuator/health`, `/swagger-ui/**`, `/api/v1/auth/login`
- Admin-only: `/actuator/**`, `/api/v1/gateway/**`
- All other endpoints: Require authentication

**CORS Configuration**:
- Allowed origins: localhost:3000, localhost:4200, *.rydeflexi.com
- Allowed methods: GET, POST, PUT, DELETE, PATCH, OPTIONS, HEAD
- Credentials: Enabled
- Max age: 1 hour

## Configuration

### Environment Variables

```bash
# User Authentication Realm
export USER_AUTH_ISSUER_URI=https://auth.rydeflexi.com/realms/user-authentication
export USER_AUTH_JWKS_URI=https://auth.rydeflexi.com/realms/user-authentication/protocol/openid-connect/certs
export USER_CLIENT_ID=user-auth
export USER_CLIENT_SECRET=your-user-secret

# Service Authentication Realm
export SERVICE_AUTH_ISSUER_URI=https://auth.rydeflexi.com/realms/service-authentication
export SERVICE_AUTH_JWKS_URI=https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/certs
export SERVICE_CLIENT_ID=svc-auth
export SERVICE_CLIENT_SECRET=pKPGmkqLJIJmqjnwCRLjbrVH27eD0oL3

# Gateway Service
export GATEWAY_SERVICE_PORT=8080
export SPRING_PROFILES_ACTIVE=prod
```

### application.yml

```yaml
spring:
  security:
    oauth2:
      client:
        registration:
          service-auth:
            client-id: ${SERVICE_CLIENT_ID}
            client-secret: ${SERVICE_CLIENT_SECRET}
            provider: service-auth
            authorization-grant-type: client_credentials
            scope: [openid]
          user-auth:
            client-id: ${USER_CLIENT_ID}
            client-secret: ${USER_CLIENT_SECRET}
            provider: user-auth
            authorization-grant-type: authorization_code
            scope: [openid, profile, email]
        provider:
          service-auth:
            issuer-uri: ${SERVICE_AUTH_ISSUER_URI}
            jwk-set-uri: ${SERVICE_AUTH_JWKS_URI}
          user-auth:
            issuer-uri: ${USER_AUTH_ISSUER_URI}
            jwk-set-uri: ${USER_AUTH_JWKS_URI}
```

## Usage Examples

### 1. User Authentication Flow

```bash
# Step 1: Get user token
curl -X POST https://auth.rydeflexi.com/realms/user-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=user-auth" \
  -d "client_secret=your-secret" \
  -d "grant_type=password" \
  -d "username=user@example.com" \
  -d "password=password123"

# Step 2: Use token to call API
curl -X GET http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer YOUR_USER_TOKEN"
```

### 2. Service-to-Service Authentication Flow

```bash
# Step 1: Get service token
curl -X POST https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=vehicle-service" \
  -d "client_secret=service-secret" \
  -d "grant_type=client_credentials"

# Step 2: Use token to call internal API
curl -X GET http://localhost:8080/api/v1/vehicles \
  -H "Authorization: Bearer YOUR_SERVICE_TOKEN"
```

### 3. Token Validation Example

**Request**:
```http
GET /api/v1/vehicles HTTP/1.1
Host: localhost:8080
Authorization: Bearer eyJhbGciOiJSUzI1NiIsInR5cCI6IkpXVCIs...
```

**Gateway Processing**:
1. Extracts token from Authorization header
2. Parses issuer: `https://auth.rydeflexi.com/realms/user-authentication`
3. Routes to user-authentication decoder
4. Validates signature using cached public key
5. Adds headers:
   - `X-User-Id: 550e8400-e29b-41d4-a716-446655440000`
   - `X-Username: user@example.com`
   - `X-Email: user@example.com`
   - `X-Auth-Realm: user-authentication`
6. Forwards to vehicle-service

## Security Features

### 1. JWKS-Based Validation
- Uses RSA public keys from Keycloak JWKS endpoints
- Validates token signatures cryptographically
- No shared secrets needed between gateway and services

### 2. Key Rotation Support
- Automatically detects unknown key IDs
- Refetches JWKS when new keys are encountered
- Maintains backward compatibility during rotation

### 3. Realm Isolation
- Separate key caches per realm
- Independent validation pipelines
- Clear realm identification in logs and headers

### 4. Performance Optimization
- Public key caching (ConcurrentHashMap)
- Pre-fetching on startup
- Minimal overhead after warm-up

### 5. Production-Ready
- Graceful error handling
- Detailed logging
- Timeout protection (10s for JWKS fetch)
- Thread-safe operations

## Monitoring and Logging

### Startup Logs

```
Initializing Multi-Realm JWT Decoder
User Auth Realm: https://auth.rydeflexi.com/realms/user-authentication
Service Auth Realm: https://auth.rydeflexi.com/realms/service-authentication
User Auth JWKS URI configured: https://auth.rydeflexi.com/realms/user-authentication/.well-known/jwks.json
User Auth JWKS pre-fetched successfully, 2 keys cached
Service Auth JWKS URI configured: https://auth.rydeflexi.com/realms/service-authentication/.well-known/jwks.json
Service Auth JWKS pre-fetched successfully, 2 keys cached
Multi-Realm JWT Decoder initialized successfully
```

### Request Logs

```
Token issuer: https://auth.rydeflexi.com/realms/user-authentication
Validating token with user-authentication realm
User auth token validated: subject=550e8400-e29b-41d4-a716-446655440000
User 550e8400-e29b-41d4-a716-446655440000 authorized successfully from user-authentication realm
```

### Error Logs

```
JWT validation failed: Token expired at 2026-01-26T10:00:00Z
Unknown issuer: https://auth.unknown.com. Expected https://auth.rydeflexi.com/realms/user-authentication or https://auth.rydeflexi.com/realms/service-authentication
No public key found for kid: unknown-key-id. Refetching JWKS...
```

## Troubleshooting

### Issue: "Token missing issuer claim"

**Cause**: Token doesn't contain an `iss` claim

**Solution**: Ensure Keycloak is configured to include issuer in tokens

### Issue: "Unknown token issuer"

**Cause**: Token issuer doesn't match configured realms

**Solution**: 
1. Verify token is from correct Keycloak realm
2. Check issuer URIs in configuration
3. Ensure no trailing slashes in issuer URIs

### Issue: "JWT validation failed: Token expired"

**Cause**: Token has expired

**Solution**: Request a new token or use refresh token

### Issue: "Failed to fetch JWKS"

**Cause**: Cannot reach Keycloak JWKS endpoint

**Solution**:
1. Verify network connectivity
2. Check Keycloak is running
3. Verify JWKS URI configuration

## Best Practices

1. **Use HTTPS in Production**: Always use HTTPS for Keycloak and gateway
2. **Rotate Keys Regularly**: Configure Keycloak to rotate keys periodically
3. **Monitor Token Expiration**: Set appropriate token lifetimes
4. **Use Client Credentials for Services**: Never use user credentials for service-to-service calls
5. **Implement Token Refresh**: Use refresh tokens to maintain user sessions
6. **Log Security Events**: Monitor authentication failures and anomalies
7. **Rate Limit Token Requests**: Prevent token abuse
8. **Secure Secrets**: Use environment variables or secret management systems

## Testing

### Unit Tests

```java
@Test
void shouldValidateUserAuthToken() {
    String token = generateUserToken();
    Jwt jwt = multiRealmJwtDecoder.decode(token).block();
    
    assertThat(jwt.getIssuer().toString())
        .isEqualTo(userAuthIssuerUri);
}

@Test
void shouldValidateServiceAuthToken() {
    String token = generateServiceToken();
    Jwt jwt = multiRealmJwtDecoder.decode(token).block();
    
    assertThat(jwt.getIssuer().toString())
        .isEqualTo(serviceAuthIssuerUri);
}
```

### Integration Tests

```bash
# Test user authentication
./test-user-auth.sh

# Test service authentication
./test-service-auth.sh

# Test multi-realm routing
./test-multi-realm.sh
```

## References

- [RFC 7517 - JSON Web Key (JWK)](https://datatracker.ietf.org/doc/html/rfc7517)
- [RFC 7519 - JSON Web Token (JWT)](https://datatracker.ietf.org/doc/html/rfc7519)
- [Keycloak Documentation](https://www.keycloak.org/docs/latest/)
- [Spring Security OAuth2](https://docs.spring.io/spring-security/reference/servlet/oauth2/resource-server/jwt.html)
- [Gateway Service JWKS Authentication](../gateway-service/JWKS_AUTHENTICATION.md)

## Support

For issues or questions:
- Email: support@rydeflexi.com
- Documentation: https://docs.rydeflexi.com
- Issue Tracker: https://github.com/rydeflexi/ride/issues
