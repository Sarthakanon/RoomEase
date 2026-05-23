/// App-wide constants and configuration
class AppConstants {
  // Backend Configuration
  // Use actual local IP address for better connectivity
  static const String backendIp = '192.168.1.89'; // Your local IP address
  static const int backendPort = 8080; // HTTP port for local development
  
  // Default backend IP for fallback
  static const String defaultBackendIp = '192.168.1.89';
  
  // Timeout settings
  static const Duration connectTimeout = Duration(seconds: 10);
  static const Duration receiveTimeout = Duration(seconds: 10);
  
  // App Info
  static const String appName = 'RoomEase';
  static const String appVersion = '1.0.0';

  // Cloudinary (unsigned upload preset flow)
  static const String cloudinaryCloudName = 'dzaakz1ir';
  static const String cloudinaryUploadPreset = 'roomease_qr';
  static const String cloudinaryFolder = 'roomease/qr';
  
  // Backend IP management methods
  static Future<String> getBackendIp() async {
    // For now, return the static IP. In the future, this could read from SharedPreferences
    return backendIp;
  }
}
