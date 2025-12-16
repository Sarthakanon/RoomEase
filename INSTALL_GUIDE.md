# 📱 RoomEase Installation Guide

## ✅ APK Built Successfully!

Your RoomEase APK has been built and is ready for installation:

**Location:** `build/app/outputs/flutter-apk/app-release.apk`
**Size:** 54.3MB

## 📋 Installation Steps

### Method 1: Direct Installation (Recommended)

1. **Copy APK to your phone:**
   - Connect your phone to computer via USB
   - Copy `app-release.apk` to your phone's Downloads folder
   - Or use cloud storage (Google Drive, etc.) to transfer

2. **Enable Unknown Sources:**
   - Go to **Settings > Security** (or **Settings > Apps & notifications > Special app access**)
   - Find **Install unknown apps** or **Unknown sources**
   - Enable it for your file manager or browser

3. **Install the APK:**
   - Open your file manager
   - Navigate to Downloads folder
   - Tap on `app-release.apk`
   - Follow the installation prompts
   - Tap **Install**

### Method 2: ADB Installation (For Developers)

If you have ADB installed and your phone is connected:

```bash
adb install -r build/app/outputs/flutter-apk/app-release.apk
```

## 🔧 After Installation

### 1. Grant Permissions
When you first open RoomEase:
- **Allow notification access** - Required for payment detection
- **Allow SMS permissions** - For SMS-based payment detection
- **Allow storage permissions** - For app functionality

### 2. Enable Notification Listener
For eSewa payment detection to work:
1. Go to **Settings > Apps & notifications > Special app access**
2. Find **Notification access** or **Device admin apps**
3. Enable **RoomEase**

### 3. Test Payment Detection
1. Open RoomEase
2. Go to **Settings > Payment Notifications**
3. Enable payment detection
4. Send a small payment via eSewa (Rs. 1)
5. Check if RoomEase detects it

## 🐛 Troubleshooting

### "Can't install" or "Install blocked"
- Make sure **Unknown sources** is enabled
- Try installing from a different file manager
- Restart your phone and try again

### "App not installed" error
- Clear storage space (need at least 100MB free)
- Uninstall any previous version of RoomEase first
- Try redownloading the APK file

### Payment detection not working
- Ensure notification access is granted
- Check that eSewa notifications are enabled
- Restart the app after granting permissions

## 📞 Need Help?

If you encounter any issues:
1. Check the app logs in Android Studio or via ADB
2. Ensure all permissions are granted
3. Try reinstalling the app
4. Contact support with error details

## 🎉 Success!

Once installed, RoomEase will automatically detect eSewa payments and prompt you to add them as expenses to your roomspace!