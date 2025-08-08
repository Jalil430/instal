import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../localization/app_localizations.dart';
import '../../features/auth/presentation/widgets/auth_service_provider.dart';
import '../../features/subscription/presentation/providers/subscription_provider.dart';
import '../../features/subscription/presentation/screens/subscription_screen.dart';

class SubscriptionGuard extends StatefulWidget {
  final Widget child;
  
  const SubscriptionGuard({super.key, required this.child});

  @override
  State<SubscriptionGuard> createState() => _SubscriptionGuardState();
}

class _SubscriptionGuardState extends State<SubscriptionGuard> {
  late final AuthService _authService;
  late final SubscriptionProvider _subscriptionProvider;
  StreamSubscription? _subscriptionSubscription;
  bool _isChecking = true;
  bool _hasActiveSubscription = false;
  bool _isServiceInitialized = false;
  Timer? _periodicTimer;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isServiceInitialized) {
      _authService = AuthServiceProvider.of(context);
      _subscriptionProvider = Provider.of<SubscriptionProvider>(context, listen: false);
      _subscribeToSubscriptionChanges();
      _checkSubscriptionStatus();
      _isServiceInitialized = true;
    }
  }

  void _subscribeToSubscriptionChanges() {
    // Listen to subscription provider changes
    _subscriptionProvider.addListener(_onSubscriptionStateChanged);
  }

  void _onSubscriptionStateChanged() {
    if (mounted) {
      final hasActive = _subscriptionProvider.hasActiveSubscription;
      if (_hasActiveSubscription != hasActive) {
        setState(() {
          _hasActiveSubscription = hasActive;
        });
      }
    }
  }

  @override
  void dispose() {
    _periodicTimer?.cancel();
    _subscriptionSubscription?.cancel();
    _subscriptionProvider.removeListener(_onSubscriptionStateChanged);
    super.dispose();
  }

  Future<void> _checkSubscriptionStatus() async {
    try {
      final user = await _authService.getCurrentUser();
      
      if (user != null && mounted) {
        // Check subscription status
        final state = await _subscriptionProvider.checkStatus(user.id);
        
        if (mounted) {
          setState(() {
            _hasActiveSubscription = _subscriptionProvider.hasActiveSubscription;
            _isChecking = false;
          });
        }

        // Start periodic silent checks every 3 hours
        _periodicTimer?.cancel();
        _periodicTimer = Timer.periodic(const Duration(hours: 3), (_) async {
          if (!mounted) return;
          final currentUser = await _authService.getCurrentUser();
          if (currentUser == null) return;
          await _subscriptionProvider.checkStatus(currentUser.id, silent: true);
        });
      } else if (mounted) {
        // User not authenticated, let AuthGuard handle this
        setState(() {
          _isChecking = false;
        });
      }
    } catch (e) {
      // If there's an error checking subscription, show subscription screen
      if (mounted) {
        setState(() {
          _hasActiveSubscription = false;
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return _buildBody();
  }

  Widget _buildBody() {
    if (_isChecking) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 28,
                height: 28,
                child: CircularProgressIndicator(strokeWidth: 3),
              ),
              const SizedBox(height: 12),
              Text(
                AppLocalizations.of(context)?.subscriptionCheckingStatus ?? 'Checking subscription...',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
            ],
          ),
        ),
      );
    }

    // If user has active subscription, show the main app
    if (_hasActiveSubscription) {
      return widget.child;
    }

    // If no active subscription, show subscription screen
    return ChangeNotifierProvider<SubscriptionProvider>.value(
      value: _subscriptionProvider,
      child: const SubscriptionScreen(),
    );
  }
}