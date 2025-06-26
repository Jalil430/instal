import '../entities/installment.dart';
import '../repositories/installment_repository.dart';

class GetAllInstallments {
  final InstallmentRepository repository;

  GetAllInstallments(this.repository);

  Future<List<Installment>> call(String userId) async {
    return await repository.getAllInstallments(userId);
  }
} 