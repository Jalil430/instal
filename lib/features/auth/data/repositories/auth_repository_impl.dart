import 'dart:async';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user.dart';
import '../../domain/repositories/auth_repository.dart';
import '../datasources/auth_local_datasource.dart';
import '../datasources/auth_remote_datasource.dart';

class AuthRepositoryImpl implements AuthRepository {
  final AuthRemoteDataSource remoteDataSource;
  final AuthLocalDataSource localDataSource;
  final StreamController<AuthState> _authStateController = StreamController<AuthState>.broadcast();

  AuthRepositoryImpl({
    required this.remoteDataSource,
    required this.localDataSource,
  });

  @override
  Future<AuthState> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    try {
      final authState = await remoteDataSource.register(
        email: email,
        password: password,
        fullName: fullName,
        phone: phone,
      );

      await _handleSuccessfulAuth(authState);
      return authState;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AuthState> login({
    required String email,
    required String password,
  }) async {
    try {
      final authState = await remoteDataSource.login(
        email: email,
        password: password,
      );

      await _handleSuccessfulAuth(authState);
      return authState;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<AuthState> refreshToken(String refreshToken) async {
    try {
      final authState = await remoteDataSource.refreshToken(refreshToken);
      await _handleSuccessfulAuth(authState);
      return authState;
    } catch (e) {
      // If refresh fails, logout the user
      await logout();
      rethrow;
    }
  }

  @override
  Future<bool> verifyToken(String accessToken) async {
    try {
      return await remoteDataSource.verifyToken(accessToken);
    } catch (e) {
      return false;
    }
  }

  @override
  Future<void> logout() async {
    try {
      // Clear stored authentication state
      await localDataSource.clearAuthState();
      
      // Emit unauthenticated state
      _authStateController.add(const AuthState.unauthenticated());
    } catch (e) {
      // Even if clearing fails, we should still emit unauthenticated state
      _authStateController.add(const AuthState.unauthenticated());
    }
  }

  @override
  Future<AuthState> getCurrentAuthState() async {
    try {
      final authState = await localDataSource.getAuthState();
      
      // No need for proactive refresh - tokens last 7 days
      
      return authState;
    } catch (e) {
      return const AuthState.unauthenticated();
    }
  }

  @override
  Future<void> saveAuthState(AuthState authState) async {
    try {
      await localDataSource.saveAuthState(authState);
      
      // Emit the new state
      _authStateController.add(authState);
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<bool> isAuthenticated() async {
    try {
      final authState = await getCurrentAuthState();
      return authState.isAuthenticated && !authState.isTokenExpired;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<User?> getCurrentUser() async {
    try {
      final authState = await getCurrentAuthState();
      return authState.isAuthenticated ? authState.user : null;
    } catch (e) {
      return null;
    }
  }

  @override
  Future<User> updateUser({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    try {
      final updatedUser = await remoteDataSource.updateUser(
        userId: userId,
        fullName: fullName,
        phone: phone,
      );

      // Update the current auth state with the new user info
      final currentAuthState = await getCurrentAuthState();
      if (currentAuthState.isAuthenticated) {
        final updatedAuthState = currentAuthState.copyWith(user: updatedUser);
        await saveAuthState(updatedAuthState);
      }

      return updatedUser;
    } catch (e) {
      rethrow;
    }
  }

  @override
  Future<User> getCurrentUserFromServer() async {
    try {
      return await remoteDataSource.getCurrentUserFromServer();
    } catch (e) {
      rethrow;
    }
  }

  @override
  Stream<AuthState> get authStateStream => _authStateController.stream;

  Future<void> _handleSuccessfulAuth(AuthState authState) async {
    // Save authentication state locally
    await saveAuthState(authState);
    
    // Log the auth state for debugging
    print('Auth state updated: $authState');
    
    // Emit the new authentication state
    _authStateController.add(authState);
  }

  void dispose() {
    _authStateController.close();
  }
} 