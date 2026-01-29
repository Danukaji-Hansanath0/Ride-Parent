## Plan: Secure Keycloak Auth Service from Malformed Requests and Bot Attacks

This plan addresses the observed Keycloak errors (IDENTITY_PROVIDER_LOGIN_ERROR, malformed JSON tokens, invalid UTF-8, null clientId/userId) by implementing multi-layered security measures including request validation, rate limiting, IP filtering, proper error handling, and monitoring improvements across the Spring Boot auth-service.

### Steps

1. **Fix RestTemplate Configuration Bug** in [AppConfig.java](../../auth-service/src/main/java/com/ride/authservice/config/AppConfig.java) - Currently creates `RequestValidationInterceptor` but returns a new unconfigured `RestTemplate` instead of the configured instance; also create the missing `RequestValidationInterceptor` class to validate request/response encoding and JSON structure.

2. **Implement Request Validation Layer** - Create new `filter` package with `RequestValidationFilter` to validate UTF-8 encoding, JSON structure, Content-Type headers, and request size limits before reaching controllers; add handler in [GlobalExceptionHandler.java](../../auth-service/src/main/java/com/ride/authservice/exception/GlobalExceptionHandler.java) for `HttpMessageNotReadableException`, `MalformedJsonException`, and `CharacterCodingException`.

3. **Add Rate Limiting with Resilience4j** - Add `resilience4j-ratelimiter` dependency to [pom.xml](../../auth-service/pom.xml) (already available in parent); configure rate limiters in new `RateLimitConfig.java` for endpoints (/api/auth/login, /api/auth/register, /api/login/google/mobile) with IP-based and global limits; create `@RateLimited` annotation and AOP aspect to apply limits declaratively.

4. **Implement IP-Based Security** - Create `IpSecurityFilter` to track suspicious IPs (multiple failed attempts, malformed requests); integrate with Redis or in-memory cache (Caffeine) for distributed rate limiting and IP blacklist; add IP logging to all authentication attempts with geolocation data if possible; configure in [application.yml](../../auth-service/src/main/resources/application.yml).

5. **Enhance Input Validation at Controller Level** - Add `@Valid` annotation to all `@RequestBody` parameters in [AuthController.java](../../auth-service/src/main/java/com/ride/authservice/controller/AuthController.java) and [MobileAuthController.java](../../auth-service/src/main/java/com/ride/authservice/controller/MobileAuthController.java); add validation constraints to [EmailChangeRequest.java](../../auth-service/src/main/java/com/ride/authservice/dto/EmailChangeRequest.java); add `@Pattern`, `@Size` constraints to all `@RequestParam` for code_verifier, redirectUri, etc.

6. **Implement OAuth2/Keycloak Error Handler** - Create `OAuth2ExceptionHandler` to catch and properly handle Keycloak-specific errors (token exchange failures, invalid client data); add detailed logging for IDENTITY_PROVIDER errors with sanitized request details; enhance error responses in [KeycloakOAuth2AdminServiceAppImpl.java](../../auth-service/src/main/java/com/ride/authservice/service/impl/KeycloakOAuth2AdminServiceAppImpl.java) and [KeycloakAdminServiceImpl.java](../../auth-service/src/main/java/com/ride/authservice/service/impl/KeycloakAdminServiceImpl.java) to catch `RestClientException`, `JsonProcessingException`, and HTTP client errors.

7. **Configure Security Headers and CORS** - Update [SecurityConfig.java](../../auth-service/src/main/java/com/ride/authservice/config/SecurityConfig.java) to add security headers (X-Content-Type-Options, X-Frame-Options, X-XSS-Protection, Content-Security-Policy, Strict-Transport-Security); create `WebMvcConfig` implementing `WebMvcConfigurer` for CORS configuration with strict allowed origins; add request/response logging interceptor.

8. **Enhance Logging and Monitoring** - Create `SecurityEventLogger` service to log all security events (failed auth attempts, rate limit triggers, malformed requests, suspicious IPs) with structured JSON logging; add custom metrics using Micrometer for failed authentication rates, malformed request counts, and rate limit hits; integrate with existing actuator endpoints; create alert thresholds for anomaly detection.

9. **Add Circuit Breaker for Keycloak Communication** - Apply `@CircuitBreaker` from Resilience4j to Keycloak admin service methods in [KeycloakAdminServiceImpl.java](../../auth-service/src/main/java/com/ride/authservice/service/impl/KeycloakAdminServiceImpl.java); configure fallback responses for when Keycloak is unavailable; add retry logic with exponential backoff for transient failures.

10. **Create Security Configuration Properties** - Externalize all security settings to [application.yml](../../auth-service/src/main/resources/application.yml) and [application-production.yml](../../auth-service/src/main/resources/application-production.yml) including rate limits, IP whitelist/blacklist, request size limits, timeout configurations; create `@ConfigurationProperties` class `SecurityProperties` for type-safe configuration binding.

### Further Considerations

1. **Testing Strategy** - Should we create integration tests for rate limiting behavior, unit tests for malformed request handling, and load tests to verify bot attack mitigation? Recommended: Yes, add test classes for each security component with scenarios for edge cases.

2. **Redis vs In-Memory Storage** - For distributed rate limiting and IP blacklist in production, should we use Redis (requires additional infrastructure) or Caffeine (in-memory, simpler but not distributed)? Recommendation: Start with Caffeine for MVP, provide Redis configuration option for production scalability.

3. **Bot Detection Enhancement** - Should we integrate with external bot detection services (Cloudflare Bot Management, reCAPTCHA Enterprise) or implement custom ML-based detection? Recommendation: Add reCAPTCHA v3 to sensitive endpoints (login, register) as Phase 2 enhancement.

4. **Monitoring Dashboard** - Should we create a dedicated security dashboard using Grafana to visualize attack patterns, or rely on existing logging infrastructure? Recommendation: Export metrics to Prometheus and create basic Grafana dashboard for security KPIs.

