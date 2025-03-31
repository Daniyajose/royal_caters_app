import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../model/user_model.dart';

class UserRepository {
  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  UserRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<List<UserModel>> getUsers() async {
    try {
      QuerySnapshot querySnapshot = await _firestore
          .collection('users')
          .where('isActive', isEqualTo: true) // Only fetch active users
          .get();
      return querySnapshot.docs.map((doc) => UserModel.fromMap(doc.id, doc.data() as Map<String, dynamic>)).toList();
    } catch (e) {
      throw Exception("Failed to fetch users: $e");
    }
  }

  Future<void> addUser(String email, String name, String role, bool isFirstLogin, String createdBy, String createdAt, String deviceId) async {
    try {
      // Store user details in pending_users collection
      await _firestore.collection('pending_users').doc(email).set({
        'email': email,
        'name': name,
        'role': role,
        'password': 'temp@123', // Temporary password
        'isFirstLogin': isFirstLogin,
        'createdBy': createdBy,
        'createdAt': createdAt,
        'deviceId': deviceId,
      });
    } catch (e) {
      throw Exception("Failed to add user: $e");
    }
  }

  Future<void> deleteUser(String userId, String requesterRole, {bool isPending = false}) async {
    try {
      if (isPending) {
        // Delete from pending_users
        DocumentSnapshot pendingDoc = await _firestore.collection('pending_users').doc(userId).get();
        if (!pendingDoc.exists) throw Exception("Pending user not found.");
        String userRole = pendingDoc['role'];
        print('roles pending $userRole , $requesterRole , $isPending');
        if (requesterRole == 'super_admin' || (requesterRole == 'admin' && userRole == 'staff')) {
          await _firestore.collection('pending_users').doc(userId).delete();
          if (_auth.currentUser?.uid == userId) await _auth.signOut();
        }else {
          throw Exception("Permission denied.");
        }
      } else {
        // Delete from users (soft delete by setting isActive to false)
        DocumentSnapshot userDoc = await _firestore.collection('users').doc(userId).get();
        if (!userDoc.exists) throw Exception("User not found.");

        String userRole = userDoc['role'];
        print('roles pending $userRole , $requesterRole , $isPending');
        if (requesterRole == 'super_admin' || (requesterRole == 'admin' && userRole == 'staff')) {
          await _firestore.collection('users').doc(userId).update({'isActive': false});
          if (_auth.currentUser?.uid == userId) await _auth.signOut();
        } else {
          throw Exception("Permission denied.");
        }
      }
    } catch (e) {
      throw Exception("Failed to delete user: $e");
    }
  }
}