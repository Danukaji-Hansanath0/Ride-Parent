# 🚗 Ride Platform - Enterprise Microservices

A modern, scalable ride-sharing platform built with **Spring Boot 3.5.9**, **Java 21**, and **Kubernetes**.

[![Java](https://img.shields.io/badge/Java-21-orange.svg)](https://openjdk.org/)
[![Spring Boot](https://img.shields.io/badge/Spring%20Boot-3.5.9-brightgreen.svg)](https://spring.io/projects/spring-boot)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-1.28+-blue.svg)](https://kubernetes.io/)
[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](LICENSE)

## 📋 Table of Contents

- [Overview](#overview)
- [Architecture](#architecture)
- [Services](#services)
- [Quick Start](#quick-start)
- [Technologies](#technologies)
- [Documentation](#documentation)
- [Development](#development)

## 🎯 Overview

Ride Platform is an enterprise-grade microservices application for ride-sharing that includes:

- ✅ **8 Independent Microservices**
- ✅ **Kubernetes-Native Deployment**
- ✅ **API Gateway with Routing**
- ✅ **OAuth2 Authentication**
- ✅ **MongoDB & PostgreSQL Databases**
- ✅ **Docker & Docker Compose Support**
- ✅ **Production-Ready Configuration**

## 🏗️ Architecture

```
                                ┌─────────────────────┐
                                │   Gateway Service   │
                                │      (Port 8080)    │
                                └──────────┬──────────┘
                                           │
                    ┌──────────────────────┼──────────────────────┐
                    │                      │                      │
         ┌──────────▼──────────┐  ┌───────▼────────┐  ┌─────────▼─────────┐
         │   Auth Service      │  │  User Service  │  │  Booking Service  │
         │    (Port 8081)      │  │  (Port 8086)   │  │   (Port 8082)     │
         └─────────────────────┘  └────────┬───────┘  └──────────┬────────┘
                                           │                      │
         ┌─────────────────────┐  ┌───────▼────────┐  ┌─────────▼─────────┐
         │  Payment Service    │  │  Mail Service  │  │  Vehicle Service  │
         │   (Port 8083)       │  │  (Port 8084)   │  │   (Port 8087)     │
         └──────────┬──────────┘  └────────┬───────┘  └──────────┬────────┘
                    │                      │                      │
         ┌──────────▼──────────┐           │           ┌─────────▼─────────┐
         │  Pricing Service    │           │           │                   │
         │   (Port 8085)       │           │           │                   │
         └──────────┬──────────┘           │           │                   │
                    │                      │           │                   │
              ┌─────▼──────┐         ┌────▼─────┐     │     ┌────────────▼─┐
              │ PostgreSQL │         │PostgreSQL│     │     │   MongoDB     │
              │  (5432)    │         │  (5432)  │     │     │   (27017)     │
              └────────────┘         └──────────┘     │     └───────────────┘
                                                      │
                                                ┌─────▼──────┐
                                                │ PostgreSQL │
                                                │  (5432)    │
                                                └────────────┘
```

## 🎪 Services

| Service | Port | Database | Description |
|---------|------|----------|-------------|
| **Gateway Service** | 8080 | - | API Gateway, routing, load balancing |
| **Auth Service** | 8081 | - | Authentication, OAuth2, JWT tokens |
| **Booking Service** | 8082 | MongoDB | Ride booking and management |
| **Payment Service** | 8083 | PostgreSQL | Payment processing and transactions |
| **Mail Service** | 8084 | PostgreSQL | Email notifications and templates |
| **Pricing Service** | 8085 | PostgreSQL | Dynamic pricing algorithms |
| **User Service** | 8086 | PostgreSQL | User profiles and management |
| **Vehicle Service** | 8087 | MongoDB | Vehicle registration and tracking |

## 🚀 Quick Start

### Prerequisites

- **Java 21** or later
- **Docker** 20.10+
- **Docker Compose** 2.0+ (for local development)
- **Kubernetes** 1.28+ (for K8s deployment)
- **kubectl** (for K8s deployment)

### Option 1: Quick Start Script (Kubernetes)

The easiest way to get started:

```bash
# Make script executable
chmod +x quick-start.sh

# Build images and deploy to Kubernetes
./quick-start.sh
```

This script will:
1. ✅ Check prerequisites (Docker, kubectl)
2. ✅ Build all Docker images
3. ✅ Deploy to Kubernetes (ride-dev namespace)
4. ✅ Wait for pods to be ready
5. ✅ Show deployment status

### Option 2: Docker Compose (Local Development)

For quick local development without Kubernetes:

```bash
# Start all services with databases
docker-compose up --build

# Run in detached mode
docker-compose up -d --build

# View logs
docker-compose logs -f gateway-service

# Stop all services
docker-compose down
```

### Option 3: Manual Build and Deploy

```bash
# 1. Build all Docker images
chmod +x build-all-images.sh
./build-all-images.sh

# 2. Deploy to Kubernetes
kubectl apply -k k8s/environments/dev

# 3. Check status
kubectl get pods -n ride-dev
kubectl get svc -n ride-dev

# 4. Port forward gateway service
kubectl port-forward -n ride-dev svc/gateway-SERVICE_NAME 8080:80
```

### Option 4: Build Individual Service

```bash
# Build from project root
docker build -f auth-service/Dockerfile -t auth-service:latest .

# Or for all services
docker build -f booking-service/Dockerfile -t booking-service:latest .
docker build -f gateway-service/Dockerfile -t gateway-service:latest .
# ... etc
```

## 🛠️ Technologies

### Backend
- **Java 21** (Eclipse Temurin)
- **Spring Boot 3.5.9**
- **Spring Cloud** (Gateway, Config, Discovery)
- **Spring Data JPA**
- **Spring Data MongoDB**
- **Spring Security** (OAuth2)

### Databases
- **PostgreSQL 16** (User, Payment, Mail, Pricing services)
- **MongoDB 7.0** (Booking, Vehicle services)

### DevOps
- **Docker** (Multi-stage builds)
- **Kubernetes** (Deployments, Services, ConfigMaps)
- **Kustomize** (Configuration management)

### Build Tools
- **Maven 3.9+**
- **Maven Wrapper** (included)

## 📚 Documentation

Comprehensive documentation is available:

- **[DEPLOYMENT_GUIDE.md](doc/DEPLOYMENT_GUIDE.md)** - Complete deployment instructions
- **[FIXES_SUMMARY.md](doc/FIXES_SUMMARY.md)** - All issues fixed and solutions
- **[k8s/README.md](k8s/README.md)** - Kubernetes configuration structure
- **Service-specific docs** - Each service has its own README

### Key Documentation Files

| File | Description |
|------|-------------|
| `DEPLOYMENT_GUIDE.md` | Step-by-step deployment guide |
| `FIXES_SUMMARY.md` | Summary of all fixes applied |
| `k8s/README.md` | Kubernetes configuration explained |
| `docker-compose.yml` | Local development setup |
| `build-all-images.sh` | Build script for all services |
| `quick-start.sh` | Automated deployment script |

## 💻 Development

### Project Structure

```
Ride/
├── auth-service/           # Authentication microservice
├── booking-service/        # Booking management
├── gateway-service/        # API Gateway
├── mail-service/          # Email service
├── payment-service/       # Payment processing
├── pricing-service/       # Dynamic pricing
├── user-service/          # User management
├── vehicle-service/       # Vehicle management
├── k8s/                   # Kubernetes manifests
│   ├── apps/             # Service configurations
│   ├── base/             # Base configurations
│   ├── components/       # Reusable components
│   ├── environments/     # Environment configs (dev/staging/prod)
│   └── README.md         # K8s documentation
├── pom.xml               # Parent POM
├── docker-compose.yml    # Local development
├── build-all-images.sh   # Build script
└── quick-start.sh        # Quick start script
```

### Building Locally

Each service can be built independently:

```bash
# Navigate to service directory
cd auth-service

# Build with Maven
./mvnw clean package -DskipTests

# Run locally
java -jar target/auth-service-1.0.0-SNAPSHOT.jar
```

### Testing

```bash
# Run tests for a service
cd auth-service
./mvnw test

# Run tests for all services
for service in *-service; do
  cd $service && ./mvnw test && cd ..
done
```

### Adding a New Service

1. Create service directory: `my-service/`
2. Add `pom.xml` with parent reference
3. Create `Dockerfile` following the template
4. Add Kubernetes manifests in `k8s/apps/my-service/`
5. Update `build-all-images.sh`
6. Update `docker-compose.yml`
7. Update environment kustomization

## 🔧 Configuration

### Environment Variables

Each service supports configuration via environment variables:

```bash
# Server configuration
SERVER_PORT=8080

# Database configuration
SPRING_DATASOURCE_URL=jdbc:postgresql://localhost:5432/mydb
SPRING_DATASOURCE_USERNAME=user
SPRING_DATASOURCE_PASSWORD=pass

# MongoDB configuration
SPRING_DATA_MONGODB_URI=mongodb://localhost:27017/mydb

# Profile
SPRING_PROFILES_ACTIVE=dev
```

### Kubernetes Secrets

Store sensitive data in Kubernetes secrets:

```bash
kubectl create secret generic db-credentials \
  --from-literal=username=admin \
  --from-literal=password=secret \
  -n ride-dev
```

## 🧪 Testing the Deployment

```bash
# Check pods
kubectl get pods -n ride-dev

# Check services
kubectl get svc -n ride-dev

# View logs
kubectl logs -n ride-dev -l app=auth-SERVICE_NAME

# Port forward to access locally
kubectl port-forward -n ride-dev svc/gateway-SERVICE_NAME 8080:80

# Test the gateway
curl http://localhost:8080/actuator/health
```

## 🧹 Cleanup

### Kubernetes

```bash
# Delete all resources
kubectl delete namespace ride-dev

# Or delete specific deployment
kubectl delete -k k8s/environments/dev
```

### Docker Compose

```bash
# Stop and remove containers, networks, volumes
docker-compose down -v
```

### Docker Images

```bash
# Remove all service images
docker rmi $(docker images | grep -E 'auth-service|booking-service|gateway-service|mail-service|payment-service|pricing-service|user-service|vehicle-service' | grep latest | awk '{print $3}')
```

## 📊 Monitoring

Services expose actuator endpoints for monitoring:

```
http://localhost:<port>/actuator/health
http://localhost:<port>/actuator/metrics
http://localhost:<port>/actuator/info
```

## 🤝 Contributing

1. Fork the repository
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

## 📄 License

This project is licensed under the Apache License 2.0 - see the LICENSE file for details.

## 🙏 Acknowledgments

- Spring Boot team for the excellent framework
- Kubernetes community for orchestration tools
- All contributors to this project

## 📞 Support

For issues and questions:
- Check [DEPLOYMENT_GUIDE.md](doc/DEPLOYMENT_GUIDE.md)
- Check [FIXES_SUMMARY.md](doc/FIXES_SUMMARY.md)
- Open an issue on GitHub

---

**Built with ❤️ using Spring Boot and Kubernetes**

**Last Updated**: January 2026

