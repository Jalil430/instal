import '../../domain/entities/investor.dart';
import '../../domain/repositories/investor_repository.dart';
import '../datasources/investor_remote_datasource.dart';
import '../models/investor_model.dart';

class InvestorRepositoryImpl implements InvestorRepository {
  final InvestorRemoteDataSource _remoteDataSource;

  InvestorRepositoryImpl(this._remoteDataSource);

  @override
  Future<List<Investor>> getAllInvestors(String userId) async {
    final investorModels = await _remoteDataSource.getAllInvestors(userId);
    return investorModels.cast<Investor>();
  }

  @override
  Future<Investor?> getInvestorById(String id) async {
    final investorModel = await _remoteDataSource.getInvestorById(id);
    return investorModel;
  }

  @override
  Future<String> createInvestor(Investor investor) async {
    final investorModel = InvestorModel.fromEntity(investor);
    return await _remoteDataSource.createInvestor(investorModel);
  }

  @override
  Future<void> updateInvestor(Investor investor) async {
    final investorModel = InvestorModel.fromEntity(investor);
    await _remoteDataSource.updateInvestor(investorModel);
  }

  @override
  Future<void> deleteInvestor(String id) async {
    await _remoteDataSource.deleteInvestor(id);
  }

  @override
  Future<List<Investor>> searchInvestors(String userId, String query) async {
    final investorModels = await _remoteDataSource.searchInvestors(userId, query);
    return investorModels.cast<Investor>();
  }
} 