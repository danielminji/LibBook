import 'package:cloud_firestore/cloud_firestore.dart';

class Feedback {
  final String feedbackId; // Firestore document ID
  final String userId;
  final String userEmail; // Denormalized for convenience
  final String message;
  final String? category; // e.g., 'General', 'Bug Report', 'Suggestion'
  final Timestamp timestamp;
  bool isAddressed;
  String? adminNotes;

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

  factory Feedback.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return Feedback(
      feedbackId: doc.id,
      userId: data['userId'] ?? '',
      userEmail: data['userEmail'] ?? '',
      message: data['message'] ?? '',
      category: data['category'],
      timestamp: data['timestamp'] ?? Timestamp.now(),
      isAddressed: data['isAddressed'] ?? false,
      adminNotes: data['adminNotes'],
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'userEmail': userEmail,
      'message': message,
      'category': category,
      'timestamp': timestamp,
      'isAddressed': isAddressed,
      'adminNotes': adminNotes,
      // feedbackId is the document ID
    };
  }
}

class FeedbackService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final String _collectionPath = 'feedback';

  // Submit new feedback
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
      print('Error submitting feedback: $e');
      rethrow;
    }
  }

  // Get a stream of all feedback for admins, newest first
  Stream<List<Feedback>> getAllFeedback() {
    return _firestore
        .collection(_collectionPath)
        .orderBy('timestamp', descending: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs.map((doc) => Feedback.fromFirestore(doc)).toList();
    });
  }

  // Get a stream of feedback submitted by a specific user
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

  // Get a stream of feedback by addressed status
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

  // Mark feedback as addressed and add admin notes (Admin action)
  Future<void> markAsAddressed(String feedbackId, String adminNotes) async {
    try {
      await _firestore.collection(_collectionPath).doc(feedbackId).update({
        'isAddressed': true,
        'adminNotes': adminNotes,
      });
    } catch (e) {
      print('Error marking feedback as addressed: $e');
      rethrow;
    }
  }

  // Update admin notes on a feedback item (Admin action)
  Future<void> updateAdminNotes(String feedbackId, String adminNotes) async {
      try {
          await _firestore.collection(_collectionPath).doc(feedbackId).update({
              'adminNotes': adminNotes,
          });
      } catch (e) {
          print('Error updating admin notes on feedback: $e');
          rethrow;
      }
  }

  // Delete feedback (Admin action - optional)
  Future<void> deleteFeedback(String feedbackId) async {
    try {
      await _firestore.collection(_collectionPath).doc(feedbackId).delete();
    } catch (e) {
      print('Error deleting feedback: $e');
      rethrow;
    }
  }
}
