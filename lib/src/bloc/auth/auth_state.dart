part of 'auth_bloc.dart';

abstract class AuthState extends Equatable {
  @override
  List<Object> get props => [];
}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthAuthenticated extends AuthState {
  final User user;
  final String role;
  final bool isFirstLogin;

  AuthAuthenticated(this.user, this.role, this.isFirstLogin);

  @override
  List<Object> get props => [user, role, isFirstLogin];
}

class AuthRegistered extends AuthState {}

class PasswordUpdated extends AuthState {}

class AuthError extends AuthState {
  final String message;

  AuthError(this.message);

  @override
  List<Object> get props => [message];
}