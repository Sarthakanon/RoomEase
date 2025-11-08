import '../models/roomspace_model.dart';

class RoomspaceService {
  // Mock data storage (in real app, this would be Firebase/API calls)
  static final Map<String, Roomspace> _mockRoomspaces = {};

  // Create a new roomspace
  static Future<String> createRoomspace({
    required String name,
    required String address,
    String? description,
    required String createdBy,
    int maxMembers = 4,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    // Generate room ID
    final roomId = _generateRoomId();
    
    final roomspace = Roomspace(
      id: roomId,
      name: name,
      address: address,
      description: description,
      memberIds: [createdBy],
      maxMembers: maxMembers,
      createdAt: DateTime.now(),
      createdBy: createdBy,
    );

    _mockRoomspaces[roomId] = roomspace;
    return roomId;
  }

  // Join an existing roomspace
  static Future<bool> joinRoomspace({
    required String roomId,
    required String userId,
  }) async {
    // Simulate API delay
    await Future.delayed(const Duration(seconds: 1));

    final roomspace = _mockRoomspaces[roomId];
    if (roomspace == null) {
      return false; // Room not found
    }

    if (!roomspace.hasSpace) {
      throw Exception('Roomspace is full');
    }

    if (roomspace.memberIds.contains(userId)) {
      throw Exception('User is already a member');
    }

    // Add user to roomspace
    final updatedMemberIds = [...roomspace.memberIds, userId];
    _mockRoomspaces[roomId] = roomspace.copyWith(memberIds: updatedMemberIds);
    
    return true;
  }

  // Get roomspace by ID
  static Future<Roomspace?> getRoomspace(String roomId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    return _mockRoomspaces[roomId];
  }

  // Get user's roomspaces
  static Future<List<Roomspace>> getUserRoomspaces(String userId) async {
    // Simulate API delay
    await Future.delayed(const Duration(milliseconds: 500));
    
    return _mockRoomspaces.values
        .where((roomspace) => roomspace.memberIds.contains(userId))
        .toList();
  }

  // Generate a random room ID
  static String _generateRoomId() {
    const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    var result = '';
    
    for (int i = 0; i < 8; i++) {
      result += chars[(random + i) % chars.length];
    }
    
    return result;
  }

  // Initialize with some mock data for testing
  static void initializeMockData() {
    _mockRoomspaces['ABC12345'] = Roomspace(
      id: 'ABC12345',
      name: 'Downtown Apartment',
      address: '123 Main St, City Center',
      description: 'Cozy apartment in the heart of the city',
      memberIds: ['user1', 'user2'],
      maxMembers: 4,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      createdBy: 'user1',
    );

    _mockRoomspaces['XYZ67890'] = Roomspace(
      id: 'XYZ67890',
      name: 'College Dorm',
      address: 'University Campus, Building A',
      description: 'Student housing near campus',
      memberIds: ['user3'],
      maxMembers: 3,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      createdBy: 'user3',
    );
  }
}