# RoomEase Admin Panel

A standalone web-based admin dashboard for managing the RoomEase application. This is completely separate from the user mobile app.

## 🎯 Features

- **Separate Authentication**: Independent login system for administrators
- **User Management**: View, manage, and control user accounts
- **Roomspace Monitoring**: Track all roomspaces and their activities
- **Expense Analytics**: System-wide expense tracking and insights
- **System Health**: Monitor backend services and database
- **Standalone**: Runs independently from the main user app

## 🚀 Quick Start

### Prerequisites

- Flutter SDK (3.0.0 or higher)
- Chrome browser
- Backend server running on `http://localhost:8080`

### Installation

1. Navigate to the admin_web directory:
```bash
cd admin_web
```

2. Install dependencies:
```bash
flutter pub get
```

3. Run the admin panel:

**On Linux/Mac:**
```bash
./run_admin.sh
```

**On Windows:**
```bash
run_admin.bat
```

**Or manually:**
```bash
flutter run -d chrome --web-port=8081
```

The admin panel will open at: `http://localhost:8081`

## 🔐 Admin Login

### Creating Admin Users

You need to create admin users in Firebase with custom claims:

1. Go to Firebase Console → Authentication
2. Add a new user with email/password
3. Get the user's UID
4. Set admin custom claim using Firebase Admin SDK or Firebase CLI:

```javascript
// Using Firebase Admin SDK (Node.js)
admin.auth().setCustomUserClaims(uid, { admin: true });
```

Or using Firebase CLI:
```bash
firebase auth:import admin_users.json
```

### Default Admin Credentials

For development, you can create an admin user:
- Email: `admin@roomease.com`
- Password: `Admin@123` (change this in production!)

## 📁 Project Structure

```
admin_web/
├── lib/
│   ├── main.dart                 # Entry point
│   ├── screens/
│   │   ├── login_screen.dart     # Admin login
│   │   └── dashboard_screen.dart # Main dashboard
│   ├── services/
│   │   ├── auth_service.dart     # Firebase auth
│   │   └── api_service.dart      # Backend API calls
│   └── providers/
│       └── admin_provider.dart   # State management
├── pubspec.yaml                  # Dependencies
├── run_admin.sh                  # Linux/Mac run script
├── run_admin.bat                 # Windows run script
└── README.md                     # This file
```

## 🔧 Configuration

### Firebase Setup

Update `lib/main.dart` with your Firebase config:

```dart
await Firebase.initializeApp(
  options: const FirebaseOptions(
    apiKey: "YOUR_API_KEY",
    authDomain: "YOUR_PROJECT.firebaseapp.com",
    projectId: "YOUR_PROJECT_ID",
    storageBucket: "YOUR_PROJECT.appspot.com",
    messagingSenderId: "YOUR_SENDER_ID",
    appId: "YOUR_APP_ID",
  ),
);
```

### Backend API URL

Update `lib/services/api_service.dart` if your backend runs on a different port:

```dart
static const String baseUrl = 'http://localhost:8080';
```

## 🛠️ Development

### Running in Development Mode

```bash
flutter run -d chrome --web-port=8081
```

### Building for Production

```bash
flutter build web --release
```

The built files will be in `build/web/` directory.

### Deploying

You can deploy the built web app to:
- Firebase Hosting
- Netlify
- Vercel
- Any static web hosting service

Example for Firebase Hosting:
```bash
firebase init hosting
firebase deploy --only hosting
```

## 📊 Admin Features

### Dashboard (Coming Soon)
- System statistics
- User growth charts
- Active roomspaces count
- Total expenses tracked
- Recent activity feed

### User Management (Coming Soon)
- View all users
- Search and filter users
- Enable/disable accounts
- View user activity
- Reset passwords

### Roomspace Management (Coming Soon)
- View all roomspaces
- Monitor roomspace activity
- View members and expenses
- Roomspace analytics

### Expense Tracking (Coming Soon)
- System-wide expense overview
- Category breakdown
- Settlement tracking
- Expense trends

### Analytics (Coming Soon)
- Platform analytics
- User behavior insights
- Financial trends
- ML model performance

## 🔒 Security

### Important Security Notes

1. **Never commit Firebase credentials** to version control
2. **Use environment variables** for sensitive data
3. **Implement proper admin verification** on backend
4. **Use HTTPS** in production
5. **Enable Firebase App Check** for additional security
6. **Set up proper CORS** on backend
7. **Implement rate limiting** on admin endpoints

### Backend Security

Ensure your backend validates admin access:

```go
// Example middleware
func AdminOnly(c *gin.Context) {
    // Verify Firebase token
    // Check custom claims for admin role
    // Return 403 if not admin
}
```

## 🐛 Troubleshooting

### Port Already in Use

If port 8081 is busy, use a different port:
```bash
flutter run -d chrome --web-port=8082
```

### Firebase Connection Issues

1. Check Firebase configuration in `main.dart`
2. Verify Firebase project is active
3. Check browser console for errors

### Backend Connection Issues

1. Ensure backend is running on `http://localhost:8080`
2. Check CORS settings on backend
3. Verify API endpoints are accessible

### Build Issues

```bash
flutter clean
flutter pub get
flutter run -d chrome
```

## 📝 TODO

- [ ] Implement user management screen
- [ ] Add roomspace monitoring
- [ ] Create expense analytics dashboard
- [ ] Add system health monitoring
- [ ] Implement real-time updates
- [ ] Add export functionality
- [ ] Create audit logs
- [ ] Add email notifications
- [ ] Implement dark mode
- [ ] Add multi-language support

## 🤝 Contributing

This is an internal admin tool. Contact the development team for access.

## 📄 License

Proprietary - RoomEase Admin Panel

## 📞 Support

For issues or questions:
- Email: admin@roomease.com
- Internal Slack: #admin-support
