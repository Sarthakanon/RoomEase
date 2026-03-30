#!/bin/bash

echo "🚀 Starting RoomEase Admin Panel..."
echo ""

# Check if Flutter is installed
if ! command -v flutter &> /dev/null; then
    echo "❌ Flutter is not installed. Please install Flutter first."
    exit 1
fi

# Get dependencies
echo "📦 Getting dependencies..."
flutter pub get

# Run the admin web app
echo "🌐 Launching admin panel on http://localhost:8081"
echo ""
flutter run -d chrome --web-port=8081 --web-hostname=localhost

