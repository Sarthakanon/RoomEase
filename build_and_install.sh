#!/bin/bash

echo "🔨 Building RoomEase APK..."

# Clean previous builds
flutter clean
flutter pub get

# Build release APK
flutter build apk --release

# Check if build was successful
if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Find the APK file
    APK_PATH="build/app/outputs/flutter-apk/app-release.apk"
    
    if [ -f "$APK_PATH" ]; then
        echo "📱 APK created at: $APK_PATH"
        echo "📋 APK size: $(du -h "$APK_PATH" | cut -f1)"
        
        # Try to install via ADB if device is connected
        if command -v adb &> /dev/null; then
            echo "🔍 Checking for connected devices..."
            DEVICES=$(adb devices | grep -v "List of devices" | grep "device$" | wc -l)
            
            if [ $DEVICES -gt 0 ]; then
                echo "📱 Found $DEVICES connected device(s)"
                echo "🚀 Installing APK..."
                adb install -r "$APK_PATH"
                
                if [ $? -eq 0 ]; then
                    echo "✅ Installation successful!"
                    echo "🎉 You can now open RoomEase on your device"
                else
                    echo "❌ Installation failed. Try installing manually:"
                    echo "   1. Copy $APK_PATH to your phone"
                    echo "   2. Enable 'Install from unknown sources' in Settings"
                    echo "   3. Tap the APK file to install"
                fi
            else
                echo "📱 No devices connected via ADB"
                echo "📋 Manual installation steps:"
                echo "   1. Copy $APK_PATH to your phone"
                echo "   2. Enable 'Install from unknown sources' in Settings > Security"
                echo "   3. Use a file manager to find and tap the APK file"
                echo "   4. Follow the installation prompts"
            fi
        else
            echo "📋 ADB not found. Manual installation required:"
            echo "   1. Copy $APK_PATH to your phone"
            echo "   2. Enable 'Install from unknown sources' in Settings"
            echo "   3. Tap the APK file to install"
        fi
    else
        echo "❌ APK file not found at expected location"
    fi
else
    echo "❌ Build failed!"
    exit 1
fi