# Fix: Keycloak Invalid Redirect URI for Swagger UI

## 🐛 Error

```
type="LOGIN_ERROR", error="invalid_redirect_uri", 
redirect_uri="http://localhost:8081/swagger-ui/index.html"
clientId="auth2-client"
```

## 🔍 Root Cause

The `auth2-client` in Keycloak doesn't have `http://localhost:8081/swagger-ui/*` registered as a valid redirect URI.

## ✅ Solution: Configure Keycloak Client

### Step 1: Access Keycloak Admin Console

1. Navigate to: `https://auth.rydeflexi.com/admin`
2. Login with admin credentials
3. Select realm: `user-authentication`

### Step 2: Configure auth2-client

1. Go to **Clients** → Select `auth2-client`
2. In the **Settings** tab:

#### Valid Redirect URIs (Add these):
```
http://localhost:8081/*
http://localhost:8081/swagger-ui/*
http://localhost:8081/swagger-ui/oauth2-redirect.html
http://localhost:8081/webjars/swagger-ui/*
https://api.rydeflexi.com/*
https://api.rydeflexi.com/auth-service/*
```

#### Valid Post Logout Redirect URIs:
```
http://localhost:8081/*
https://api.rydeflexi.com/*
+
```

#### Web Origins:
```
http://localhost:8081
https://api.rydeflexi.com
+
```

#### Other Important Settings:
- **Client Protocol**: `openid-connect`
- **Access Type**: `confidential` (or `public` for Swagger)
- **Standard Flow Enabled**: `ON`
- **Implicit Flow Enabled**: `OFF` (unless needed)
- **Direct Access Grants Enabled**: `ON`
- **Service Accounts Enabled**: `ON` (if using client credentials)

### Step 3: Save and Test

1. Click **Save**
2. Restart your auth-service (if needed)
3. Access Swagger UI: `http://localhost:8081/swagger-ui.html`
4. Try OAuth2 authentication

---

## 🔧 Alternative: Create Separate Swagger Client

For better security, create a dedicated Swagger client:

### Create New Client: `swagger-ui-client`

1. **Clients** → **Create**
2. **Client ID**: `swagger-ui-client`
3. **Client Protocol**: `openid-connect`
4. **Root URL**: `http://localhost:8081`

#### Settings:
```yaml
Access Type: public
Standard Flow: Enabled
Direct Access Grants: Enabled
Valid Redirect URIs:
  - http://localhost:8081/*
  - http://localhost:8081/swagger-ui/*
  - http://localhost:8081/swagger-ui/oauth2-redirect.html
Web Origins:
  - http://localhost:8081
  - +
```

#### Then update your application.yml:
```yaml
springdoc:
  swagger-ui:
    oauth:
      client-id: swagger-ui-client
      use-pkce-with-authorization-code-grant: true
```

---

## 🧪 Testing

After configuration, test with:

```bash
# 1. Access Swagger UI
open http://localhost:8081/swagger-ui.html

# 2. Click "Authorize" button
# 3. Select OAuth2
# 4. Click "Authorize"
# 5. Should redirect to Keycloak login
# 6. After login, should redirect back to Swagger UI
```

---

## 📋 Quick Fix Checklist

- [ ] Login to Keycloak Admin Console
- [ ] Navigate to `user-authentication` realm
- [ ] Open `auth2-client` settings
- [ ] Add redirect URIs for localhost:8081
- [ ] Add web origins
- [ ] Save configuration
- [ ] Test Swagger UI OAuth2 flow

---

## 🔒 Production Configuration

For production, use:

```
Valid Redirect URIs:
  - https://api.rydeflexi.com/*
  - https://api.rydeflexi.com/auth-service/swagger-ui/*
  - https://api.rydeflexi.com/auth-service/swagger-ui/oauth2-redirect.html

Web Origins:
  - https://api.rydeflexi.com
  - +
```

**Remove** all `localhost` URIs in production!

---

## 🐛 Common Issues

### Issue 1: Still getting invalid_redirect_uri
**Solution**: 
- Clear browser cache
- Check for typos in URIs
- Ensure no trailing slashes where not needed
- Restart Keycloak (if using docker: `docker restart keycloak`)

### Issue 2: CORS errors
**Solution**: 
- Add `+` to Web Origins (enables all origins from valid redirect URIs)
- Or explicitly add the origin

### Issue 3: 401 Unauthorized
**Solution**: 
- Check client secret matches in application.yml
- Ensure client has correct roles assigned
- Verify user has required realm roles

---

## 📝 Current Configuration

Based on your error, here's what you need:

**Client ID**: `auth2-client`  
**Realm**: `user-authentication`  
**Current Issue**: Missing redirect URI for Swagger

**Minimum Required Redirect URIs**:
```
http://localhost:8081/swagger-ui/oauth2-redirect.html
http://localhost:8081/swagger-ui/*
```

---

## ✅ Verification

After fixing, you should see in Keycloak logs:
```
type="LOGIN", clientId="auth2-client", redirect_uri="http://localhost:8081/swagger-ui/..."
```

Instead of:
```
type="LOGIN_ERROR", error="invalid_redirect_uri"
```

---

**Status**: Configuration required in Keycloak  
**Impact**: Swagger UI OAuth2 authentication  
**Priority**: Medium (blocks Swagger testing only)
