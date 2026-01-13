# 📁 Project Structure Guide

## Complete Directory Layout

```
Ride/                                    # Project root
│
├── 📄 README.md                         # Main documentation (START HERE!)
├── 📄 START_HERE.md                     # Quick reference guide
├── 📄 DEPLOYMENT_GUIDE.md               # Deployment instructions
├── 📄 FIXES_SUMMARY.md                  # All fixes documented
├── 📄 pom.xml                           # Parent POM (Maven)
├── 📄 docker-compose.yml                # Local dev with Docker Compose
│
├── 🔧 build-all-images.sh               # Build all Docker images
├── 🔧 quick-start.sh                    # Automated deployment
├── 🔧 verify-setup.sh                   # Verify configuration
├── 🔧 manage.sh                         # Management operations
│
├── 📦 auth-service/                     # Authentication Service (Port 8081)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile                       # ✅ Fixed: builds from root
│   └── mvnw
│
├── 📦 booking-service/                  # Booking Service (Port 8082)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile                       # ✅ Fixed: builds from root
│   └── mvnw
│
├── 📦 gateway-service/                  # API Gateway (Port 8080)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile                       # ✅ Fixed: builds from root
│   └── mvnw
│
├── 📦 mail-service/                     # Mail Service (Port 8084)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile                       # ✅ Fixed: builds from root
│   └── mvnw
│
├── 📦 payment-service/                  # Payment Service (Port 8083)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile                       # ✅ Fixed: builds from root
│   └── mvnw
│
├── 📦 pricing-service/                  # Pricing Service (Port 8085)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile                       # ✅ Fixed: builds from root
│   └── mvnw
│
├── 📦 user-service/                     # User Service (Port 8086)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile                       # ✅ Fixed: builds from root
│   └── mvnw
│
├── 📦 vehicle-service/                  # Vehicle Service (Port 8087)
│   ├── src/
│   ├── pom.xml
│   ├── Dockerfile                       # ✅ Fixed: builds from root
│   └── mvnw
│
└── ☸️  k8s/                              # Kubernetes Configuration
    ├── 📄 README.md                     # K8s structure explained
    │
    ├── 📂 base/                         # Base configurations
    │   ├── common-config/
    │   ├── common-configmap.yaml
    │   ├── namespace.yaml
    │   └── kustomization.yaml
    │
    ├── 📂 components/                   # Reusable templates
    │   ├── deployment/
    │   │   ├── deployment.yaml          # Generic deployment template
    │   │   └── kustomization.yaml
    │   └── service/
    │       ├── service.yaml             # Generic service template
    │       └── kustomization.yaml
    │
    ├── 📂 apps/                         # Service configurations
    │   ├── auth-service/
    │   │   ├── config/
    │   │   │   ├── configmap.yaml
    │   │   │   └── kustomization.yaml
    │   │   ├── overlays/
    │   │   │   └── dev/
    │   │   │       ├── config/          # ✅ Fixed: created directory
    │   │   │       │   ├── configmap.yaml
    │   │   │       │   └── kustomization.yaml
    │   │   │       ├── deployment-patch.yaml
    │   │   │       ├── ingress-patch.yaml
    │   │   │       └── kustomization.yaml  # ✅ Fixed: namePrefix: auth-
    │   │   └── kustomization.yaml
    │   │
    │   ├── booking-service/
    │   │   └── overlays/
    │   │       └── dev/
    │   │           ├── config/
    │   │           └── kustomization.yaml  # ✅ Fixed: namePrefix: booking-
    │   │
    │   ├── gateway-service/
    │   │   └── overlays/
    │   │       └── dev/
    │   │           └── kustomization.yaml  # ✅ Fixed: namePrefix: gateway-
    │   │
    │   ├── mail-service/
    │   │   └── overlays/
    │   │       └── dev/
    │   │           └── kustomization.yaml  # ✅ Fixed: namePrefix: mail-
    │   │
    │   ├── payment-service/
    │   │   └── overlays/
    │   │       └── dev/
    │   │           └── kustomization.yaml  # ✅ Fixed: namePrefix: payment-
    │   │
    │   ├── pricing-service/
    │   │   └── overlays/
    │   │       └── dev/
    │   │           └── kustomization.yaml  # ✅ Fixed: namePrefix: pricing-
    │   │
    │   ├── user-service/
    │   │   └── overlays/
    │   │       └── dev/
    │   │           └── kustomization.yaml  # ✅ Fixed: namePrefix: user-
    │   │
    │   └── vehicle-service/
    │       └── overlays/
    │           └── dev/
    │               └── kustomization.yaml  # ✅ Fixed: namePrefix: vehicle-
    │
    ├── 📂 environments/                 # Environment deployments
    │   ├── dev/
    │   │   └── kustomization.yaml       # References all services
    │   ├── staging/
    │   │   └── kustomization.yaml
    │   └── prod/
    │       └── kustomization.yaml
    │
    └── 📂 cluster-wide/                 # Cluster resources
        ├── ingress/
        └── rbac/
```

## 📊 File Counts

- **Services**: 8 microservices
- **Dockerfiles**: 8 (all fixed)
- **Kustomizations**: 8 service overlays (all fixed with namePrefix)
- **Scripts**: 4 helper scripts
- **Documentation**: 5 markdown files
- **Total fixes applied**: 25+ files

## ✅ What Was Fixed

### Dockerfiles (8 files)
- ✅ auth-service/Dockerfile
- ✅ booking-service/Dockerfile
- ✅ gateway-service/Dockerfile
- ✅ mail-service/Dockerfile
- ✅ payment-service/Dockerfile
- ✅ pricing-service/Dockerfile
- ✅ user-service/Dockerfile
- ✅ vehicle-service/Dockerfile

### Kubernetes Kustomizations (8 files)
- ✅ k8s/apps/auth-service/overlays/dev/kustomization.yaml (+ config dir)
- ✅ k8s/apps/booking-service/overlays/dev/kustomization.yaml
- ✅ k8s/apps/gateway-service/overlays/dev/kustomization.yaml
- ✅ k8s/apps/mail-service/overlays/dev/kustomization.yaml
- ✅ k8s/apps/payment-service/overlays/dev/kustomization.yaml
- ✅ k8s/apps/pricing-service/overlays/dev/kustomization.yaml
- ✅ k8s/apps/user-service/overlays/dev/kustomization.yaml
- ✅ k8s/apps/vehicle-service/overlays/dev/kustomization.yaml

### Build Scripts (1 file)
- ✅ build-all-images.sh

### New Files Created (9 files)
- ✨ README.md
- ✨ START_HERE.md
- ✨ DEPLOYMENT_GUIDE.md
- ✨ FIXES_SUMMARY.md
- ✨ docker-compose.yml
- ✨ quick-start.sh
- ✨ verify-setup.sh
- ✨ manage.sh
- ✨ k8s/README.md

## 🎯 Key Locations

### To Build
```bash
./build-all-images.sh              # From project root
```

### To Deploy
```bash
./quick-start.sh                   # Automated
# OR
kubectl apply -k k8s/environments/dev
```

### To Manage
```bash
./manage.sh help                   # Show all commands
./manage.sh status                 # Check status
./manage.sh logs auth-service      # View logs
```

### To Develop Locally
```bash
docker-compose up --build          # All services + databases
```

## 🔍 Finding Things

### Looking for service code?
→ `<service-name>/src/main/java/`

### Looking for Kubernetes config?
→ `k8s/apps/<service-name>/overlays/dev/`

### Looking for database setup?
→ Each service has `compose.yaml` or `init-scripts/`

### Looking for documentation?
→ Project root: `README.md`, `START_HERE.md`
→ K8s specific: `k8s/README.md`

## 💡 Quick Tips

1. **Start here**: Open `START_HERE.md`
2. **Verify setup**: Run `./verify-setup.sh`
3. **Local dev**: Use `docker-compose up`
4. **K8s deploy**: Use `./quick-start.sh`
5. **Manage**: Use `./manage.sh help`

---

**Navigate with confidence!** 🚀

