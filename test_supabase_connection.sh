#!/bin/bash

echo "🔍 Testing Supabase Connection Issues"
echo "===================================="

SUPABASE_HOST="db.raabjafkrerotvqbimbp.supabase.co"
SUPABASE_PORT="5432"

echo ""
echo "1. Testing DNS Resolution:"
echo "-------------------------"
nslookup $SUPABASE_HOST

echo ""
echo "2. Testing IPv4 vs IPv6:"
echo "------------------------"
echo "IPv4 addresses:"
dig +short A $SUPABASE_HOST
echo "IPv6 addresses:"
dig +short AAAA $SUPABASE_HOST

echo ""
echo "3. Testing TCP Connection (IPv4):"
echo "---------------------------------"
timeout 10 nc -4 -v $SUPABASE_HOST $SUPABASE_PORT 2>&1

echo ""
echo "4. Testing TCP Connection (IPv6):"
echo "---------------------------------"
timeout 10 nc -6 -v $SUPABASE_HOST $SUPABASE_PORT 2>&1

echo ""
echo "5. Testing with curl (IPv4 only):"
echo "---------------------------------"
curl -4 -v --connect-timeout 10 telnet://$SUPABASE_HOST:$SUPABASE_PORT 2>&1 | head -10

echo ""
echo "6. Testing PostgreSQL Connection:"
echo "---------------------------------"
echo "Attempting to connect to PostgreSQL..."
timeout 15 psql "postgresql://postgres:malaiktha%40123@$SUPABASE_HOST:$SUPABASE_PORT/postgres?sslmode=require&connect_timeout=10" -c "SELECT version();" 2>&1

echo ""
echo "7. Network Route to Supabase:"
echo "----------------------------"
echo "Traceroute to $SUPABASE_HOST (first 10 hops):"
timeout 30 traceroute -m 10 $SUPABASE_HOST 2>&1

echo ""
echo "🏁 Connection test completed!"
echo ""
echo "💡 Recommendations:"
echo "- If IPv6 fails but IPv4 works: Force IPv4 in your connection string"
echo "- If both fail: Check firewall/ISP blocking"
echo "- If connection is slow: Consider using a different region"
echo "- If intermittent: Add retry logic and connection pooling"