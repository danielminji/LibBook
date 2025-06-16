import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a library room with its details.
///
/// This class is used as a data model for rooms stored in Firestore
/// and interacted with via [RoomService].
class Room {
  /// The unique identifier for the room (Firestore document ID).
  final String roomId;

  /// The display name of the room (e.g., "Discussion Room A", "Quiet Study Zone 1").
  final String name;

  /// The maximum number of occupants the room can hold.
  final int capacity;

  /// A list of amenities available in the room (e.g., "Projector", "Whiteboard").
  final List<String> amenities;

  /// Indicates whether the room is currently active and bookable.
  /// `true` if active, `false` if inactive (e.g., under maintenance).
  final bool isActive;

  /// The timestamp when the room was first created in Firestore.
  final DateTime createdAt;

  /// The timestamp of the last update to the room's details in Firestore.
  /// Can be null if the room has never been updated after creation.
  DateTime? updatedAt;

  /// Creates a [Room] instance.
  ///
  /// All parameters except [amenities], [isActive], and [updatedAt] are required.
  /// [amenities] defaults to an empty list.
  /// [isActive] defaults to `true`.
  Room({
    required this.roomId,
    required this.name,
    required this.capacity,
    this.amenities = const [],
    this.isActive = true,
    required this.createdAt,
    this.updatedAt,
  });

  /// Creates a [Room] instance from a Firestore document snapshot.
  ///
  /// This factory constructor is used to convert Firestore data into a [Room] object.
  /// It handles potential null values from Firestore by providing defaults.
  ///
  /// - [doc]: The [DocumentSnapshot] from Firestore.
  factory Room.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Room(
      roomId: doc.id,
      name: data['name'] ?? '',
      capacity: data['capacity'] ?? 0,
      amenities: List<String>.from(data['amenities'] ?? []),
      isActive: data['isActive'] ?? true,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(), // Default to now if null
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
    );
  }

  /// Converts this [Room] object to a [Map] suitable for storage in Firestore.
  ///
  /// The `roomId` is not included in the map as it's used as the document ID in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'name': name,
      'capacity': capacity,
      'amenities': amenities,
      'isActive': isActive,
      'createdAt': createdAt, // Should be Timestamp.fromDate(createdAt) if not already a Timestamp
      'updatedAt': updatedAt, // Should be Timestamp.fromDate(updatedAt) if not already a Timestamp
    };
  }
}

/// Service class for managing library room data in Firestore.
///
/// Provides methods for CRUD (Create, Read, Update, Delete) operations
/// on rooms, as well as streaming active or all rooms.
class RoomService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'rooms';

  /// Adds a new room to the 'rooms' collection in Firestore.
  ///
  /// Firestore will auto-generate the document ID for the new room.
  /// `createdAt` and `updatedAt` timestamps are set to the current server time.
  ///
  /// - [name]: The name of the room.
  /// - [capacity]: The capacity of the room.
  /// - [amenities]: A list of amenities available in the room. Defaults to an empty list.
  /// - [isActive]: Whether the room is initially active. Defaults to `true`.
  ///
  /// Returns a [Future<DocumentReference>] to the newly created room document.
  /// Rethrows any [FirebaseException] or other errors encountered during the Firestore operation.
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
      print('Error adding room: $e');
      rethrow;
    }
  }

  /// Retrieves a specific room by its ID from Firestore.
  ///
  /// - [roomId]: The unique ID of the room to retrieve.
  ///
  /// Returns a [Future<Room?>]. If the room document exists, it's converted
  /// to a [Room] object. Returns `null` if the document does not exist.
  /// Rethrows any [FirebaseException] or other errors encountered during fetching.
  Future<Room?> getRoom(String roomId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection(_collectionPath).doc(roomId).get();
      if (doc.exists) {
        return Room.fromFirestore(doc);
      }
      return null;
    } catch (e) {
      print('Error getting room $roomId: $e');
      rethrow;
    }
  }

  /// Gets a stream of all rooms from Firestore, ordered by creation date (descending).
  ///
  /// This is typically used for admin views where all rooms (active or inactive) are needed.
  ///
  /// Returns a [Stream<List<Room>>] that emits a list of [Room] objects
  /// whenever the underlying Firestore data changes.
  Stream<List<Room>> getAllRooms() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }

  /// Gets a stream of all *active* rooms from Firestore, ordered by name (ascending).
  ///
  /// Filters rooms where `isActive` is `true`.
  /// This is typically used for user-facing views where only bookable rooms are shown.
  ///
  /// Returns a [Stream<List<Room>>] that emits a list of active [Room] objects.
  Stream<List<Room>> getActiveRooms() {
    return _firestore
        .collection(_collectionPath)
        .where('isActive', isEqualTo: true)
        .orderBy('name', descending: false)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Room.fromFirestore(doc)).toList();
    });
  }

  /// Updates an existing room in Firestore with the provided data.
  ///
  /// The `dataToUpdate` map should contain only the fields to be updated.
  /// The 'updatedAt' field is automatically set to the current server time.
  ///
  /// - [roomId]: The ID of the room to update.
  /// - [dataToUpdate]: A [Map<String, dynamic>] containing the fields and new values.
  ///
  /// Rethrows any [FirebaseException] or other errors during the update.
  Future<void> updateRoom(String roomId, Map<String, dynamic> dataToUpdate) async {
    try {
      dataToUpdate['updatedAt'] = Timestamp.now();
      await _firestore.collection(_collectionPath).doc(roomId).update(dataToUpdate);
    } catch (e) {
      print('Error updating room $roomId: $e');
      rethrow;
    }
  }

  /// Deactivates a room by setting its `isActive` status to `false`.
  ///
  /// This is a soft delete, meaning the room data remains but is marked as inactive.
  /// Also updates the 'updatedAt' timestamp.
  ///
  /// - [roomId]: The ID of the room to deactivate.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> deactivateRoom(String roomId) async {
    try {
      await _firestore.collection(_collectionPath).doc(roomId).update({
        'isActive': false,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error deactivating room $roomId: $e');
      rethrow;
    }
  }

  /// Activates a room by setting its `isActive` status to `true`.
  ///
  /// Useful for re-enabling a previously deactivated room.
  /// Also updates the 'updatedAt' timestamp.
  ///
  /// - [roomId]: The ID of the room to activate.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> activateRoom(String roomId) async {
    try {
      await _firestore.collection(_collectionPath).doc(roomId).update({
        'isActive': true,
        'updatedAt': Timestamp.now(),
      });
    } catch (e) {
      print('Error activating room $roomId: $e');
      rethrow;
    }
  }

  /// Permanently deletes a room document from Firestore.
  ///
  /// This is a hard delete and should be used with caution as the data cannot be recovered.
  ///
  /// - [roomId]: The ID of the room to delete permanently.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> deleteRoomPermanently(String roomId) async {
    try {
      await _firestore.collection(_collectionPath).doc(roomId).delete();
    } catch (e) {
      print('Error deleting room $roomId permanently: $e');
      rethrow;
    }
  }
}
