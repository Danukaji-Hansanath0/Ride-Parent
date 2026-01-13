# Google OAuth2 Error Flow Diagram

## Where the "invalid_client" Error Occurs

```mermaid
sequenceDiagram
    participant App as Your Spring Boot App
    participant KC as Keycloak
    participant Google as Google OAuth2
    participant User as User Browser

    Note over App,Google: Step 1-4: Normal Flow (Works Fine)
    
    App->>KC: 1. GET /auth?kc_idp_hint=google
    KC->>User: 2. Redirect to Google Login
    User->>Google: 3. Authenticate & Authorize
    Google->>KC: 4. Redirect with auth code
    
    Note over KC,Google: Step 5: ERROR HAPPENS HERE! ❌
    
    KC->>Google: 5. POST /token (Exchange code)<br/>❌ Missing/Invalid Client Secret
    Google-->>KC: 401 Unauthorized<br/>{"error": "invalid_client"}
    KC-->>App: ❌ Error: identity_provider_login_failure
    
    Note over KC,Google: After Fix: Correct Flow ✅
    
    KC->>Google: 5. POST /token (with valid credentials)
    Google->>KC: ✅ 200 OK (access_token, id_token)
    KC->>App: ✅ Success (Keycloak tokens)
```

## Problem: Missing Google Client Secret in Keycloak

```mermaid
graph TB
    A[Your App Code] -->|Has| B[Keycloak Client Secret]
    A -->|Has| C[OAuth2 Client ID]
    
    KC[Keycloak Server] -->|MISSING| D[Google Client Secret]
    KC -->|MISSING| E[Google Client ID]
    
    style D fill:#ff6b6b,stroke:#c92a2a,stroke-width:3px
    style E fill:#ff6b6b,stroke:#c92a2a,stroke-width:3px
    
    D -.->|Needed for| F[Google Token Exchange]
    E -.->|Needed for| F
    
    F -->|Without these| G[invalid_client Error ❌]
    
    classDef error fill:#ff6b6b,stroke:#c92a2a,color:#fff
    class G error
```

## Solution: Configure in Keycloak Admin Console

```mermaid
graph LR
    A[Get Google Credentials] -->|From| B[Google Cloud Console]
    B --> C[Client ID]
    B --> D[Client Secret]
    
    C --> E[Keycloak Admin Console]
    D --> E
    
    E --> F[Identity Providers]
    F --> G[Google Settings]
    
    G --> H[Enter Client ID]
    G --> I[Enter Client Secret ⭐]
    
    H --> J[Save Configuration]
    I --> J
    
    J --> K[✅ Error Fixed!]
    
    style I fill:#51cf66,stroke:#2f9e44,stroke-width:3px
    style K fill:#51cf66,stroke:#2f9e44,color:#fff
```

## Configuration Locations

### ❌ WRONG: Putting Google Credentials Here

```
Your Spring Boot App
├── application.yml
│   ├── keycloak.admin.client-secret  (for admin API)
│   └── keycloak.auth2-client.client-secret  (for OAuth2)
│   ❌ DON'T PUT GOOGLE SECRETS HERE!
```

### ✅ CORRECT: Put Google Credentials Here

```
Keycloak Admin Console
└── user-authentication-realm
    └── Identity Providers
        └── Google
            ├── Client ID: YOUR_GOOGLE_CLIENT_ID ✅
            ├── Client Secret: YOUR_GOOGLE_CLIENT_SECRET ✅
            └── Default Scopes: openid email profile
```

## Three Different Client Secrets

```mermaid
graph TB
    subgraph "Your Application"
        A1[Client: user-authentication]
        A2[Secret: ludlrv4v0e0p6TZkp9TNQl14LoNe3dCl]
        A1 --- A2
        A3[Purpose: Admin API Access]
        A2 --- A3
    end
    
    subgraph "Your OAuth2 Client"
        B1[Client: auth2-client]
        B2[Secret: T6kMu741uDkfrGs1rkaBiiveCJRxpQPn]
        B1 --- B2
        B3[Purpose: Your App's OAuth2 Flow]
        B2 --- B3
    end
    
    subgraph "Google Identity Provider"
        C1[Client: YOUR_GOOGLE_CLIENT_ID]
        C2[Secret: YOUR_GOOGLE_CLIENT_SECRET]
        C1 --- C2
        C3[Purpose: Keycloak → Google Communication]
        C2 --- C3
        
        style C2 fill:#51cf66,stroke:#2f9e44,stroke-width:3px
        C4[⭐ This one is MISSING!]
        C2 --- C4
    end
```

## Step-by-Step Fix

```mermaid
flowchart TD
    Start([User tries Google Login]) --> A{Does Keycloak have<br/>Google Client Secret?}
    
    A -->|NO ❌| B[Error: invalid_client]
    B --> C[Open Keycloak Admin Console]
    C --> D[Navigate to Identity Providers → Google]
    D --> E[Enter Google Client ID]
    E --> F[Enter Google Client Secret]
    F --> G[Set Default Scopes: openid email profile]
    G --> H[Save Configuration]
    H --> I[Test Google Login Again]
    I --> J{Works now?}
    
    J -->|YES ✅| K[Success! Users can login]
    J -->|NO ❌| L[Check Google Cloud Console<br/>Verify credentials are correct]
    L --> F
    
    A -->|YES ✅| M[Login works normally]
    
    style B fill:#ff6b6b,stroke:#c92a2a,color:#fff
    style K fill:#51cf66,stroke:#2f9e44,color:#fff
    style F fill:#ffd43b,stroke:#fab005
```

## Quick Reference

| Location | What to Configure | Why |
|----------|-------------------|-----|
| **Google Cloud Console** | Create OAuth2 Client, Get Client ID & Secret | Generate credentials for Keycloak |
| **Keycloak Admin Console** | Enter Google Client ID & Secret in Identity Provider | ⭐ **THIS FIXES THE ERROR** |
| **application.yml** | Keycloak admin & OAuth2 client secrets | For your app to communicate with Keycloak |

## Key Takeaway

```
The error "invalid_client" from Google means:
→ Keycloak is trying to talk to Google
→ But Keycloak doesn't have valid Google credentials
→ Solution: Give Keycloak the Google Client Secret
→ Where: Keycloak Admin Console → Identity Providers → Google
```

