import 'package:cloud_firestore/cloud_firestore.dart';

/// Represents a piece of feedback submitted by a user.
///
/// This class serves as the data model for user feedback stored in Firestore
/// and managed by the [FeedbackService].
class Feedback {
  /// The unique identifier for the feedback (Firestore document ID).
  final String feedbackId;

  /// The ID of the user who submitted the feedback.
  final String userId;

  /// The email of the user who submitted the feedback (denormalized for convenience).
  final String userEmail;

  /// The main content of the feedback message.
  final String message;

  /// Optional category for the feedback, e.g., 'General', 'Bug Report', 'Suggestion'.
  final String? category;

  /// The Firestore [Timestamp] when the feedback was submitted.
  final Timestamp timestamp;

  /// Indicates whether an admin has addressed or reviewed the feedback.
  /// `true` if addressed, `false` otherwise.
  bool isAddressed;

  /// Optional notes added by an admin when addressing the feedback.
  String? adminNotes;

  /// Creates a [Feedback] instance.
  Feedback({
    required this.feedbackId,
    required this.userId,
    required this.userEmail,
    required this.message,
    this.category,
    required this.timestamp,
    this.isAddressed = false,
    this.adminNotes,
  });

  /// Creates a [Feedback] instance from a Firestore document snapshot.
  ///
  /// This factory constructor is used to convert Firestore data into a [Feedback] object.
  /// It handles potential null values by providing defaults.
  ///
  /// - [doc]: The [DocumentSnapshot] from Firestore.
  factory Feedback.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Feedback(
      feedbackId: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      message: data['message'] ?? '',
      category: data['category'],
      timestamp: data['timestamp'] ?? Timestamp.now(), // Default to now if missing
      isAddressed: data['isAddressed'] ?? false,
      adminNotes: data['adminNotes'],
    );
  }

  /// Converts this [Feedback] object to a [Map] suitable for storage in Firestore.
  ///
  /// The `feedbackId` is not included in the map as it's used as the document ID.
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'message': message,
      'category': category,
      'timestamp': timestamp,
      'isAddressed': isAddressed,
      'adminNotes': adminNotes,
    };
  }
}

/// Service for managing user feedback within Firestore.
///
/// Provides methods for users to submit feedback and for admins to view,
/// address, and manage feedback items.
class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'feedback';

  /// Submits new feedback from a user to the 'feedback' collection in Firestore.
  ///
  /// Sets `isAddressed` to `false` and `adminNotes` to `null` by default for new feedback.
  /// The `timestamp` is set to the current server time.
  ///
  /// - [userId]: The ID of the user submitting the feedback.
  /// - [userEmail]: The email of the user (denormalized for convenience).
  /// - [message]: The content of the feedback message.
  /// - [category]: Optional category for the feedback (e.g., 'General', 'Bug Report').
  ///
  /// Returns a [Future<DocumentReference>] to the newly created feedback document.
  /// Rethrows any [FirebaseException] or other errors encountered during the Firestore operation.
  Future<DocumentReference> submitFeedback({
    required String userId,
    required String userEmail,
    required String message,
    String? category,
  }) async {
    try {
      return await _firestore.collection(_collectionPath).add({
        'userId': userId,
        'userEmail': userEmail,
        'message': message,
        'category': category,
        'timestamp': Timestamp.now(),
        'isAddressed': false,
        'adminNotes': null,
      });
    } catch (e) {
      print('Error submitting feedback for user $userId: $e');
      rethrow;
    }
  }

  /// Retrieves a stream of all feedback items, ordered by timestamp descending (newest first).
  ///
  /// This is typically used by administrators to view all submitted feedback.
  ///
  /// Returns a [Stream<List<Feedback>>].
  Stream<List<Feedback>> getAllFeedback() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Feedback.fromFirestore(doc)).toList();
    });
  }

  /// Retrieves a stream of feedback items submitted by a specific user, ordered by timestamp descending.
  ///
  /// - [userId]: The ID of the user whose feedback is to be fetched.
  ///
  /// Returns a [Stream<List<Feedback>>].
  Stream<List<Feedback>> getFeedbackByUser(String userId) {
    return _firestore
        .collection(_collectionPath)
        .where('userId', isEqualTo: userId)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Feedback.fromFirestore(doc)).toList();
    });
  }

  /// Retrieves a stream of feedback items filtered by their addressed status, ordered by timestamp descending.
  ///
  /// - [isAddressed]: `true` to fetch addressed feedback, `false` for pending feedback.
  ///
  /// Returns a [Stream<List<Feedback>>].
  Stream<List<Feedback>> getFeedbackByStatus(bool isAddressed) {
    return _firestore
        .collection(_collectionPath)
        .where('isAddressed', isEqualTo: isAddressed)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Feedback.fromFirestore(doc)).toList();
    });
  }

  /// Marks a feedback item as addressed and optionally adds admin notes.
  ///
  /// Sets `isAddressed` to `true` and updates `adminNotes`.
  ///
  /// - [feedbackId]: The ID of the feedback item to update.
  /// - [adminNotes]: Notes from the admin regarding how the feedback was addressed. Can be empty.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> markAsAddressed(String feedbackId, String adminNotes) async {
    try {
      await _firestore.collection(_collectionPath).doc(feedbackId).update({
        'isAddressed': true,
        'adminNotes': adminNotes,
      });
    } catch (e) {
      print('Error marking feedback $feedbackId as addressed: $e');
      rethrow;
    }
  }

  /// Updates the admin notes for an already addressed feedback item.
  ///
  /// - [feedbackId]: The ID of the feedback item whose notes are to be updated.
  /// - [adminNotes]: The new or updated notes from the admin.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> updateAdminNotes(String feedbackId, String adminNotes) async {
      try {
          await _firestore.collection(_collectionPath).doc(feedbackId).update({
              'adminNotes': adminNotes,
          });
      } catch (e) {
          print('Error updating admin notes on feedback $feedbackId: $e');
          rethrow;
      }
  }

  /// Permanently deletes a feedback item from Firestore.
  ///
  /// This is an administrative action and should be used with caution.
  ///
  /// - [feedbackId]: The ID of the feedback item to delete.
  ///
  /// Rethrows any [FirebaseException] or other errors.
  Future<void> deleteFeedback(String feedbackId) async {
    try {
      await _firestore.collection(_collectionPath).doc(feedbackId).delete();
    } catch (e) {
      print('Error deleting feedback $feedbackId: $e');
      rethrow;
    }
  }
}
