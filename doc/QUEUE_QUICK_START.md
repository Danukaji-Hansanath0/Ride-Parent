# Quick Start: RabbitMQ Queue System

## 🚀 Start Services with Queue

```bash
# Start all services including RabbitMQ
docker-compose up -d

# Check RabbitMQ is running
docker-compose logs rabbitmq

# Access RabbitMQ Management UI
open http://localhost:15672
# Login: guest/guest
```

## 📝 Register a User (Queue Test)

```bash
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "queuetest@example.com",
    "firstName": "Queue",
    "lastName": "Test",
    "password": "password123",
    "role": "CUSTOMER"
  }'
```

## 🔍 Verify Queue Working

### Check Auth Service Logs
```bash
docker-compose logs -f auth-service | grep "queued successfully"
# Should see: "User profile creation message queued successfully"
```

### Check User Service Logs
```bash
docker-compose logs -f user-service | grep "Successfully created"
# Should see: "Successfully created user profile from queue message"
```

### Check RabbitMQ Management UI
1. Open http://localhost:15672
2. Click "Queues" tab
3. See `user.profile.queue`
4. Should show messages being processed

## 🧪 Test Resilience

### Test 1: Stop User Service
```bash
# Stop user service
docker-compose stop user-service

# Register users - they'll queue up!
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{"email":"test1@example.com","firstName":"Test","lastName":"One","password":"pass123","role":"CUSTOMER"}'

# Check queue depth in RabbitMQ UI
# Should see messages waiting

# Start user service
docker-compose start user-service

# Watch messages get processed!
docker-compose logs -f user-service
```

## ✅ Compilation Commands

```bash
# Compile auth-service
cd /mnt/projects/Ride/auth-service
./mvnw clean compile

# Compile user-service  
cd /mnt/projects/Ride/user-service
./mvnw clean compile

# Build Docker images
cd /mnt/projects/Ride
docker-compose build auth-service user-service
```

## 🎯 Key URLs

- **RabbitMQ Management**: http://localhost:15672 (guest/guest)
- **Auth Service**: http://localhost:8081
- **User Service**: http://localhost:8086
- **User Service Swagger**: http://localhost:8086/api/users/swagger-ui/index.html

## 📊 Monitoring

### Check Queue Status
```bash
# Via Management UI
open http://localhost:15672/#/queues

# Via CLI
docker exec rabbitmq rabbitmqctl list_queues name messages consumers
```

### Check Message Rate
```bash
# View in Management UI under Queues tab
# Shows: Message rate in/out, total queued
```

## ⚡ Quick Debug

### Auth Service Not Queuing?
```bash
# Check logs
docker-compose logs auth-service | tail -50

# Check RabbitMQ connection
docker-compose exec auth-service netstat -an | grep 5672
```

### User Service Not Processing?
```bash
# Check logs
docker-compose logs user-service | tail -50

# Check if listening to queue
docker-compose logs user-service | grep "RabbitListener"
```

### Messages Stuck in DLQ?
```bash
# Check DLQ in Management UI
open http://localhost:15672/#/queues/%2F/user.profile.dlq

# View failed messages and reasons
```

## 🎉 Success Indicators

✅ RabbitMQ Management UI accessible  
✅ Queues visible: `user.profile.queue`, `user.profile.dlq`  
✅ Auth service logs show "queued successfully"  
✅ User service logs show "Successfully created user profile"  
✅ Users created in database even if service was temporarily down  

## 🔧 Configuration Files Changed

1. `auth-service/pom.xml` - Added RabbitMQ dependency
2. `user-service/pom.xml` - Added RabbitMQ dependency
3. `auth-service/application.yml` - Added RabbitMQ config
4. `user-service/application.yml` - Added RabbitMQ config
5. `docker-compose.yml` - Added RabbitMQ service
6. New files created for queue handling

**Total Impact**: Minimal code changes, massive reliability improvement! 🚀
