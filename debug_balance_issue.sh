#!/bin/bash

echo "🔍 Debug Balance Issue Script"
echo "============================="

# Check if backend is running
echo "📡 Checking if backend is running..."
if curl -s http://localhost:8080/api/health > /dev/null; then
    echo "✅ Backend is running"
else
    echo "❌ Backend is not running on localhost:8080"
    echo "Please start the backend first"
    exit 1
fi

echo ""
echo "📋 Instructions:"
echo "1. Make sure you're logged in to the app"
echo "2. Note your roomspace ID from the app"
echo "3. Run this script with your session ID and roomspace ID"
echo ""
echo "Usage: $0 <session_id> <roomspace_id>"
echo ""

if [ $# -ne 2 ]; then
    echo "❌ Please provide session ID and roomspace ID"
    exit 1
fi

SESSION_ID="$1"
ROOMSPACE_ID="$2"

echo "🔍 Testing balance API for roomspace: $ROOMSPACE_ID"
echo ""

# Test the balance API
echo "📡 Calling GET /api/roomspaces/$ROOMSPACE_ID/balances"
response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=$SESSION_ID" \
  "http://localhost:8080/api/roomspaces/$ROOMSPACE_ID/balances")

# Extract HTTP status
http_status=$(echo "$response" | grep "HTTP_STATUS:" | cut -d: -f2)
response_body=$(echo "$response" | sed '/HTTP_STATUS:/d')

echo "HTTP Status: $http_status"
echo ""
echo "Response Body:"
echo "$response_body" | jq '.' 2>/dev/null || echo "$response_body"
echo ""

# Also test getting expenses for this roomspace
echo "📡 Calling GET /api/roomspaces/$ROOMSPACE_ID/expenses"
expenses_response=$(curl -s -w "\nHTTP_STATUS:%{http_code}" \
  -H "Content-Type: application/json" \
  -H "Cookie: session_id=$SESSION_ID" \
  "http://localhost:8080/api/roomspaces/$ROOMSPACE_ID/expenses")

expenses_status=$(echo "$expenses_response" | grep "HTTP_STATUS:" | cut -d: -f2)
expenses_body=$(echo "$expenses_response" | sed '/HTTP_STATUS:/d')

echo "Expenses HTTP Status: $expenses_status"
echo ""
echo "Expenses Response:"
echo "$expenses_body" | jq '.data | length' 2>/dev/null && echo "expenses found" || echo "No expenses or error"
echo ""

echo "🏁 Debug completed. Check the backend logs for detailed balance calculation info."