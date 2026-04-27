#!/bin/bash

echo "🔍 Checking Database for Expenses"
echo "================================="

# Check if we can connect to the database
echo "📡 Checking database connection..."

# You'll need to replace these with your actual database credentials
DB_HOST="localhost"
DB_PORT="5432"
DB_NAME="roomease"
DB_USER="postgres"

echo "Attempting to connect to database: $DB_NAME on $DB_HOST:$DB_PORT"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "❌ psql command not found. Please install PostgreSQL client."
    echo "   On Ubuntu/Debian: sudo apt install postgresql-client"
    echo "   On macOS: brew install postgresql"
    exit 1
fi

echo "📊 Checking expenses table..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT 
    COUNT(*) as total_expenses,
    COUNT(DISTINCT roomspace_id) as unique_roomspaces
FROM expenses;
" 2>/dev/null || echo "❌ Could not connect to database or expenses table doesn't exist"

echo ""
echo "📊 Checking expense_splits table..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT 
    COUNT(*) as total_splits,
    COUNT(DISTINCT expense_id) as expenses_with_splits
FROM expense_splits;
" 2>/dev/null || echo "❌ Could not connect to database or expense_splits table doesn't exist"

echo ""
echo "📊 Recent expenses (last 5)..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT 
    id,
    roomspace_id,
    title,
    amount,
    paid_by,
    created_at
FROM expenses 
ORDER BY created_at DESC 
LIMIT 5;
" 2>/dev/null || echo "❌ Could not query expenses table"

echo ""
echo "📊 Recent expense splits (last 10)..."
psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "
SELECT 
    es.id,
    es.expense_id,
    es.user_uid,
    es.amount,
    e.title as expense_title
FROM expense_splits es
JOIN expenses e ON es.expense_id = e.id
ORDER BY es.id DESC 
LIMIT 10;
" 2>/dev/null || echo "❌ Could not query expense_splits table"

echo ""
echo "🏁 Database check completed"
echo ""
echo "💡 If you see connection errors, make sure:"
echo "   1. PostgreSQL is running"
echo "   2. Database credentials are correct"
echo "   3. Database 'roomease' exists"
echo "   4. You have permission to access the database"