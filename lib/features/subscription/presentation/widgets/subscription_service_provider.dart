import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/subscription_provider.dart';
import '../../domain/usecases/validate_subscription_code.dart';
import '../../domain/usecases/check_subscription_status.dart';
import '../../data/repositories/subscription_repository_impl.dart';
import '../../data/datasources/subscription_remote_datasource_impl.dart';
import '../../data/datasources/subscription_local_datasource_impl.dart';

class SubscriptionServiceFactory {
  static Future<SubscriptionProvider> create() async {
    // Initialize dependencies
    final sharedPreferences = await SharedPreferences.getInstance();
    
    // Create data sources
    final remoteDataSource = const SubscriptionRemoteDataSourceImpl();
    
    final localDataSource = SubscriptionLocalDataSourceImpl(
      sharedPreferences: sharedPreferences,
    );
    
    // Create repository
    final repository = SubscriptionRepositoryImpl(
      remoteDataSource: remoteDataSource,
      localDataSource: localDataSource,
    );
    
    // Create use cases
    final validateSubscriptionCode = ValidateSubscriptionCode(repository);
    final checkSubscriptionStatus = CheckSubscriptionStatus(repository);
    
    // Create and return provider
    return SubscriptionProvider(
      validateSubscriptionCode: validateSubscriptionCode,
      checkSubscriptionStatus: checkSubscriptionStatus,
    );
  }
}

class SubscriptionServiceProvider extends StatelessWidget {
  final SubscriptionProvider subscriptionProvider;
  final Widget child;

  const SubscriptionServiceProvider({
    super.key,
    required this.subscriptionProvider,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<SubscriptionProvider>.value(
      value: subscriptionProvider,
      child: child,
    );
  }

  static SubscriptionProvider of(BuildContext context) {
    return Provider.of<SubscriptionProvider>(context, listen: false);
  }
}