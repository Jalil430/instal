import 'user.dart';

class AuthState {
  final User? user;
  final String? accessToken;
  final String? refreshToken;
  final DateTime? expiresAt;
  final bool isAuthenticated;

  const AuthState({
    this.user,
    this.accessToken,
    this.refreshToken,
    this.expiresAt,
    this.isAuthenticated = false,
  });

  // Initial unauthenticated state
  const AuthState.unauthenticated()
      : user = null,
        accessToken = null,
        refreshToken = null,
        expiresAt = null,
        isAuthenticated = false;

  // Authenticated state
  AuthState.authenticated({
    required User user,
    required String accessToken,
    required String refreshToken,
    required DateTime expiresAt,
  })  : user = user,
        accessToken = accessToken,
        refreshToken = refreshToken,
        expiresAt = expiresAt,
        isAuthenticated = true;

  AuthState copyWith({
    User? user,
    String? accessToken,
    String? refreshToken,
    DateTime? expiresAt,
    bool? isAuthenticated,
  }) {
    return AuthState(
      user: user ?? this.user,
      accessToken: accessToken ?? this.accessToken,
      refreshToken: refreshToken ?? this.refreshToken,
      expiresAt: expiresAt ?? this.expiresAt,
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
    );
  }

  bool get isTokenExpired {
    if (expiresAt == null) return true;
    return DateTime.now().isAfter(expiresAt!);
  }

  bool get needsRefresh {
    if (!isAuthenticated || expiresAt == null) return false;
    // Refresh if token expires in less than 10 minutes
    return DateTime.now().isAfter(expiresAt!.subtract(const Duration(minutes: 10)));
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    
    return other is AuthState &&
        other.user == user &&
        other.accessToken == accessToken &&
        other.refreshToken == refreshToken &&
        other.expiresAt == expiresAt &&
        other.isAuthenticated == isAuthenticated;
  }

  @override
  int get hashCode {
    return user.hashCode ^
        accessToken.hashCode ^
        refreshToken.hashCode ^
        expiresAt.hashCode ^
        isAuthenticated.hashCode;
  }

  @override
  String toString() {
    return 'AuthState(user: $user, accessToken: $accessToken, refreshToken: $refreshToken, expiresAt: $expiresAt, isAuthenticated: $isAuthenticated, needsRefresh: $needsRefresh)';
  }
} 