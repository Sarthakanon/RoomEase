#!/bin/bash

echo "🚀 RoomEase AWS Database Migration Script"
echo "========================================"

# Database connection details
DB_HOST="roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com"
DB_PORT="5432"
DB_USER="postgres"
DB_NAME="postgres"
DB_PASSWORD="RoomEase2024!"

echo ""
echo "📋 Migration Details:"
echo "Host: $DB_HOST"
echo "Port: $DB_PORT"
echo "Database: $DB_NAME"
echo "User: $DB_USER"
echo ""

# Test connection first
echo "🔍 Step 1: Testing database connection..."
if ! nc -zv $DB_HOST $DB_PORT 2>/dev/null; then
    echo "❌ ERROR: Cannot connect to database!"
    echo ""
    echo "🔧 Fix required:"
    echo "1. Go to AWS Console > RDS > Databases > roomease-db"
    echo "2. Click 'Connectivity & security' tab"
    echo "3. Click on the Security Group link"
    echo "4. Edit inbound rules > Add rule:"
    echo "   - Type: PostgreSQL"
    echo "   - Port: 5432"
    echo "   - Source: My IP"
    echo "5. Save rules and try again"
    echo ""
    exit 1
fi

echo "✅ Database connection successful!"
echo ""

# Check if psql is available
if ! command -v psql &> /dev/null; then
    echo "📦 Installing PostgreSQL client..."
    sudo apt-get update
    sudo apt-get install -y postgresql-client
fi

echo "🗄️  Step 2: Running database migration..."
echo "Creating tables and indexes..."

# Run migration
PGPASSWORD="$DB_PASSWORD" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -f migrate-to-aws.sql

if [ $? -eq 0 ]; then
    echo "✅ Database migration completed successfully!"
    echo ""
    echo "📊 Verifying tables..."
    
    # Verify tables were created
    PGPASSWORD="$DB_PASSWORD" psql -h $DB_HOST -p $DB_PORT -U $DB_USER -d $DB_NAME -c "\dt"
    
    echo ""
    echo "🎉 AWS RDS Database is ready!"
    echo ""
    echo "📋 Next steps:"
    echo "1. Deploy backend to AWS App Runner"
    echo "2. Update Flutter app with new backend URL"
    echo "3. Build and test new APK"
    echo ""
    echo "💡 Backend connection string:"
    echo "postgresql://postgres:RoomEase2024%21@roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com:5432/postgres"
    
else
    echo "❌ Migration failed! Check the error messages above."
    exit 1
fi