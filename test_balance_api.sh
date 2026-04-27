#!/bin/bash

# Simple test script to verify the balance API returns the correct format
# This script assumes the backend is running on localhost:8080

echo "🧪 Testing Balance API Response Format"
echo "======================================"

# Test endpoint (replace with actual roomspace ID and session)
ROOMSPACE_ID="your-roomspace-id"
SESSION_ID="your-session-id"
BASE_URL="http://localhost:8080"

echo "📡 Testing GET /api/roomspaces/$ROOMSPACE_ID/balances"
echo ""

# Make the API call
response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=$SESSION_ID" \
  "$BASE_URL/api/roomspaces/$ROOMSPACE_ID/balances")

# Extract HTTP status
http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
response_body=$(echo "$response" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $http_status"
echo ""
echo "Response Body:"
echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
echo ""

# Check if response contains the expected fields
if echo "$response_body" | jq -e '.data.you_owe' >/dev/null 2>&1; then
    echo "✅ 'you_owe' field found in response"
else
    echo "❌ 'you_owe' field missing from response"
fi

if echo "$response_body" | jq -e '.data.you_are_owed' >/dev/null 2>&1; then
    echo "✅ 'you_are_owed' field found in response"
else
    echo "❌ 'you_are_owed' field missing from response"
fi

if echo "$response_body" | jq -e '.data.your_balance' >/dev/null 2>&1; then
    echo "✅ 'your_balance' field found in response"
else
    echo "❌ 'your_balance' field missing from response"
fi

echo ""
echo "🏁 Test completed"