# Testing Multi-Realm Authentication

This guide provides step-by-step instructions for testing the multi-realm JWT authentication system in the Ride Flexi API Gateway.

## Prerequisites

- Gateway Service running on port 8080
- Discovery Service running on port 8761
- Keycloak accessible at https://auth.rydeflexi.com
- curl or Postman installed
- jq installed (for JSON parsing)

## Test Setup

### 1. Start Services

```bash
# Terminal 1: Start Discovery Service
cd /mnt/projects/Ride/discovery-service
mvn spring-boot:run

# Terminal 2: Start Gateway Service
cd /mnt/projects/Ride/gateway-service
mvn spring-boot:run

# Wait for services to register (check Eureka dashboard)
# http://localhost:8761
```

### 2. Verify Service Registration

```bash
# Check Eureka dashboard
curl http://localhost:8761/eureka/apps | grep -i gateway

# Check gateway health
curl http://localhost:8080/actuator/health
```

Expected Response:
```json
{
  "status": "UP",
  "components": {
    "discoveryComposite": {
      "status": "UP"
    }
  }
}
```

## Test Scenarios

### Scenario 1: User Authentication Flow

#### 1.1 Get User Token

```bash
# Using password grant (development only)
USER_TOKEN=$(curl -X POST \
  https://auth.rydeflexi.com/realms/user-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=user-auth" \
  -d "client_secret=your-user-secret" \
  -d "grant_type=password" \
  -d "username=testuser@example.com" \
  -d "password=testpass123" \
  | jq -r '.access_token')

echo "User Token: $USER_TOKEN"
```

#### 1.2 Decode and Inspect Token

```bash
# Decode JWT (without validation)
echo $USER_TOKEN | cut -d'.' -f2 | base64 -d | jq .
```

Expected Claims:
```json
{
  "sub": "550e8400-e29b-41d4-a716-446655440000",
  "iss": "https://auth.rydeflexi.com/realms/user-authentication",
  "preferred_username": "testuser@example.com",
  "email": "testuser@example.com",
  "realm_access": {
    "roles": ["USER"]
  }
}
```

#### 1.3 Call Protected Endpoint

```bash
# Test user endpoint
curl -X GET http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer $USER_TOKEN" \
  -v
```

Expected Headers Received by Downstream Service:
```
X-User-Id: 550e8400-e29b-41d4-a716-446655440000
X-Username: testuser@example.com
X-Email: testuser@example.com
X-Auth-Realm: user-authentication
X-Token: eyJhbGciOiJSUzI1NiIs...
```

#### 1.4 Check Gateway Logs

```bash
# Check logs for validation
tail -f /mnt/projects/Ride/gateway-service/logs/application.log | grep "user-authentication"
```

Expected Log Output:
```
Token issuer: https://auth.rydeflexi.com/realms/user-authentication
Validating token with user-authentication realm
User auth token validated: subject=550e8400-e29b-41d4-a716-446655440000
User 550e8400-e29b-41d4-a716-446655440000 authorized successfully from user-authentication realm
```

### Scenario 2: Service-to-Service Authentication

#### 2.1 Get Service Token

```bash
# Using client credentials grant
SERVICE_TOKEN=$(curl -X POST \
  https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=vehicle-service" \
  -d "client_secret=service-secret-here" \
  -d "grant_type=client_credentials" \
  | jq -r '.access_token')

echo "Service Token: $SERVICE_TOKEN"
```

#### 2.2 Decode and Inspect Token

```bash
echo $SERVICE_TOKEN | cut -d'.' -f2 | base64 -d | jq .
```

Expected Claims:
```json
{
  "sub": "service-account-vehicle-service",
  "iss": "https://auth.rydeflexi.com/realms/service-authentication",
  "azp": "vehicle-service",
  "client_id": "vehicle-service",
  "scope": "openid"
}
```

#### 2.3 Call Internal API

```bash
# Test service-to-service call
curl -X GET http://localhost:8080/api/v1/vehicles \
  -H "Authorization: Bearer $SERVICE_TOKEN" \
  -v
```

Expected Headers:
```
X-User-Id: service-account-vehicle-service
X-Username: 
X-Email: 
X-Auth-Realm: service-authentication
X-Token: eyJhbGciOiJSUzI1NiIs...
```

#### 2.4 Check Gateway Logs

```bash
tail -f /mnt/projects/Ride/gateway-service/logs/application.log | grep "service-authentication"
```

Expected Log Output:
```
Token issuer: https://auth.rydeflexi.com/realms/service-authentication
Validating token with service-authentication realm
Service auth token validated: subject=service-account-vehicle-service
User service-account-vehicle-service authorized successfully from service-authentication realm
```

### Scenario 3: Invalid Token Tests

#### 3.1 Missing Authorization Header

```bash
curl -X GET http://localhost:8080/api/v1/users/me -v
```

Expected Response:
```
HTTP/1.1 401 Unauthorized
```

#### 3.2 Malformed Token

```bash
curl -X GET http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer invalid.token.here" \
  -v
```

Expected Response:
```
HTTP/1.1 401 Unauthorized
```

Expected Log:
```
JWT validation failed: Invalid JWT format
```

#### 3.3 Expired Token

```bash
# Use an expired token
EXPIRED_TOKEN="eyJhbGciOiJSUzI1NiIsInR5cCI..."

curl -X GET http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer $EXPIRED_TOKEN" \
  -v
```

Expected Response:
```
HTTP/1.1 401 Unauthorized
```

Expected Log:
```
JWT validation failed: Token expired at 2026-01-25T10:00:00Z
```

#### 3.4 Unknown Issuer

```bash
# Create token with unknown issuer (mocked)
UNKNOWN_ISSUER_TOKEN="..."

curl -X GET http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer $UNKNOWN_ISSUER_TOKEN" \
  -v
```

Expected Log:
```
Unknown issuer: https://unknown.issuer.com
Expected https://auth.rydeflexi.com/realms/user-authentication or https://auth.rydeflexi.com/realms/service-authentication
```

### Scenario 4: Key Rotation Test

#### 4.1 Rotate Keys in Keycloak

1. Log in to Keycloak Admin Console
2. Navigate to Realm Settings → Keys
3. Click "Providers" tab
4. Add new RSA key provider
5. Set priority higher than existing provider
6. Generate new keys

#### 4.2 Get Token with New Key

```bash
NEW_TOKEN=$(curl -X POST \
  https://auth.rydeflexi.com/realms/user-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=user-auth" \
  -d "client_secret=your-secret" \
  -d "grant_type=password" \
  -d "username=testuser@example.com" \
  -d "password=testpass123" \
  | jq -r '.access_token')
```

#### 4.3 Verify New Key ID

```bash
echo $NEW_TOKEN | cut -d'.' -f1 | base64 -d | jq .
```

Expected Output:
```json
{
  "alg": "RS256",
  "typ": "JWT",
  "kid": "new-key-id-here"
}
```

#### 4.4 Test Token Validation

```bash
curl -X GET http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer $NEW_TOKEN" \
  -v
```

Expected Log:
```
No public key found for kid: new-key-id-here. Refetching JWKS from https://auth.rydeflexi.com/realms/user-authentication/.well-known/jwks.json...
Successfully cached 3 public keys from https://auth.rydeflexi.com/realms/user-authentication/.well-known/jwks.json
User auth token validated: subject=550e8400-e29b-41d4-a716-446655440000
```

### Scenario 5: JWKS Endpoint Verification

#### 5.1 Check User Auth JWKS

```bash
curl -X GET \
  https://auth.rydeflexi.com/realms/user-authentication/.well-known/jwks.json \
  | jq .
```

Expected Response:
```json
{
  "keys": [
    {
      "kid": "key-id-1",
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "n": "xGOr-H7A...",
      "e": "AQAB"
    },
    {
      "kid": "key-id-2",
      "kty": "RSA",
      "alg": "RS256",
      "use": "sig",
      "n": "yHPs-I8B...",
      "e": "AQAB"
    }
  ]
}
```

#### 5.2 Check Service Auth JWKS

```bash
curl -X GET \
  https://auth.rydeflexi.com/realms/service-authentication/.well-known/jwks.json \
  | jq .
```

### Scenario 6: Performance Testing

#### 6.1 Measure Token Validation Time

```bash
# Create test script
cat > test-performance.sh << 'EOF'
#!/bin/bash

TOKEN=$1
ITERATIONS=${2:-100}

echo "Testing $ITERATIONS requests..."
START=$(date +%s%N)

for i in $(seq 1 $ITERATIONS); do
  curl -s -X GET http://localhost:8080/api/v1/users/me \
    -H "Authorization: Bearer $TOKEN" \
    -o /dev/null
done

END=$(date +%s%N)
DURATION=$((($END - $START) / 1000000))
AVG=$(($DURATION / $ITERATIONS))

echo "Total time: ${DURATION}ms"
echo "Average per request: ${AVG}ms"
EOF

chmod +x test-performance.sh

# Run test
./test-performance.sh "$USER_TOKEN" 100
```

Expected Output:
```
Testing 100 requests...
Total time: 1523ms
Average per request: 15ms
```

#### 6.2 Cache Hit Rate

```bash
# Monitor logs for cache hits
grep "Cached public key" gateway-service/logs/application.log | wc -l
grep "Refetching JWKS" gateway-service/logs/application.log | wc -l
```

Expected: High cache hit rate (>99%)

### Scenario 7: Concurrent Requests

#### 7.1 Parallel Request Test

```bash
# Create concurrent test script
cat > test-concurrent.sh << 'EOF'
#!/bin/bash

TOKEN=$1
CONCURRENT=${2:-10}

echo "Testing $CONCURRENT concurrent requests..."

for i in $(seq 1 $CONCURRENT); do
  curl -s -X GET http://localhost:8080/api/v1/users/me \
    -H "Authorization: Bearer $TOKEN" \
    -w "Request $i: %{http_code}\n" \
    -o /dev/null &
done

wait
echo "All requests completed"
EOF

chmod +x test-concurrent.sh

# Run test
./test-concurrent.sh "$USER_TOKEN" 20
```

Expected: All requests return 200 OK

#### 7.2 Check for Race Conditions

```bash
# Monitor logs for concurrent key cache updates
grep -A 5 "Successfully cached" gateway-service/logs/application.log
```

Expected: No duplicate cache updates or errors

## Automated Test Suite

### Create Test Suite Script

```bash
cat > test-multi-realm-auth.sh << 'EOF'
#!/bin/bash

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "======================================="
echo "Multi-Realm Authentication Test Suite"
echo "======================================="

# Test 1: User Authentication
echo -e "\n${YELLOW}Test 1: User Authentication${NC}"
USER_TOKEN=$(curl -s -X POST \
  https://auth.rydeflexi.com/realms/user-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=user-auth" \
  -d "client_secret=your-secret" \
  -d "grant_type=password" \
  -d "username=testuser@example.com" \
  -d "password=testpass123" \
  | jq -r '.access_token')

if [ -n "$USER_TOKEN" ]; then
  echo -e "${GREEN}✓ User token obtained${NC}"
else
  echo -e "${RED}✗ Failed to obtain user token${NC}"
  exit 1
fi

# Test 2: User Token Validation
echo -e "\n${YELLOW}Test 2: User Token Validation${NC}"
RESPONSE=$(curl -s -w "%{http_code}" -X GET \
  http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer $USER_TOKEN")

HTTP_CODE="${RESPONSE: -3}"
if [ "$HTTP_CODE" == "200" ]; then
  echo -e "${GREEN}✓ User token validated successfully${NC}"
else
  echo -e "${RED}✗ User token validation failed (HTTP $HTTP_CODE)${NC}"
  exit 1
fi

# Test 3: Service Authentication
echo -e "\n${YELLOW}Test 3: Service Authentication${NC}"
SERVICE_TOKEN=$(curl -s -X POST \
  https://auth.rydeflexi.com/realms/service-authentication/protocol/openid-connect/token \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=vehicle-service" \
  -d "client_secret=service-secret" \
  -d "grant_type=client_credentials" \
  | jq -r '.access_token')

if [ -n "$SERVICE_TOKEN" ]; then
  echo -e "${GREEN}✓ Service token obtained${NC}"
else
  echo -e "${RED}✗ Failed to obtain service token${NC}"
  exit 1
fi

# Test 4: Service Token Validation
echo -e "\n${YELLOW}Test 4: Service Token Validation${NC}"
RESPONSE=$(curl -s -w "%{http_code}" -X GET \
  http://localhost:8080/api/v1/vehicles \
  -H "Authorization: Bearer $SERVICE_TOKEN")

HTTP_CODE="${RESPONSE: -3}"
if [ "$HTTP_CODE" == "200" ]; then
  echo -e "${GREEN}✓ Service token validated successfully${NC}"
else
  echo -e "${RED}✗ Service token validation failed (HTTP $HTTP_CODE)${NC}"
  exit 1
fi

# Test 5: Invalid Token
echo -e "\n${YELLOW}Test 5: Invalid Token Rejection${NC}"
RESPONSE=$(curl -s -w "%{http_code}" -X GET \
  http://localhost:8080/api/v1/users/me \
  -H "Authorization: Bearer invalid.token.here")

HTTP_CODE="${RESPONSE: -3}"
if [ "$HTTP_CODE" == "401" ]; then
  echo -e "${GREEN}✓ Invalid token rejected correctly${NC}"
else
  echo -e "${RED}✗ Invalid token not rejected (HTTP $HTTP_CODE)${NC}"
  exit 1
fi

# Test 6: Missing Authorization Header
echo -e "\n${YELLOW}Test 6: Missing Authorization Header${NC}"
RESPONSE=$(curl -s -w "%{http_code}" -X GET \
  http://localhost:8080/api/v1/users/me)

HTTP_CODE="${RESPONSE: -3}"
if [ "$HTTP_CODE" == "401" ]; then
  echo -e "${GREEN}✓ Missing auth header rejected correctly${NC}"
else
  echo -e "${RED}✗ Missing auth header not rejected (HTTP $HTTP_CODE)${NC}"
  exit 1
fi

echo -e "\n${GREEN}=======================================${NC}"
echo -e "${GREEN}All tests passed successfully!${NC}"
echo -e "${GREEN}=======================================${NC}"
EOF

chmod +x test-multi-realm-auth.sh
```

### Run Test Suite

```bash
./test-multi-realm-auth.sh
```

## Monitoring and Debugging

### Enable Debug Logging

```yaml
# application.yml
logging:
  level:
    com.ride.gatewayservice: DEBUG
    org.springframework.security: DEBUG
```

### Monitor Logs in Real-Time

```bash
# Terminal 1: General logs
tail -f gateway-service/logs/application.log

# Terminal 2: Security-specific logs
tail -f gateway-service/logs/application.log | grep -E "(JWT|authentication|authorization)"

# Terminal 3: Performance metrics
tail -f gateway-service/logs/application.log | grep -E "(cached|fetched|validated)"
```

### Check Actuator Metrics

```bash
# Health check
curl http://localhost:8080/actuator/health | jq .

# Metrics
curl http://localhost:8080/actuator/metrics | jq .

# Specific metric
curl http://localhost:8080/actuator/metrics/http.server.requests | jq .
```

## Troubleshooting Common Issues

### Issue 1: Gateway Cannot Reach Keycloak

**Symptoms**:
```
Failed to fetch JWKS from https://auth.rydeflexi.com/realms/user-authentication/.well-known/jwks.json
```

**Debug Steps**:
```bash
# Test network connectivity
curl -v https://auth.rydeflexi.com/realms/user-authentication/.well-known/jwks.json

# Check DNS resolution
nslookup auth.rydeflexi.com

# Check firewall rules
iptables -L -n -v
```

### Issue 2: Token Validation Fails

**Symptoms**:
```
JWT validation failed: Invalid signature
```

**Debug Steps**:
```bash
# Decode token header
echo $TOKEN | cut -d'.' -f1 | base64 -d | jq .

# Check kid matches JWKS
curl https://auth.rydeflexi.com/realms/user-authentication/.well-known/jwks.json | jq '.keys[] | .kid'

# Verify issuer
echo $TOKEN | cut -d'.' -f2 | base64 -d | jq '.iss'
```

### Issue 3: Wrong Realm Routing

**Symptoms**:
```
Unknown issuer: https://auth.rydeflexi.com/realms/wrong-realm
```

**Debug Steps**:
```bash
# Check configured issuers
curl http://localhost:8080/actuator/env | jq '.propertySources[] | select(.name | contains("application.yml"))'

# Verify token issuer
echo $TOKEN | cut -d'.' -f2 | base64 -d | jq '.iss'
```

## Best Practices

1. **Always Use HTTPS in Production**
2. **Rotate Keys Regularly** (every 90 days)
3. **Monitor Token Expiration**
4. **Set Appropriate Timeouts** (10s for JWKS fetch)
5. **Implement Rate Limiting**
6. **Log Security Events**
7. **Test Key Rotation Regularly**
8. **Use Separate Realms** for users and services

## References

- [Multi-Realm Auth Guide](MULTI_REALM_AUTH_GUIDE.md)
- [JWKS Authentication](../gateway-service/JWKS_AUTHENTICATION.md)
- [Keycloak Testing](https://www.keycloak.org/docs/latest/server_admin/#_testing)
