#!/bin/bash

# Verification script for balance tables migration
# Run this after applying migration 011

echo "=========================================="
echo "Balance Tables Schema Verification"
echo "=========================================="
echo ""

# Database connection details (update as needed)
DB_HOST="${DB_HOST:-localhost}"
DB_PORT="${DB_PORT:-5432}"
DB_NAME="${DB_NAME:-roomease}"
DB_USER="${DB_USER:-postgres}"

# Function to run SQL query
run_query() {
    PGPASSWORD=$DB_PASSWORD psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -t -c "$1"
}

echo "1. Checking if user_balances table exists..."
TABLE_EXISTS=$(run_query "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'user_balances');")
if [[ $TABLE_EXISTS == *"t"* ]]; then
    echo "   ✓ user_balances table exists"
else
    echo "   ✗ user_balances table NOT found"
    exit 1
fi

echo ""
echo "2. Checking if settlements table exists..."
TABLE_EXISTS=$(run_query "SELECT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'settlements');")
if [[ $TABLE_EXISTS == *"t"* ]]; then
    echo "   ✓ settlements table exists"
else
    echo "   ✗ settlements table NOT found"
    exit 1
fi

echo ""
echo "3. Verifying user_balances columns..."
COLUMNS=$(run_query "SELECT column_name FROM information_schema.columns WHERE table_name = 'user_balances' ORDER BY ordinal_position;")
echo "$COLUMNS" | while read -r col; do
    if [ ! -z "$col" ]; then
        echo "   - $col"
    fi
done

echo ""
echo "4. Verifying settlements columns..."
COLUMNS=$(run_query "SELECT column_name FROM information_schema.columns WHERE table_name = 'settlements' ORDER BY ordinal_position;")
echo "$COLUMNS" | while read -r col; do
    if [ ! -z "$col" ]; then
        echo "   - $col"
    fi
done

echo ""
echo "5. Checking indexes..."
INDEXES=$(run_query "SELECT indexname FROM pg_indexes WHERE tablename IN ('user_balances', 'settlements') ORDER BY indexname;")
echo "$INDEXES" | while read -r idx; do
    if [ ! -z "$idx" ]; then
        echo "   ✓ $idx"
    fi
done

echo ""
echo "6. Checking foreign key constraints..."
CONSTRAINTS=$(run_query "SELECT constraint_name, table_name FROM information_schema.table_constraints WHERE table_name IN ('user_balances', 'settlements') AND constraint_type = 'FOREIGN KEY';")
echo "$CONSTRAINTS" | while read -r constraint; do
    if [ ! -z "$constraint" ]; then
        echo "   ✓ $constraint"
    fi
done

echo ""
echo "7. Testing insert into user_balances (will rollback)..."
run_query "BEGIN; INSERT INTO user_balances (user_id, roomspace_id, balance) VALUES ('test_user', (SELECT id FROM roomspaces LIMIT 1), 100.00); ROLLBACK;" > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "   ✓ Insert test passed"
else
    echo "   ✗ Insert test failed"
fi

echo ""
echo "8. Testing unique constraint on user_balances..."
run_query "BEGIN; INSERT INTO user_balances (user_id, roomspace_id, balance) VALUES ('test_user', (SELECT id FROM roomspaces LIMIT 1), 100.00); INSERT INTO user_balances (user_id, roomspace_id, balance) VALUES ('test_user', (SELECT id FROM roomspaces LIMIT 1), 200.00); ROLLBACK;" > /dev/null 2>&1
if [ $? -ne 0 ]; then
    echo "   ✓ Unique constraint working"
else
    echo "   ✗ Unique constraint NOT working"
fi

echo ""
echo "=========================================="
echo "Verification Complete!"
echo "=========================================="
