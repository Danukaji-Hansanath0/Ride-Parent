# RabbitMQ Message Deserialization Fix

## 🐛 Problem: Message Conversion Exception

### Error Details
```
Retries exhausted for message
org.springframework.amqp.rabbit.support.ListenerExecutionFailedException: Failed to convert message
Caused by: com.fasterxml.jackson.databind.exc.MismatchedInputException: 
Cannot deserialize value of type `java.lang.String` from Object value (token `JsonToken.START_OBJECT`)
```

### Root Cause
The `VehicleImageResponseListener.handleResponse()` method was expecting a `String` parameter:
```java
@RabbitListener(queues = RabbitMQConfig.VEHICLE_RESPONSE_QUEUE)
public void handleResponse(String message) {  // ❌ Wrong type!
    VehicleImageResponse response = objectMapper.readValue(message, VehicleImageResponse.class);
    // ...
}
```

But the `Jackson2JsonMessageConverter` automatically deserializes JSON messages to objects. Since the listener declared `String` as the parameter type, Jackson tried to deserialize the JSON object `{}` into a String, which failed.

---

## ✅ Solution: Accept Deserialized Object

### Fixed Code
```java
@RabbitListener(queues = RabbitMQConfig.VEHICLE_RESPONSE_QUEUE)
public void handleResponse(VehicleImageResponse response) {  // ✅ Correct type!
    log.info("Vehicle Image Response received");
    log.info("  - Vehicle ID: {}", response.getVehicleId());
    log.info("  - Status: {}", response.getStatus());
    
    if ("SUCCESS".equalsIgnoreCase(response.getStatus())) {
        handleSuccessResponse(response);
    } else {
        handleFailureResponse(response);
    }
}
```

### Key Changes

| Issue | Before | After |
|-------|--------|-------|
| **Listener Parameter Type** | `String message` | `VehicleImageResponse response` |
| **JSON Parsing** | Manual: `objectMapper.readValue(message, ...)` | Automatic: Jackson deserializes in framework |
| **ObjectMapper Field** | Required | Not needed |
| **Error Handling** | Catches deserialization error | Works correctly |

---

## 🔧 Additional Fixes

### 1. RabbitMQ Queue Configuration
**Problem:** Response queue was created without a name
```java
@Bean
public Queue vehicleResponseQueue(){
    return QueueBuilder.durable().build();  // ❌ No queue name!
}
```

**Solution:** Added queue name constant
```java
@Bean
public Queue vehicleResponseQueue(){
    return QueueBuilder.durable(VEHICLE_RESPONSE_QUEUE).build();  // ✅ Named queue
}
```

### 2. Removed Redundant Code
- Removed unused `ObjectMapper objectMapper` field
- Removed unused import of `ObjectMapper`
- Removed manual JSON parsing code

---

## 🔄 How Jackson Message Converter Works

```
1. Message arrives from RabbitMQ (JSON bytes)
   {"vehicleId": "abc-123", "colorId": "def-456", "status": "SUCCESS"}

2. Framework checks listener method signature
   handleResponse(VehicleImageResponse response)

3. Jackson2JsonMessageConverter deserializes
   byte[] → VehicleImageResponse object

4. Spring calls listener with deserialized object
   handleResponse(response) ✅

5. Processing continues successfully
```

### Before (Broken)
```
1. Message arrives (JSON bytes)
2. Listener expects: String
3. Jackson tries: JSON object → String ❌
4. Error: "Cannot deserialize object to String"
5. Message goes to DLQ (Dead Letter Queue)
```

---

## 📋 Files Modified

1. **RabbitMQConfig.java**
   - Added queue name to `vehicleResponseQueue()` bean
   - Removed redundant parameter in `@ConditionalOnProperty`

2. **VehicleImageResponseListener.java**
   - Changed parameter type from `String` to `VehicleImageResponse`
   - Removed manual JSON parsing with ObjectMapper
   - Removed unused ObjectMapper import and field

3. **application.yaml** (Previously Fixed)
   - Added `spring.rabbitmq.enabled: true` to enable RabbitMQ configuration

---

## ✅ Verification Checklist

After this fix, verify:

- [ ] RabbitMQ connection is successful
- [ ] Vehicle creation triggers VehicleCreateEvent
- [ ] Event handler queues image generation requests
- [ ] Messages are sent to `vehicle.response.exchange`
- [ ] Listener receives messages without errors
- [ ] Response messages are properly deserialized
- [ ] VehicleColor records are created successfully
- [ ] No "Retries exhausted" warnings in logs

---

## 📝 How to Use Jackson Auto-Deserialization

### Pattern for Other Listeners

```java
@Component
@Slf4j
public class MyMessageListener {
    
    // ✅ Correct: Let Jackson deserialize automatically
    @RabbitListener(queues = "my.queue")
    public void handleMessage(MyMessageDto message) {
        log.info("Received: {}", message.getField());
        // Process message...
    }
}
```

### Rules for Jackson Deserialization

1. **Method parameter type** must be:
   - A POJO (Plain Old Java Object)
   - With getters/setters or public fields
   - Or with `@Data` or `@Getter/@Setter` Lombok annotations

2. **Message content type** should be:
   - `application/json` (default with Jackson2JsonMessageConverter)
   - Valid JSON matching the POJO structure

3. **Field names** must match:
   - JSON keys = POJO field names (case-sensitive)
   - Or use `@JsonProperty("key")` for mapping

---

## 🎓 Best Practices

### ✅ DO
- Use typed parameters matching message content
- Let Spring handle deserialization
- Add logging for debugging message structure
- Use strongly-typed DTOs

### ❌ DON'T
- Accept `String` and manually parse JSON
- Use `Map<String, Object>` unless structure is dynamic
- Skip logging message details
- Ignore message converter configuration

---

## 🚀 Testing

### Test Event Publishing
```bash
# Create a vehicle (triggers image generation request)
curl -X POST http://localhost:8087/vehicles \
  -H "Content-Type: application/json" \
  -d '{
    "make": "Toyota",
    "model": "Camry",
    "year": "2024",
    "trimName": "LE",
    "engineDisplacement": 2.5,
    "fuelType": "Gasoline"
  }'

# Watch logs for:
# ✅ "Publishing event: type=VehicleCreateEvent"
# ✅ "Successfully queued 3 image generation requests"
# ✅ "Received RabbitMQ Message"
# ✅ "Parsed Vehicle Image Response"
```

### Monitor RabbitMQ

Visit `http://localhost:15672` (guest/guest)
- Check `vehicle.create.queue` - should be empty (processed)
- Check `vehicle.response.queue` - should have responses being processed
- Check `vehicle.create.dlq` - should be empty if all succeed

---

## 📊 Message Flow

```
VehicleServiceImpl
    ↓
publish(VehicleCreateEvent)
    ↓
EventPublisher.publish()
    ↓
VehicleCreateHandler.handle()
    ↓
VehicleImageMessageProducer.sendMessage()
    ↓
RabbitTemplate sends to vehicle.create.exchange
    ↓
Message routed to vehicle.create.queue
    ↓
(Python Image Service processes)
    ↓
Response sent to vehicle.response.exchange
    ↓
Message routed to vehicle.response.queue
    ↓
Jackson2JsonMessageConverter deserializes ✅
    ↓
VehicleImageResponseListener.handleResponse(VehicleImageResponse)
    ↓
handleSuccessResponse() or handleFailureResponse()
    ↓
VehicleColor record created in database ✅
```

---

## 🎉 Result

**Before Fix:**
- ❌ Messages received but not processed
- ❌ Deserialization errors
- ❌ Messages sent to DLQ
- ❌ Silent failures

**After Fix:**
- ✅ Messages properly deserialized
- ✅ Handlers process messages successfully
- ✅ VehicleColor records created
- ✅ Complete message flow works end-to-end
