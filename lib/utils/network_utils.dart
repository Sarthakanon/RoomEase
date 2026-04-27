import 'dart:io';
import 'package:flutter/foundation.dart';

/// Utility class for network-related operations
class NetworkUtils {
  /// Check if the backend server is reachable
  static Future<bool> isBackendReachable(String host, int port) async {
    try {
      debugPrint('🌐 Testing connection to $host:$port...');
      
      final socket = await Socket.connect(
        host,
        port,
        timeout: const Duration(seconds: 5),
      );
      
      await socket.close();
      debugPrint('✅ Backend is reachable at $host:$port');
      return true;
    } catch (e) {
      debugPrint('❌ Backend not reachable at $host:$port - $e');
      return false;
    }
  }

  /// Get current device IP address
  static Future<String?> getDeviceIP() async {
    try {
      final interfaces = await NetworkInterface.list();
      
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (address.type == InternetAddressType.IPv4 && 
              !address.isLoopback &&
              address.address.startsWith('192.168.')) {
            debugPrint('📱 Device IP: ${address.address}');
            return address.address;
          }
        }
      }
      
      return null;
    } catch (e) {
      debugPrint('❌ Error getting device IP: $e');
      return null;
    }
  }

  /// Get suggested backend URLs to try
  static List<String> getSuggestedBackendUrls(int port) {
    return [
      'http://192.168.18.13:$port', // Current configured IP
      'http://192.168.1.100:$port', // Common router IP range
      'http://10.0.2.2:$port',      // Android emulator host
      'http://localhost:$port',     // Local development
    ];
  }

  /// Test multiple backend URLs and return the first working one
  static Future<String?> findWorkingBackendUrl(int port) async {
    final urls = getSuggestedBackendUrls(port);
    
    for (final url in urls) {
      final uri = Uri.parse(url);
      final isReachable = await isBackendReachable(uri.host, uri.port);
      
      if (isReachable) {
        debugPrint('✅ Found working backend URL: $url');
        return url;
      }
    }
    
    debugPrint('❌ No working backend URL found');
    return null;
  }
}