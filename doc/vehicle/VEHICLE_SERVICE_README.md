# Vehicle Service

Enterprise-grade vehicle management microservice with external API integration using the Car API (carapi.app).

## Overview

The Vehicle Service manages vehicle information with a hybrid data strategy:
1. **Primary**: Local PostgreSQL database for fast access
2. **Fallback**: External Car API (carapi.app) when data is not found locally
3. **Sync**: Manual sync endpoints to populate database from external API

## Architecture & Design Patterns

### Design Patterns Used

1. **Repository Pattern**: Data access abstraction
2. **Service Layer Pattern**: Business logic separation
3. **Interface Segregation**: Service interfaces with concrete implementations
4. **Dependency Injection**: Constructor-based DI for loose coupling
5. **DTO Pattern**: Data transfer objects for API communication
6. **Strategy Pattern**: Hybrid data retrieval (local DB + external API)
7. **Factory Pattern**: ObjectMapper and RestTemplate configuration
8. **Singleton Pattern**: Spring-managed beans

### Project Structure

```
vehicle-service/
├── src/main/java/com/ride/vehicleservice/
│   ├── config/              # Configuration classes
│   │   ├── AppConfig.java           # RestTemplate, ObjectMapper beans
│   │   ├── SecurityConfig.java      # OAuth2 security
│   │   └── SwaggerConfig.java       # API documentation
│   ├── controller/          # REST API Controllers
│   │   ├── CarApiController.java    # Make management endpoints
│   │   ├── ModelController.java     # Model management endpoints
│   │   └── VehicleController.java   # Vehicle CRUD endpoints
│   ├── dto/                 # Data Transfer Objects
│   │   ├── MakeDto.java
│   │   ├── ModelDto.java
│   │   └── VehicleDto.java
│   ├── exception/           # Exception handling
│   │   ├── ResourceNotFoundException.java
│   │   └── GlobalExceptionHandler.java
│   ├── model/               # JPA Entities
│   │   ├── Makes.java
│   │   ├── CarModels.java
│   │   └── Vehicle.java
│   ├── repository/          # JPA Repositories
│   │   ├── MakesRepository.java
│   │   ├── CarModelsRepository.java
│   │   └── VehicleRepository.java
│   ├── service/             # Service Interfaces
│   │   ├── ICarApiClient.java       # External API client interface
│   │   ├── IMakeService.java        # Make service interface
│   │   ├── IModelService.java       # Model service interface
│   │   ├── IVehicleService.java     # Vehicle service interface
│   │   ├── CarApiClient.java        # API client implementation
│   │   ├── CarApiAuthService.java   # JWT authentication
│   │   └── impl/                    # Service Implementations
│   │       ├── MakeServiceImpl.java
│   │       ├── ModelServiceImpl.java
│   │       └── VehicleServiceImpl.java
│   └── util/                # Utility classes
│       └── CarApiUrlBuilder.java    # API URL construction
└── src/main/resources/
    └── application.yaml     # Application configuration
```

## Features

### Core Functionality

1. **Vehicle Management**
   - CRUD operations for vehicles
   - Search by make, model, and year
   - Filter by make or year
   - Pagination support

2. **Make Management**
   - List all makes
   - Get make by name
   - Sync all makes from external API

3. **Model Management**
   - List models by make
   - Get model by name and make
   - Sync models from external API

4. **Hybrid Data Strategy**
   - Checks local database first
   - Falls back to external API if not found
   - Automatically stores API data locally
   - Manual sync endpoints for bulk data import

### External API Integration

- **Provider**: Car API (carapi.app)
- **Authentication**: JWT-based (cached for performance)
- **Auto-retry**: Automatic token refresh on expiration
- **Fallback**: Graceful error handling when API is unavailable

## API Endpoints

### Vehicle Endpoints

```
GET    /api/v1/vehicles                    # Get all vehicles (paginated)
GET    /api/v1/vehicles/{id}               # Get vehicle by ID
GET    /api/v1/vehicles/search             # Search vehicle (make, model, year)
GET    /api/v1/vehicles/make/{make}        # Get vehicles by make
GET    /api/v1/vehicles/year/{year}        # Get vehicles by year
POST   /api/v1/vehicles                    # Create vehicle
PUT    /api/v1/vehicles/{id}               # Update vehicle
DELETE /api/v1/vehicles/{id}               # Delete vehicle
POST   /api/v1/vehicles/sync               # Sync vehicle from API
```

### Make Endpoints

```
GET    /api/v1/vehicles/makes              # Get all makes
GET    /api/v1/vehicles/makes/{name}       # Get make by name
POST   /api/v1/vehicles/makes/sync         # Sync all makes from API
GET    /api/v1/vehicles/makes/api/health   # Check API availability
```

### Model Endpoints

```
GET    /api/v1/vehicles/models             # Get models by make (query param)
GET    /api/v1/vehicles/models/{modelName} # Get model by name and make
POST   /api/v1/vehicles/models/sync        # Sync models from API
```

## Configuration

### Application Properties

```yaml
server:
  port: 8087

spring:
  datasource:
    url: jdbc:postgresql://localhost:5437/vehicledb
    username: vehicleservice
    password: vehicleservice123
  
  jpa:
    hibernate:
      ddl-auto: update
    show-sql: true

carapi:
  token: your-api-token
  secret: your-api-secret
```

### Environment Variables

- `SPRING_DATASOURCE_URL`: PostgreSQL connection URL
- `SPRING_DATASOURCE_USERNAME`: Database username
- `SPRING_DATASOURCE_PASSWORD`: Database password
- `CARAPI_TOKEN`: Car API token
- `CARAPI_SECRET`: Car API secret

## Usage Examples

### 1. Search for a Vehicle (Hybrid Strategy)

```bash
# Checks local DB first, then fetches from API if not found
curl -X GET "http://localhost:8087/api/v1/vehicles/search?make=Toyota&model=Camry&year=2020"
```

Response:
```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "make": "Toyota",
  "model": "Camry",
  "year": "2020",
  "transmission": "Automatic"
}
```

### 2. Sync All Makes from API

```bash
curl -X POST "http://localhost:8087/api/v1/vehicles/makes/sync"
```

### 3. Get All Vehicles (Paginated)

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles?page=0&size=10&sortBy=year&direction=desc"
```

### 4. Check API Health

```bash
curl -X GET "http://localhost:8087/api/v1/vehicles/makes/api/health"
```

Response:
```json
{
  "status": "UP",
  "apiAvailable": true
}
```

## Database Schema

### Tables

1. **makes**
   - `id` (BIGSERIAL PRIMARY KEY)
   - `name` (VARCHAR UNIQUE)

2. **car_models**
   - `id` (UUID PRIMARY KEY)
   - `name` (VARCHAR)
   - `make_id` (BIGINT FOREIGN KEY → makes)

3. **vehicles**
   - `id` (UUID PRIMARY KEY)
   - `make_id` (BIGINT FOREIGN KEY → makes)
   - `model_id` (UUID FOREIGN KEY → car_models)
   - `year` (VARCHAR)
   - `transmission` (VARCHAR)
   - `fuel_type` (VARCHAR)
   - `seats` (INTEGER)
   - `doors` (INTEGER)
   - `drivetrain` (VARCHAR)
   - `engine_type` (VARCHAR)
   - `engine_displacement` (DOUBLE)
   - `created_at` (TIMESTAMP)
   - `updated_at` (TIMESTAMP)

## Development

### Prerequisites

- Java 21+
- Maven 3.8+
- PostgreSQL 14+
- Car API credentials (from carapi.app)

### Build

```bash
mvn clean install
```

### Run

```bash
mvn spring-boot:run
```

### Test

```bash
mvn test
```

## Swagger Documentation

Access API documentation at:
```
http://localhost:8087/swagger-ui.html
```

## Error Handling

The service implements comprehensive error handling:

- `404 Not Found`: Resource not found (vehicle, make, model)
- `400 Bad Request`: Invalid input parameters
- `401 Unauthorized`: External API authentication failed
- `500 Internal Server Error`: Unexpected errors

## Performance Optimizations

1. **JWT Token Caching**: Caches authentication tokens for 30 minutes
2. **Database Connection Pooling**: HikariCP with optimized settings
3. **Lazy Loading**: JPA entities use lazy loading for relationships
4. **Pagination**: All list endpoints support pagination

## Security

- OAuth2 Resource Server configuration
- JWT-based authentication with Keycloak
- Secure external API communication
- Input validation and sanitization

## Monitoring

- Health check endpoint: `/actuator/health`
- Metrics endpoint: `/actuator/metrics`
- Info endpoint: `/actuator/info`

## Future Enhancements

- [ ] Add Redis caching layer
- [ ] Implement GraphQL API
- [ ] Add vehicle image storage
- [ ] Implement full-text search
- [ ] Add batch sync operations
- [ ] Implement rate limiting
- [ ] Add event-driven architecture with Kafka

## License

Apache License 2.0

## Contact

For issues and questions, please open an issue on the project repository.
