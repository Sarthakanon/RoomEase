import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/roomspace_model.dart';
import '../models/user_model.dart';

class FirestoreService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Collections
  static const String usersCollection = 'users';
  static const String roomspacesCollection = 'roomspaces';

  // ==================== USER OPERATIONS ====================

  // Create user document
  Future<void> createUser(UserModel user) async {
    try {
      await _firestore
          .collection(usersCollection)
          .doc(user.id)
          .set(user.toJson());
    } catch (e) {
      throw 'Failed to create user profile. Please try again.';
    }
  }

  // Get user by ID
  Future<UserModel?> getUser(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(usersCollection)
          .doc(userId)
          .get();
      if (doc.exists) {
        return UserModel.fromJson(doc.data() as Map<String, dynamic>);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch user data. Please try again.';
    }
  }

  // Update user
  Future<void> updateUser(String userId, Map<String, dynamic> data) async {
    try {
      await _firestore.collection(usersCollection).doc(userId).update(data);
    } catch (e) {
      throw 'Failed to update user profile. Please try again.';
    }
  }

  // ==================== ROOMSPACE OPERATIONS ====================

  // Create roomspace
  Future<String> createRoomspace(Roomspace roomspace) async {
    try {
      DocumentReference docRef = await _firestore
          .collection(roomspacesCollection)
          .add(roomspace.toJson());
      return docRef.id;
    } catch (e) {
      throw 'Failed to create roomspace. Please try again.';
    }
  }

  // Get roomspace by ID
  Future<Roomspace?> getRoomspace(String roomspaceId) async {
    try {
      DocumentSnapshot doc = await _firestore
          .collection(roomspacesCollection)
          .doc(roomspaceId)
          .get();
      if (doc.exists) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Roomspace.fromJson(data);
      }
      return null;
    } catch (e) {
      throw 'Failed to fetch roomspace data. Please try again.';
    }
  }

  // Update roomspace
  Future<void> updateRoomspace(
    String roomspaceId,
    Map<String, dynamic> data,
  ) async {
    try {
      await _firestore
          .collection(roomspacesCollection)
          .doc(roomspaceId)
          .update(data);
    } catch (e) {
      throw 'Failed to update roomspace. Please try again.';
    }
  }

  // Add member to roomspace
  Future<void> addMemberToRoomspace(String roomspaceId, String userId) async {
    try {
      await _firestore.collection(roomspacesCollection).doc(roomspaceId).update(
        {
          'memberIds': FieldValue.arrayUnion([userId]),
        },
      );
    } catch (e) {
      throw 'Failed to join roomspace. Please try again.';
    }
  }

  // Remove member from roomspace
  Future<void> removeMemberFromRoomspace(
    String roomspaceId,
    String userId,
  ) async {
    try {
      await _firestore.collection(roomspacesCollection).doc(roomspaceId).update(
        {
          'memberIds': FieldValue.arrayRemove([userId]),
        },
      );
    } catch (e) {
      throw 'Failed to leave roomspace. Please try again.';
    }
  }

  // Get user's roomspaces
  Future<List<Roomspace>> getUserRoomspaces(String userId) async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection(roomspacesCollection)
          .where('memberIds', arrayContains: userId)
          .get();

      return querySnapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
        data['id'] = doc.id;
        return Roomspace.fromJson(data);
      }).toList();
    } catch (e) {
      throw 'Failed to fetch roomspaces. Please try again.';
    }
  }

  // Delete roomspace
  Future<void> deleteRoomspace(String roomspaceId) async {
    try {
      await _firestore
          .collection(roomspacesCollection)
          .doc(roomspaceId)
          .delete();
    } catch (e) {
      throw 'Failed to delete roomspace. Please try again.';
    }
  }

  // Stream roomspace updates
  Stream<Roomspace?> streamRoomspace(String roomspaceId) {
    return _firestore
        .collection(roomspacesCollection)
        .doc(roomspaceId)
        .snapshots()
        .map((doc) {
          if (doc.exists) {
            Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
            data['id'] = doc.id;
            return Roomspace.fromJson(data);
          }
          return null;
        });
  }
}
