#!/bin/bash

echo "🔧 Simple database fix - Starting backend server to auto-create tables..."

# Navigate to backend directory
cd backend

echo "Starting backend server (this will auto-create missing tables)..."
echo "Press Ctrl+C after you see 'Database migrations completed successfully'"
echo ""

# Start the backend server - it will auto-migrate on startup
go run main.go

echo ""
echo "✅ Backend server started and should have created the missing tables."
echo "🚀 You can now restart your Flutter app - the balance API should work correctly."