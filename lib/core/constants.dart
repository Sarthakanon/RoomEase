/// App-wide constants and configuration
class AppConstants {
  // Backend Configuration
  // Vercel production URL
  static const String backendIp = 'room-ease-r4ie.vercel.app'; // Your deployed Vercel URL
  static const int backendPort = 443; // HTTPS port for production
  
  // Use HTTPS for production
  static String get baseUrl => 'https://$backendIp';
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // App Info
  static const String appName = 'RoomEase';
  static const String appVersion = '1.0.0';
}
