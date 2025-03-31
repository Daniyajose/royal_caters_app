import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../repositories/auth_repository.dart';

part 'auth_event.dart';
part 'auth_state.dart';

class AuthBloc extends Bloc<AuthEvent, AuthState> {
  final AuthRepository authRepository;

  AuthBloc({required this.authRepository}) : super(AuthInitial()) {
    on<LoginEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authRepository.signIn(event.email, event.password);
        if (user != null) {
          final needsChange = await authRepository.checkPasswordChange(user.uid);
          final userRole = await authRepository.getCurrentUserRole(user.uid);
          emit(AuthAuthenticated(user, userRole, needsChange));
        }
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });

    on<LogoutEvent>((event, emit) async {
      await authRepository.signOut();
      emit(AuthInitial());
    });

    on<RegisterEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authRepository.registerUser(
          event.email,
          event.password,
          event.name,
          event.role,
          event.isFirstLogin,
          event.createdBy,
          event.createdAt,
          event.deviceId,
        );
        if (user != null) {
          emit(AuthRegistered());
        } else {
          emit(AuthError("Registration failed. Please try again."));
        }
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });


    on<RegisterPendingEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        final user = await authRepository.registerFromPending(event.email, event.password, event.deviceId);
        if (user != null) {
          final needsChange = await authRepository.checkPasswordChange(user.uid);
          final role = await authRepository.getCurrentUserRole(user.uid);
          emit(AuthAuthenticated(user, role,needsChange));
        }
      } catch (e) {
        emit(AuthError( "Authentication failed: $e"));
      }
    });

    on<UpdatePasswordEvent>((event, emit) async {
      emit(AuthLoading());
      try {
        await authRepository.updatePassword(event.newPassword);
        emit(PasswordUpdated());
      } catch (e) {
        emit(AuthError(e.toString()));
      }
    });
  }
}