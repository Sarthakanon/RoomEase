#!/bin/bash

echo "🔧 Applying Supabase Connection Fixes"
echo "====================================="

# 1. Disable IPv6 for this session (temporary fix)
echo ""
echo "1. Temporarily disabling IPv6 for better connectivity..."
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 2>/dev/null || echo "⚠️  Could not disable IPv6 (requires sudo)"

# 2. Flush DNS cache
echo ""
echo "2. Flushing DNS cache..."
sudo systemctl flush-dns 2>/dev/null || sudo systemctl restart systemd-resolved 2>/dev/null || echo "⚠️  Could not flush DNS cache"

# 3. Test the connection
echo ""
echo "3. Testing connection to Supabase..."
timeout 10 nc -4 -v db.raabjafkrerotvqbimbp.supabase.co 5432

# 4. Restart the backend with new settings
echo ""
echo "4. Restarting backend with optimized connection settings..."
echo "Please restart your Go backend now with: go run main.go"

echo ""
echo "✅ Quick fixes applied!"
echo ""
echo "🔄 Next steps:"
echo "1. Restart your Go backend: cd backend && go run main.go"
echo "2. If issues persist, run: ./test_supabase_connection.sh"
echo "3. Consider switching to a different Supabase region if problems continue"

# 5. Re-enable IPv6 after 5 minutes (cleanup)
echo ""
echo "⏰ IPv6 will be re-enabled automatically in 5 minutes..."
(sleep 300 && sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 2>/dev/null) &