import '../models/roomspace_model.dart';
import 'api_service.dart';

class RoomspaceService {
  final ApiService _apiService = ApiService();

  // Create a new roomspace
  Future<Map<String, dynamic>> createRoomspace({
    required String name,
    String? description,
  }) async {
    return await _apiService.createRoomspace(
      name: name,
      description: description,
    );
  }

  // Join an existing roomspace by room ID (format: ROOM-123)
  Future<Map<String, dynamic>> joinRoomspace(String roomId) async {
    // Extract the numeric ID from the room ID format (ROOM-123 -> 123)
    String numericId = roomId;
    if (roomId.startsWith('ROOM-')) {
      numericId = roomId.substring(5);
    }

    final id = int.tryParse(numericId);
    if (id == null) {
      throw Exception('Invalid room ID format');
    }

    // Join the roomspace using its ID
    return await _apiService.joinRoomspace(id);
  }

  // Get roomspace by ID
  Future<Map<String, dynamic>> getRoomspace(int id) async {
    return await _apiService.getRoomspace(id);
  }

  // Get user's roomspaces
  Future<List<dynamic>> getUserRoomspaces() async {
    final response = await _apiService.getRoomspaces();
    return response['data'] as List<dynamic>;
  }
}
