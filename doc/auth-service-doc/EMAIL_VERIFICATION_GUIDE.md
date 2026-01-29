# Email Verification System - Quick Guide

## 🎯 Overview

The auth-service implements a complete email verification system integrated with Keycloak. Users receive verification emails automatically upon registration and can request new verification emails if needed.

---

## 📧 Email Verification Flow

```
┌─────────────┐
│   User      │
│  Registers  │
└──────┬──────┘
       │
       ▼
┌──────────────────────┐
│  Auth Service        │
│  - Creates user      │
│  - Sends verify email│ ✅ Automatic
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  User's Email        │
│  - Receives link     │
│  - Clicks verify     │
└──────┬───────────────┘
       │
       ▼
┌──────────────────────┐
│  Keycloak            │
│  - Verifies email    │
│  - Sets verified=true│
└──────────────────────┘
```

---

## 🛠️ Implementation Details

### 1. Automatic Email on Registration

**When:** User registers via `/api/auth/register`  
**What Happens:**
1. User is created in Keycloak
2. Verification email is sent automatically
3. If email fails, registration still succeeds (logged for retry)

**Code Location:** `KeycloakAdminServiceImpl.registerUser()`

```java
// After user creation
try {
    sendVerificationEmail(userId);
    log.info("Verification email sent successfully to user: {} ({})", userId, request.email());
} catch (Exception emailException) {
    log.error("Failed to send verification email to user {} ({}): {}", 
             userId, request.email(), emailException.getMessage());
    // Registration continues - email can be resent manually
}
```

---

### 2. Manual Verification Email Resend

**Endpoint:** `GET /api/auth/send-verification-email/{userId}`  
**Purpose:** Resend verification email if user didn't receive it  
**Features:**
- Checks if user exists
- Skips sending if already verified
- Detailed error handling
- Comprehensive logging

**Example Request:**
```bash
curl -X GET http://localhost:8081/api/auth/send-verification-email/a1b2c3d4-5678-90ab-cdef-1234567890ab
```

**Response Codes:**
- `200 OK` - Email sent successfully
- `404 Not Found` - User doesn't exist
- `500 Internal Server Error` - Email service failure

---

### 3. Check Verification Status

**Endpoint:** `GET /api/auth/verify-email/{userId}`  
**Purpose:** Check if user's email is verified  
**Returns:** `true` or `false`

**Example Request:**
```bash
curl -X GET http://localhost:8081/api/auth/verify-email/a1b2c3d4-5678-90ab-cdef-1234567890ab
```

**Response Examples:**
```json
true   // Email is verified
false  // Email not verified yet
```

---

## 🔧 Configuration

### Keycloak Email Settings

Ensure Keycloak realm has email configuration:

1. **SMTP Server Settings:**
   - Host: `smtp.gmail.com` (or your provider)
   - Port: `587` (TLS) or `465` (SSL)
   - Username: Your email
   - Password: App password

2. **Email Theme:**
   - From: `noreply@yourdomain.com`
   - From Display Name: `Your App Name`
   - Reply To: `support@yourdomain.com`

3. **Verification Email Template:**
   Located in Keycloak theme under `email/html/email-verification.ftl`

### Application Configuration

**File:** `application.yml`

```yaml
keycloak:
  admin:
    server-url: ${RD_KEYCLOAK_SERVER_URL:https://auth.rydeflexi.com/}
    realm: ${RD_KEYCLOAK_ADMIN_REALM:user-authentication}
    client-id: ${RD_KEYCLOAK_ADMIN_CLIENT_ID:auth-client}
    client-secret: ${RD_KEYCLOAK_ADMIN_CLIENT_SECRET:your-secret}
    token-url: ${RD_KEYCLOAK_ADMIN_TOKEN_URL:https://auth.rydeflexi.com/realms/user-authentication/protocol/openid-connect/token}
```

---

## 📱 API Examples

### Complete Registration Flow

#### Step 1: Register User
```bash
curl -X POST http://localhost:8081/api/auth/register \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "password": "SecurePass123!",
    "firstName": "John",
    "lastName": "Doe",
    "role": "CUSTOMER"
  }'
```

**Response:**
```json
{
  "userId": "a1b2c3d4-5678-90ab-cdef-1234567890ab",
  "email": "newuser@example.com",
  "firstName": "John",
  "lastName": "Doe",
  "emailVerified": false,
  "createdAt": "2026-01-17T12:30:00Z",
  "message": "USER_CREATED"
}
```

#### Step 2: User Checks Email
User receives email with verification link:
```
Subject: Verify your email address

Hi John,

Please click the link below to verify your email address:

https://auth.rydeflexi.com/realms/user-authentication/login-actions/action-token?key=...

This link expires in 12 hours.
```

#### Step 3: User Clicks Link
- Redirected to Keycloak
- Email verified automatically
- Redirected to your app

#### Step 4: Verify Status (Optional)
```bash
curl -X GET http://localhost:8081/api/auth/verify-email/a1b2c3d4-5678-90ab-cdef-1234567890ab
```

**Response:** `true`

#### Step 5: Login
```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "newuser@example.com",
    "password": "SecurePass123!"
  }'
```

**Success Response:**
```json
{
  "accessToken": "eyJhbGciOiJSUzI1NiIsInR5cCI...",
  "refreshToken": "eyJhbGciOiJIUzI1NiIsInR5cC...",
  "expiresIn": 3600,
  "refreshExpiresIn": 7200,
  "tokenType": "Bearer",
  "scope": "openid profile email",
  "firstName": "John",
  "lastName": "Doe",
  "email": "newuser@example.com",
  "userId": "user-service-id",
  "userAvailability": "AVAILABLE",
  "isActive": true
}
```

---

## 🚫 Error Scenarios

### 1. Email Not Verified - Login Attempt

**Request:**
```bash
curl -X POST http://localhost:8081/api/auth/login \
  -H "Content-Type: application/json" \
  -d '{
    "email": "unverified@example.com",
    "password": "password123"
  }'
```

**Response: 403 Forbidden**
```json
{
  "timestamp": "2026-01-17T12:45:00Z",
  "status": 403,
  "error": "Forbidden",
  "message": "Email verification required. Please verify your email before logging in.",
  "path": "/api/auth/login",
  "traceId": "a1b2c3d4-5678-90ab-cdef-1234567890ab"
}
```

**Solution:** Resend verification email

---

### 2. Resend Verification - User Not Found

**Request:**
```bash
curl -X GET http://localhost:8081/api/auth/send-verification-email/invalid-user-id
```

**Response: 404 Not Found**
```json
{
  "timestamp": "2026-01-17T12:46:00Z",
  "status": 404,
  "error": "Not Found",
  "message": "User not found with ID: invalid-user-id",
  "path": "/api/auth/send-verification-email/invalid-user-id",
  "traceId": "b2c3d4e5-6789-01bc-def0-234567890abc"
}
```

---

### 3. Already Verified

**Request:**
```bash
curl -X GET http://localhost:8081/api/auth/send-verification-email/already-verified-id
```

**Response: 200 OK**
```
(No email sent, logged as already verified)
```

**Log Output:**
```
INFO: Email already verified for user: already-verified-id (user@example.com)
```

---

## 🔍 Monitoring & Debugging

### Log Messages to Watch

#### Success:
```
INFO: Sending verification email to user: {userId} ({email})
INFO: Verification email sent successfully to user: {userId} ({email})
```

#### Already Verified:
```
INFO: Email already verified for user: {userId} ({email})
```

#### Errors:
```
ERROR: Failed to send verification email to user: {userId}
ERROR: User not found with ID: {userId}
```

### Common Issues

| Issue | Cause | Solution |
|-------|-------|----------|
| Email not received | SMTP not configured | Configure Keycloak SMTP settings |
| 404 on resend | Invalid userId | Verify userId from registration response |
| 500 on send | Keycloak service down | Check Keycloak availability |
| Already verified warning | User clicked link | This is normal, ignore |

---

## 🎨 Customization

### Email Template Location
```
keycloak/themes/your-theme/email/html/email-verification.ftl
```

### Custom Email Content
Edit the FreeMarker template:
```html
<#import "template.ftl" as layout>
<@layout.emailLayout>
  <h2>Welcome to ${realmName}!</h2>
  <p>Hi ${user.firstName},</p>
  <p>Please verify your email address by clicking the link below:</p>
  <p><a href="${link}">Verify Email</a></p>
  <p>This link expires in ${linkExpirationFormatter(linkExpiration)}.</p>
</@layout.emailLayout>
```

---

## 📊 Statistics

Track verification metrics:
- Registration count
- Verification rate
- Resend requests
- Time to verification

**Example Query (from logs):**
```bash
# Count verification emails sent today
grep "Verification email sent successfully" auth-service.log | grep "$(date +%Y-%m-%d)" | wc -l

# Count resend requests
grep "Received send verification email request" auth-service.log | wc -l
```

---

## ✅ Best Practices

1. **Don't Block Registration:** If email fails, allow registration to complete
2. **Log Everything:** Track all email operations for debugging
3. **Rate Limit:** Prevent spam by limiting resend requests (consider adding)
4. **Clear Messages:** Tell users to check spam folder
5. **Expiration:** Set reasonable expiration (12-24 hours)
6. **Retry Logic:** Allow users to request new emails
7. **Status Check:** Provide endpoint to check verification status
8. **Testing:** Use test email service in development (MailHog, Mailtrap)

---

## 🧪 Testing

### Manual Testing Checklist

- [ ] Register new user
- [ ] Check email inbox
- [ ] Click verification link
- [ ] Confirm login works
- [ ] Try resend on verified user (should skip)
- [ ] Check status endpoint
- [ ] Test with invalid userId
- [ ] Test login before verification (should fail)

### Automated Testing

```java
@Test
public void testSendVerificationEmail_Success() {
    String userId = "test-user-id";
    // Mock Keycloak response
    // Call sendVerificationEmail
    // Assert no exceptions thrown
}

@Test
public void testSendVerificationEmail_UserNotFound() {
    String userId = "non-existent-user";
    // Assert NotFoundException thrown
}
```

---

## 📞 Support

If verification emails are not working:

1. Check Keycloak SMTP configuration
2. Review auth-service logs
3. Test SMTP connection directly
4. Check spam folder
5. Verify email template exists
6. Ensure Keycloak service is running
7. Check firewall rules for SMTP port

---

**System Status:** ✅ Fully Functional  
**Last Updated:** January 17, 2026  
**Version:** 1.0.0
