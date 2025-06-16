import 'package:cloud_firestore/cloud_firestore.dart';

class Announcement {
  final String announcementId; // Firestore document ID
  final String adminId; // ID of the admin who posted
  final String title;
  final String message;
  final Timestamp timestamp;
  final String category; // e.g., 'General', 'Maintenance', 'Event'
  bool isActive; // To allow retraction or hiding

  Announcement({
    required this.announcementId,
    required this.adminId,
    required this.title,
    required this.message,
    required this.timestamp,
    required this.category,
    this.isActive = true,
  });

  factory Announcement.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Announcement(
      announcementId: doc.id,
      adminId: data['adminId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      category: data['category'] ?? 'General',
      isActive: data['isActive'] ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'adminId': adminId,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'category': category,
      'isActive': isActive,
      // announcementId is the document ID
    };
  }
}

class AnnouncementService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'announcements';

  // Post a new announcement (Admin action)
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
        'isActive': true,
      });
      // TODO: Consider triggering NotificationService here or in the calling UI function
    } catch (e) {
      print('Error posting announcement: $e');
      rethrow;
    }
  }

  // Get a stream of active announcements for users (newest first)
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

  // Get a stream of all announcements for admin management (newest first)
  Stream<List<Announcement>> getAllAnnouncementsForAdmin() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Announcement.fromFirestore(doc)).toList();
    });
  }

  // Update an existing announcement (Admin action)
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
        dataToUpdate['timestamp'] = Timestamp.now(); // Update timestamp on modification
        await _firestore.collection(_collectionPath).doc(announcementId).update(dataToUpdate);
      }
    } catch (e) {
      print('Error updating announcement: $e');
      rethrow;
    }
  }

  // Deactivate an announcement (Admin action)
  Future<void> deactivateAnnouncement(String announcementId) async {
    try {
      await _firestore.collection(_collectionPath).doc(announcementId).update({
        'isActive': false,
        'timestamp': Timestamp.now(), // Optionally update timestamp
      });
    } catch (e) {
      print('Error deactivating announcement: $e');
      rethrow;
    }
  }

  // Activate an announcement (Admin action)
  Future<void> activateAnnouncement(String announcementId) async {
    try {
      await _firestore.collection(_collectionPath).doc(announcementId).update({
        'isActive': true,
        'timestamp': Timestamp.now(), // Optionally update timestamp
      });
    } catch (e) {
      print('Error activating announcement: $e');
      rethrow;
    }
  }

  // Delete an announcement permanently (Admin action - use with caution)
  Future<void> deleteAnnouncement(String announcementId) async {
    try {
      await _firestore.collection(_collectionPath).doc(announcementId).delete();
    } catch (e) {
      print('Error deleting announcement: $e');
      rethrow;
    }
  }
}
