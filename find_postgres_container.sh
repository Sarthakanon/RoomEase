#!/bin/bash

# 🔍 Find PostgreSQL Container
echo "🔍 Finding PostgreSQL Container"
echo "==============================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}📋 All running containers:${NC}"
docker ps --format "table {{.Names}}\t{{.Image}}\t{{.Ports}}\t{{.Status}}"

echo ""
echo -e "${YELLOW}🔍 Looking for PostgreSQL containers...${NC}"

# Check all running containers for PostgreSQL
POSTGRES_CONTAINERS=()

for container in $(docker ps --format "{{.Names}}"); do
    echo -n "Checking $container: "
    
    # Check if container has PostgreSQL
    if docker exec $container which psql >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Has PostgreSQL${NC}"
        POSTGRES_CONTAINERS+=($container)
        
        # Test connection
        echo "  Testing connection..."
        if docker exec $container psql --version >/dev/null 2>&1; then
            echo -e "  ${GREEN}✅ psql works${NC}"
            
            # Try to connect
            if docker exec $container psql -U postgres -c "SELECT version();" >/dev/null 2>&1; then
                echo -e "  ${GREEN}✅ Can connect as postgres user${NC}"
                
                # List databases
                echo -e "  ${YELLOW}📊 Databases:${NC}"
                docker exec $container psql -U postgres -c '\l' 2>/dev/null | grep -E "^\s*\w+\s*\|" | head -10
                
            else
                echo -e "  ${YELLOW}⚠️  Cannot connect (might need password)${NC}"
            fi
        fi
        echo ""
    else
        echo -e "${RED}❌ No PostgreSQL${NC}"
    fi
done

echo ""
if [ ${#POSTGRES_CONTAINERS[@]} -eq 0 ]; then
    echo -e "${RED}❌ No PostgreSQL containers found${NC}"
    echo ""
    echo -e "${YELLOW}💡 Possible solutions:${NC}"
    echo "1. Your PostgreSQL might be in a stopped container:"
    echo "   docker ps -a"
    echo ""
    echo "2. PostgreSQL might be running on host (not in Docker):"
    echo "   sudo systemctl status postgresql"
    echo ""
    echo "3. Use pgAdmin export instead:"
    echo "   - Open pgAdmin at http://localhost:5050"
    echo "   - Right-click your database → Backup"
    echo "   - Download the SQL file"
    echo ""
    echo "4. Start fresh with Supabase (lose existing data)"
    
else
    echo -e "${GREEN}🎉 Found PostgreSQL containers:${NC}"
    for container in "${POSTGRES_CONTAINERS[@]}"; do
        echo "  - $container"
    done
    
    echo ""
    echo -e "${YELLOW}🔧 Updating scripts with correct container name...${NC}"
    
    # Use the first PostgreSQL container found
    CORRECT_CONTAINER=${POSTGRES_CONTAINERS[0]}
    
    # Update all scripts
    sed -i "s/CONTAINER_NAME=\"roomease-pg\"/CONTAINER_NAME=\"$CORRECT_CONTAINER\"/" test_docker_connection.sh
    sed -i "s/CONTAINER_NAME=\"roomease-pg\"/CONTAINER_NAME=\"$CORRECT_CONTAINER\"/" migrate_to_supabase.sh
    sed -i "s/CONTAINER_NAME=\"roomease-pg\"/CONTAINER_NAME=\"$CORRECT_CONTAINER\"/" direct_migration.sh
    
    echo -e "${GREEN}✅ Scripts updated to use container: $CORRECT_CONTAINER${NC}"
    echo ""
    echo -e "${YELLOW}🚀 Now try:${NC}"
    echo "./test_docker_connection.sh"
fi