#!/bin/bash

# 🔧 Fix Docker Database Connection
echo "🔧 Fixing Docker Database Connection"
echo "==================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

CONTAINER_NAME="roomease-pg"

echo -e "${YELLOW}🔍 Checking available databases...${NC}"
echo ""

# List all databases
echo "Available databases:"
docker exec -t $CONTAINER_NAME psql -U postgres -c '\l'

echo ""
echo -e "${YELLOW}🔍 Checking for common database names...${NC}"

# Check for common database names
DATABASES=("roomease" "postgres" "room_ease" "roomease_dev")

for db in "${DATABASES[@]}"; do
    echo -n "Checking database '$db': "
    if docker exec -t $CONTAINER_NAME psql -U postgres -d $db -c "SELECT 1;" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ EXISTS${NC}"
        
        # Check if it has tables
        TABLE_COUNT=$(docker exec -t $CONTAINER_NAME psql -U postgres -d $db -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" -t 2>/dev/null | tr -d ' ')
        if [ "$TABLE_COUNT" -gt 0 ]; then
            echo -e "  ${GREEN}📊 Has $TABLE_COUNT tables${NC}"
            echo -e "  ${YELLOW}📋 Tables:${NC}"
            docker exec -t $CONTAINER_NAME psql -U postgres -d $db -c "\dt" 2>/dev/null | head -10
            echo ""
            echo -e "${GREEN}🎯 Found your database: '$db'${NC}"
            echo ""
            echo -e "${YELLOW}🔧 Updating migration script...${NC}"
            
            # Update the test script with correct database name
            sed -i "s/DATABASE_NAME=\"roomease\"/DATABASE_NAME=\"$db\"/" test_docker_connection.sh
            sed -i "s/LOCAL_DB=\${LOCAL_DB:-roomease}/LOCAL_DB=\${LOCAL_DB:-$db}/" migrate_to_supabase.sh
            
            echo -e "${GREEN}✅ Scripts updated to use database '$db'${NC}"
            echo ""
            echo -e "${YELLOW}🚀 Now run:${NC}"
            echo "./test_docker_connection.sh"
            exit 0
        else
            echo -e "  ${YELLOW}⚠️  Empty database${NC}"
        fi
    else
        echo -e "${RED}❌ NOT FOUND${NC}"
    fi
done

echo ""
echo -e "${YELLOW}💡 Manual steps:${NC}"
echo "1. If you see your database in the list above, note its name"
echo "2. Update the scripts manually:"
echo "   - Edit test_docker_connection.sh"
echo "   - Change DATABASE_NAME=\"roomease\" to your actual database name"
echo ""
echo "3. Or create the 'roomease' database:"
echo "   docker exec -t $CONTAINER_NAME psql -U postgres -c 'CREATE DATABASE roomease;'"