import '../entities/auth_state.dart';
import '../repositories/auth_repository.dart';

class LoginUser {
  final AuthRepository repository;

  LoginUser(this.repository);

  Future<AuthState> call({
    required String email,
    required String password,
  }) async {
    if (email.trim().isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }

    if (password.trim().isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }

    // Basic email validation
    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      throw ArgumentError('Please enter a valid email address');
    }

    return await repository.login(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }
} 