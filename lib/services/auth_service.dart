import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Sign up with email and password
  Future<UserCredential> registerWithEmailPassword({
    required String email,
    required String password,
    required String username,
  }) async {
    try {
      // Create user with email and password
      UserCredential userCredential = await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );

      // Create user document in Firestore
      await createUserDocument(userCredential.user!, 'user', username);
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Create user document in Firestore
  Future<void> createUserDocument(User user, String role, String username) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'username': username,
      'role': role,
      'createdAt': Timestamp.now(),
      'lastLogin': Timestamp.now(),
      'telegram_chat_id': null,
    });
  }

  // Sign in with email and password
  Future<UserCredential?> signInWithEmailPassword(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      
      // Update last login
      await _firestore.collection('users').doc(userCredential.user!.uid).update({
        'lastLogin': Timestamp.now(),
      });
      
      return userCredential;
    } catch (e) {
      rethrow;
    }
  }

  // Sign out
  Future<void> signOut() async {
    await _auth.signOut();
  }

  // Get user role
  Future<String?> getUserRole(String uid) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(uid).get();
      if (doc.exists) {
        return doc.get('role') as String?;
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  // Update Telegram chat ID
  Future<void> updateTelegramChatId(String userId, String chatId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'telegram_chat_id': chatId,
      });
    } catch (e) {
      // Consider logging the error or handling it more specifically
      print('Error updating Telegram chat ID: $e');
      rethrow;
    }
  }

  // Get user's Telegram Chat ID
  Future<String?> getUserTelegramChatId(String userId) async {
    try {
      DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
      if (doc.exists) {
        // Attempt to cast to Map<String, dynamic> first for safety
        var data = doc.data() as Map<String, dynamic>?;
        if (data != null && data.containsKey('telegram_chat_id')) {
          return data['telegram_chat_id'] as String?;
        }
      }
      return null;
    } catch (e) {
      print('Error getting user Telegram chat ID: $e');
      return null; // Or rethrow, depending on desired error handling
    }
  }

  Future<DocumentSnapshot?> getUserDocument(String uid) async {
    try {
      return await _firestore.collection('users').doc(uid).get();
    } catch (e) {
      print('Error getting user document: $e');
      return null;
    }
  }
} 