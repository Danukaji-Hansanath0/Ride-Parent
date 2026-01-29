# User Service Database Setup

This guide explains how to set up and run the PostgreSQL database for the User Service.

## Prerequisites

- Docker and Docker Compose installed
- Port 5433 available on your machine

## Database Configuration

- **Database Name**: `userdb`
- **Username**: `userservice`
- **Password**: `userservice123`
- **Host**: `localhost`
- **Port**: `5433` (mapped from container's 5432)

## Quick Start

### 1. Start the Database

```bash
cd /mnt/projects/Ride/user-service
docker-compose up -d
```

This will:
- Pull the PostgreSQL 16 Alpine image if not already available
- Create a PostgreSQL container named `user-service-postgres`
- Initialize the database with the scripts in `init-scripts/`
- Set up a persistent volume for data storage

### 2. Check Database Status

```bash
docker-compose ps
```

You should see the `user-service-postgres` container running and healthy.

### 3. View Logs

```bash
docker-compose logs -f postgres
```

### 4. Connect to the Database

Using psql:
```bash
docker exec -it user-service-postgres psql -U userservice -d userdb
```

Using a database client:
- Host: localhost
- Port: 5433
- Database: userdb
- Username: userservice
- Password: userservice123

## Managing the Database

### Stop the Database
```bash
docker-compose stop
```

### Start the Database Again
```bash
docker-compose start
```

### Remove the Database (including volumes)
```bash
docker-compose down -v
```

### View Database Logs
```bash
docker-compose logs postgres
```

## Application Configuration

The `application.yml` is configured to connect to this database automatically. Make sure the database is running before starting the User Service application.

### Connection Properties:
- URL: `jdbc:postgresql://localhost:5433/userdb`
- Hibernate DDL Auto: `update` (automatically creates/updates tables)
- Connection Pool: HikariCP with optimized settings

## Database Schema

The database schema will be automatically created by Hibernate based on your JPA entities. The initial setup script (`init-scripts/01-init.sql`) includes:
- UUID extension for generating unique identifiers
- Necessary permissions for the userservice user
- Database comments and documentation

## Troubleshooting

### Port Already in Use
If port 5433 is already in use, you can change it in `compose.yaml`:
```yaml
ports:
  - "YOUR_PORT:5432"
```
And update the `application.yml` accordingly.

### Connection Refused
1. Ensure the database container is running: `docker-compose ps`
2. Check logs for errors: `docker-compose logs postgres`
3. Verify the health check: `docker inspect user-service-postgres`

### Reset Database
To completely reset the database:
```bash
docker-compose down -v
docker-compose up -d
```

## Production Considerations

For production environments:
1. Change the default password in both `compose.yaml` and `application.yml`
2. Use environment variables or secrets management
3. Set up proper backup strategies
4. Configure SSL/TLS for database connections
5. Use a different `ddl-auto` setting (e.g., `validate` instead of `update`)
6. Set up database monitoring and alerting

