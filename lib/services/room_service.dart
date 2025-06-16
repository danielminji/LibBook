import 'package:cloud_firestore/cloud_firestore.dart';

// Data model for a Room
class Room {
  final String roomId; // Firestore document ID
  final String name;
  final int capacity;
  final List<String> amenities; // e.g., ['Projector', 'Whiteboard']
  final bool isActive; // To allow admins to enable/disable rooms
  final DateTime createdAt;
  DateTime? updatedAt;

  Room({
    required this.roomId,
    required this.name,
    required this.capacity,
    this.amenities = const [],
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  // Factory constructor to create a Room from a Firestore document
  factory Room.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Room(
      roomId: doc.id,
      name: data['name'] ?? '',
      capacity: data['capacity'] ?? 0,
      amenities: List<String>.from(data['amenities'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  // Method to convert a Room object to a Map for Firestore
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'capacity': capacity,
      'amenities': amenities,
      'isActive': isActive,
      'createdAt': createdAt,
      'updatedAt': updatedAt,
      // roomId is not stored in the document itself, it's the ID
    };
  }
}

// Service class for Room operations
class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'rooms';

  // Add a new room
  Future<DocumentReference> addRoom({
    required String name,
    required int capacity,
    List<String> amenities = const [],
    bool isActive = true,
  }) async {
    try {
      Timestamp now = Timestamp.now();
      DocumentReference docRef = await _firestore.collection(_collectionPath).add({
        'name': name,
        'capacity': capacity,
        'amenities': amenities,
        'isActive': isActive,
        'createdAt': now,
        'updatedAt': now,
      });
      return docRef;
    } catch (e) {
      // Log error or rethrow
      print('Error adding room: $e');
      rethrow;
    }
  }

  // Get a specific room by ID
  Future<Room?> getRoom(String roomId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collectionPath).doc(roomId).get();
      if (doc.exists) {
        return Room.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting room: $e');
      rethrow;
    }
  }

  // Get a stream of all rooms
  Stream<List<Room>> getAllRooms() {
    return _firestore.collection(_collectionPath).orderBy('createdAt', descending: true).snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }

  // Get a stream of all active rooms
  Stream<List<Room>> getActiveRooms() {
    return _firestore.collection(_collectionPath)
        .where('isActive', isEqualTo: true)
        .orderBy('name', descending: false) // Order active rooms by name
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }

  // Update an existing room
  Future<void> updateRoom(String roomId, Map<String, dynamic> dataToUpdate) async {
    try {
      dataToUpdate['updatedAt'] = Timestamp.now();
      await _firestore.collection(_collectionPath).doc(roomId).update(dataToUpdate);
    } catch (e) {
      print('Error updating room: $e');
      rethrow;
    }
  }

  // Deactivate a room (soft delete)
  Future<void> deactivateRoom(String roomId) async {
    try {
      await _firestore.collection(_collectionPath).doc(roomId).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error deactivating room: $e');
      rethrow;
    }
  }

  // Activate a room
  Future<void> activateRoom(String roomId) async {
    try {
      await _firestore.collection(_collectionPath).doc(roomId).update({
        'isActive': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error activating room: $e');
      rethrow;
    }
  }

  // Hard delete a room (use with caution)
  Future<void> deleteRoomPermanently(String roomId) async {
    try {
      await _firestore.collection(_collectionPath).doc(roomId).delete();
    } catch (e) {
      print('Error deleting room permanently: $e');
      rethrow;
    }
  }
}
