import 'package:flutter/material.dart';
import '../../domain/entities/auth_state.dart';
import '../../domain/entities/user.dart';
import '../../domain/usecases/login_user.dart';
import '../../domain/usecases/register_user.dart';
import '../../domain/usecases/logout_user.dart';
import '../../domain/usecases/get_current_user.dart';
import '../../domain/usecases/update_user.dart';
import '../../data/repositories/auth_repository_impl.dart';
import '../../data/datasources/auth_remote_datasource.dart';
import '../../data/datasources/auth_local_datasource.dart';

class AuthService {
  final LoginUser _loginUser;
  final RegisterUser _registerUser;
  final LogoutUser _logoutUser;
  final GetCurrentUser _getCurrentUser;
  final UpdateUser _updateUser;
  final AuthRepositoryImpl _repository;

  AuthService({
    required LoginUser loginUser,
    required RegisterUser registerUser,
    required LogoutUser logoutUser,
    required GetCurrentUser getCurrentUser,
    required UpdateUser updateUser,
    required AuthRepositoryImpl repository,
  })  : _loginUser = loginUser,
        _registerUser = registerUser,
        _logoutUser = logoutUser,
        _getCurrentUser = getCurrentUser,
        _updateUser = updateUser,
        _repository = repository;

  Future<AuthState> login({
    required String email,
    required String password,
  }) async {
    return await _loginUser(email: email, password: password);
  }

  Future<AuthState> register({
    required String email,
    required String password,
    required String fullName,
    String? phone,
  }) async {
    return await _registerUser(
      email: email,
      password: password,
      fullName: fullName,
      phone: phone,
    );
  }

  Future<void> logout() async {
    await _logoutUser();
  }

  Future<User?> getCurrentUser() async {
    return await _getCurrentUser();
  }

  Future<User> getCurrentUserFromServer() async {
    return await _repository.getCurrentUserFromServer();
  }

  Future<User> updateUser({
    required String userId,
    String? fullName,
    String? phone,
  }) async {
    return await _updateUser(
      userId: userId,
      fullName: fullName,
      phone: phone,
    );
  }

  Future<AuthState> getCurrentAuthState() async {
    return await _repository.getCurrentAuthState();
  }

  Future<bool> isAuthenticated() async {
    return await _repository.isAuthenticated();
  }

  Stream<AuthState> get authStateStream => _repository.authStateStream;

  Future<String?> getToken() async {
    final authState = await getCurrentAuthState();
    return authState.isAuthenticated ? authState.accessToken : null;
  }

  void dispose() {
    _repository.dispose();
  }
}

class AuthServiceProvider extends InheritedWidget {
  final AuthService authService;

  const AuthServiceProvider({
    super.key,
    required this.authService,
    required super.child,
  });

  static AuthService of(BuildContext context) {
    final AuthServiceProvider? result = context.dependOnInheritedWidgetOfExactType<AuthServiceProvider>();
    assert(result != null, 'No AuthServiceProvider found in context');
    return result!.authService;
  }

  @override
  bool updateShouldNotify(AuthServiceProvider oldWidget) {
    return authService != oldWidget.authService;
  }
}

class AuthServiceFactory {
  static AuthService create() {
    // Create data sources
    final remoteDataSource = AuthRemoteDataSourceImpl();
    final localDataSource = AuthLocalDataSourceImpl();

    // Create repository
    final repository = AuthRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );

    // Create use cases
    final loginUser = LoginUser(repository);
    final registerUser = RegisterUser(repository);
    final logoutUser = LogoutUser(repository);
    final getCurrentUser = GetCurrentUser(repository);
    final updateUser = UpdateUser(repository);

    // Create and return auth service
    return AuthService(
      loginUser: loginUser,
      registerUser: registerUser,
      logoutUser: logoutUser,
      getCurrentUser: getCurrentUser,
      updateUser: updateUser,
      repository: repository,
    );
  }
} 