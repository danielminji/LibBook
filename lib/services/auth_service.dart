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
} 