import '../entities/investor.dart';

abstract class InvestorRepository {
  Future<List<Investor>> getAllInvestors(String userId);
  Future<Investor?> getInvestorById(String id);
  Future<String> createInvestor(Investor investor);
  Future<void> updateInvestor(Investor investor);
  Future<void> deleteInvestor(String id);
  Future<List<Investor>> searchInvestors(String userId, String query);
} 