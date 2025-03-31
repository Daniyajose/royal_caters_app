import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../repositories/user_repository.dart';
import 'user_event.dart';
import 'user_state.dart';

class UserBloc extends Bloc<UserEvent, UserState> {
  final UserRepository _userRepository;

  UserBloc({required UserRepository userRepository})
      : _userRepository = userRepository,
        super(UserLoading()) {
    on<LoadUsers>(_onLoadUsers);
    on<AddUser>(_onAddUser);
    on<DeleteUser>(_onDeleteUser);
  }

  Future<void> _onLoadUsers(LoadUsers event, Emitter<UserState> emit) async {
    emit(UserLoading());
    try {
      final users = await _userRepository.getUsers();
      final currentUserId = FirebaseAuth.instance.currentUser?.uid;
      if (currentUserId == null) {
        emit(UserError("No authenticated user found"));
        return;
      }
      final filteredUsers = users.where((user) => user.id != currentUserId).toList();
      emit(UserLoaded(filteredUsers));
    } catch (e) {
      emit(UserError("Failed to load users: $e"));
    }
  }

  Future<void> _onAddUser(AddUser event, Emitter<UserState> emit) async {
    try {
      await _userRepository.addUser(event.email, event.name, event.role, event.isFirstLogin, event.createdBy, event.createdAt, event.deviceId);
      add(LoadUsers());
    } catch (e) {
      emit(UserError("Failed to add user: $e"));
    }
  }

  Future<void> _onDeleteUser(DeleteUser event, Emitter<UserState> emit) async {
    try {
      await _userRepository.deleteUser(event.userId, event.requesterRole, isPending: event.isPending);
      add(LoadUsers());
    } catch (e) {
      emit(UserError("Failed to delete user: $e"));
    }
  }
}