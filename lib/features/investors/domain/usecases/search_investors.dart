import '../entities/investor.dart';
import '../repositories/investor_repository.dart';

class SearchInvestors {
  final InvestorRepository repository;

  SearchInvestors(this.repository);

  Future<List<Investor>> call(String userId, String query) async {
    return await repository.searchInvestors(userId, query);
  }
} 