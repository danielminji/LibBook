import 'package:cloud_firestore/cloud_firestore.dart';

class Notification {
  final String notificationId; // Firestore document ID
  final String userId;
  final String title;
  final String message;
  final Timestamp timestamp;
  bool isRead;
  final String type; // e.g., 'booking_status_update', 'general_announcement'
  final String? relatedEntityId; // e.g., bookingId

  Notification({
    required this.notificationId,
    required this.userId,
    required this.title,
    required this.message,
    required this.timestamp,
    this.isRead = false,
    required this.type,
    this.relatedEntityId,
  });

  factory Notification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Notification(
      notificationId: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? 'general',
      relatedEntityId: data['relatedEntityId'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type,
      'relatedEntityId': relatedEntityId,
      // notificationId is the document ID, not stored in the fields
    };
  }
}

class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'notifications';

  // Create a new notification
  Future<DocumentReference> createNotification({
    required String userId,
    required String title,
    required String message,
    required String type,
    String? relatedEntityId,
  }) async {
    try {
      return await _firestore.collection(_collectionPath).add({
        'userId': userId,
        'title': title,
        'message': message,
        'timestamp': Timestamp.now(),
        'isRead': false,
        'type': type,
        'relatedEntityId': relatedEntityId,
      });
    } catch (e) {
      print('Error creating notification: $e');
      rethrow;
    }
  }

  // Get a stream of notifications for a specific user
  Stream<List<Notification>> getUserNotifications(String userId) {
    return _firestore
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Notification.fromFirestore(doc)).toList();
    });
  }

  // Get a stream of unread notifications for a specific user
   Stream<List<Notification>> getUnreadUserNotifications(String userId) {
     return _firestore
         .collection(_collectionPath)
         .where('userId', isEqualTo: userId)
         .where('isRead', isEqualTo: false)
         .orderBy('timestamp', descending: true)
         .snapshots()
         .map((snapshot) {
       return snapshot.docs.map((doc) => Notification.fromFirestore(doc)).toList();
     });
   }

  // Mark a specific notification as read
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('Error marking notification as read: $e');
      rethrow;
    }
  }

  // Mark all unread notifications for a user as read
  Future<void> markAllAsRead(String userId) async {
    try {
      QuerySnapshot unreadNotifications = await _firestore
          .collection(_collectionPath)
          .where('userId', isEqualTo: userId)
          .where('isRead', isEqualTo: false)
          .get();

      WriteBatch batch = _firestore.batch();
      for (DocumentSnapshot doc in unreadNotifications.docs) {
        batch.update(doc.reference, {'isRead': true});
      }
      await batch.commit();
    } catch (e) {
      print('Error marking all notifications as read: $e');
      rethrow;
    }
  }

  // Delete a notification (optional)
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification: $e');
      rethrow;
    }
  }
}
