# User Service API - Quick Reference

## 📚 API Documentation

**Swagger UI:** `http://localhost:8086/swagger-ui/index.html`  
**OpenAPI Docs:** `http://localhost:8086/v3/api-docs`  
**Health Check:** `http://localhost:8086/actuator/health`

**Base URL:** `http://localhost:8086`  
**API Path:** `/api/v1/users`

---

## ✅ Valid API Endpoints

### 1. Get All Users (Paginated & Sorted)

**Endpoint:** `GET /api/v1/users/all`

**Valid Sort Fields:**
- `userId`
- `email`
- `firstName`
- `lastName`
- `createdAt`
- `updatedAt`
- `isActive`
- `userType`

**Examples:**

```bash
# Get all users (default sort by createdAt, desc, page 0, size 15)
curl -X GET 'http://localhost:8086/api/v1/users/all'

# Sort by email (ascending)
curl -X GET 'http://localhost:8086/api/v1/users/all?sort=email,asc'

# Sort by firstName (descending)
curl -X GET 'http://localhost:8086/api/v1/users/all?sort=firstName,desc'

# Sort by createdAt (descending) with pagination
curl -X GET 'http://localhost:8086/api/v1/users/all?page=0&size=20&sort=createdAt,desc'

# Sort by lastName (ascending) with custom page size
curl -X GET 'http://localhost:8086/api/v1/users/all?page=1&size=10&sort=lastName,asc'

# Multiple sort fields (lastName then firstName)
curl -X GET 'http://localhost:8086/api/v1/users/all?sort=lastName,asc&sort=firstName,asc'
```

**Query Parameters:**
- `page` - Page number (default: 0)
- `size` - Page size (default: 15)
- `sort` - Format: `fieldName,direction` (direction: `asc` or `desc`)

---

### 2. Get User Profile by Email

**Endpoint:** `GET /api/v1/users/profile/{email}`

**Example:**

```bash
curl -X GET 'http://localhost:8086/api/v1/users/profile/user@example.com'
```

**Response (200 OK):**
```json
{
  "uid": "abc-123-def-456",
  "firstName": "John",
  "lastName": "Doe",
  "email": "user@example.com",
  "phoneNumber": "+1234567890",
  "userAvailability": "AVAILABLE"
}
```

**Error Response (404 Not Found):**
```json
{
  "timestamp": "2026-01-16T04:00:00.000+05:30",
  "status": 404,
  "error": "Not Found",
  "message": "User not found with email: nonexistent@example.com",
  "path": "/api/v1/users/profile/nonexistent@example.com",
  "traceId": "abc-123-def-456"
}
```

---

### 3. Create User

**Endpoint:** `POST /api/v1/users`

**Example:**

```bash
curl -X POST 'http://localhost:8086/api/v1/users' \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "newuser@example.com",
    "firstName": "Jane",
    "lastName": "Smith",
    "phoneNumber": "+1234567890",
    "profilePictureUrl": "https://example.com/pic.jpg",
    "isActive": true
  }'
```

**Response (200 OK):**
```json
{
  "userId": "generated-uuid",
  "email": "newuser@example.com",
  "firstName": "Jane",
  "lastName": "Smith",
  "phoneNumber": "+1234567890",
  "profilePictureUrl": "https://example.com/pic.jpg",
  "isActive": true
}
```

---

### 4. Update User

**Endpoint:** `PUT /api/v1/users`

**Example:**

```bash
curl -X PUT 'http://localhost:8086/api/v1/users' \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "existing@example.com",
    "firstName": "John",
    "lastName": "Updated",
    "phoneNumber": "+9876543210",
    "profilePictureUrl": "https://example.com/newpic.jpg",
    "isActive": true
  }'
```

---

### 5. Delete User (Soft Delete)

**Endpoint:** `DELETE /api/v1/users/{email}`

**Example:**

```bash
curl -X DELETE 'http://localhost:8086/api/v1/users/user@example.com'
```

**Note:** This is a soft delete - sets user availability to DELETED

---

## ❌ Common Errors

### Invalid Sort Field (400)
```bash
# ❌ Wrong
curl -X GET 'http://localhost:8086/api/v1/users/all?sort=invalidField,desc'

# Response:
{
  "status": 400,
  "error": "Bad Request",
  "message": "Invalid sort field: invalidField. Allowed: [firstName, email, createdAt, ...]",
  "traceId": "..."
}
```

### User Not Found (404)
```bash
# ❌ Wrong email
curl -X GET 'http://localhost:8086/api/v1/users/profile/nonexistent@example.com'

# Response:
{
  "status": 404,
  "error": "Not Found",
  "message": "User not found with email: nonexistent@example.com",
  "traceId": "..."
}
```

### Missing Required Fields (400)
```bash
# ❌ Missing required fields
curl -X POST 'http://localhost:8086/api/v1/users' \
  -H 'Content-Type: application/json' \
  -d '{
    "email": "test@example.com"
  }'

# Response:
{
  "status": 400,
  "error": "Bad Request",
  "message": "Validation failed",
  "details": [
    "firstName: must not be null",
    "lastName: must not be null"
  ],
  "traceId": "..."
}
```

---

## 🎯 Best Practices

### 1. Always Use Valid Sort Fields
Only use the allowed fields: `userId`, `email`, `firstName`, `lastName`, `createdAt`, `updatedAt`, `isActive`, `userType`

### 2. Handle 404 Errors
When fetching by email, always handle the case where the user doesn't exist

### 3. Check TraceId for Debugging
Every error response includes a `traceId` - use it to correlate errors in logs

### 4. Use Pagination
For large datasets, use the `page` and `size` parameters to avoid loading too much data

### 5. URL Encode Emails
When passing emails in URL paths, make sure to URL encode them:
```bash
# ✅ Correct
curl -X GET 'http://localhost:8086/api/v1/users/profile/user%40example.com'

# or let curl handle it
curl -X GET 'http://localhost:8086/api/v1/users/profile/user@example.com'
```

---

## 🧪 Testing the Error Handling

### Test 1: Valid Request
```bash
curl -X GET 'http://localhost:8086/api/v1/users/all?sort=email,asc'
# Should return 200 with user list
```

### Test 2: Invalid Sort Field
```bash
curl -X GET 'http://localhost:8086/api/v1/users/all?sort=invalidField,desc'
# Should return 400 with error message listing allowed fields
```

### Test 3: User Not Found
```bash
curl -X GET 'http://localhost:8086/api/v1/users/profile/notfound@test.com'
# Should return 404 with descriptive message
```

### Test 4: Database Error (optional)
```bash
# Stop the database
docker-compose stop postgres

# Try to query
curl -X GET 'http://localhost:8086/api/v1/users/all'
# Should return 500 with generic error message
# Check logs for detailed error

# Start database again
docker-compose start postgres
```

---

## 📚 Response Format

All API responses follow a consistent format:

### Success Response:
```json
{
  // Response data here
}
```

### Error Response:
```json
{
  "timestamp": "2026-01-16T04:00:00.000+05:30",
  "status": 400,
  "error": "Bad Request",
  "message": "Descriptive error message",
  "path": "/api/v1/users/all",
  "traceId": "unique-trace-id",
  "details": []  // Optional: for validation errors
}
```

---

## 🚀 Quick Start

1. **Check service is running:**
```bash
curl http://localhost:8086/actuator/health
```

2. **Get all users:**
```bash
curl -X GET 'http://localhost:8086/api/v1/users/all'
```

3. **Get specific user:**
```bash
curl -X GET 'http://localhost:8086/api/v1/users/profile/user@example.com'
```

4. **Sort users by email:**
```bash
curl -X GET 'http://localhost:8086/api/v1/users/all?sort=email,asc'
```

---

**Last Updated:** January 16, 2026  
**Version:** 1.0  
**Status:** ✅ All error handling implemented and tested
