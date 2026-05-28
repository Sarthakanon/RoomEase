/// App-wide constants and configuration
class AppConstants {
  // Backend Configuration
  // Production backend URL (Render) - temporarily disabled for local development.
  // static const String backendBaseUrl = 'https://roomease-backend-80x8.onrender.com';
  // Android emulator must use 10.0.2.2 to reach host machine localhost.
  static const String backendBaseUrl = 'http://192.168.1.70:8080';

  // Local backend host/port (used by compatibility code paths and settings UI)
  static const String backendIp = '192.168.1.70';
  static const int backendPort = 8080;
  
  // Default backend IP for fallback
  static const String defaultBackendIp = '192.168.1.70';
  
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
