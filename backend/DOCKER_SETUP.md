# Docker Setup Guide

This guide will help you set up PostgreSQL and pgAdmin using Docker for the RoomEase backend.

## Prerequisites

- Docker installed and running
- Docker Compose installed

## Quick Start

1. **Start the containers:**
   ```bash
   cd backend
   docker-compose up -d
   ```

2. **Verify containers are running:**
   ```bash
   docker-compose ps
   ```

## Services

### PostgreSQL Database
- **Host:** localhost
- **Port:** 5432
- **Database:** roomease
- **Username:** postgres
- **Password:** roomease_dev_password

### pgAdmin (Web Interface)
- **URL:** http://localhost:5050
- **Email:** admin@example.com
- **Password:** admin

## Connecting to PostgreSQL

### From Your Go Application

Update your `.env` file with these values:
```env
POSTGRES_HOST=localhost
POSTGRES_PORT=5432
POSTGRES_USER=postgres
POSTGRES_PASSWORD=roomease_dev_password
POSTGRES_DATABASE=roomease
```

### Using pgAdmin

1. Open http://localhost:5050 in your browser
2. Login with:
   - Email: `admin@example.com`
   - Password: `admin`
3. Add a new server:
   - Right-click "Servers" → "Register" → "Server"
   - **General Tab:**
     - Name: `RoomEase Local`
   - **Connection Tab:**
     - Host: `postgres` (when connecting from pgAdmin container)
     - Port: `5432`
     - Database: `roomease`
     - Username: `postgres`
     - Password: `roomease_dev_password`
4. Click "Save"

### Using psql CLI

Connect directly to the PostgreSQL container:
```bash
docker exec -it roomease-postgres psql -U postgres -d roomease
```

## Useful Commands

### Start containers
```bash
docker-compose up -d
```

### Stop containers
```bash
docker-compose down
```

### Stop and remove volumes (deletes all data)
```bash
docker-compose down -v
```

### View logs
```bash
# All services
docker-compose logs -f

# PostgreSQL only
docker-compose logs -f postgres

# pgAdmin only
docker-compose logs -f pgadmin
```

### Restart containers
```bash
docker-compose restart
```

### Check container status
```bash
docker-compose ps
```

## Database Backup and Restore

### Backup
```bash
docker exec roomease-postgres pg_dump -U postgres roomease > backup.sql
```

### Restore
```bash
docker exec -i roomease-postgres psql -U postgres roomease < backup.sql
```

## Troubleshooting

### Port already in use
If port 5432 or 5050 is already in use, edit `docker-compose.yml` and change the port mapping:
```yaml
ports:
  - "5433:5432"  # Use 5433 on host instead
```

### Cannot connect from Go app
Make sure you're using `localhost` as the host when connecting from your local machine (not from within a container).

### Reset everything
```bash
docker-compose down -v
docker-compose up -d
```

## Production Notes

For production deployment:
1. Change all default passwords
2. Use environment variables for sensitive data
3. Set up proper backup strategies
4. Configure SSL/TLS connections
5. Restrict pgAdmin access or remove it entirely
