import 'package:equatable/equatable.dart';

abstract class UserEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoadUsers extends UserEvent {}

class AddUser extends UserEvent {
  final String email;
  final String name;
  final String role;
  final bool isFirstLogin;
  final String createdBy;
  final String createdAt;
  final String deviceId;

  AddUser({
    required this.email,
    required this.name,
    required this.role,
    required this.isFirstLogin,
    required this.createdBy,
    required this.createdAt,
    required this.deviceId,
  });

  @override
  List<Object> get props => [email, name, role];
}

class DeleteUser extends UserEvent {
  final String userId;
  final String requesterRole;
  final bool isPending;

  DeleteUser({required this.userId, required this.requesterRole, this.isPending = false});
}