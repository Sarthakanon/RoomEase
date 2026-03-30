#!/bin/bash

# 🚀 RoomEase Database Migration to Supabase
# This script helps migrate your local PostgreSQL to Supabase

echo "🚀 RoomEase Database Migration to Supabase"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required tools are installed
command -v docker >/dev/null 2>&1 || { echo -e "${RED}❌ Docker is required but not installed.${NC}" >&2; exit 1; }
command -v psql >/dev/null 2>&1 || { echo -e "${RED}❌ psql is required but not installed.${NC}" >&2; exit 1; }

echo -e "${YELLOW}📋 Before running this script, make sure you have:${NC}"
echo "1. Created a Supabase project"
echo "2. Noted down your Supabase connection details"
echo "3. Your local Docker PostgreSQL is running"
echo ""

# Get user input
read -p "Enter your Docker PostgreSQL container name (default: roomease-pg): " CONTAINER_NAME
CONTAINER_NAME=${CONTAINER_NAME:-roomease-pg}

read -p "Enter your local database name (default: roomease): " LOCAL_DB
LOCAL_DB=${LOCAL_DB:-roomease}

read -p "Enter your Supabase project reference (from URL): " SUPABASE_REF
read -s -p "Enter your Supabase database password: " SUPABASE_PASSWORD
echo ""

# Validate inputs
if [ -z "$SUPABASE_REF" ] || [ -z "$SUPABASE_PASSWORD" ]; then
    echo -e "${RED}❌ Supabase project reference and password are required${NC}"
    exit 1
fi

# Build connection strings
LOCAL_CONNECTION="postgresql://postgres:postgres@localhost:5432/$LOCAL_DB"
SUPABASE_CONNECTION="postgresql://postgres:$SUPABASE_PASSWORD@db.$SUPABASE_REF.supabase.co:5432/postgres"

echo -e "${YELLOW}🔄 Starting migration process...${NC}"

# Step 1: Create backup from local database
echo -e "${YELLOW}📦 Creating backup from local database...${NC}"
docker exec -t $CONTAINER_NAME pg_dump -U postgres $LOCAL_DB > roomease_backup.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Backup created successfully${NC}"
else
    echo -e "${RED}❌ Failed to create backup${NC}"
    exit 1
fi

# Step 2: Clean the backup file (remove Docker-specific issues)
echo -e "${YELLOW}🧹 Cleaning backup file...${NC}"
sed -i 's/OWNER TO postgres;//g' roomease_backup.sql
sed -i '/^SET /d' roomease_backup.sql

# Step 3: Import to Supabase
echo -e "${YELLOW}📤 Importing to Supabase...${NC}"
psql "$SUPABASE_CONNECTION" < roomease_backup.sql

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Migration completed successfully!${NC}"
    echo ""
    echo -e "${GREEN}🎉 Your database is now hosted on Supabase!${NC}"
    echo ""
    echo -e "${YELLOW}📝 Next steps:${NC}"
    echo "1. Update your .env file with the new connection string:"
    echo "   POSTGRES_DATABASE_URL=$SUPABASE_CONNECTION"
    echo ""
    echo "2. Test your backend connection"
    echo "3. You can now stop your local Docker PostgreSQL"
    echo ""
    echo -e "${YELLOW}🗑️  Cleanup:${NC}"
    echo "The backup file 'roomease_backup.sql' has been created."
    echo "You can delete it after confirming everything works."
else
    echo -e "${RED}❌ Migration failed${NC}"
    echo "Please check the error messages above and try again."
    exit 1
fi

echo ""
echo -e "${GREEN}🚀 Migration complete! Your RoomEase database is now cloud-hosted!${NC}"