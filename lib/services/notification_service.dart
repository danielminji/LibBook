import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents an in-app notification for a user.
///
/// This class is the data model for notifications stored in Firestore
/// and managed by the [NotificationService].
class Notification {
  /// The unique identifier for the notification (Firestore document ID).
  final String notificationId;

  /// The ID of the user to whom this notification belongs.
  final String userId;

  /// The title of the notification, displayed prominently.
  final String title;

  /// The main content or body of the notification message.
  final String message;

  /// The Firestore [Timestamp] when the notification was created.
  final Timestamp timestamp;

  /// Indicates whether the notification has been read by the user.
  /// `true` if read, `false` otherwise.
  bool isRead;

  /// The type or category of the notification, used for potential filtering or specific handling.
  /// Examples: 'booking_status_update', 'general_announcement', 'feedback_reply'.
  final String type;

  /// An optional ID of an entity related to this notification.
  /// For example, a `bookingId` if the notification is about a booking,
  /// or an `announcementId` if it's about a general announcement.
  final String? relatedEntityId;

  /// Creates a [Notification] instance.
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

  /// Creates a [Notification] instance from a Firestore document snapshot.
  ///
  /// This factory constructor is used to convert Firestore data into a [Notification] object.
  /// It handles potential null values from Firestore by providing sensible defaults.
  ///
  /// - [doc]: The [DocumentSnapshot] from Firestore.
  factory Notification.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Notification(
      notificationId: doc.id,
      userId: data['userId'] ?? '',
      title: data['title'] ?? '',
      message: data['message'] ?? '',
      timestamp: data['timestamp'] ?? Timestamp.now(), // Default to now if timestamp is missing
      isRead: data['isRead'] ?? false,
      type: data['type'] ?? 'general', // Default type if missing
      relatedEntityId: data['relatedEntityId'],
    );
  }

  /// Converts this [Notification] object to a [Map] suitable for storage in Firestore.
  ///
  /// The `notificationId` is not included in the map as it's used as the document ID.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'title': title,
      'message': message,
      'timestamp': timestamp,
      'isRead': isRead,
      'type': type,
      'relatedEntityId': relatedEntityId,
    };
  }
}

/// Service for managing user-specific in-app notifications in Firestore.
///
/// Provides methods to create, retrieve, and manage the read status of notifications.
class NotificationService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'notifications';

  /// Creates a new notification document in Firestore for a specific user.
  ///
  /// Sets `isRead` to `false` and `timestamp` to the current server time by default.
  ///
  /// - [userId]: The ID of the user to receive the notification.
  /// - [title]: The title of the notification.
  /// - [message]: The main content/body of the notification.
  /// - [type]: A string indicating the type of notification (e.g., 'booking_status_update').
  /// - [relatedEntityId]: Optional ID of an entity (e.g., a booking ID) related to this notification.
  ///
  /// Returns a [Future<DocumentReference>] to the newly created notification document.
  /// Rethrows any [FirebaseException] or other errors encountered during the Firestore operation.
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
      print('Error creating notification for user $userId: $e');
      rethrow;
    }
  }

  /// Retrieves a stream of all notifications for a specific user, ordered by timestamp descending (newest first).
  ///
  /// - [userId]: The ID of the user whose notifications are to be fetched.
  ///
  /// Returns a [Stream<List<Notification>>] that emits a list of [Notification] objects.
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

  /// Retrieves a stream of unread notifications for a specific user, ordered by timestamp descending.
  ///
  /// Filters notifications where `isRead` is `false`.
  ///
  /// - [userId]: The ID of the user whose unread notifications are to be fetched.
  ///
  /// Returns a [Stream<List<Notification>>].
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

  /// Marks a specific notification as read by updating its `isRead` status to `true`.
  ///
  /// - [notificationId]: The ID of the notification to mark as read.
  ///
  /// Rethrows any [FirebaseException] or other errors during the update.
  Future<void> markAsRead(String notificationId) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).update({'isRead': true});
    } catch (e) {
      print('Error marking notification $notificationId as read: $e');
      rethrow;
    }
  }

  /// Marks all unread notifications for a specific user as read.
  ///
  /// Performs a batch update to set `isRead` to `true` for all notifications
  /// belonging to the [userId] that are currently unread.
  ///
  /// - [userId]: The ID of the user whose notifications are to be marked as read.
  ///
  /// Rethrows any [FirebaseException] or other errors during the batch operation.
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
      print('Error marking all notifications as read for user $userId: $e');
      rethrow;
    }
  }

  /// Deletes a specific notification document from Firestore.
  ///
  /// This is an optional administrative or user action.
  ///
  /// - [notificationId]: The ID of the notification to delete.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> deleteNotification(String notificationId) async {
    try {
      await _firestore.collection(_collectionPath).doc(notificationId).delete();
    } catch (e) {
      print('Error deleting notification $notificationId: $e');
      rethrow;
    }
  }
}
