import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../features/auth/presentation/widgets/auth_service_provider.dart';

class AuthGuard extends StatefulWidget {
  final Widget child;
  
  const AuthGuard({super.key, required this.child});

  @override
  State<AuthGuard> createState() => _AuthGuardState();
}

class _AuthGuardState extends State<AuthGuard> {
  late final AuthService _authService;
  StreamSubscription? _authSubscription;
  bool _isChecking = true;
  bool _isAuthenticated = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _authService = AuthServiceProvider.of(context);
    _subscribeToAuthStream();
      _checkAuthentication();
    }

  void _subscribeToAuthStream() {
    _authSubscription?.cancel();
    _authSubscription = _authService.authStateStream.listen((authState) {
      if (mounted) {
        final isAuthenticated = authState.isAuthenticated;
        if (_isAuthenticated != isAuthenticated) {
        setState(() {
          _isAuthenticated = isAuthenticated;
        });
        if (!isAuthenticated) {
              context.go('/auth/login');
            }
        }
      }
          });
        }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _checkAuthentication() async {
    final isAuthenticated = await _authService.isAuthenticated();
      if (mounted) {
        setState(() {
        _isAuthenticated = isAuthenticated;
          _isChecking = false;
        });
      if (!isAuthenticated) {
            context.go('/auth/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isChecking) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // When not authenticated, GoRouter's redirect will handle navigation.
    // A placeholder is returned to avoid rendering the child.
    return _isAuthenticated ? widget.child : const SizedBox.shrink();
  }
} 