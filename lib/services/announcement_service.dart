import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an announcement made by an administrator.
///
/// This class is the data model for announcements stored in Firestore
/// and managed by the [AnnouncementService].
class Announcement {
  /// The unique identifier for the announcement (Firestore document ID).
  final String announcementId;

  /// The ID of the admin user who posted the announcement.
  final String adminId;

  /// The title of the announcement.
  final String title;

  /// The main content or message of the announcement.
  final String message;

  /// The Firestore [Timestamp] when the announcement was created or last significantly updated.
  final Timestamp timestamp;

  /// The category of the announcement, e.g., 'General', 'Maintenance', 'Event'.
  final String category;

  /// Indicates whether the announcement is currently active and visible to users.
  /// `true` if active, `false` if inactive (e.g., retracted or expired).
  bool isActive;

  /// Creates an [Announcement] instance.
  ///
  /// [isActive] defaults to `true`. All other parameters are required.
  Announcement({
    required this.announcementId,
    required this.adminId,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isActive = true,
  });

  /// Creates an [Announcement] instance from a Firestore document snapshot.
  ///
  /// This factory constructor converts Firestore data into an [Announcement] object,
  /// providing defaults for fields that might be null or missing.
  ///
  /// - [doc]: The [DocumentSnapshot] from Firestore.
  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Announcement(
      announcementId: doc.id,
      adminId: data['adminId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(), // Default to now if missing
      category: data['category'] ?? 'General', // Default category
      isActive: data['isActive'] ?? true,
    );
  }

  /// Converts this [Announcement] object to a [Map] suitable for storage in Firestore.
  ///
  /// The `announcementId` is not included as it's the document ID in Firestore.
  Map<String, dynamic> toFirestore() {
    return {
      'adminId': adminId,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'category': category,
      'isActive': isActive,
    };
  }
}

/// Service for managing admin announcements in Firestore.
///
/// Provides methods for administrators to post, update, activate/deactivate,
/// and delete announcements. Also provides streams for fetching announcements.
class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'announcements';

  /// Posts a new announcement to the 'announcements' collection in Firestore.
  ///
  /// New announcements are set to `isActive: true` and `timestamp` to the current server time by default.
  ///
  /// - [adminId]: The ID of the admin user posting the announcement.
  /// - [title]: The title of the announcement.
  /// - [message]: The main content of the announcement.
  /// - [category]: The category of the announcement (e.g., 'General', 'Event').
  ///
  /// Returns a [Future<DocumentReference>] to the newly created announcement document.
  /// Rethrows any [FirebaseException] or other errors encountered during the Firestore operation.
  /// Includes a TODO comment regarding potential integration with [NotificationService].
  Future<DocumentReference> postAnnouncement({
    required String adminId,
    required String title,
    required String message,
    required String category,
  }) async {
    try {
      return await _firestore.collection(_collectionPath).add({
        'adminId': adminId,
        'title': title,
        'message': message,
        'timestamp': Timestamp.now(),
        'category': category,
        'isActive': true, // New announcements are active by default
      });
      // TODO: Consider triggering NotificationService here or in the calling UI function
      // to notify all users about the new announcement.
    } catch (e) {
      print('Error posting announcement: $e');
      rethrow;
    }
  }

  /// Retrieves a stream of all *active* announcements, ordered by timestamp descending (newest first).
  ///
  /// Filters announcements where `isActive` is `true`.
  /// Suitable for display to general users.
  ///
  /// Returns a [Stream<List<Announcement>>].
  Stream<List<Announcement>> getActiveAnnouncements() {
    return _firestore
        .collection(_collectionPath)
        .where('isActive', isEqualTo: true)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList();
    });
  }

  /// Retrieves a stream of all announcements, regardless of active status, ordered by timestamp descending.
  ///
  /// Suitable for administrator views to manage all announcements.
  ///
  /// Returns a [Stream<List<Announcement>>].
  Stream<List<Announcement>> getAllAnnouncementsForAdmin() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList();
    });
  }

  /// Updates an existing announcement in Firestore.
  ///
  /// Only non-null fields provided in the parameters will be updated.
  /// The `timestamp` field is automatically updated to the current server time if any other field is changed.
  ///
  /// - [announcementId]: The ID of the announcement to update.
  /// - [title]: Optional new title for the announcement.
  /// - [message]: Optional new message content.
  /// - [category]: Optional new category.
  /// - [isActive]: Optional new active status.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> updateAnnouncement(String announcementId, {
    String? title,
    String? message,
    String? category,
    bool? isActive,
  }) async {
    try {
      Map<String, dynamic> dataToUpdate = {};
      if (title != null) dataToUpdate['title'] = title;
      if (message != null) dataToUpdate['message'] = message;
      if (category != null) dataToUpdate['category'] = category;
      if (isActive != null) dataToUpdate['isActive'] = isActive;

      if (dataToUpdate.isNotEmpty) {
        dataToUpdate['timestamp'] = Timestamp.now(); // Update timestamp on any modification
        await _firestore.collection(_collectionPath).doc(announcementId).update(dataToUpdate);
      }
    } catch (e) {
      print('Error updating announcement $announcementId: $e');
      rethrow;
    }
  }

  /// Deactivates an announcement by setting its `isActive` status to `false`.
  ///
  /// Also updates the 'timestamp' to reflect the time of deactivation.
  ///
  /// - [announcementId]: The ID of the announcement to deactivate.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> deactivateAnnouncement(String announcementId) async {
    try {
      await _firestore.collection(_collectionPath).doc(announcementId).update({
        'isActive': false,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print('Error deactivating announcement $announcementId: $e');
      rethrow;
    }
  }

  /// Activates an announcement by setting its `isActive` status to `true`.
  ///
  /// Also updates the 'timestamp' to reflect the time of activation.
  ///
  /// - [announcementId]: The ID of the announcement to activate.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> activateAnnouncement(String announcementId) async {
    try {
      await _firestore.collection(_collectionPath).doc(announcementId).update({
        'isActive': true,
        'timestamp': Timestamp.now(),
      });
    } catch (e) {
      print('Error activating announcement $announcementId: $e');
      rethrow;
    }
  }

  /// Permanently deletes an announcement document from Firestore.
  ///
  /// This action is irreversible and should be used with caution.
  ///
  /// - [announcementId]: The ID of the announcement to delete.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await _firestore.collection(_collectionPath).doc(announcementId).delete();
    } catch (e) {
      print('Error deleting announcement $announcementId: $e');
      rethrow;
    }
  }
}
