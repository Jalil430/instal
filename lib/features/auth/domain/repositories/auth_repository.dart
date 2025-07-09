import '../entities/auth_state.dart';
import '../entities/user.dart';

abstract class AuthRepository {
  /// Register a new user
  Future<AuthState> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  });

  /// Login with email and password
  Future<AuthState> login({
    required String email,
    required String password,
  });

  /// Refresh access token using refresh token
  Future<AuthState> refreshToken(String refreshToken);

  /// Verify current access token
  Future<bool> verifyToken(String accessToken);

  /// Logout user (clear stored tokens)
  Future<void> logout();

  /// Get current authentication state from storage
  Future<AuthState> getCurrentAuthState();

  /// Save authentication state to storage
  Future<void> saveAuthState(AuthState authState);

  /// Check if user is currently authenticated
  Future<bool> isAuthenticated();

  /// Get current user if authenticated
  Future<User?> getCurrentUser();

  /// Update user information (full name and phone only)
  Future<User> updateUser({
    required String userId,
    String? fullName,
    String? phone,
  });

  /// Get fresh user data from server
  Future<User> getCurrentUserFromServer();

  /// Stream of authentication state changes
  Stream<AuthState> get authStateStream;
} 