import '../entities/investor.dart';
import '../repositories/investor_repository.dart';

class GetAllInvestors {
  final InvestorRepository repository;

  GetAllInvestors(this.repository);

  Future<List<Investor>> call(String userId) async {
    return await repository.getAllInvestors(userId);
  }
} 