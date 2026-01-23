import 'package:flutter/material.dart';

/// Model representing roomspace data for multi-roomspace support
/// Used for displaying and managing multiple roomspaces in the UI
class RoomspaceData {
  final String id;
  final String name;
  final String inviteCode;
  final int memberCount;
  final Color visualColor;
  final IconData visualIcon;
  final DateTime joinedAt;
  final bool isCreator;

  RoomspaceData({
    required this.id,
    required this.name,
    required this.inviteCode,
    required this.memberCount,
    required this.visualColor,
    required this.visualIcon,
    required this.joinedAt,
    required this.isCreator,
  });

  /// Create RoomspaceData from JSON response
  factory RoomspaceData.fromJson(Map<String, dynamic> json) {
    final id = json['id'] as String;
    
    // Parse members array to get member count and check if user is creator
    final members = json['members'] as List<dynamic>? ?? [];
    final memberCount = members.length;
    
    // Check if current user is creator (you'll need to pass current user ID)
    // For now, check if any member has role 'creator'
    bool isCreator = false;
    DateTime? joinedAt;
    
    // Try to find current user's membership info
    // This assumes the API returns the current user's info in the members array
    for (var member in members) {
      if (member is Map<String, dynamic>) {
        final role = member['role'] as String?;
        if (role == 'creator') {
          isCreator = true;
        }
        // Use the first member's joined_at as fallback
        if (joinedAt == null && member['joined_at'] != null) {
          try {
            joinedAt = DateTime.parse(member['joined_at'] as String);
          } catch (e) {
            // Ignore parse errors
          }
        }
      }
    }
    
    return RoomspaceData(
      id: id,
      name: json['name'] as String,
      inviteCode: json['invite_code'] as String,
      memberCount: memberCount,
      visualColor: _getColorForRoomspace(id),
      visualIcon: _getIconForRoomspace(id),
      joinedAt: joinedAt ?? DateTime.now(),
      isCreator: isCreator,
    );
  }

  /// Convert RoomspaceData to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'invite_code': inviteCode,
      'member_count': memberCount,
      'joined_at': joinedAt.toIso8601String(),
      'is_creator': isCreator,
    };
  }

  /// Assign a deterministic color based on roomspace ID hash
  /// This ensures the same roomspace always gets the same color
  static Color _getColorForRoomspace(String id) {
    final hash = id.hashCode.abs();
    
    // Predefined color palette for roomspaces
    final colors = [
      const Color(0xFF2196F3), // Blue
      const Color(0xFF4CAF50), // Green
      const Color(0xFFFF9800), // Orange
      const Color(0xFF9C27B0), // Purple
      const Color(0xFF009688), // Teal
      const Color(0xFFE91E63), // Pink
      const Color(0xFFFF5722), // Deep Orange
      const Color(0xFF3F51B5), // Indigo
      const Color(0xFF00BCD4), // Cyan
      const Color(0xFF8BC34A), // Light Green
    ];
    
    return colors[hash % colors.length];
  }

  /// Assign a deterministic icon based on roomspace ID hash
  /// This ensures the same roomspace always gets the same icon
  static IconData _getIconForRoomspace(String id) {
    final hash = id.hashCode.abs();
    
    // Predefined icon set for roomspaces
    final icons = [
      Icons.home,
      Icons.apartment,
      Icons.house,
      Icons.villa,
      Icons.cottage,
      Icons.holiday_village,
      Icons.cabin,
      Icons.bungalow,
      Icons.roofing,
      Icons.foundation,
    ];
    
    return icons[hash % icons.length];
  }

  /// Copy with method for updates
  RoomspaceData copyWith({
    String? id,
    String? name,
    String? inviteCode,
    int? memberCount,
    Color? visualColor,
    IconData? visualIcon,
    DateTime? joinedAt,
    bool? isCreator,
  }) {
    return RoomspaceData(
      id: id ?? this.id,
      name: name ?? this.name,
      inviteCode: inviteCode ?? this.inviteCode,
      memberCount: memberCount ?? this.memberCount,
      visualColor: visualColor ?? this.visualColor,
      visualIcon: visualIcon ?? this.visualIcon,
      joinedAt: joinedAt ?? this.joinedAt,
      isCreator: isCreator ?? this.isCreator,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is RoomspaceData &&
        other.id == id &&
        other.name == name &&
        other.inviteCode == inviteCode &&
        other.memberCount == memberCount &&
        other.visualColor == visualColor &&
        other.visualIcon == visualIcon &&
        other.joinedAt == joinedAt &&
        other.isCreator == isCreator;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      inviteCode,
      memberCount,
      visualColor,
      visualIcon,
      joinedAt,
      isCreator,
    );
  }

  @override
  String toString() {
    return 'RoomspaceData(id: $id, name: $name, inviteCode: $inviteCode, '
        'memberCount: $memberCount, joinedAt: $joinedAt, isCreator: $isCreator)';
  }
}
