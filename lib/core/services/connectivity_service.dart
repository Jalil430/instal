import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Service to monitor network connectivity
class ConnectivityService {
  static final ConnectivityService _instance = ConnectivityService._internal();
  factory ConnectivityService() => _instance;
  ConnectivityService._internal();

  final StreamController<bool> _connectivityController = StreamController<bool>.broadcast();
  bool _isConnected = true;
  Timer? _connectivityTimer;

  /// Stream of connectivity status changes
  Stream<bool> get connectivityStream => _connectivityController.stream;

  /// Current connectivity status
  bool get isConnected => _isConnected;

  /// Initialize connectivity monitoring
  void initialize() {
    _startConnectivityMonitoring();
  }

  /// Start monitoring connectivity
  void _startConnectivityMonitoring() {
    // Check connectivity every 30 seconds
    _connectivityTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      _checkConnectivity();
    });

    // Initial check
    _checkConnectivity();
  }

  /// Check current connectivity status
  Future<void> _checkConnectivity() async {
    try {
      final result = await _hasInternetConnection();
      if (result != _isConnected) {
        _isConnected = result;
        _connectivityController.add(_isConnected);
      }
    } catch (e) {
      // If check fails, assume no connection
      if (_isConnected) {
        _isConnected = false;
        _connectivityController.add(_isConnected);
      }
    }
  }

  /// Test internet connection by attempting to reach a reliable host
  Future<bool> _hasInternetConnection() async {
    if (kIsWeb) {
      // For web, we can't easily test connectivity, so assume connected
      return true;
    }

    try {
      final result = await InternetAddress.lookup('google.com');
      return result.isNotEmpty && result[0].rawAddress.isNotEmpty;
    } on SocketException catch (_) {
      return false;
    } catch (_) {
      return false;
    }
  }

  /// Manually trigger connectivity check
  Future<bool> checkConnectivity() async {
    await _checkConnectivity();
    return _isConnected;
  }

  /// Dispose of resources
  void dispose() {
    _connectivityTimer?.cancel();
    _connectivityController.close();
  }
}

/// Widget that rebuilds based on connectivity status
class ConnectivityBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool isConnected) builder;
  final Widget? offlineWidget;

  const ConnectivityBuilder({
    super.key,
    required this.builder,
    this.offlineWidget,
  });

  @override
  State<ConnectivityBuilder> createState() => _ConnectivityBuilderState();
}

class _ConnectivityBuilderState extends State<ConnectivityBuilder> {
  late StreamSubscription<bool> _connectivitySubscription;
  bool _isConnected = true;

  @override
  void initState() {
    super.initState();
    final connectivityService = ConnectivityService();
    _isConnected = connectivityService.isConnected;
    
    _connectivitySubscription = connectivityService.connectivityStream.listen((isConnected) {
      if (mounted) {
        setState(() {
          _isConnected = isConnected;
        });
      }
    });
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_isConnected && widget.offlineWidget != null) {
      return widget.offlineWidget!;
    }
    
    return widget.builder(context, _isConnected);
  }
}