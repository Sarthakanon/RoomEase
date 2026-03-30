#!/bin/bash

echo "🚀 RoomEase Admin Panel - Quick Setup"
echo "======================================"
echo ""

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

echo -e "${YELLOW}Step 1: Create Admin User in Firebase${NC}"
echo "----------------------------------------"
echo "1. Go to: https://console.firebase.google.com/"
echo "2. Select your project"
echo "3. Click 'Authentication' → 'Users' → 'Add User'"
echo "4. Enter:"
echo "   Email: admin@roomease.com"
echo "   Password: Admin@123"
echo ""
read -p "Press Enter when you've created the admin user..."

echo ""
echo -e "${YELLOW}Step 2: Update Firebase Config${NC}"
echo "----------------------------------------"
echo "Edit: admin_web/lib/main.dart"
echo "Copy Firebase config from your main app's lib/firebase_options.dart"
echo ""
read -p "Press Enter when you've updated the config..."

echo ""
echo -e "${YELLOW}Step 3: Install Dependencies${NC}"
echo "----------------------------------------"
flutter pub get

echo ""
echo -e "${GREEN}✅ Setup Complete!${NC}"
echo ""
echo "To start the admin panel, run:"
echo "  ./run_admin.sh"
echo ""
echo "Then login with:"
echo "  Email: admin@roomease.com"
echo "  Password: Admin@123"
echo ""
echo -e "${RED}⚠️  Remember to change the password in production!${NC}"
