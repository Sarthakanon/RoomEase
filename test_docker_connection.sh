#!/bin/bash

# 🧪 Test Docker PostgreSQL Connection
echo "🧪 Testing Docker PostgreSQL Connection"
echo "======================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONTAINER_NAME="roomease-postgres"
DATABASE_NAME="roomease"

echo -e "${YELLOW}📋 Testing connection to:${NC}"
echo "Container: $CONTAINER_NAME"
echo "Database: $DATABASE_NAME"
echo ""

# Test if container is running
if docker ps | grep -q "$CONTAINER_NAME"; then
    echo -e "${GREEN}✅ Container $CONTAINER_NAME is running${NC}"
else
    echo -e "${RED}❌ Container $CONTAINER_NAME is not running${NC}"
    echo "Please start your Docker containers first"
    exit 1
fi

# Test database connection
echo -e "${YELLOW}🔍 Testing database connection...${NC}"

# Try different connection methods
echo "Method 1: Direct connection to roomease database"
if docker exec -t $CONTAINER_NAME psql -U postgres -d $DATABASE_NAME -c "SELECT current_database(), current_user;" 2>/dev/null; then
    echo -e "${GREEN}✅ Direct connection successful!${NC}"
    CONNECTION_SUCCESS=true
else
    echo -e "${YELLOW}⚠️  Direct connection failed, trying alternative...${NC}"
    
    echo "Method 2: Connect to postgres database first"
    if docker exec -t $CONTAINER_NAME psql -U postgres -c "SELECT current_database();" 2>/dev/null; then
        echo -e "${GREEN}✅ PostgreSQL server is accessible${NC}"
        
        # Check if roomease database exists
        DB_EXISTS=$(docker exec -t $CONTAINER_NAME psql -U postgres -c "SELECT 1 FROM pg_database WHERE datname='$DATABASE_NAME';" -t 2>/dev/null | tr -d ' \n')
        
        if [ "$DB_EXISTS" = "1" ]; then
            echo -e "${GREEN}✅ Database '$DATABASE_NAME' exists${NC}"
            CONNECTION_SUCCESS=true
        else
            echo -e "${RED}❌ Database '$DATABASE_NAME' does not exist${NC}"
            CONNECTION_SUCCESS=false
        fi
    else
        echo -e "${RED}❌ Cannot connect to PostgreSQL server${NC}"
        CONNECTION_SUCCESS=false
    fi
fi

if [ "$CONNECTION_SUCCESS" = true ]; then
    
    # Show tables
    echo -e "${YELLOW}📊 Current tables in database:${NC}"
    docker exec -t $CONTAINER_NAME psql -U postgres -d $DATABASE_NAME -c "\dt" 2>/dev/null || echo "Could not list tables, but database exists"
    
    echo ""
    echo -e "${GREEN}🎉 Your Docker database is ready for migration!${NC}"
    echo ""
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Run: ./complete_supabase_setup.sh (enter your Supabase password)"
    echo "2. Run: ./migrate_to_supabase.sh (migrate your data)"
    
else
    echo -e "${RED}❌ Database connection failed${NC}"
    echo ""
    echo -e "${YELLOW}💡 Troubleshooting:${NC}"
    echo "1. Check if database '$DATABASE_NAME' exists:"
    echo "   docker exec -t $CONTAINER_NAME psql -U postgres -c '\l'"
    echo ""
    echo "2. If database doesn't exist, create it:"
    echo "   docker exec -t $CONTAINER_NAME psql -U postgres -c 'CREATE DATABASE $DATABASE_NAME;'"
    echo ""
    echo "3. Or check what databases exist and update the script"
fi