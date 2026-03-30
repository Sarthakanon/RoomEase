import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../lib/services/ban_monitoring_service.dart';
import '../../lib/services/api_service.dart';

// Generate mocks
@GenerateMocks([ApiService, FirebaseAuth, User])
import 'ban_monitoring_service_test.mocks.dart';

void main() {
  group('BanMonitoringService', () {
    late BanMonitoringService banMonitoringService;
    late MockApiService mockApiService;
    late MockFirebaseAuth mockFirebaseAuth;
    late MockUser mockUser;

    setUp(() {
      banMonitoringService = BanMonitoringService();
      mockApiService = MockApiService();
      mockFirebaseAuth = MockFirebaseAuth();
      mockUser = MockUser();
    });

    tearDown(() {
      banMonitoringService.stopMonitoring();
      banMonitoringService.dispose();
    });

    test('should start monitoring when user is logged in', () {
      // Arrange
      when(mockUser.uid).thenReturn('test-user-id');
      
      // Act
      banMonitoringService.startMonitoring();
      
      // Assert
      expect(banMonitoringService._isMonitoring, true);
    });

    test('should stop monitoring when requested', () {
      // Arrange
      banMonitoringService.startMonitoring();
      
      // Act
      banMonitoringService.stopMonitoring();
      
      // Assert
      expect(banMonitoringService._isMonitoring, false);
    });

    test('should emit ban notification when user is banned', () async {
      // Arrange
      const testReason = 'Test ban reason';
      bool banNotificationReceived = false;
      String? receivedReason;

      banMonitoringService.banNotificationStream.listen((reason) {
        banNotificationReceived = true;
        receivedReason = reason;
      });

      // Act
      banMonitoringService._notifyBanDetected(testReason);

      // Wait for stream to emit
      await Future.delayed(const Duration(milliseconds: 100));

      // Assert
      expect(banNotificationReceived, true);
      expect(receivedReason, testReason);
    });

    test('should handle API errors gracefully during ban check', () async {
      // Arrange
      when(mockApiService.get(any)).thenThrow(Exception('Network error'));
      
      // Act & Assert - Should not throw
      expect(() => banMonitoringService._checkBanStatus('test-user-id'), 
             returnsNormally);
    });
  });
}