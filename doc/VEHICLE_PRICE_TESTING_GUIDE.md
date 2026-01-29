# Vehicle Price Creation - Testing & Integration Guide

## Integration Overview

The vehicle price creation feature integrates three microservices:

```
Owner BFF Service
    ↓
Vehicle Service
    ↓
Pricing Service
```

## 1. Testing createVehiclePrice Implementation

### Unit Test Example

```java
import com.ride.ownerbff.dto.VehiclePriceDto;
import com.ride.ownerbff.service.IPriceServiceClient;
import com.ride.ownerbff.service.impl.VehicleService;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.InjectMocks;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import reactor.core.publisher.Mono;

import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class VehicleServiceTest {

    @Mock
    private IPriceServiceClient priceServiceClient;

    @InjectMocks
    private VehicleService vehicleService;

    @Test
    void testCreateVehiclePrice_Success() {
        // Arrange
        VehiclePriceDto inputDto = VehiclePriceDto.builder()
                .userId("user-123")
                .vehicleId("vehicle-456")
                .vehicleBodyType("SUV")
                .currencyCode("USD")
                .perDay(100.0)
                .perWeek(600.0)
                .perMonth(2400.0)
                .build();

        when(priceServiceClient.createPrice(any(VehiclePriceDto.class)))
                .thenReturn(Mono.just("{\"id\":\"123\",\"vehicleId\":\"vehicle-456\"}"));

        // Act
        VehiclePriceDto result = vehicleService.createVehiclePrice(inputDto);

        // Assert
        assertNotNull(result);
        assertEquals(inputDto.getUserId(), result.getUserId());
        assertEquals(inputDto.getVehicleId(), result.getVehicleId());
    }

    @Test
    void testCreateVehiclePrice_NullResponse() {
        // Arrange
        VehiclePriceDto inputDto = VehiclePriceDto.builder()
                .userId("user-123")
                .vehicleId("vehicle-456")
                .vehicleBodyType("SUV")
                .currencyCode("USD")
                .perDay(100.0)
                .perWeek(600.0)
                .perMonth(2400.0)
                .build();

        when(priceServiceClient.createPrice(any(VehiclePriceDto.class)))
                .thenReturn(Mono.just(""));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> vehicleService.createVehiclePrice(inputDto));
    }

    @Test
    void testCreateVehiclePrice_ServiceError() {
        // Arrange
        VehiclePriceDto inputDto = VehiclePriceDto.builder()
                .userId("user-123")
                .vehicleId("vehicle-456")
                .vehicleBodyType("SUV")
                .currencyCode("USD")
                .perDay(100.0)
                .perWeek(600.0)
                .perMonth(2400.0)
                .build();

        when(priceServiceClient.createPrice(any(VehiclePriceDto.class)))
                .thenReturn(Mono.error(new RuntimeException("Service unavailable")));

        // Act & Assert
        assertThrows(RuntimeException.class, () -> vehicleService.createVehiclePrice(inputDto));
    }
}
```

### Integration Test Example

```java
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.web.servlet.MockMvc;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class VehiclePriceIntegrationTest {

    @Autowired
    private MockMvc mockMvc;

    @Test
    void testCreateVehiclePrice_E2E() throws Exception {
        String requestBody = """
                {
                    "userId": "user-123",
                    "vehicleId": "vehicle-456",
                    "vehicleBodyType": "SUV",
                    "currencyCode": "USD",
                    "perDay": 100.0,
                    "perWeek": 600.0,
                    "perMonth": 2400.0
                }
                """;

        mockMvc.perform(post("/api/v1/vehicles/prices")
                        .contentType("application/json")
                        .content(requestBody)
                        .header("Authorization", "Bearer token-here"))
                .andExpect(status().isOk());
    }
}
```

## 2. Manual Testing with cURL

### Test 1: Create Vehicle Price (Happy Path)

```bash
#!/bin/bash

# Variables
GATEWAY_URL="http://localhost:8080"
ENDPOINT="/api/v1/vehicles/prices"
AUTH_TOKEN="your-bearer-token-here"

# Create vehicle price
curl -X POST \
  "${GATEWAY_URL}${ENDPOINT}" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${AUTH_TOKEN}" \
  -d '{
    "userId": "12345",
    "vehicleId": "67890",
    "vehicleBodyType": "SUV",
    "currencyCode": "USD",
    "perDay": 100.0,
    "perWeek": 600.0,
    "perMonth": 2400.0
  }' \
  -v

# Expected Response: 200 OK
# {
#   "userId": "12345",
#   "vehicleId": "67890",
#   "vehicleBodyType": "SUV",
#   "currencyCode": "USD",
#   "perDay": 100.0,
#   "perWeek": 600.0,
#   "perMonth": 2400.0
# }
```

### Test 2: Invalid Input (Null DTO)

```bash
curl -X POST \
  "http://localhost:8080/api/v1/vehicles/prices" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token-here" \
  -d '{}' \
  -v

# Expected Response: 400 Bad Request or validation error
```

### Test 3: Missing Authorization

```bash
curl -X POST \
  "http://localhost:8080/api/v1/vehicles/prices" \
  -H "Content-Type: application/json" \
  -d '{
    "userId": "12345",
    "vehicleId": "67890",
    "vehicleBodyType": "SUV",
    "currencyCode": "USD",
    "perDay": 100.0,
    "perWeek": 600.0,
    "perMonth": 2400.0
  }' \
  -v

# Expected Response: 401 Unauthorized
```

## 3. Database Verification

### Check Created Records in Pricing Service DB

```sql
-- Check if vehicle price was created
SELECT * FROM vehicle_price 
WHERE vehicle_id = '67890' 
ORDER BY created_at DESC 
LIMIT 1;

-- Check price range
SELECT * FROM price_range 
WHERE id IN (
  SELECT price_range_id FROM vehicle_price 
  WHERE vehicle_id = '67890'
) 
ORDER BY created_at DESC 
LIMIT 1;

-- Verify commission was applied
SELECT * FROM commission 
WHERE vehicle_type_id = 'SUV';
```

## 4. Service Communication Flow Test

### Step 1: Verify Owner BFF can reach Vehicle Service

```bash
# From Owner BFF container
curl -X POST \
  "http://vehicle-service:8084/api/v1/vehicles" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SERVICE_TOKEN}" \
  -d '{
    "userId": "12345",
    "vehicleId": "67890",
    "availableFrom": "2026-01-20",
    "availableUntil": "2026-12-31",
    "bodyTypeId": "SUV"
  }'
```

### Step 2: Verify Vehicle Service can reach Pricing Service

```bash
# From Vehicle Service container
curl -X POST \
  "http://pricing-service:8082/api/v1/price" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${SERVICE_TOKEN}" \
  -d '{
    "userId": "12345",
    "vehicleId": "67890",
    "vehicleBodyType": "SUV",
    "currencyCode": "USD",
    "perDay": 100.0,
    "perWeek": 600.0,
    "perMonth": 2400.0
  }'
```

## 5. Error Scenarios Testing

### Scenario A: Pricing Service Timeout

```
Expected Behavior:
1. Owner BFF calls PriceServiceClient.createPrice()
2. WebClient request times out
3. onErrorResume catches timeout exception
4. VehicleService catches and re-throws RuntimeException
5. Client receives 500 Internal Server Error with message
```

**Test Command:**
```bash
# Stop pricing service and try to create price
docker-compose stop pricing-service

curl -X POST "http://localhost:8080/api/v1/vehicles/prices" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer token" \
  -d '{"userId":"12345","vehicleId":"67890",...}'

# Expected: Connection timeout error
```

### Scenario B: Invalid Token

```
Expected Behavior:
1. ServiceTokenService returns invalid/expired token
2. Pricing Service rejects request with 401 Unauthorized
3. PriceServiceClient logs error
4. VehicleService catches exception
5. Client receives error response
```

**Test Command:**
```bash
curl -X POST "http://localhost:8080/api/v1/vehicles/prices" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer invalid-token" \
  -d '{"userId":"12345","vehicleId":"67890",...}'

# Expected: 401 Unauthorized
```

### Scenario C: Database Connection Error

```
Expected Behavior:
1. Pricing Service database connection fails
2. PriceService.addPrice() throws exception
3. PriceService logs and returns error
4. PriceServiceClient receives error response
5. VehicleService logs and throws RuntimeException
```

## 6. Load Testing

### Using Apache JMeter

```xml
<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testname="Vehicle Price Creation Load Test">
      <ThreadGroup guiclass="ThreadGroupGui" testname="Vehicle Price Creators">
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController">
          <intProp name="LoopController.loops">100</intProp>
          <boolProp name="LoopController.continue_forever">false</boolProp>
        </elementProp>
        <stringProp name="ThreadGroup.num_threads">10</stringProp>
        <stringProp name="ThreadGroup.ramp_time">10</stringProp>
      </ThreadGroup>
      <HTTPSampler guiclass="HttpTestSampleGui" testname="Create Vehicle Price">
        <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
          <HTTPArgument>
            <name>userId</name>
            <value>user-${__threadNum}</value>
          </HTTPArgument>
          <HTTPArgument>
            <name>vehicleId</name>
            <value>vehicle-${__counter()}</value>
          </HTTPArgument>
        </elementProp>
        <stringProp name="HTTPSampler.domain">localhost</stringProp>
        <stringProp name="HTTPSampler.port">8080</stringProp>
        <stringProp name="HTTPSampler.path">/api/v1/vehicles/prices</stringProp>
        <stringProp name="HTTPSampler.method">POST</stringProp>
      </HTTPSampler>
    </TestPlan>
  </hashTree>
</jmeterTestPlan>
```

## 7. Monitoring & Logging

### Application Logs to Monitor

```
# Owner BFF Logs
2026-01-22T10:30:00 INFO  - Creating vehicle price for userId: 12345, vehicleId: 67890
2026-01-22T10:30:01 INFO  - Successfully created vehicle price for vehicleId: 67890

# Pricing Service Logs
2026-01-22T10:30:01 INFO  - Adding price for vehicleId: 67890
2026-01-22T10:30:02 INFO  - Commission percentage: 15%
2026-01-22T10:30:03 INFO  - Price range saved successfully
```

### Metrics to Track

| Metric | Target | Tool |
|--------|--------|------|
| Request latency | < 500ms | Actuator/Prometheus |
| Error rate | < 0.5% | Actuator/ELK Stack |
| Database writes | > 100/sec | Database monitoring |
| Service availability | > 99.9% | Health checks |

## 8. Pre-Deployment Checklist

```
□ All unit tests passing
□ Integration tests passing
□ No compilation errors
□ No code quality warnings
□ Database migrations verified
□ Service dependencies running
□ Environment variables configured
□ OAuth2 tokens obtainable
□ WebClient configurations correct
□ Error handling tested
□ Load testing completed (1000+ req/sec)
□ Security review passed
□ Documentation complete
□ Rollback plan ready
```

## 9. Deployment Verification

### Post-Deployment Tests

```bash
#!/bin/bash

# Test endpoint availability
echo "Testing endpoint availability..."
curl -s -o /dev/null -w "%{http_code}" \
  "http://api.rydeflexi.com/api/v1/vehicles/prices"

# Test with valid request
echo "Testing valid request..."
curl -X POST \
  "http://api.rydeflexi.com/api/v1/vehicles/prices" \
  -H "Content-Type: application/json" \
  -H "Authorization: Bearer ${PROD_TOKEN}" \
  -d '{
    "userId": "test-user",
    "vehicleId": "test-vehicle",
    "vehicleBodyType": "SUV",
    "currencyCode": "USD",
    "perDay": 100.0,
    "perWeek": 600.0,
    "perMonth": 2400.0
  }'

# Verify database records created
echo "Verifying database records..."
mysql -h pricing-db.prod -u user -p${DB_PASSWORD} -e \
  "SELECT COUNT(*) FROM vehicle_price WHERE created_at > DATE_SUB(NOW(), INTERVAL 5 MINUTE);"
```

## 10. Troubleshooting Guide

### Issue: 401 Unauthorized from Pricing Service

**Possible Causes:**
- ServiceTokenService not returning valid token
- Token expired
- Service account permissions incorrect

**Resolution:**
1. Check ServiceTokenService logs
2. Verify Keycloak configuration
3. Validate service account credentials
4. Check token expiration time

### Issue: 500 Internal Server Error

**Possible Causes:**
- Database connection failure
- Exception in commission calculation
- Price range save failure

**Resolution:**
1. Check database connectivity
2. Review pricing service logs
3. Verify commission configuration
4. Check for null values in request

### Issue: Request Timeout

**Possible Causes:**
- Pricing service slow
- Database queries slow
- Network latency

**Resolution:**
1. Check pricing service performance
2. Analyze database queries
3. Increase WebClient timeout
4. Check network connectivity

---

**Status:** ✅ TESTING GUIDE COMPLETE

Next Steps:
1. Run all test scenarios
2. Verify in development environment
3. Execute load tests
4. Deploy to staging
5. Perform final verification
6. Deploy to production
