import '../repositories/installment_repository.dart';

class RegisterPayment {
  final InstallmentRepository repository;

  RegisterPayment(this.repository);

  Future<void> call({
    required String paymentId,
    required DateTime paidDate,
  }) async {
    final payment = await repository.getPaymentById(paymentId);
    if (payment == null) {
      throw Exception('Payment not found');
    }

    final updatedPayment = payment.copyWith(
      isPaid: true,
      paidDate: paidDate,
      updatedAt: DateTime.now(),
    );

    await repository.updatePayment(updatedPayment);
  }
} 