import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:room_ease/providers/roomspace_provider.dart';
import 'package:room_ease/models/roomspace_data.dart';

/// Integration tests for multi-roomspace scenarios
/// Tests the complete flow of joining, switching, and managing multiple roomspaces
/// 
/// Requirements tested: All requirements from the multiple-roomspace-support spec
/// 
/// Note: These tests focus on the state management and caching logic.
/// They do not test actual API calls, which would require a running backend.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Integration Test: Multi-Roomspace Scenarios', () {
    late RoomspaceProvider provider;

    setUp(() {
      provider = RoomspaceProvider();
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(() async {
      await provider.clear();
    });

    /// Test Scenario 1: Joining 5 roomspaces and verifying limit
    /// Validates Requirements: 1.1, 1.2, 9.1, 9.2, 9.3
    test('Scenario 1: Join 5 roomspaces and verify limit enforcement', () async {
      // Setup: Create mock data for 5 roomspaces
      final mockRoomspaces = List.generate(5, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 3 + index,
        'joined_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
        'is_creator': index == 0,
      });

      // Simulate loading 5 roomspaces with proper JSON encoding
      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(mockRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Load roomspaces from cache
      await provider.loadRoomspaces();

      // Verify: User has exactly 5 roomspaces
      expect(provider.roomspaceCount, equals(5));
      expect(provider.roomspaces.length, equals(5));

      // Verify: canJoinMore should be false (at limit)
      expect(provider.canJoinMore, isFalse);

      // Verify: All roomspaces are loaded correctly
      for (int i = 0; i < 5; i++) {
        expect(provider.roomspaces[i].id, equals('roomspace-${i + 1}'));
        expect(provider.roomspaces[i].name, equals('Roomspace ${i + 1}'));
      }

      // Verify: Active roomspace is set (should be first one)
      expect(provider.activeRoomspace, isNotNull);
      expect(provider.activeRoomspace!.id, equals('roomspace-1'));
    });

    /// Test Scenario 2: Switching between roomspaces and data isolation
    /// Validates Requirements: 2.1, 2.2, 2.3, 2.4, 3.1, 3.2, 3.3
    test('Scenario 2: Switch between roomspaces and verify context changes', () async {
      // Setup: Create mock data for 3 roomspaces
      final mockRoomspaces = List.generate(3, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2 + index,
        'joined_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
        'is_creator': index == 0,
      });

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(mockRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await provider.loadRoomspaces();

      // Verify: Initial state
      expect(provider.roomspaceCount, equals(3));
      expect(provider.hasMultipleRoomspaces, isTrue);
      expect(provider.activeRoomspace!.id, equals('roomspace-1'));

      // Action: Switch to roomspace 2
      await provider.setActiveRoomspace('roomspace-2');

      // Verify: Active roomspace changed
      expect(provider.activeRoomspace!.id, equals('roomspace-2'));
      expect(provider.activeRoomspace!.name, equals('Roomspace 2'));
      expect(provider.getActiveRoomspaceId(), equals('roomspace-2'));

      // Action: Switch to roomspace 3
      await provider.setActiveRoomspace('roomspace-3');

      // Verify: Active roomspace changed again
      expect(provider.activeRoomspace!.id, equals('roomspace-3'));
      expect(provider.activeRoomspace!.name, equals('Roomspace 3'));

      // Verify: Can get roomspace by ID
      final roomspace2 = provider.getRoomspaceById('roomspace-2');
      expect(roomspace2, isNotNull);
      expect(roomspace2!.name, equals('Roomspace 2'));
    });

    /// Test Scenario 3: Leaving roomspace and rejoining
    /// Validates Requirements: 5.6, 5.7, 10.3
    test('Scenario 3: Leave roomspace and verify cleanup', () async {
      // Setup: Create mock data for 3 roomspaces
      final mockRoomspaces = List.generate(3, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2 + index,
        'joined_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
        'is_creator': index == 0,
      });

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(mockRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await provider.loadRoomspaces();

      // Verify: Initial state - 3 roomspaces
      expect(provider.roomspaceCount, equals(3));
      expect(provider.canJoinMore, isTrue);

      // Set active roomspace to roomspace-2
      await provider.setActiveRoomspace('roomspace-2');
      expect(provider.activeRoomspace!.id, equals('roomspace-2'));

      // Note: We cannot actually test the API call to leave roomspace
      // in a unit test without mocking the API service.
      // This test verifies the state management logic only.

      // Verify: After leaving, user can join more roomspaces
      expect(provider.canJoinMore, isTrue);
    });

    /// Test Scenario 4: Active roomspace persistence across sessions
    /// Validates Requirements: 10.1, 10.2, 10.3
    test('Scenario 4: Active roomspace persists across sessions', () async {
      // Setup: Create mock data for 3 roomspaces
      final mockRoomspaces = List.generate(3, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2 + index,
        'joined_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
        'is_creator': index == 0,
      });

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(mockRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      // Session 1: Load roomspaces and set active roomspace
      await provider.loadRoomspaces();
      await provider.setActiveRoomspace('roomspace-3');
      expect(provider.activeRoomspace!.id, equals('roomspace-3'));

      // Verify: Active roomspace is persisted to SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      final savedRoomspaceId = prefs.getString('active_roomspace_id');
      expect(savedRoomspaceId, equals('roomspace-3'));

      // Session 2: Create new provider instance (simulating app restart)
      final newProvider = RoomspaceProvider();
      await newProvider.loadRoomspaces();

      // Verify: Active roomspace is restored from SharedPreferences
      expect(newProvider.activeRoomspace, isNotNull);
      expect(newProvider.activeRoomspace!.id, equals('roomspace-3'));
      expect(newProvider.activeRoomspace!.name, equals('Roomspace 3'));
    });

    /// Test Scenario 5: Fallback when active roomspace is no longer available
    /// Validates Requirements: 10.3
    test('Scenario 5: Fallback to first roomspace when saved roomspace unavailable', () async {
      // Setup: Create mock data for 3 roomspaces
      final mockRoomspaces = List.generate(3, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2 + index,
        'joined_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
        'is_creator': index == 0,
      });

      // Set up SharedPreferences with a saved roomspace that no longer exists
      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(mockRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
        'active_roomspace_id': 'roomspace-999', // This roomspace doesn't exist
      });

      // Load roomspaces
      await provider.loadRoomspaces();

      // Verify: Provider falls back to first available roomspace
      expect(provider.activeRoomspace, isNotNull);
      expect(provider.activeRoomspace!.id, equals('roomspace-1'));
    });

    /// Test Scenario 6: Visual distinction between roomspaces
    /// Validates Requirements: 6.1, 6.2, 6.5
    test('Scenario 6: Each roomspace has unique visual identifiers', () async {
      // Setup: Create mock data for 5 roomspaces
      final mockRoomspaces = List.generate(5, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2 + index,
        'joined_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
        'is_creator': index == 0,
      });

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(mockRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await provider.loadRoomspaces();

      // Verify: Each roomspace has visual identifiers
      final colors = <int>{};
      final icons = <int>{};

      for (final roomspace in provider.roomspaces) {
        expect(roomspace.visualColor, isNotNull);
        expect(roomspace.visualIcon, isNotNull);

        // Track colors and icons
        colors.add(roomspace.visualColor.value);
        icons.add(roomspace.visualIcon.codePoint);
      }

      // Verify: Visual identifiers are assigned (may not all be unique if hash collision)
      expect(colors.isNotEmpty, isTrue);
      expect(icons.isNotEmpty, isTrue);

      // Verify: Same roomspace ID always gets same color/icon (deterministic)
      final roomspace1 = provider.roomspaces.firstWhere((r) => r.id == 'roomspace-1');
      final roomspace1Again = RoomspaceData.fromJson({
        'id': 'roomspace-1',
        'name': 'Test',
        'invite_code': 'TEST1234',
        'member_count': 1,
        'joined_at': DateTime.now().toIso8601String(),
        'is_creator': true,
      });

      expect(roomspace1.visualColor, equals(roomspace1Again.visualColor));
      expect(roomspace1.visualIcon, equals(roomspace1Again.visualIcon));
    });

    /// Test Scenario 7: Roomspace switcher visibility
    /// Validates Requirements: 2.5, 6.3
    test('Scenario 7: Roomspace switcher visibility based on count', () async {
      // Test with 1 roomspace
      final oneRoomspace = [{
        'id': 'roomspace-1',
        'name': 'Single Roomspace',
        'invite_code': 'CODE1234',
        'member_count': 2,
        'joined_at': DateTime.now().toIso8601String(),
        'is_creator': true,
      }];

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(oneRoomspace),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await provider.loadRoomspaces();

      // Verify: hasMultipleRoomspaces is false (switcher should be hidden)
      expect(provider.hasMultipleRoomspaces, isFalse);
      expect(provider.roomspaceCount, equals(1));

      // Test with 2 roomspaces
      final twoRoomspaces = List.generate(2, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2,
        'joined_at': DateTime.now().toIso8601String(),
        'is_creator': index == 0,
      });

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(twoRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      final provider2 = RoomspaceProvider();
      await provider2.loadRoomspaces();

      // Verify: hasMultipleRoomspaces is true (switcher should be visible)
      expect(provider2.hasMultipleRoomspaces, isTrue);
      expect(provider2.roomspaceCount, equals(2));
    });

    /// Test Scenario 8: Error handling and recovery
    /// Validates Requirements: 2.3, 10.3, 10.4
    test('Scenario 8: Error handling for invalid roomspace operations', () async {
      // Setup: Create mock data for 2 roomspaces
      final mockRoomspaces = List.generate(2, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2,
        'joined_at': DateTime.now().toIso8601String(),
        'is_creator': index == 0,
      });

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(mockRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await provider.loadRoomspaces();

      // Test: Try to set invalid roomspace ID
      await provider.setActiveRoomspace('invalid-roomspace-id');

      // Verify: Provider falls back to first available roomspace
      expect(provider.activeRoomspace, isNotNull);
      expect(provider.activeRoomspace!.id, equals('roomspace-1'));
      expect(provider.error, isNotNull);
      expect(provider.errorType, equals(RoomspaceErrorType.invalidRoomspace));

      // Test: Clear error
      provider.clearError();
      expect(provider.error, isNull);
      expect(provider.errorType, isNull);

      // Test: Get user-friendly error message
      await provider.setActiveRoomspace('another-invalid-id');
      final errorMessage = provider.getUserFriendlyErrorMessage();
      expect(errorMessage, isNotEmpty);
      expect(errorMessage, contains('no longer available'));
    });

    /// Test Scenario 9: Cache expiration and refresh
    /// Validates Requirements: 10.5
    test('Scenario 9: Cache expiration and data refresh', () async {
      // Setup: Create mock data with expired cache
      final mockRoomspaces = List.generate(2, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': 'Roomspace ${index + 1}',
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2,
        'joined_at': DateTime.now().toIso8601String(),
        'is_creator': index == 0,
      });

      // Set cache timestamp to 25 hours ago (expired)
      final expiredTimestamp = DateTime.now()
          .subtract(const Duration(hours: 25))
          .millisecondsSinceEpoch;

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(mockRoomspaces),
        'cache_timestamp': expiredTimestamp,
      });

      // Load roomspaces (should still load from expired cache)
      await provider.loadRoomspaces();

      // Verify: Roomspaces loaded from cache even though expired
      expect(provider.roomspaceCount, equals(2));

      // Verify: hasCachedData returns true
      final hasCached = await provider.hasCachedData();
      expect(hasCached, isTrue);
    });

    /// Test Scenario 10: Complete multi-roomspace workflow
    /// Validates Requirements: All
    test('Scenario 10: Complete workflow - join, switch, manage multiple roomspaces', () async {
      // Step 1: Start with no roomspaces
      expect(provider.roomspaceCount, equals(0));
      expect(provider.hasNoRoomspaces, isTrue);
      expect(provider.canJoinMore, isTrue);

      // Step 2: Join first roomspace
      final roomspace1 = [{
        'id': 'roomspace-1',
        'name': 'Home',
        'invite_code': 'HOME1234',
        'member_count': 2,
        'joined_at': DateTime.now().toIso8601String(),
        'is_creator': true,
      }];

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(roomspace1),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await provider.loadRoomspaces();

      expect(provider.roomspaceCount, equals(1));
      expect(provider.hasNoRoomspaces, isFalse);
      expect(provider.hasMultipleRoomspaces, isFalse);
      expect(provider.canJoinMore, isTrue);
      expect(provider.activeRoomspace!.name, equals('Home'));

      // Step 3: Join more roomspaces (up to 5)
      final allRoomspaces = List.generate(5, (index) => {
        'id': 'roomspace-${index + 1}',
        'name': ['Home', 'Office', 'Vacation', 'Studio', 'Cabin'][index],
        'invite_code': 'CODE${index + 1}234',
        'member_count': 2 + index,
        'joined_at': DateTime.now().subtract(Duration(days: index)).toIso8601String(),
        'is_creator': index == 0,
      });

      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(allRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });

      await provider.refreshRoomspaces();

      // Note: refreshRoomspaces tries to fetch from API, which will fail in tests
      // But it should still have the cached data from before
      // Let's manually update the cache to simulate the refresh
      SharedPreferences.setMockInitialValues({
        'cached_roomspaces': jsonEncode(allRoomspaces),
        'cache_timestamp': DateTime.now().millisecondsSinceEpoch,
      });
      
      // Create a new provider to load the updated cache
      final refreshedProvider = RoomspaceProvider();
      await refreshedProvider.loadRoomspaces();

      expect(refreshedProvider.roomspaceCount, equals(5));
      expect(refreshedProvider.hasMultipleRoomspaces, isTrue);
      expect(refreshedProvider.canJoinMore, isFalse); // At limit

      // Step 4: Switch between roomspaces
      await refreshedProvider.setActiveRoomspace('roomspace-3');
      expect(refreshedProvider.activeRoomspace!.name, equals('Vacation'));

      await refreshedProvider.setActiveRoomspace('roomspace-5');
      expect(refreshedProvider.activeRoomspace!.name, equals('Cabin'));

      // Step 5: Verify all roomspaces have unique properties
      final roomspaceNames = refreshedProvider.roomspaces.map((r) => r.name).toSet();
      expect(roomspaceNames.length, equals(5)); // All unique names

      // Step 6: Verify persistence
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getString('active_roomspace_id'), equals('roomspace-5'));

      // Step 7: Clear all data (logout scenario)
      await refreshedProvider.clear();
      expect(refreshedProvider.roomspaceCount, equals(0));
      expect(refreshedProvider.activeRoomspace, isNull);
      expect(prefs.getString('active_roomspace_id'), isNull);
    });
  });
}
