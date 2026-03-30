#!/bin/bash

# 🔧 Update .env file for Supabase connection
echo "🔧 RoomEase Environment Configuration for Supabase"
echo "================================================="

# Get current directory
BACKEND_DIR="backend"

if [ ! -d "$BACKEND_DIR" ]; then
    echo "❌ Backend directory not found. Please run this from the project root."
    exit 1
fi

# Get user input
read -p "Enter your Supabase project reference (from dashboard URL): " SUPABASE_REF
read -s -p "Enter your Supabase database password: " SUPABASE_PASSWORD
echo ""

# Validate inputs
if [ -z "$SUPABASE_REF" ] || [ -z "$SUPABASE_PASSWORD" ]; then
    echo "❌ Both project reference and password are required"
    exit 1
fi

# Build connection string
SUPABASE_CONNECTION="postgresql://postgres:$SUPABASE_PASSWORD@db.$SUPABASE_REF.supabase.co:5432/postgres"

# Update .env file
ENV_FILE="$BACKEND_DIR/.env"

if [ -f "$ENV_FILE" ]; then
    # Backup original .env
    cp "$ENV_FILE" "$ENV_FILE.backup"
    echo "📋 Backed up original .env to .env.backup"
    
    # Update the PostgreSQL URL
    if grep -q "POSTGRES_DATABASE_URL" "$ENV_FILE"; then
        # Replace existing line
        sed -i "s|POSTGRES_DATABASE_URL=.*|POSTGRES_DATABASE_URL=$SUPABASE_CONNECTION|" "$ENV_FILE"
        echo "✅ Updated existing POSTGRES_DATABASE_URL in .env"
    else
        # Add new line
        echo "POSTGRES_DATABASE_URL=$SUPABASE_CONNECTION" >> "$ENV_FILE"
        echo "✅ Added POSTGRES_DATABASE_URL to .env"
    fi
    
    echo ""
    echo "🎉 Environment configuration updated!"
    echo ""
    echo "📝 Your .env now contains:"
    echo "POSTGRES_DATABASE_URL=$SUPABASE_CONNECTION"
    echo ""
    echo "🚀 Next steps:"
    echo "1. Restart your Go backend server"
    echo "2. Test your API endpoints"
    echo "3. You can now stop Docker PostgreSQL"
    
else
    echo "❌ .env file not found in backend directory"
    echo "Please create it manually with:"
    echo "POSTGRES_DATABASE_URL=$SUPABASE_CONNECTION"
fi