#!/bin/bash

# 🔍 Comprehensive Docker PostgreSQL Diagnosis
echo "🔍 Docker PostgreSQL Diagnosis"
echo "=============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONTAINER_NAME="roomease-pg"

echo -e "${YELLOW}📋 Step 1: Container Status${NC}"
echo "Container name: $CONTAINER_NAME"
echo ""

# Check if container exists and is running
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${GREEN}✅ Container is running${NC}"
    
    # Get container details
    echo -e "${YELLOW}📊 Container details:${NC}"
    docker ps --filter "name=$CONTAINER_NAME" --format "table {{.Names}}\t{{.Status}}\t{{.Ports}}"
    echo ""
else
    echo -e "${RED}❌ Container is not running${NC}"
    
    # Check if container exists but is stopped
    if docker ps -a | grep -q "$CONTAINER_NAME"; then
        echo -e "${YELLOW}⚠️  Container exists but is stopped${NC}"
        echo "Starting container..."
        docker start $CONTAINER_NAME
        sleep 3
    else
        echo -e "${RED}❌ Container does not exist${NC}"
        echo "Please check your Docker setup"
        exit 1
    fi
fi

echo -e "${YELLOW}📋 Step 2: PostgreSQL Process Check${NC}"
# Check if PostgreSQL is running inside the container
if docker exec $CONTAINER_NAME ps aux | grep -q postgres; then
    echo -e "${GREEN}✅ PostgreSQL process is running${NC}"
else
    echo -e "${RED}❌ PostgreSQL process not found${NC}"
    echo "Container might not be ready yet, waiting..."
    sleep 5
fi

echo ""
echo -e "${YELLOW}📋 Step 3: Connection Tests${NC}"

# Test 1: Basic connection without specifying database
echo "Test 1: Basic PostgreSQL connection"
if docker exec $CONTAINER_NAME psql --version >/dev/null 2>&1; then
    echo -e "${GREEN}✅ psql is available${NC}"
else
    echo -e "${RED}❌ psql not available${NC}"
fi

# Test 2: Try different authentication methods
echo ""
echo "Test 2: Authentication methods"

# Method A: Default postgres user, no password
echo -n "Method A (postgres, no password): "
if docker exec $CONTAINER_NAME psql -U postgres -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ SUCCESS${NC}"
    AUTH_METHOD="postgres_no_pass"
elif docker exec $CONTAINER_NAME psql -U postgres -W -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ SUCCESS (with password prompt)${NC}"
    AUTH_METHOD="postgres_with_pass"
else
    echo -e "${RED}❌ FAILED${NC}"
fi

# Method B: Try with password from environment
echo -n "Method B (with password): "
if docker exec -e PGPASSWORD=roomease_dev_password $CONTAINER_NAME psql -U postgres -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ SUCCESS${NC}"
    AUTH_METHOD="postgres_env_pass"
else
    echo -e "${RED}❌ FAILED${NC}"
fi

# Method C: Try different users
echo -n "Method C (root user): "
if docker exec $CONTAINER_NAME psql -U root -c "SELECT 1;" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ SUCCESS${NC}"
    AUTH_METHOD="root"
else
    echo -e "${RED}❌ FAILED${NC}"
fi

echo ""
echo -e "${YELLOW}📋 Step 4: Database Listing${NC}"

# Try to list databases with successful auth method
if [ "$AUTH_METHOD" = "postgres_no_pass" ]; then
    echo "Using postgres user without password:"
    docker exec $CONTAINER_NAME psql -U postgres -c '\l'
elif [ "$AUTH_METHOD" = "postgres_env_pass" ]; then
    echo "Using postgres user with environment password:"
    docker exec -e PGPASSWORD=roomease_dev_password $CONTAINER_NAME psql -U postgres -c '\l'
elif [ "$AUTH_METHOD" = "root" ]; then
    echo "Using root user:"
    docker exec $CONTAINER_NAME psql -U root -c '\l'
else
    echo -e "${RED}❌ No working authentication method found${NC}"
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting suggestions:${NC}"
    echo "1. Check Docker logs:"
    echo "   docker logs $CONTAINER_NAME"
    echo ""
    echo "2. Check PostgreSQL configuration:"
    echo "   docker exec $CONTAINER_NAME cat /var/lib/postgresql/data/pg_hba.conf"
    echo ""
    echo "3. Try connecting to pgAdmin (port 5050) to verify database works"
    echo ""
    echo "4. Restart the container:"
    echo "   docker restart $CONTAINER_NAME"
    exit 1
fi

echo ""
echo -e "${YELLOW}📋 Step 5: Table Check${NC}"

# If we found a working auth method, check for tables
if [ -n "$AUTH_METHOD" ]; then
    echo "Checking for tables in roomease database..."
    
    if [ "$AUTH_METHOD" = "postgres_no_pass" ]; then
        docker exec $CONTAINER_NAME psql -U postgres -d roomease -c '\dt' 2>/dev/null || echo "Could not connect to roomease database"
    elif [ "$AUTH_METHOD" = "postgres_env_pass" ]; then
        docker exec -e PGPASSWORD=roomease_dev_password $CONTAINER_NAME psql -U postgres -d roomease -c '\dt' 2>/dev/null || echo "Could not connect to roomease database"
    fi
fi

echo ""
echo -e "${GREEN}🎯 Diagnosis Complete!${NC}"
echo ""
echo -e "${YELLOW}📝 Summary:${NC}"
echo "Container Status: Running"
echo "Authentication Method: $AUTH_METHOD"
echo ""
echo -e "${YELLOW}🚀 Next Steps:${NC}"
echo "1. If authentication works, I'll create a fixed migration script"
echo "2. If not, we can export data directly from pgAdmin"
echo "3. Or we can start fresh with Supabase and recreate data"