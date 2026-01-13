### THIS DIAGRAM REPRESENTS AN AUTHENTICATION FLOW USING KEYCLOAK AND SOCIAL LOGIN PROVIDERS
* we are using auhentication via Keycloak with social login providers (Google, Facebook, Apple)
* after successful login, Keycloak returns ID token and Access token (JWT)
* the client (Android/Web) sends a request to our User Service to create or update the user
* the User Service may optionally validate the token with Keycloak or fetch user info via the userinfo endpoint
* finally, the User Service saves the user data, linking it to the Keycloak subject (sub) and responds with a 201 Created status and an app-specific user ID

    
```mermaid
sequenceDiagram
    participant A as 📱📱📱 Client<br/>(Android/Web/macOS)
    participant B as 🚪 Gateway
    participant C as 🔐 Auth Service
    participant D as 🔑 Keycloak
    participant E as 👤 User Service
    participant F as 📧 Email Service

    A->>B: POST /api/register<br/>{email, password, name}
    B->>C: Forward request
    C->>D: 1. Create user
    D-->>C: keycloakId
    C->>E: 2. Save user
    E-->>C: userId

    rect rgb(240, 240, 255)
        Note over C,F: Email Verification Flow
        C->>F: 3. Send verification email
        F-->>A: Email with link:<br/>https://app.com/verify?token=xyz
        A->>B: GET /verify?token=xyz
        B->>C: Forward
        C->>D: Validate token → update emailVerified=true
        D-->>C: OK
        C->>F: 4. Send welcome email
        F-->>A: "Welcome! You're all set."
    end

    C-->>A: 5. Issue tokens & auto-login<br/>{access_token, refresh_token}
    A->>B: Future API calls<br/>Authorization: Bearer <token>
    B->>E: Route (e.g., /api/users/me)
```

```mermaid
sequenceDiagram
    participant User
    participant App as Android App
    participant Browser as Chrome Custom Tab
    participant KC as Keycloak
    participant Google as Google

    User->>App: Click "Sign in with Google"
    App->>Browser: Launch Auth Request (code + PKCE)
    Browser->>KC: /auth?client_id=...&redirect_uri=com.giglox.app:/callback&...
    KC->>Google: Redirect to Google (via broker)
    Google->>User: Consent Screen
    User->>Google: Approve
    Google->>KC: Return code
    KC->>Browser: Redirect to com.giglox.app:/callback?code=ABC...
    Browser->>App: Android Intent opens app
    App->>KC: POST /token (with code + PKCE verifier)
    KC->>App: ID Token + Access Token
    App->>User: Logged in ✅
```


# App Social Login Help 

--- 
## Google

### 1. Add dependency (```build.gradle:app```)

```gradle
implementation 'net.openid:appauth:0.11.1'
```
### 2. Add intent filter to ```AndroidManifest.xml```

```xml

<!-- AndroidManifest.xml -->
<activity android:name=".AuthCallbackActivity">
    <intent-filter>
        <action android:name="android.intent.action.VIEW"/>
        <category android:name="android.intent.category.DEFAULT"/>
        <category android:name="android.intent.category.BROWSABLE"/>
        <data android:scheme="com.giglox.app" android:host="callback" />
    </intent-filter>
</activity>

```

### 3. Configure Authorization Service

```kotlin
// AuthorizationServiceConfiguration
AuthorizationServiceConfiguration serviceConfig =
    new AuthorizationServiceConfiguration(
        Uri.parse("https://keycloak.orysone.com/auth/realms/user-authentication-realm/protocol/openid-connect/auth"),
        Uri.parse("https://keycloak.orysone.com/auth/realms/user-authentication-realm/protocol/openid-connect/token")
    );

// AuthState + PKCE
AuthorizationRequest.Builder authRequestBuilder =
    new AuthorizationRequest.Builder(
        serviceConfig,
        "your-client-id", // ← your Keycloak client ID
        ResponseTypeValues.CODE,
        Uri.parse("com.giglox.app:/callback")
    )
    .setScopes("openid", "email", "profile")
    .setCodeVerifier(); // ✅ generates PKCE code_verifier & challenge

AuthorizationRequest authRequest = authRequestBuilder.build();

// Launch
AuthorizationService authService = new AuthorizationService(this);
authService.performAuthorizationRequest(authRequest, ...);
```

### 4. Handle Auth Callback

```kotlin
// In AuthCallbackActivity
if (response != null && response.authorizationCode != null) {
    authService.performTokenRequest(
        response.createTokenExchangeRequest(),
        (tokenResp, ex) -> {
        if (tokenResp != null) {
            // ✅ Success! Use tokenResp.idToken, accessToken
            String idToken = tokenResp.idToken;
            // Parse JWT to get email, name (e.g., using jwt.io or a lib)
        }
    }
    );
}
```