import '../entities/installment.dart';
import '../entities/installment_payment.dart';
import '../repositories/installment_repository.dart';

class CreateInstallment {
  final InstallmentRepository repository;

  CreateInstallment(this.repository);

  Future<void> call({
    required String userId,
    required String clientId,
    required String investorId,
    required String productName,
    required double cashPrice,
    required double installmentPrice,
    required int termMonths,
    required double downPayment,
    required double monthlyPayment,
    required DateTime downPaymentDate,
    required DateTime installmentStartDate,
  }) async {
    final installmentId = DateTime.now().millisecondsSinceEpoch.toString();
    
    // Calculate installment end date (date of last monthly payment)
    final monthlyPaymentsCount = downPayment > 0 ? termMonths - 1 : termMonths;
    final monthsToAdd = monthlyPaymentsCount - 1;
    final installmentEndDate = DateTime(
      installmentStartDate.year,
      installmentStartDate.month + monthsToAdd,
      installmentStartDate.day,
    );

    final installment = Installment(
      id: installmentId,
      userId: userId,
      clientId: clientId,
      investorId: investorId,
      productName: productName,
      cashPrice: cashPrice,
      installmentPrice: installmentPrice,
      termMonths: termMonths,
      downPayment: downPayment,
      monthlyPayment: monthlyPayment,
      downPaymentDate: downPaymentDate,
      installmentStartDate: installmentStartDate,
      installmentEndDate: installmentEndDate,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );

    // Generate payment schedule
    final payments = _generatePaymentSchedule(
      installmentId: installmentId,
      downPayment: downPayment,
      monthlyPayment: monthlyPayment,
      downPaymentDate: downPaymentDate,
      installmentStartDate: installmentStartDate,
      termMonths: termMonths,
    );

    await repository.createInstallment(installment);
    
    // Create all payments using the correct method name
    for (final payment in payments) {
      await repository.createPayment(payment);
    }
  }

  List<InstallmentPayment> _generatePaymentSchedule({
    required String installmentId,
    required double downPayment,
    required double monthlyPayment,
    required DateTime downPaymentDate,
    required DateTime installmentStartDate,
    required int termMonths,
  }) {
    final payments = <InstallmentPayment>[];
    final now = DateTime.now();

    // Create down payment if there is one
    if (downPayment > 0) {
      payments.add(InstallmentPayment(
        id: '${installmentId}_0',
        installmentId: installmentId,
        paymentNumber: 0,
        dueDate: downPaymentDate,
        expectedAmount: downPayment,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    // Create monthly payments
    // Correct logic: if there's a down payment, it counts as part of the term
    final monthlyPaymentsCount = downPayment > 0 ? termMonths - 1 : termMonths;
    
    for (int i = 1; i <= monthlyPaymentsCount; i++) {
      // Monthly payment 1: Always due on installment start date (monthsToAdd = 0)
      // Monthly payment 2: Due 1 month after installment start date (monthsToAdd = 1)
      // Monthly payment 3: Due 2 months after installment start date (monthsToAdd = 2)
      // Down payment does NOT affect monthly payment timing
      final monthsToAdd = i - 1;
      final totalMonths = installmentStartDate.month + monthsToAdd;
      final year = installmentStartDate.year + (totalMonths - 1) ~/ 12;
      final month = (totalMonths - 1) % 12 + 1;
      
      final dueDate = DateTime(
        year,
        month,
        installmentStartDate.day,
      );
      
      payments.add(InstallmentPayment(
        id: '${installmentId}_$i',
        installmentId: installmentId,
        paymentNumber: i,
        dueDate: dueDate,
        expectedAmount: monthlyPayment,
        isPaid: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      ));
    }

    return payments;
  }
} 