# Security Implementation - Auth Service

## Overview

This document describes the comprehensive security implementation added to the auth-service to protect against malformed requests, bot attacks, and other security threats observed in Keycloak logs.

## Problem Statement

The Keycloak logs showed numerous security issues:
- **Malformed JSON requests**: `Unrecognized token 'hHLvl'` errors
- **Invalid UTF-8 encoding**: `Invalid UTF-8 middle byte 0x15` errors
- **Bot/Scanner attacks**: Multiple requests from various IPs with invalid data
- **Identity Provider errors**: `IDENTITY_PROVIDER_LOGIN_ERROR` and `IDENTITY_PROVIDER_FIRST_LOGIN_ERROR`
- **Null client/user IDs**: All errors showed `clientId="null", userId="null"`

## Security Layers Implemented

### 1. Request Validation Filter (`RequestValidationFilter`)
**Location**: `com.ride.authservice.filter.RequestValidationFilter`

**Features**:
- ✅ **UTF-8 Encoding Validation**: Enforces UTF-8 encoding for all requests
- ✅ **JSON Structure Validation**: Validates JSON syntax before reaching controllers
- ✅ **Content-Type Validation**: Ensures proper content types for POST/PUT requests
- ✅ **Request Size Limits**: Enforces 1MB maximum request size
- ✅ **Body Caching**: Uses `CachedBodyHttpServletRequest` to read body multiple times

**Configuration**:
```yaml
security:
  request-validation:
    enabled: true
    max-request-size: 1048576  # 1MB
    enforce-utf8: true
    validate-json: true
```

### 2. IP-Based Security Filter (`IpSecurityFilter`)
**Location**: `com.ride.authservice.filter.IpSecurityFilter`

**Features**:
- ✅ **Rate Limiting**: 60 requests per minute per IP (configurable)
- ✅ **Automatic Blacklisting**: IPs with 10+ failed attempts are blocked for 60 minutes
- ✅ **Malformed Request Tracking**: Double-weight for malformed requests
- ✅ **In-Memory Caching**: Uses Caffeine cache for high performance
- ✅ **IP Whitelisting**: Configurable whitelist for trusted IPs

**Configuration**:
```yaml
security:
  ip:
    enabled: true
    max-failed-attempts: 10
    max-requests-per-minute: 60
    blacklist-duration-minutes: 60
    whitelist:
      - "127.0.0.1"
      - "::1"
```

### 3. Circuit Breaker & Retry (`Resilience4j`)
**Location**: `KeycloakOAuth2AdminServiceAppImpl`, `KeycloakAdminServiceImpl`

**Features**:
- ✅ **Circuit Breaker**: Protects against cascading failures when Keycloak is down
- ✅ **Automatic Retry**: 3 attempts with exponential backoff (500ms → 1s → 2s)
- ✅ **Fallback Methods**: Graceful degradation with user-friendly error messages

**Configuration**:
```yaml
resilience4j:
  circuitbreaker:
    instances:
      keycloak:
        sliding-window-size: 10
        failure-rate-threshold: 50
        wait-duration-in-open-state: 10s
  retry:
    instances:
      keycloak:
        max-attempts: 3
        wait-duration: 500ms
        exponential-backoff-multiplier: 2
```

### 4. Enhanced Exception Handling
**Location**: `GlobalExceptionHandler`

**New Handlers**:
- ✅ `HttpMessageNotReadableException`: Catches malformed JSON/HTTP messages
- ✅ `JsonProcessingException`: Handles JSON parsing errors
- ✅ `CharacterCodingException`: Handles invalid character encoding
- ✅ `RestClientException`: Handles Keycloak communication errors

**Features**:
- Security event logging for all errors
- Automatic IP blacklisting for malformed requests
- Client IP tracking with X-Forwarded-For support
- Sanitized error messages (no sensitive data exposed)

### 5. Security Event Logger
**Location**: `com.ride.authservice.service.SecurityEventLogger`

**Features**:
- ✅ **Structured JSON Logging**: All security events logged in JSON format
- ✅ **Event Types**: Failed auth, rate limits, blacklisting, malformed requests, OAuth2 errors
- ✅ **Timestamp Tracking**: ISO-8601 formatted timestamps
- ✅ **Context Preservation**: IP, endpoint, error details included

**Example Log**:
```json
{
  "eventType": "MALFORMED_REQUEST",
  "timestamp": "2026-01-14T15:31:50.123Z",
  "details": {
    "ip": "198.92.97.36",
    "endpoint": "/api/auth/login",
    "error": "Invalid JSON structure"
  }
}
```

### 6. Security Headers
**Location**: `SecurityConfig`

**Headers Added**:
- ✅ `X-Content-Type-Options: nosniff`
- ✅ `X-Frame-Options: DENY`
- ✅ `X-XSS-Protection: 1; mode=block`
- ✅ `Content-Security-Policy: default-src 'self'; frame-ancestors 'none'`
- ✅ `Strict-Transport-Security: max-age=31536000; includeSubDomains`

### 7. Input Validation
**Location**: Controllers (`AuthController`, `MobileAuthController`)

**Validation Rules**:
- ✅ `@Valid` annotation on all `@RequestBody` parameters
- ✅ `@NotBlank` for required fields
- ✅ `@Size` constraints (e.g., code_verifier: 43-128 characters)
- ✅ `@Pattern` for URL validation (redirect URIs)
- ✅ Automatic validation error responses with field details

### 8. RestTemplate Interceptor
**Location**: `RequestValidationInterceptor`

**Features**:
- ✅ **Outgoing Request Validation**: Ensures all Keycloak requests use UTF-8
- ✅ **Request/Response Logging**: Debug-level logging with sanitization
- ✅ **Error Detection**: Catches encoding issues before they reach Keycloak

### 9. CORS Configuration
**Location**: `WebMvcConfig`

**Features**:
- ✅ Configurable allowed origins via environment variables
- ✅ Restricted to specific HTTP methods
- ✅ Credentials support enabled
- ✅ 1-hour max age for preflight caching

**Configuration**:
```yaml
cors:
  allowed-origins: ${CORS_ALLOWED_ORIGINS:http://localhost:3000,https://rydeflexi.com}
```

### 10. Configuration Properties
**Location**: `SecurityProperties`

**Type-Safe Configuration**:
- ✅ `@ConfigurationProperties` for all security settings
- ✅ Grouped by concern (IP, rate-limit, request-validation)
- ✅ Default values with production-ready settings
- ✅ Environment variable override support

## Dependencies Added

```xml
<!-- Resilience4j for Circuit Breaker, Retry, Rate Limiting -->
<dependency>
    <groupId>io.github.resilience4j</groupId>
    <artifactId>resilience4j-spring-boot3</artifactId>
</dependency>

<!-- Caffeine for in-memory caching -->
<dependency>
    <groupId>com.github.ben-manes.caffeine</groupId>
    <artifactId>caffeine</artifactId>
</dependency>

<!-- Micrometer for metrics -->
<dependency>
    <groupId>io.micrometer</groupId>
    <artifactId>micrometer-registry-prometheus</artifactId>
</dependency>
```

## Request Flow

```
1. Client Request
   ↓
2. RequestValidationFilter (Order 1)
   - Validates UTF-8 encoding
   - Validates JSON structure
   - Validates content type
   - Checks request size
   ↓
3. IpSecurityFilter (Order 2)
   - Checks IP blacklist
   - Enforces rate limits
   - Tracks failed attempts
   ↓
4. Spring Security Filter Chain
   - Authentication
   - Authorization
   ↓
5. Controller (with @Valid)
   - Input validation
   - Business logic
   ↓
6. Service Layer (with @CircuitBreaker, @Retry)
   - Keycloak communication
   - Error handling
   ↓
7. GlobalExceptionHandler
   - Catches all exceptions
   - Logs security events
   - Updates IP reputation
   ↓
8. Response to Client
```

## Error Response Format

All validation and security errors return a consistent JSON format:

```json
{
  "error": true,
  "message": "Invalid JSON structure",
  "timestamp": 1705252310000
}
```

For validation errors (400):
```json
{
  "timestamp": "2026-01-14T15:31:50.123Z",
  "status": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "path": "/api/auth/register",
  "traceId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "details": [
    "email: must be a valid email address",
    "password: size must be between 8 and 100"
  ]
}
```

## Monitoring & Metrics

The implementation exposes several metrics via Micrometer/Prometheus:

- `security.failed_auth_attempts_total` - Total failed authentication attempts
- `security.rate_limit_exceeded_total` - Total rate limit violations
- `security.malformed_requests_total` - Total malformed requests
- `security.blacklisted_ips_total` - Total IPs blacklisted
- `resilience4j.circuitbreaker.state` - Circuit breaker state
- `resilience4j.retry.calls` - Retry attempts

Access metrics at: `http://localhost:8081/actuator/prometheus`

## Testing

### Test Malformed JSON
```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d 'hHLvl'
```

Expected: `400 Bad Request - Invalid JSON structure`

### Test Rate Limiting
```bash
for i in {1..65}; do
  curl -X POST http://localhost:8081/api/auth/login \
    -H "Content-Type: application/json" \
    -d '{"email":"test@example.com","password":"test"}';
done
```

Expected: After 60 requests, receive `429 Too Many Requests`

### Test Invalid UTF-8
```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json; charset=UTF-8" \
  -d $'\xFF\xFE{"email":"test@example.com"}'
```

Expected: `400 Bad Request - Invalid character encoding`

### Test Circuit Breaker
1. Stop Keycloak
2. Make 10 requests to trigger circuit breaker
3. Observe fallback response: "Authentication service is temporarily unavailable"

## Production Deployment

### Environment Variables

```bash
# Security Settings
export SECURITY_IP_ENABLED=true
export SECURITY_IP_MAX_FAILED_ATTEMPTS=10
export SECURITY_IP_MAX_REQUESTS_PER_MINUTE=60
export SECURITY_IP_BLACKLIST_DURATION_MINUTES=60

# CORS Settings
export CORS_ALLOWED_ORIGINS=https://app.rydeflexi.com,https://admin.rydeflexi.com

# Keycloak Settings
export RD_KEYCLOAK_SERVER_URL=https://auth.rydeflexi.com/
export RD_KEYCLOAK_ADMIN_REALM=user-authentication
```

### Recommended Settings by Environment

#### Development
- `max-requests-per-minute: 100`
- `max-failed-attempts: 20`
- `blacklist-duration-minutes: 15`

#### Staging
- `max-requests-per-minute: 80`
- `max-failed-attempts: 15`
- `blacklist-duration-minutes: 30`

#### Production
- `max-requests-per-minute: 60`
- `max-failed-attempts: 10`
- `blacklist-duration-minutes: 60`

## Security Event Types

| Event Type | Description | Action Taken |
|------------|-------------|--------------|
| `FAILED_AUTH_ATTEMPT` | Invalid credentials | Increment failure counter |
| `RATE_LIMIT_EXCEEDED` | Too many requests | Return 429, log IP |
| `BLACKLISTED_IP_ATTEMPT` | Blocked IP attempted access | Return 403, log attempt |
| `IP_BLACKLISTED` | IP auto-blacklisted | Block all requests for duration |
| `MALFORMED_REQUEST` | Invalid JSON/UTF-8 | Return 400, double-count failure |
| `INVALID_TOKEN` | JWT validation failed | Return 401 |
| `KEYCLOAK_ERROR` | Keycloak communication error | Trigger retry/circuit breaker |
| `OAUTH2_ERROR` | OAuth2 flow error | Log and return error |
| `SUSPICIOUS_ACTIVITY` | Anomaly detected | Log for review |

## Clearing Blacklist (Admin)

To manually clear an IP from the blacklist:

```java
@Autowired
private IpSecurityFilter ipSecurityFilter;

// Clear specific IP
ipSecurityFilter.clearBlacklist("192.168.1.100");
```

Or via REST endpoint (implement if needed):
```bash
curl -X DELETE http://localhost:8081/admin/security/blacklist/192.168.1.100 \
  -H "Authorization: Bearer $ADMIN_TOKEN"
```

## Future Enhancements

1. **Redis Integration**: For distributed rate limiting across multiple instances
2. **GeoIP Blocking**: Block requests from specific countries/regions
3. **reCAPTCHA**: Add to login/register endpoints for advanced bot protection
4. **Machine Learning**: Anomaly detection for suspicious patterns
5. **Admin Dashboard**: Web UI to manage blacklist and view security events
6. **Automated Alerts**: Slack/Email notifications for security incidents

## Troubleshooting

### Issue: Legitimate users getting blocked
**Solution**: 
1. Check whitelist configuration
2. Increase `max-failed-attempts`
3. Decrease `blacklist-duration-minutes`
4. Review logs for false positives

### Issue: Rate limits too strict
**Solution**:
1. Increase `max-requests-per-minute`
2. Implement per-user rate limiting instead of per-IP
3. Add exemptions for authenticated users

### Issue: Circuit breaker opening frequently
**Solution**:
1. Check Keycloak availability
2. Increase `failure-rate-threshold`
3. Increase `wait-duration-in-open-state`
4. Review network connectivity

## References

- [Resilience4j Documentation](https://resilience4j.readme.io/)
- [Caffeine Cache](https://github.com/ben-manes/caffeine)
- [OWASP Security Guidelines](https://owasp.org/www-project-web-security-testing-guide/)
- [Spring Security Best Practices](https://docs.spring.io/spring-security/reference/)

## Support

For security-related issues or questions:
- Review logs: `/var/log/auth-service/security-events.log`
- Check metrics: `http://localhost:8081/actuator/prometheus`
- Contact: security-team@rydeflexi.com

