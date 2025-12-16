class Roomspace {
  final String id;
  final String name;
  final String address;
  final String? description;
  final List<String> memberIds;
  final int maxMembers;
  final DateTime createdAt;
  final String createdBy;

  Roomspace({
    required this.id,
    required this.name,
    required this.address,
    this.description,
    required this.memberIds,
    required this.maxMembers,
    required this.createdAt,
    required this.createdBy,
  });

  // Convert to JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'address': address,
      'description': description,
      'memberIds': memberIds,
      'maxMembers': maxMembers,
      'createdAt': createdAt.toIso8601String(),
      'createdBy': createdBy,
    };
  }

  // Create from JSON
  factory Roomspace.fromJson(Map<String, dynamic> json) {
    return Roomspace(
      id: json['id'],
      name: json['name'],
      address: json['address'],
      description: json['description'],
      memberIds: List<String>.from(json['memberIds']),
      maxMembers: json['maxMembers'],
      createdAt: DateTime.parse(json['createdAt']),
      createdBy: json['createdBy'],
    );
  }

  // Copy with method for updates
  Roomspace copyWith({
    String? id,
    String? name,
    String? address,
    String? description,
    List<String>? memberIds,
    int? maxMembers,
    DateTime? createdAt,
    String? createdBy,
  }) {
    return Roomspace(
      id: id ?? this.id,
      name: name ?? this.name,
      address: address ?? this.address,
      description: description ?? this.description,
      memberIds: memberIds ?? this.memberIds,
      maxMembers: maxMembers ?? this.maxMembers,
      createdAt: createdAt ?? this.createdAt,
      createdBy: createdBy ?? this.createdBy,
    );
  }

  // Check if room has space for more members
  bool get hasSpace => memberIds.length < maxMembers;

  // Get current member count
  int get currentMemberCount => memberIds.length;
}