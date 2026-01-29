# Security Implementation - Quick Reference

## 🚀 Quick Start

### Environment Variables
```bash
# Required for production
export SECURITY_IP_ENABLED=true
export SECURITY_IP_MAX_FAILED_ATTEMPTS=10
export SECURITY_IP_MAX_REQUESTS_PER_MINUTE=60
export CORS_ALLOWED_ORIGINS=https://app.rydeflexi.com
```

### Build & Deploy
```bash
# Build
cd /mnt/projects/Ride/auth-service
mvn clean package -DskipTests

# Run locally
java -jar target/auth-service-1.0.0-SNAPSHOT.jar

# Docker build
docker build -t auth-service:latest .
```

## 🔍 Health Checks

### Endpoints
- Health: `http://localhost:8081/actuator/health`
- Metrics: `http://localhost:8081/actuator/prometheus`
- Info: `http://localhost:8081/actuator/info`

### Check Circuit Breaker
```bash
curl http://localhost:8081/actuator/health | jq '.components.circuitBreakers'
```

## 🛡️ Security Features

| Feature | Status | Config |
|---------|--------|--------|
| Request Validation | ✅ Enabled | `security.request-validation.enabled` |
| Rate Limiting | ✅ 60 req/min | `security.ip.max-requests-per-minute` |
| Auto-Blacklist | ✅ 10 attempts | `security.ip.max-failed-attempts` |
| Circuit Breaker | ✅ Enabled | `resilience4j.circuitbreaker.instances.keycloak` |
| Retry Logic | ✅ 3 attempts | `resilience4j.retry.instances.keycloak` |

## 📊 Common Commands

### View Security Logs
```bash
# Docker
docker logs auth-service | grep "SECURITY_EVENT"

# Local
tail -f logs/auth-service.log | grep "SECURITY_EVENT"
```

### Clear IP Blacklist
```java
// In code or via admin endpoint
ipSecurityFilter.clearBlacklist("192.168.1.100");
```

### Test Security

#### Test Malformed Request
```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d 'invalid-json'
```
Expected: `400 Bad Request`

#### Test Rate Limit
```bash
for i in {1..65}; do 
  curl http://localhost:8081/api/auth/login; 
done
```
Expected: `429 Too Many Requests` after 60 requests

#### Test Circuit Breaker
```bash
# Stop Keycloak, then:
curl http://localhost:8081/api/auth/login
```
Expected: `503 Service Unavailable`

## 🔧 Troubleshooting

### Issue: Users Getting Blocked
**Symptoms**: Legitimate users receive 403 responses  
**Solution**:
1. Check IP in whitelist: `security.ip.whitelist`
2. Increase threshold: `security.ip.max-failed-attempts=20`
3. Clear blacklist manually

### Issue: High CPU Usage
**Symptoms**: CPU spike on auth-service  
**Solution**:
1. Check metrics: `/actuator/metrics/process.cpu.usage`
2. Review cache size: May need Redis for distributed deployment
3. Increase rate limit if too strict

### Issue: Circuit Breaker Always Open
**Symptoms**: All requests failing with 503  
**Solution**:
1. Check Keycloak availability
2. Review logs: `grep "circuit_breaker" logs/*.log`
3. Adjust threshold: `resilience4j.circuitbreaker.failure-rate-threshold=70`

## 📈 Key Metrics

```bash
# Rate limit hits
curl http://localhost:8081/actuator/metrics/security.rate_limit_exceeded_total

# Failed auth attempts
curl http://localhost:8081/actuator/metrics/security.failed_auth_attempts_total

# Circuit breaker state
curl http://localhost:8081/actuator/metrics/resilience4j.circuitbreaker.state
```

## 🔐 Security Event Types

| Event | Meaning | Action |
|-------|---------|--------|
| `FAILED_AUTH_ATTEMPT` | Wrong password | Track failures |
| `RATE_LIMIT_EXCEEDED` | Too many requests | Block temporarily |
| `IP_BLACKLISTED` | Auto-banned | Block for 60min |
| `MALFORMED_REQUEST` | Invalid data | Double-count failure |
| `KEYCLOAK_ERROR` | Service error | Trigger circuit breaker |

## 🚨 Production Settings

### Conservative (High Security)
```yaml
security:
  ip:
    max-failed-attempts: 5
    max-requests-per-minute: 30
    blacklist-duration-minutes: 120
```

### Moderate (Balanced)
```yaml
security:
  ip:
    max-failed-attempts: 10
    max-requests-per-minute: 60
    blacklist-duration-minutes: 60
```

### Lenient (Development)
```yaml
security:
  ip:
    max-failed-attempts: 20
    max-requests-per-minute: 100
    blacklist-duration-minutes: 15
```

## 📚 Documentation

- Full Implementation: `/auth-service/SECURITY_IMPLEMENTATION.md`
- Summary: `/doc/KEYCLOAK_SECURITY_FIX.md`
- Plan: `/plan-secureKeycloakAuthService.prompt.md`

## 🆘 Emergency Actions

### Disable Security Temporarily
```yaml
security:
  ip:
    enabled: false
  request-validation:
    enabled: false
```

### Reset All Blacklists
```bash
# Restart service (clears in-memory cache)
docker restart auth-service
```

### View Real-Time Attacks
```bash
watch -n 1 'curl -s http://localhost:8081/actuator/metrics/security.malformed_requests_total | jq'
```

---

**Quick Links**:
- Health: http://localhost:8081/actuator/health
- Metrics: http://localhost:8081/actuator/prometheus
- Swagger: http://localhost:8081/swagger-ui.html

