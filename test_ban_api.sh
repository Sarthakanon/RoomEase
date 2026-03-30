#!/bin/bash

# Test script for ban system
echo "🧪 Testing Ban System API"

# Configuration
BACKEND_URL="http://localhost:8080"
TEST_USER_ID="test-user-firebase-uid"  # Replace with actual Firebase UID

echo "📋 Step 1: Check current user status"
curl -s "$BACKEND_URL/api/admin/users/$TEST_USER_ID/ban-status" | jq '.'

echo -e "\n📋 Step 2: Ban the user"
curl -s -X POST "$BACKEND_URL/api/admin/users/$TEST_USER_ID/ban" \
  -H "Content-Type: application/json" \
  -d '{"reason": "Testing ban system"}' | jq '.'

echo -e "\n📋 Step 3: Check user status after ban"
curl -s "$BACKEND_URL/api/admin/users/$TEST_USER_ID/ban-status" | jq '.'

echo -e "\n📋 Step 4: Test protected endpoint (should return ban error)"
echo "Note: This requires a valid session cookie from the mobile app"
echo "Try making an API call from the mobile app now..."

echo -e "\n📋 Step 5: Unban the user"
curl -s -X POST "$BACKEND_URL/api/admin/users/$TEST_USER_ID/unban" | jq '.'

echo -e "\n📋 Step 6: Check user status after unban"
curl -s "$BACKEND_URL/api/admin/users/$TEST_USER_ID/ban-status" | jq '.'

echo -e "\n✅ Test completed!"
echo "Now test with the mobile app:"
echo "1. Login to mobile app"
echo "2. Run: ./test_ban_api.sh (to ban user)"
echo "3. Try any action in mobile app"
echo "4. Should see ban dialog immediately"