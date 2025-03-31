import 'package:cloud_firestore/cloud_firestore.dart';

class UserModel {
  final String id;
  final String email;
  final String name;
  final String role;
  final bool isActive;
  final bool isFirstLogin;
  final String createdBy;
  final String createdAt;
  final String deviceId;
  final String fcmToken;
  final String lastFcmUpdated;

  UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.role,
    required this.isActive,
    required this.isFirstLogin,
    required this.createdBy,
    required this.createdAt,
    required this.deviceId,
    required this.fcmToken,
    required this.lastFcmUpdated,
  });

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    return UserModel(
      id: id,
      email: data['email'] ?? '',
      name: data['name'] ?? '',
      role: data['role'] ?? 'staff',
      isActive: data['isActive'],
      isFirstLogin: data['isFirstLogin'],
      createdBy: data['createdBy'] ?? '',
      createdAt: data['createdAt'] ?? '',
      deviceId: data['deviceId'] ?? '',
      fcmToken: data['fcmToken'] ?? '',
      lastFcmUpdated: data['lastFcmUpdated'] is Timestamp
          ? (data['lastFcmUpdated'] as Timestamp).toDate().toIso8601String()
          : data['lastFcmUpdated'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'email': email,
      'name': name,
      'role': role,
      'isActive': isActive,
      'isFirstLogin': isFirstLogin,
      'createdBy': createdBy,
      'createdAt': createdAt,
      'deviceId': deviceId,
      'fcmToken': fcmToken,
      'lastFcmUpdated': lastFcmUpdated,
    };
  }
}
