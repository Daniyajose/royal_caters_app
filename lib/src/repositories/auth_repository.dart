import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

class AuthRepository {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<User?> signIn(String email, String password) async {
    try {
      UserCredential userCredential = await _auth.signInWithEmailAndPassword(email: email, password: password);
      await saveUserToken(userCredential.user!.uid);
      return userCredential.user;
    } catch (e) {
      // Check if user exists in pending_users and prompt registration
      DocumentSnapshot pendingUserDoc = await _firestore.collection('pending_users').doc(email).get();
      if (pendingUserDoc.exists && pendingUserDoc['password'] == password) {
        throw Exception("User not registered yet. Please register with the temporary password.");
      }
      throw Exception("Login failed: $e");
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }

  Future<bool> isFirstUser() async {
    QuerySnapshot users = await _firestore.collection('users').get();
    return users.docs.isEmpty;
  }

  Future<User?> registerUser(String email, String password, String name, String role, bool isFirstLogin, String createdBy, String createdAt, String deviceId) async {
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    String fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'name': name,
      'role': role,
      'isActive': true,
      'isFirstLogin': isFirstLogin,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'deviceId': deviceId,
      'fcmToken': fcmToken,
      'lastFcmUpdated': FieldValue.serverTimestamp(),
    });
    return userCredential.user;
  }

  Future<User?> registerFromPending(String email, String password,String deviceId) async {
    DocumentSnapshot pendingUserDoc = await _firestore.collection('pending_users').doc(email).get();
    if (!pendingUserDoc.exists || pendingUserDoc['password'] != password) {
      throw Exception("Invalid temporary credentials or user not found.");
    }

    final data = pendingUserDoc.data() as Map<String, dynamic>;
    UserCredential userCredential = await _auth.createUserWithEmailAndPassword(email: email, password: password);
    String fcmToken = await FirebaseMessaging.instance.getToken() ?? '';
    await _firestore.collection('users').doc(userCredential.user!.uid).set({
      'email': email,
      'name': data['name'],
      'role': data['role'],
      'isActive': true,
      'isFirstLogin': data['isFirstLogin'],
      'createdBy': data['createdBy'],
      'createdAt': data['createdAt'],
      'deviceId': deviceId,
      'fcmToken': fcmToken,
      'lastFcmUpdated': FieldValue.serverTimestamp(),
    });
    // Delete from pending_users after successful registration
    await _firestore.collection('pending_users').doc(email).delete();
    return userCredential.user;
  }

  Future<void> saveUserToken(String userId) async {
    String? token = await FirebaseMessaging.instance.getToken();
    if (token != null) {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': token,
        'lastFcmUpdated': FieldValue.serverTimestamp(),
      });
    }
  }

  Future<bool> checkPasswordChange(String userId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    return doc['isFirstLogin'] ?? true;
  }

  Future<String> getCurrentUserRole(String userId) async {
    DocumentSnapshot doc = await _firestore.collection('users').doc(userId).get();
    return doc['role'] ?? 'staff';
  }

  Future<void> updatePassword(String newPassword) async {
    User? user = _auth.currentUser;
    if (user != null) {
      await user.updatePassword(newPassword);
      await _firestore.collection('users').doc(user.uid).update({'isFirstLogin': false});
    }
  }

  Future<bool> doesUserExist(String email) async {
    QuerySnapshot userDocs = await _firestore.collection('users').where('email', isEqualTo: email).get();
    return userDocs.docs.isNotEmpty;
  }
}