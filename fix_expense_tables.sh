#!/bin/bash

echo "🔧 Fixing expense tables in database..."

# Navigate to backend directory
cd backend

# Run the migration script
echo "Running expense table migration..."
go run cmd/ensure_expense_tables.go

if [ $? -eq 0 ]; then
    echo "✅ Expense tables fixed successfully!"
    echo ""
    echo "🚀 You can now restart your Flutter app - the balance API should work correctly."
    echo ""
    echo "To restart the backend server:"
    echo "  cd backend && go run main.go"
    echo ""
    echo "To restart the Flutter app:"
    echo "  flutter run"
else
    echo "❌ Failed to fix expense tables. Please check the error messages above."
    exit 1
fi