#!/bin/bash

# 🚀 Complete Supabase Setup for RoomEase
echo "🚀 Completing Supabase Setup for RoomEase"
echo "========================================"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${YELLOW}📋 Your Supabase connection string:${NC}"
echo "postgresql://postgres:[YOUR-PASSWORD]@db.raabjafkrerotvqbimbp.supabase.co:5432/postgres"
echo ""

# Get the actual password
read -s -p "🔑 Enter your Supabase database password: " SUPABASE_PASSWORD
echo ""

if [ -z "$SUPABASE_PASSWORD" ]; then
    echo -e "${RED}❌ Password is required${NC}"
    exit 1
fi

# Build the complete connection string
COMPLETE_CONNECTION="postgresql://postgres:$SUPABASE_PASSWORD@db.raabjafkrerotvqbimbp.supabase.co:5432/postgres"

# Update the .env file
ENV_FILE="backend/.env"

if [ -f "$ENV_FILE" ]; then
    # Replace the placeholder with actual password
    sed -i "s|postgresql://postgres:\[YOUR-PASSWORD\]@db.raabjafkrerotvqbimbp.supabase.co:5432/postgres|$COMPLETE_CONNECTION|g" "$ENV_FILE"
    
    echo -e "${GREEN}✅ Updated .env file with your Supabase connection${NC}"
    echo ""
    
    echo -e "${YELLOW}🔄 Next steps:${NC}"
    echo "1. Choose migration option:"
    echo ""
    echo -e "${YELLOW}   Option A: Migrate existing data from Docker${NC}"
    echo "   ./migrate_to_supabase.sh"
    echo ""
    echo -e "${YELLOW}   Option B: Start fresh (lose existing data)${NC}"
    echo "   - Stop Docker PostgreSQL"
    echo "   - Start your Go backend"
    echo "   - Backend will create empty tables"
    echo ""
    
    echo -e "${YELLOW}2. Test the connection:${NC}"
    echo "   cd backend && go run main.go"
    echo ""
    
    echo -e "${GREEN}🎉 Configuration complete!${NC}"
    echo "Your RoomEase backend is now configured to use Supabase!"
    
else
    echo -e "${RED}❌ .env file not found in backend directory${NC}"
    echo "Please make sure you're running this from the project root directory"
fi