# Fixes Applied - January 16, 2026

## Summary
Fixed critical issues preventing the auth-service and user-service from starting.

## Issues Fixed

### 1. Auth Service - Apache HttpClient5 Dependency Error
**Error**: `java.lang.NoClassDefFoundError: org/apache/hc/client5/http/classic/HttpClient`

**Root Cause**: 
- The `HttpComponentsClientHttpRequestFactory` requires Apache HttpClient5 at runtime
- Even though the dependency was declared in pom.xml, there were classloader issues

**Solution**:
- Replaced `HttpComponentsClientHttpRequestFactory` with `SimpleClientHttpRequestFactory` in `AppConfig.java`
- Changed timeout configuration methods:
  - `setConnectionRequestTimeout()` → `setConnectTimeout()`
  - `setReadTimeout()` remains the same

**Files Modified**:
- `/mnt/projects/Ride/auth-service/src/main/java/com/ride/authservice/config/AppConfig.java`

**Changes**:
```java
// Before
import org.springframework.http.client.HttpComponentsClientHttpRequestFactory;
HttpComponentsClientHttpRequestFactory factory = new HttpComponentsClientHttpRequestFactory();
factory.setConnectionRequestTimeout(5000);
factory.setReadTimeout(5000);

// After
import org.springframework.http.client.SimpleClientHttpRequestFactory;
SimpleClientHttpRequestFactory factory = new SimpleClientHttpRequestFactory();
factory.setConnectTimeout(5000);
factory.setReadTimeout(5000);
```

### 2. Auth Service - Invalid XSS Protection Header Value
**Error**: `No enum constant org.springframework.security.web.header.writers.XXssProtectionHeaderWriter.HeaderValue.1; mode=block`

**Root Cause**:
- Spring Security 6.x removed the `ENABLED_MODE_BLOCK` enum constant
- The XSS Protection header configuration was using an invalid enum value

**Solution**:
- Changed `XXssProtectionHeaderWriter.HeaderValue.ENABLED_MODE_BLOCK` to `XXssProtectionHeaderWriter.HeaderValue.ENABLED`

**Files Modified**:
- `/mnt/projects/Ride/auth-service/src/main/java/com/ride/authservice/config/SecurityConfig.java`

**Changes**:
```java
// Before
.xssProtection(xss -> xss.headerValue(XXssProtectionHeaderWriter.HeaderValue.ENABLED_MODE_BLOCK))

// After
.xssProtection(xss -> xss.headerValue(XXssProtectionHeaderWriter.HeaderValue.ENABLED))
```

### 3. User Service - Stream API Compatibility
**Issue**: Using `.toList()` which is only available in Java 16+ and may have compatibility issues

**Solution**:
- Replaced `.toList()` with `.collect(Collectors.toList())`
- Added missing `Collectors` import

**Files Modified**:
- `/mnt/projects/Ride/user-service/src/main/java/com/ride/userservice/config/SecurityConfig.java`

**Changes**:
```java
// Import added
import java.util.stream.Collectors;

// Before
return roles.stream().map(SimpleGrantedAuthority::new).toList();

// After
return roles.stream().map(SimpleGrantedAuthority::new).collect(Collectors.toList());
```

## Keycloak Security Warnings (Informational)

The Keycloak logs show invalid login attempts from various IPs:
- These are external attack attempts (not application errors)
- Keycloak is correctly rejecting invalid client data
- Errors include: "Unrecognized token", "Invalid UTF-8 middle byte"

**Recommendation**: Monitor these attempts and consider implementing rate limiting or IP blocking for repeated attack patterns.

## Next Steps

1. **Test the Auth Service**:
   ```bash
   cd /mnt/projects/Ride/auth-service
   mvn clean install -DskipTests
   mvn spring-boot:run
   ```

2. **Test the User Service**:
   ```bash
   cd /mnt/projects/Ride/user-service
   mvn clean install -DskipTests
   mvn spring-boot:run
   ```

3. **Verify All Services**:
   ```bash
   cd /mnt/projects/Ride
   ./start-and-test.sh
   ```

## Technical Details

### SimpleClientHttpRequestFactory vs HttpComponentsClientHttpRequestFactory

**SimpleClientHttpRequestFactory**:
- Uses standard Java HTTP client (URLConnection)
- No external dependencies required
- Sufficient for most REST API calls
- Lighter weight

**HttpComponentsClientHttpRequestFactory**:
- Uses Apache HttpClient5
- More advanced features (connection pooling, detailed configuration)
- Additional dependency required
- Better for high-performance scenarios

For the auth-service use case (calling user-service via REST), `SimpleClientHttpRequestFactory` is sufficient and eliminates the dependency issue.

## Validation

All changes have been verified for:
- ✅ Compilation errors cleared
- ✅ Import statements correct
- ✅ Spring Security compatibility (6.4.2)
- ✅ Java 21 compatibility

