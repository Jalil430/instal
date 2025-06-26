import '../entities/installment_payment.dart';

class PaymentStatusService {
  static const String statusPaid = 'оплачено';
  static const String statusUpcoming = 'предстоящий';
  static const String statusDue = 'к оплате';
  static const String statusOverdue = 'просрочено';

  /// Calculate the status of a payment based on its due date and paid amount
  static String calculatePaymentStatus(InstallmentPayment payment) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final dueDate = DateTime(payment.dueDate.year, payment.dueDate.month, payment.dueDate.day);
    
    // If payment is fully paid
    if (payment.paidAmount >= payment.expectedAmount) {
      return statusPaid;
    }
    
    // Calculate days difference
    final daysDifference = today.difference(dueDate).inDays;
    
    if (daysDifference > 2) {
      // More than 2 days overdue
      return statusOverdue;
    } else if (daysDifference >= 0) {
      // Due today or yesterday (0-2 days)
      return statusDue;
    } else {
      // Future payment
      return statusUpcoming;
    }
  }

  /// Update payment status for a single payment
  static InstallmentPayment updatePaymentStatus(InstallmentPayment payment) {
    final newStatus = calculatePaymentStatus(payment);
    if (payment.status != newStatus) {
      return payment.copyWith(
        status: newStatus,
        updatedAt: DateTime.now(),
      );
    }
    return payment;
  }

  /// Update payment statuses for a list of payments
  static List<InstallmentPayment> updatePaymentStatuses(List<InstallmentPayment> payments) {
    return payments.map((payment) => updatePaymentStatus(payment)).toList();
  }

  /// Check if a payment is overdue
  static bool isPaymentOverdue(InstallmentPayment payment) {
    return calculatePaymentStatus(payment) == statusOverdue;
  }

  /// Check if a payment is due
  static bool isPaymentDue(InstallmentPayment payment) {
    return calculatePaymentStatus(payment) == statusDue;
  }

  /// Get payments that need status updates
  static List<InstallmentPayment> getPaymentsNeedingStatusUpdate(List<InstallmentPayment> payments) {
    return payments.where((payment) {
      final currentStatus = payment.status;
      final calculatedStatus = calculatePaymentStatus(payment);
      return currentStatus != calculatedStatus;
    }).toList();
  }

  /// Calculate total paid amount for an installment
  static double calculateTotalPaidAmount(List<InstallmentPayment> payments) {
    return payments.fold(0.0, (sum, payment) => sum + payment.paidAmount);
  }

  /// Calculate total expected amount for an installment
  static double calculateTotalExpectedAmount(List<InstallmentPayment> payments) {
    return payments.fold(0.0, (sum, payment) => sum + payment.expectedAmount);
  }

  /// Calculate remaining amount for an installment
  static double calculateRemainingAmount(List<InstallmentPayment> payments) {
    return calculateTotalExpectedAmount(payments) - calculateTotalPaidAmount(payments);
  }

  /// Get next payment due
  static InstallmentPayment? getNextPaymentDue(List<InstallmentPayment> payments) {
    final unpaidPayments = payments.where((payment) => 
        payment.paidAmount < payment.expectedAmount).toList();
    
    if (unpaidPayments.isEmpty) return null;
    
    unpaidPayments.sort((a, b) => a.dueDate.compareTo(b.dueDate));
    return unpaidPayments.first;
  }
} 