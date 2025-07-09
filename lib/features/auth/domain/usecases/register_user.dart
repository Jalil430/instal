import '../entities/auth_state.dart';
import '../repositories/auth_repository.dart';

class RegisterUser {
  final AuthRepository repository;

  RegisterUser(this.repository);

  Future<AuthState> call({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    // Validate email
    if (email.trim().isEmpty) {
      throw ArgumentError('Email cannot be empty');
    }

    final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
    if (!emailRegex.hasMatch(email.trim())) {
      throw ArgumentError('Please enter a valid email address');
    }

    // Validate password
    if (password.trim().isEmpty) {
      throw ArgumentError('Password cannot be empty');
    }

    if (password.length < 8) {
      throw ArgumentError('Password must be at least 8 characters long');
    }

    // Check for at least one letter and one number
    if (!RegExp(r'[A-Za-z]').hasMatch(password)) {
      throw ArgumentError('Password must contain at least one letter');
    }

    if (!RegExp(r'\d').hasMatch(password)) {
      throw ArgumentError('Password must contain at least one number');
    }

    // Validate full name
    if (fullName.trim().isEmpty) {
      throw ArgumentError('Full name cannot be empty');
    }

    if (fullName.trim().length < 2) {
      throw ArgumentError('Full name must be at least 2 characters long');
    }

    // Validate phone if provided
    if (phone != null && phone.trim().isNotEmpty) {
      if (phone.trim().length < 5) {
        throw ArgumentError('Phone number must be at least 5 characters long');
      }
    }

    return await repository.register(
      email: email.trim().toLowerCase(),
      password: password,
      fullName: fullName.trim(),
      phone: phone?.trim(),
    );
  }
} 