# Ride Platform - Deployment Guide

## Issues Fixed

### 1. Maven Parent POM Issue ✅
**Problem:** Docker builds failed because child services couldn't find the parent POM (`ride-parent`).

**Solution:** Updated all Dockerfiles to build from the project root directory with proper context:
- Changed build context from service directory to root directory
- Dockerfiles now copy both parent POM and service directory
- Build command: `docker build -f <service>/Dockerfile -t <service>:latest .`

### 2. Kubernetes Duplicate Service Names ✅
**Problem:** Multiple services tried to create resources with the same name "SERVICE_NAME", causing conflicts.

**Solution:** Added unique `namePrefix` to each service's kustomization:
- auth-service: `namePrefix: auth-`
- booking-service: `namePrefix: booking-`
- gateway-service: `namePrefix: gateway-`
- mail-service: `namePrefix: mail-`
- payment-service: `namePrefix: payment-`
- pricing-service: `namePrefix: pricing-`
- user-service: `namePrefix: user-`
- vehicle-service: `namePrefix: vehicle-`

### 3. Missing Config Directory ✅
**Problem:** auth-service overlay referenced `../../config` which didn't exist.

**Solution:** Created `config` directory with proper kustomization files in each service's overlay.

### 4. Maven POM XML Errors ✅
**Problem:** Invalid XML comments (`// Optional, for monitoring`) and duplicate dependencies.

**Solution:** 
- Removed invalid `//` comments (XML uses `<!-- -->` syntax)
- Removed duplicate `spring-boot-starter-actuator` dependencies
- Replaced deprecated `<version>RELEASE</version>` with specific version `7.10.2` for TestNG

### 5. Malformed Kustomization YAML ✅
**Problem:** `kustomization.yaml is empty` error due to fields in wrong order.

**Solution:** Fixed YAML structure in auth-service config kustomization file.

## How to Build and Run

### Prerequisites
- Docker installed
- Kubernetes cluster (minikube, kind, or cloud provider)
- kubectl configured

### Step 1: Build Docker Images

From the project root directory:

```bash
# Make build script executable
chmod +x build-all-images.sh

# Build all service images
./build-all-images.sh
```

This will build all 8 microservices:
- auth-service:latest
- booking-service:latest
- gateway-service:latest
- mail-service:latest
- payment-service:latest
- pricing-service:latest
- user-service:latest
- vehicle-service:latest

### Step 2: Deploy to Kubernetes

```bash
# Create namespace and deploy all services
kubectl apply -k k8s/environments/dev
```

### Step 3: Verify Deployment

```bash
# Check all pods are running
kubectl get pods -n ride-dev

# Check services
kubectl get svc -n ride-dev

# Check deployments
kubectl get deployments -n ride-dev
```

### Step 4: Access Services

Services will be available on the following ports:
- Gateway Service: 8080
- Auth Service: 8081
- Booking Service: 8082
- Payment Service: 8083
- Mail Service: 8084
- Pricing Service: 8085
- User Service: 8086
- Vehicle Service: 8087

## Service Ports

| Service | Port | Description |
|---------|------|-------------|
| gateway-service | 8080 | API Gateway |
| auth-service | 8081 | Authentication & Authorization |
| booking-service | 8082 | Booking Management |
| payment-service | 8083 | Payment Processing |
| mail-service | 8084 | Email Notifications |
| pricing-service | 8085 | Dynamic Pricing |
| user-service | 8086 | User Management |
| vehicle-service | 8087 | Vehicle Management |

## Troubleshooting

### Build Issues

If you encounter build errors:

1. **Parent POM not found**: Ensure you're building from the project root directory
2. **Maven dependencies**: Clear local Maven repository: `rm -rf ~/.m2/repository/com/ride`
3. **Java version**: Ensure Java 21 is installed
4. **Invalid XML comments**: Check POM files for `//` comments (should be `<!-- -->`)
5. **Duplicate dependencies**: Check for duplicate actuator or other dependencies

### Kubernetes Issues

1. **Duplicate resources**: Ensure each service has a unique `namePrefix` in its kustomization.yaml
2. **Image pull errors**: For local images, use `imagePullPolicy: Never` or `IfNotPresent`
3. **Service not starting**: Check logs: `kubectl logs -n ride-dev <pod-name>`
4. **"kustomization.yaml is empty"**: Check that YAML structure is correct:
   ```yaml
   apiVersion: kustomize.config.k8s.io/v1beta1
   kind: Kustomization
   resources:
     - configmap.yaml
   ```
   Fields must be in correct order: apiVersion, kind, then other fields.

5. **"couldn't make target for path"**: Ensure all referenced directories have kustomization.yaml files

### Clean Up

```bash
# Delete all resources
kubectl delete namespace ride-dev

# Remove Docker images
docker rmi $(docker images | grep -E 'auth-service|booking-service|gateway-service|mail-service|payment-service|pricing-service|user-service|vehicle-service' | awk '{print $3}')
```

## Architecture

```
┌─────────────────┐
│  Gateway (8080) │
└────────┬────────┘
         │
    ┌────┴────┬────────┬──────────┬──────────┬──────────┬──────────┬──────────┐
    │         │        │          │          │          │          │          │
┌───▼──┐  ┌──▼───┐ ┌──▼────┐ ┌───▼────┐ ┌───▼───┐ ┌───▼────┐ ┌───▼───┐ ┌───▼────┐
│ Auth │  │ User │ │Booking│ │Payment │ │ Mail  │ │Pricing │ │Vehicle│ │  ...   │
│ 8081 │  │ 8086 │ │ 8082  │ │ 8083   │ │ 8084  │ │ 8085   │ │ 8087  │ │        │
└──────┘  └──────┘ └───────┘ └────────┘ └───────┘ └────────┘ └───────┘ └────────┘
```

## Next Steps

1. **Configure Databases**: Set up MongoDB, PostgreSQL as needed for each service
2. **Configure Secrets**: Add database credentials and API keys
3. **Configure Ingress**: Set up ingress rules for external access
4. **Configure Monitoring**: Add Prometheus and Grafana for monitoring
5. **Configure Logging**: Set up centralized logging with ELK stack

## Additional Resources

- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Kustomize Documentation](https://kustomize.io/)
- [Spring Boot on Kubernetes](https://spring.io/guides/gs/spring-boot-kubernetes/)

