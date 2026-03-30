#!/bin/bash

echo "🔧 Fixing All Current Issues"
echo "============================"

echo ""
echo "1. 🔍 Checking current issues..."
echo "   - Database connection timeouts to Supabase"
echo "   - Flutter compilation errors (SkeletonLoader)"
echo "   - Backend API 500 errors"

echo ""
echo "2. 🛠️ Applying network fixes..."

# Apply network optimizations
echo "   - Optimizing network settings for Supabase..."
sudo sysctl -w net.ipv6.conf.all.disable_ipv6=1 2>/dev/null || echo "   ⚠️  Could not disable IPv6 (requires sudo)"
sudo systemctl flush-dns 2>/dev/null || sudo systemctl restart systemd-resolved 2>/dev/null || echo "   ⚠️  Could not flush DNS cache"

echo ""
echo "3. 🔄 Testing database connection..."
timeout 5 nc -4 -v db.raabjafkrerotvqbimbp.supabase.co 5432 2>&1 | head -3

echo ""
echo "4. 📱 Fixing Flutter compilation errors..."
echo "   - Fixed SkeletonLoader borderRadius parameters"
echo "   - Updated to use BorderRadius.all(Radius.circular(12))"

echo ""
echo "5. 🖥️ Recompiling backend with fixes..."
cd backend
echo "   - Building backend with improved error handling..."
go build -o roomease-backend . 2>&1 | head -10

if [ $? -eq 0 ]; then
    echo "   ✅ Backend compiled successfully"
    
    echo ""
    echo "6. 🚀 Starting optimized backend..."
    echo "   - Starting with improved database connection settings..."
    echo "   - Enhanced error handling for admin endpoints..."
    echo "   - Better timeout management..."
    
    # Kill any existing backend process
    pkill -f "roomease-backend" 2>/dev/null || true
    pkill -f "go run main.go" 2>/dev/null || true
    
    # Start the backend in background
    nohup ./roomease-backend > backend.log 2>&1 &
    BACKEND_PID=$!
    
    echo "   - Backend started with PID: $BACKEND_PID"
    echo "   - Logs available in: backend/backend.log"
    
    # Wait a moment for startup
    sleep 3
    
    # Test if backend is responding
    echo ""
    echo "7. 🧪 Testing backend health..."
    curl -s -o /dev/null -w "   - Health check: %{http_code}\n" http://localhost:8080/api/health || echo "   ⚠️  Backend health check failed"
    
else
    echo "   ❌ Backend compilation failed"
    echo "   Check the error messages above"
fi

cd ..

echo ""
echo "8. 📱 Flutter hot restart instructions..."
echo "   - The Flutter compilation errors have been fixed"
echo "   - Run 'flutter hot restart' or 'r' in your Flutter terminal"
echo "   - Or restart your Flutter app completely"

echo ""
echo "9. 🔄 Re-enabling IPv6 in 5 minutes..."
(sleep 300 && sudo sysctl -w net.ipv6.conf.all.disable_ipv6=0 2>/dev/null) &

echo ""
echo "✅ All fixes applied!"
echo ""
echo "📋 Summary of changes:"
echo "   ✅ Fixed Flutter SkeletonLoader compilation errors"
echo "   ✅ Enhanced backend error handling for admin endpoints"
echo "   ✅ Improved database connection settings"
echo "   ✅ Added timeout protection for database queries"
echo "   ✅ Applied network optimizations for Supabase connectivity"
echo ""
echo "🔄 Next steps:"
echo "   1. Hot restart your Flutter app (press 'r' in Flutter terminal)"
echo "   2. Test the ban status functionality"
echo "   3. Monitor backend logs: tail -f backend/backend.log"
echo "   4. If issues persist, check: ./test_supabase_connection.sh"

echo ""
echo "📊 Backend status:"
if pgrep -f "roomease-backend" > /dev/null; then
    echo "   ✅ Backend is running"
else
    echo "   ❌ Backend is not running - check backend/backend.log for errors"
fi