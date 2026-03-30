/// App-wide constants and configuration
class AppConstants {
  // Backend Configuration
  // Production backend URL - UPDATE THIS after Railway deployment
  static const String backendIp = 'your-railway-url.up.railway.app'; // Replace with actual Railway URL
  static const int backendPort = 443; // HTTPS port for production
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // App Info
  static const String appName = 'RoomEase';
  static const String appVersion = '1.0.0';
}
