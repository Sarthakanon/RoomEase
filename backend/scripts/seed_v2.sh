#!/bin/bash

# Data Seeding Script v2 for RoomEase
# This script seeds the database with specific test users and groups

echo "🌱 RoomEase Data Seeding Script v2"
echo "===================================="
echo ""

# Check if we're in the backend directory
if [ ! -f "main.go" ]; then
    echo "❌ Error: Please run this script from the backend directory"
    echo "   cd backend && ./scripts/seed_v2.sh"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found"
    echo "   Please create a .env file with DATABASE_URL"
    exit 1
fi

echo "📋 Configuration:"
echo "   - 6 Roomspaces (groups)"
echo "   - 18 Test users (all PRO plan)"
echo "   - Group sizes: 4, 4, 3, 3, 2, 2 people"
echo "   - 20-30 expenses per roomspace"
echo "   - 5-10 personal expenses per user"
echo "   - Each user pays some expenses"
echo ""

read -p "⚠️  This will add data to your database. Continue? (y/N) " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "❌ Seeding cancelled"
    exit 1
fi

echo ""
echo "🚀 Starting data seeding..."
echo ""

# Run the seeding script
go run scripts/seed_data_v2.go

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Data seeding completed successfully!"
    echo ""
    echo "🔍 You can now:"
    echo "   - Login with any test user email and password"
    echo "   - View roomspaces and expenses in the app"
    echo "   - Test analytics and reporting features"
    echo "   - Test balance calculations with real data"
else
    echo ""
    echo "❌ Data seeding failed!"
    echo "   Check the error messages above"
    exit 1
fi
