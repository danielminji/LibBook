import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service responsible for handling user authentication with Firebase
/// and managing user data in Firestore.
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  /// Registers a new user with the provided email, password, and username.
  ///
  /// Upon successful Firebase authentication, it also creates a corresponding
  /// user document in Firestore via [createUserDocument].
  ///
  /// - [email]: The user's email address for registration.
  /// - [password]: The user's chosen password.
  /// - [username]: The user's chosen username.
  ///
  /// Returns a [UserCredential] object containing the user's information
  /// upon successful registration.
  ///
  /// Throws a [FirebaseAuthException] if Firebase registration fails (e.g.,
  /// email already in use, weak password). Other exceptions might occur
  /// if Firestore operations fail.
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

  /// Creates a user document in the Firestore 'users' collection.
  ///
  /// This document stores essential user information beyond Firebase Auth details.
  ///
  /// - [user]: The Firebase [User] object obtained after authentication.
  /// - [role]: The role to assign to the user (e.g., 'user', 'admin').
  /// - [username]: The username for the user.
  ///
  /// Initializes 'telegram_chat_id' to null.
  /// Sets 'createdAt' and 'lastLogin' timestamps to the current time.
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

  /// Signs in an existing user with their email and password.
  ///
  /// Updates the 'lastLogin' timestamp in the user's Firestore document
  /// upon successful sign-in.
  ///
  /// - [email]: The user's email address.
  /// - [password]: The user's password.
  ///
  /// Returns a [UserCredential] object if sign-in is successful.
  ///
  /// Throws a [FirebaseAuthException] for sign-in failures (e.g.,
  /// invalid credentials, user not found).
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

  /// Signs out the current Firebase user.
  ///
  /// This method calls Firebase Auth's `signOut` method.
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Retrieves the role of a user from their Firestore document.
  ///
  /// - [uid]: The unique ID of the user.
  ///
  /// Returns the user's role as a [String] if the document and role field exist,
  /// otherwise returns `null`. Returns `null` also if any error occurs during fetching.
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

  /// Updates the 'telegram_chat_id' field for a user in Firestore.
  ///
  /// - [userId]: The unique ID of the user whose Telegram chat ID is to be updated.
  /// - [chatId]: The new Telegram chat ID to store.
  ///
  /// Throws a [FirebaseException] or other errors if the Firestore update fails,
  /// which will be rethrown to the caller.
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

  /// Retrieves the 'telegram_chat_id' for a user from Firestore.
  ///
  /// - [userId]: The unique ID of the user.
  ///
  /// Returns the Telegram chat ID as a [String] if found, otherwise `null`.
  /// Returns `null` if any error occurs during fetching.
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

  /// Retrieves a user's entire document from the Firestore 'users' collection.
  ///
  /// - [uid]: The unique ID of the user.
  ///
  /// Returns a [DocumentSnapshot] containing the user's data if the document exists.
  /// Returns `null` if the document does not exist or an error occurs during fetching.
  Future<DocumentSnapshot?> getUserDocument(String uid) async {
    try {
      return await _firestore.collection('users').doc(uid).get();
    } catch (e) {
      print('Error getting user document: $e');
      return null;
    }
  }
} 