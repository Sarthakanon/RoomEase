/// App-wide constants and configuration
class AppConstants {
  // Backend Configuration
  // Production backend URL (update after deployment)
  static const String backendIp = 'roomease-backend.onrender.com'; // Your deployed backend URL
  static const int backendPort = 443; // HTTPS port for production
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // App Info
  static const String appName = 'RoomEase';
  static const String appVersion = '1.0.0';
}
