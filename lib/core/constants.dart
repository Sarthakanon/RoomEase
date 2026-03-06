/// App-wide constants and configuration
class AppConstants {
  // Backend Configuration
  // Update this IP address when switching networks
  static const String backendIp = '10.64.101.246'; // Your backend server IP
  static const int backendPort = 8080;
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // App Info
  static const String appName = 'RoomEase';
  static const String appVersion = '1.0.0';
}
