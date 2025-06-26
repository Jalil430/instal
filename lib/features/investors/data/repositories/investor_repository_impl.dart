import '../../domain/entities/investor.dart';
import '../../domain/repositories/investor_repository.dart';
import '../datasources/investor_local_datasource.dart';
import '../models/investor_model.dart';

class InvestorRepositoryImpl implements InvestorRepository {
  final InvestorLocalDataSource _localDataSource;

  InvestorRepositoryImpl(this._localDataSource);

  @override
  Future<List<Investor>> getAllInvestors(String userId) async {
    final investorModels = await _localDataSource.getAllInvestors(userId);
    return investorModels.cast<Investor>();
  }

  @override
  Future<Investor?> getInvestorById(String id) async {
    final investorModel = await _localDataSource.getInvestorById(id);
    return investorModel;
  }

  @override
  Future<String> createInvestor(Investor investor) async {
    final investorModel = InvestorModel.fromEntity(investor);
    return await _localDataSource.createInvestor(investorModel);
  }

  @override
  Future<void> updateInvestor(Investor investor) async {
    final investorModel = InvestorModel.fromEntity(investor);
    await _localDataSource.updateInvestor(investorModel);
  }

  @override
  Future<void> deleteInvestor(String id) async {
    await _localDataSource.deleteInvestor(id);
  }

  @override
  Future<List<Investor>> searchInvestors(String userId, String query) async {
    final investorModels = await _localDataSource.searchInvestors(userId, query);
    return investorModels.cast<Investor>();
  }
} 