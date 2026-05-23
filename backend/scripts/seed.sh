#!/bin/bash

# Data Seeding Script for RoomEase
# This script seeds the database with 100 users, roomspaces, and expenses

echo "🌱 RoomEase Data Seeding Script"
echo "================================"
echo ""

# Check if we're in the backend directory
if [ ! -f "main.go" ]; then
    echo "❌ Error: Please run this script from the backend directory"
    echo "   cd backend && ./scripts/seed.sh"
    exit 1
fi

# Check if .env file exists
if [ ! -f ".env" ]; then
    echo "❌ Error: .env file not found"
    echo "   Please create a .env file with DATABASE_URL"
    exit 1
fi

echo "📋 Configuration:"
echo "   - Users to create: 100"
echo "   - Group size: 3-5 users per roomspace"
echo "   - Expenses: 15-30 per roomspace"
echo "   - Personal expenses: 3-8 per user"
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
go run scripts/seed_data.go

if [ $? -eq 0 ]; then
    echo ""
    echo "✅ Data seeding completed successfully!"
    echo ""
    echo "📊 Summary:"
    echo "   - 100 users created"
    echo "   - ~20-33 roomspaces created (groups of 3-5)"
    echo "   - ~300-1000 shared expenses created"
    echo "   - ~300-800 personal expenses created"
    echo ""
    echo "🔍 You can now:"
    echo "   - Login with any user email (format: firstname.lastnameN@roomease.test)"
    echo "   - View roomspaces and expenses in the app"
    echo "   - Test analytics and reporting features"
else
    echo ""
    echo "❌ Data seeding failed!"
    echo "   Check the error messages above"
    exit 1
fi
