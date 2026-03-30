#!/bin/bash

# Debug Balance Calculation Script
# This script helps debug balance issues by querying the API

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
API_BASE="http://localhost:8080/api"
TOKEN=""
ROOMSPACE_ID=""
USER_ID=""

# Function to print colored output
print_header() {
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Check if jq is installed
if ! command -v jq &> /dev/null; then
    print_error "jq is not installed. Please install it: sudo apt-get install jq"
    exit 1
fi

# Get parameters
if [ -z "$1" ] || [ -z "$2" ]; then
    echo "Usage: $0 <roomspace_id> <auth_token> [user_id]"
    echo ""
    echo "Example:"
    echo "  $0 3ce5eb29-004e-42ab-9034-5106e627a44a eyJhbGc... 4i9FNTKBwae1soC1qX06fFad4cI2"
    exit 1
fi

ROOMSPACE_ID="$1"
TOKEN="$2"
USER_ID="${3:-}"

print_header "Balance Debugging Tool"
echo "Roomspace ID: $ROOMSPACE_ID"
echo "User ID: ${USER_ID:-<not specified>}"
echo ""

# 1. Get Balance Summary
print_header "1. Balance Summary"
BALANCE_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$API_BASE/roomspaces/$ROOMSPACE_ID/balances")

if echo "$BALANCE_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    print_success "Balance summary retrieved"
    
    # Extract data
    TOTAL_EXPENSES=$(echo "$BALANCE_RESPONSE" | jq -r '.data.total_expenses')
    EXPENSE_COUNT=$(echo "$BALANCE_RESPONSE" | jq -r '.data.expense_count')
    
    echo ""
    print_info "Total Expenses: Rs.$TOTAL_EXPENSES"
    print_info "Expense Count: $EXPENSE_COUNT"
    echo ""
    
    # Show user balances
    echo "User Balances:"
    echo "$BALANCE_RESPONSE" | jq -r '.data.user_balances | to_entries[] | "  \(.key): Rs.\(.value)"'
    echo ""
    
    # Verify sum is zero
    SUM=$(echo "$BALANCE_RESPONSE" | jq '[.data.user_balances[]] | add')
    if [ "$(echo "$SUM < 0.01 && $SUM > -0.01" | bc)" -eq 1 ]; then
        print_success "Balance sum is zero: $SUM (correct!)"
    else
        print_error "Balance sum is NOT zero: $SUM (ERROR!)"
    fi
    echo ""
    
    # Show members with balances
    echo "Members:"
    echo "$BALANCE_RESPONSE" | jq -r '.data.members[] | "  \(.name) (\(.user_id)): Rs.\(.balance // "N/A")"'
    echo ""
    
    # Check if balance is included in members
    HAS_BALANCE=$(echo "$BALANCE_RESPONSE" | jq '.data.members[0] | has("balance")')
    if [ "$HAS_BALANCE" = "true" ]; then
        print_success "Members array includes balance field"
    else
        print_error "Members array MISSING balance field (needs backend update)"
    fi
else
    print_error "Failed to get balance summary"
    echo "$BALANCE_RESPONSE" | jq '.'
fi

echo ""

# 2. Get Settlement Suggestions
print_header "2. Settlement Suggestions"
SUGGESTIONS_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
    "$API_BASE/roomspaces/$ROOMSPACE_ID/settlements/suggestions")

if echo "$SUGGESTIONS_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
    SUGGESTION_COUNT=$(echo "$SUGGESTIONS_RESPONSE" | jq '.data | length')
    
    if [ "$SUGGESTION_COUNT" -gt 0 ]; then
        print_success "Found $SUGGESTION_COUNT settlement suggestion(s)"
        echo ""
        echo "$SUGGESTIONS_RESPONSE" | jq -r '.data[] | "  \(.from_user_name) should pay Rs.\(.amount) to \(.to_user_name)"'
    else
        print_info "No settlement suggestions (all balanced or data issue)"
    fi
else
    print_error "Failed to get settlement suggestions"
    echo "$SUGGESTIONS_RESPONSE" | jq '.'
fi

echo ""

# 3. Get User Balance (if user_id provided)
if [ -n "$USER_ID" ]; then
    print_header "3. User Balance Details"
    USER_BALANCE_RESPONSE=$(curl -s -H "Authorization: Bearer $TOKEN" \
        "$API_BASE/roomspaces/$ROOMSPACE_ID/balances/$USER_ID")
    
    if echo "$USER_BALANCE_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
        print_success "User balance retrieved"
        echo ""
        
        BALANCE=$(echo "$USER_BALANCE_RESPONSE" | jq -r '.data.balance')
        TOTAL_PAID=$(echo "$USER_BALANCE_RESPONSE" | jq -r '.data.total_paid')
        TOTAL_OWED=$(echo "$USER_BALANCE_RESPONSE" | jq -r '.data.total_owed')
        EXPENSE_COUNT=$(echo "$USER_BALANCE_RESPONSE" | jq -r '.data.expense_count')
        
        print_info "Balance: Rs.$BALANCE"
        print_info "Total Paid: Rs.$TOTAL_PAID"
        print_info "Total Owed: Rs.$TOTAL_OWED"
        print_info "Expense Count: $EXPENSE_COUNT"
        echo ""
        
        # Verify calculation
        CALCULATED_BALANCE=$(echo "$TOTAL_PAID - $TOTAL_OWED" | bc)
        if [ "$(echo "$CALCULATED_BALANCE - $BALANCE < 0.01 && $CALCULATED_BALANCE - $BALANCE > -0.01" | bc)" -eq 1 ]; then
            print_success "Balance calculation correct: $TOTAL_PAID - $TOTAL_OWED = $BALANCE"
        else
            print_error "Balance calculation WRONG: $TOTAL_PAID - $TOTAL_OWED = $CALCULATED_BALANCE, but stored as $BALANCE"
        fi
        
        echo ""
        if [ "$(echo "$BALANCE > 0.01" | bc)" -eq 1 ]; then
            print_info "Status: You are OWED Rs.$BALANCE"
        elif [ "$(echo "$BALANCE < -0.01" | bc)" -eq 1 ]; then
            OWED_AMOUNT=$(echo "$BALANCE * -1" | bc)
            print_info "Status: You OWE Rs.$OWED_AMOUNT"
        else
            print_info "Status: All SETTLED UP!"
        fi
    else
        print_error "Failed to get user balance"
        echo "$USER_BALANCE_RESPONSE" | jq '.'
    fi
fi

echo ""

# 4. Refresh Balance Cache
print_header "4. Refresh Balance Cache"
read -p "Do you want to refresh the balance cache? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    REFRESH_RESPONSE=$(curl -s -X POST -H "Authorization: Bearer $TOKEN" \
        "$API_BASE/roomspaces/$ROOMSPACE_ID/balances/refresh")
    
    if echo "$REFRESH_RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
        print_success "Balance cache refreshed successfully"
    else
        print_error "Failed to refresh balance cache"
        echo "$REFRESH_RESPONSE" | jq '.'
    fi
fi

echo ""
print_header "Debug Complete"
