#!/bin/bash

echo "🔍 Testing AWS RDS PostgreSQL Connection..."
echo "Database: roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com:5432"
echo "=========================================================="

# Test basic connectivity with timeout
echo ""
echo "1. Testing basic connectivity (10s timeout)..."
if timeout 10 bash -c "</dev/tcp/roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com/5432" 2>/dev/null; then
    echo "✅ Port 5432 is OPEN - Connection successful!"
else
    echo "❌ Port 5432 is CLOSED or FILTERED - Connection failed!"
fi

echo ""
echo "2. Testing with netcat..."
nc -zv -w 10 roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com 5432 2>&1

echo ""
echo "3. Testing DNS resolution..."
if command -v dig &> /dev/null; then
    dig +short roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com
elif command -v host &> /dev/null; then
    host roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com
else
    echo "DNS tools not available, but hostname resolves to: 172.31.31.106"
fi

echo ""
echo "4. Testing PostgreSQL connection..."
if command -v psql &> /dev/null; then
    echo "Attempting PostgreSQL connection (15s timeout)..."
    timeout 15 bash -c 'PGPASSWORD="RoomEase2024!" psql -h roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com -p 5432 -U postgres -d postgres -c "SELECT version();"' 2>&1
    if [ $? -eq 0 ]; then
        echo "✅ PostgreSQL connection successful!"
    else
        echo "❌ PostgreSQL connection failed!"
    fi
else
    echo "psql not installed. Install with: sudo apt-get install postgresql-client"
fi

echo ""
echo "📊 Connection Analysis:"
echo "Your public IP: $(curl -s ifconfig.me 2>/dev/null || echo 'Unable to detect')"
echo "Target IP: 172.31.31.106 (AWS internal IP)"
echo ""

if timeout 10 bash -c "</dev/tcp/roomease-db.cru6oo86256i.eu-north-1.rds.amazonaws.com/5432" 2>/dev/null; then
    echo "🎉 SUCCESS: Database is accessible!"
    echo "✅ You can proceed with migration: ./run_aws_migration.sh"
else
    echo "🚨 FAILED: Database is not accessible!"
    echo ""
    echo "🔧 REQUIRED FIXES:"
    echo "1. AWS Console → RDS → Databases → roomease-db → Modify"
    echo "   ✓ Set 'Public access' to 'Publicly accessible'"
    echo ""
    echo "2. AWS Console → RDS → roomease-db → Connectivity & security"
    echo "   ✓ Click security group link → Edit inbound rules → Add rule:"
    echo "   ✓ Type: PostgreSQL, Port: 5432, Source: 0.0.0.0/0"
    echo ""
    echo "3. Wait 2-3 minutes after changes, then test again"
    echo ""
    echo "💡 Alternative: Your IP is IPv6, try adding IPv6 rule: ::/0"
fi

echo ""