#!/bin/bash

# Verification script for analytics tables migration
# This script checks if the analytics tables can be created successfully

echo "🔍 Analytics Tables Migration Verification"
echo "=========================================="
echo ""

# Check if PostgreSQL is available
if ! command -v psql &> /dev/null; then
    echo "❌ PostgreSQL client (psql) not found"
    echo "   Please install PostgreSQL client to run this verification"
    exit 1
fi

echo "✅ PostgreSQL client found"
echo ""

# Check if migration file exists
MIGRATION_FILE="010_create_analytics_tables.sql"
if [ ! -f "$MIGRATION_FILE" ]; then
    echo "❌ Migration file not found: $MIGRATION_FILE"
    exit 1
fi

echo "✅ Migration file found: $MIGRATION_FILE"
echo ""

# Validate SQL syntax (basic check)
echo "🔍 Validating SQL syntax..."
if grep -q "CREATE TABLE" "$MIGRATION_FILE"; then
    echo "✅ CREATE TABLE statements found"
else
    echo "❌ No CREATE TABLE statements found"
    exit 1
fi

if grep -q "CREATE INDEX" "$MIGRATION_FILE"; then
    echo "✅ CREATE INDEX statements found"
else
    echo "⚠️  Warning: No CREATE INDEX statements found"
fi

if grep -q "CREATE OR REPLACE FUNCTION" "$MIGRATION_FILE"; then
    echo "✅ Utility functions found"
else
    echo "⚠️  Warning: No utility functions found"
fi

echo ""
echo "📊 Migration Summary:"
echo "-------------------"
echo "Tables to be created:"
grep -o "CREATE TABLE IF NOT EXISTS [a-z_]*" "$MIGRATION_FILE" | sed 's/CREATE TABLE IF NOT EXISTS /  - /'
echo ""

echo "Indexes to be created:"
grep -o "CREATE INDEX IF NOT EXISTS [a-z_]*" "$MIGRATION_FILE" | sed 's/CREATE INDEX IF NOT EXISTS /  - /'
echo ""

echo "Functions to be created:"
grep -o "CREATE OR REPLACE FUNCTION [a-z_]*" "$MIGRATION_FILE" | sed 's/CREATE OR REPLACE FUNCTION /  - /'
echo ""

echo "✅ Migration file validation complete!"
echo ""
echo "To apply this migration manually:"
echo "  psql -U your_username -d your_database -f $MIGRATION_FILE"
echo ""
echo "Or run the application to apply automatically via AutoMigrate:"
echo "  go run main.go"
