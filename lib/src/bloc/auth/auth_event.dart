part of 'auth_bloc.dart';

abstract class AuthEvent extends Equatable {
  @override
  List<Object> get props => [];
}

class LoginEvent extends AuthEvent {
  final String email;
  final String password;

  LoginEvent(this.email, this.password);
}

class LogoutEvent extends AuthEvent {}

class RegisterEvent extends AuthEvent {
  final String email;
  final String password;
  final String name;
  final String role;
  final bool isFirstLogin;
  final String createdBy;
  final String createdAt;
  final String deviceId;

  RegisterEvent(this.email, this.password, this.name, this.role, this.isFirstLogin, this.createdBy, this.createdAt, this.deviceId);
}

class RegisterPendingEvent extends AuthEvent {
  final String email;
  final String password;
  final String deviceId;

  RegisterPendingEvent(this.email,  this.password, this.deviceId);

}

class UpdatePasswordEvent extends AuthEvent {
  final String newPassword;

  UpdatePasswordEvent(this.newPassword);
}