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

  // Join an existing roomspace by room ID
  Future<Map<String, dynamic>> joinRoomspace(String roomId) async {
    // First, get all roomspaces to find the one with matching room_id
    final roomspacesResponse = await _apiService.getRoomspaces();
    final roomspaces = roomspacesResponse['roomspaces'] as List<dynamic>;

    // Find roomspace with matching room_id
    final roomspace = roomspaces.firstWhere(
      (r) => r['room_id'] == roomId,
      orElse: () => null,
    );

    if (roomspace == null) {
      throw Exception('Roomspace not found');
    }

    // Join the roomspace using its ID
    return await _apiService.joinRoomspace(roomspace['id']);
  }

  // Get roomspace by ID
  Future<Map<String, dynamic>> getRoomspace(int id) async {
    return await _apiService.getRoomspace(id);
  }

  // Get user's roomspaces
  Future<List<dynamic>> getUserRoomspaces() async {
    final response = await _apiService.getRoomspaces();
    return response['roomspaces'] as List<dynamic>;
  }
}
