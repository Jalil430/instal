import '../entities/investor.dart';
import '../repositories/investor_repository.dart';

class CreateInvestor {
  final InvestorRepository repository;

  CreateInvestor(this.repository);

  Future<void> call({
    required String userId,
    required String fullName,
    required double investmentAmount,
    required double investorPercentage,
    required double userPercentage,
  }) async {
    final investor = Investor(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      userId: userId,
      fullName: fullName,
      investmentAmount: investmentAmount,
      investorPercentage: investorPercentage,
      userPercentage: userPercentage,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    await repository.createInvestor(investor);
  }
} 