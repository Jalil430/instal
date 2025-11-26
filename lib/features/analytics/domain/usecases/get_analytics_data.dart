import 'package:instal_app/features/analytics/data/repositories/analytics_repository.dart';
import 'package:instal_app/features/analytics/domain/entities/analytics_data.dart';

class GetAnalyticsData {
  final AnalyticsRepository _repository;

  GetAnalyticsData(this._repository);

  Future<AnalyticsData> call(String userId, {String? walletId}) async {
    return await _repository.getAnalyticsData(userId, walletId: walletId);
  }
}
