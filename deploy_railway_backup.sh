#!/bin/bash

echo "🚀 Railway Deployment - Backup Plan"
echo "=================================="

echo "📦 Installing Railway CLI..."
npm install -g @railway/cli

echo "🔐 Login to Railway..."
railway login

echo "📁 Navigate to backend..."
cd backend

echo "🆕 Initialize Railway project..."
railway init

echo "🗄️ Add PostgreSQL database..."
railway add postgresql

echo "🚀 Deploy backend..."
railway up

echo ""
echo "✅ Railway deployment complete!"
echo ""
echo "📋 Next steps:"
echo "1. Get Railway URL from dashboard"
echo "2. Update Flutter app with Railway URL"
echo "3. Build new APK"
echo ""
echo "💡 Railway provides:"
echo "- ✅ Automatic PostgreSQL database"
echo "- ✅ Automatic HTTPS"
echo "- ✅ No security group issues"
echo "- ✅ Simple deployment"