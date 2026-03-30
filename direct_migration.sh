#!/bin/bash

# 🚀 Direct Migration from Docker to Supabase
echo "🚀 Direct Migration: Docker → Supabase"
echo "===================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Configuration
CONTAINER_NAME="roomease-postgres"
DATABASE_NAME="roomease"
SUPABASE_REF="raabjafkrerotvqbimbp"

echo -e "${YELLOW}📋 Migration Details:${NC}"
echo "Source: Docker container '$CONTAINER_NAME', database '$DATABASE_NAME'"
echo "Target: Supabase database"
echo ""

# Get Supabase password
read -s -p "🔑 Enter your Supabase database password: " SUPABASE_PASSWORD
echo ""

if [ -z "$SUPABASE_PASSWORD" ]; then
    echo -e "${RED}❌ Password is required${NC}"
    exit 1
fi

# Build connection strings
SUPABASE_CONNECTION="postgresql://postgres:$SUPABASE_PASSWORD@db.$SUPABASE_REF.supabase.co:5432/postgres"

echo -e "${YELLOW}🔄 Starting migration...${NC}"

# Step 1: Create backup using pg_dump
echo -e "${YELLOW}📦 Step 1: Creating database backup...${NC}"

# Try different pg_dump approaches
echo "Attempting backup with pg_dump..."

# Method 1: Direct pg_dump
if docker exec $CONTAINER_NAME pg_dump -U postgres -d $DATABASE_NAME --no-owner --no-privileges > roomease_backup.sql 2>/dev/null; then
    echo -e "${GREEN}✅ Backup created successfully (Method 1)${NC}"
elif docker exec $CONTAINER_NAME pg_dump -U postgres $DATABASE_NAME > roomease_backup.sql 2>/dev/null; then
    echo -e "${GREEN}✅ Backup created successfully (Method 2)${NC}"
else
    echo -e "${RED}❌ pg_dump failed, trying alternative method...${NC}"
    
    # Method 2: Manual table export
    echo -e "${YELLOW}🔄 Trying manual export...${NC}"
    
    # Get list of tables
    TABLES=$(docker exec $CONTAINER_NAME psql -U postgres -d $DATABASE_NAME -t -c "SELECT tablename FROM pg_tables WHERE schemaname='public';" 2>/dev/null | tr -d ' ')
    
    if [ -n "$TABLES" ]; then
        echo "-- RoomEase Database Backup" > roomease_backup.sql
        echo "-- Generated: $(date)" >> roomease_backup.sql
        echo "" >> roomease_backup.sql
        
        for table in $TABLES; do
            echo -e "${YELLOW}  Exporting table: $table${NC}"
            docker exec $CONTAINER_NAME pg_dump -U postgres -d $DATABASE_NAME -t $table --no-owner --no-privileges >> roomease_backup.sql 2>/dev/null
        done
        echo -e "${GREEN}✅ Manual backup completed${NC}"
    else
        echo -e "${RED}❌ Could not get table list${NC}"
        exit 1
    fi
fi

# Check if backup file was created and has content
if [ -s roomease_backup.sql ]; then
    BACKUP_SIZE=$(wc -l < roomease_backup.sql)
    echo -e "${GREEN}✅ Backup file created: $BACKUP_SIZE lines${NC}"
else
    echo -e "${RED}❌ Backup file is empty or not created${NC}"
    exit 1
fi

# Step 2: Clean backup file
echo -e "${YELLOW}🧹 Step 2: Cleaning backup file...${NC}"
# Remove problematic lines that might cause issues in Supabase
sed -i '/^SET /d' roomease_backup.sql
sed -i '/^SELECT pg_catalog.set_config/d' roomease_backup.sql
sed -i 's/OWNER TO [^;]*;//g' roomease_backup.sql

# Step 3: Import to Supabase
echo -e "${YELLOW}📤 Step 3: Importing to Supabase...${NC}"
echo "Connecting to Supabase..."

# Test Supabase connection first
if psql "$SUPABASE_CONNECTION" -c "SELECT version();" >/dev/null 2>&1; then
    echo -e "${GREEN}✅ Supabase connection successful${NC}"
    
    # Import the backup
    echo "Importing data..."
    if psql "$SUPABASE_CONNECTION" < roomease_backup.sql >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Data imported successfully!${NC}"
        
        # Verify import
        echo -e "${YELLOW}🔍 Verifying import...${NC}"
        TABLE_COUNT=$(psql "$SUPABASE_CONNECTION" -t -c "SELECT COUNT(*) FROM information_schema.tables WHERE table_schema = 'public';" 2>/dev/null | tr -d ' ')
        
        if [ "$TABLE_COUNT" -gt 0 ]; then
            echo -e "${GREEN}✅ Verification successful: $TABLE_COUNT tables imported${NC}"
            echo ""
            echo -e "${GREEN}🎉 Migration completed successfully!${NC}"
            echo ""
            echo -e "${YELLOW}📝 Next steps:${NC}"
            echo "1. Update your .env file:"
            echo "   POSTGRES_DATABASE_URL=$SUPABASE_CONNECTION"
            echo ""
            echo "2. Test your backend:"
            echo "   cd backend && go run main.go"
            echo ""
            echo "3. You can now stop Docker PostgreSQL"
            echo ""
            echo -e "${YELLOW}🗑️  Cleanup:${NC}"
            echo "Backup file saved as: roomease_backup.sql"
            echo "Keep this file as a backup until you confirm everything works"
        else
            echo -e "${YELLOW}⚠️  Import completed but no tables found${NC}"
            echo "Check the backup file and try manual import"
        fi
    else
        echo -e "${RED}❌ Import failed${NC}"
        echo "Check the backup file for issues"
    fi
else
    echo -e "${RED}❌ Cannot connect to Supabase${NC}"
    echo "Check your connection string and password"
fi

echo ""
echo -e "${GREEN}🚀 Migration process complete!${NC}"