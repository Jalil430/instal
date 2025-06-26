import 'package:intl/intl.dart';

/// Format a DateTime object to a human-readable string
/// Returns a string in the format "dd MMMM yyyy" (e.g., "15 января 2023")
String formatDate(DateTime date) {
  return DateFormat('dd MMMM yyyy', 'ru').format(date);
}

/// Format a DateTime object to a short date string
/// Returns a string in the format "dd.MM.yyyy" (e.g., "15.01.2023")
String formatShortDate(DateTime date) {
  return DateFormat('dd.MM.yyyy', 'ru').format(date);
}

/// Calculate the number of months between two dates
int monthsBetween(DateTime from, DateTime to) {
  return (to.year - from.year) * 12 + to.month - from.month;
}

/// Calculate the next payment date based on a start date and payment number
DateTime calculatePaymentDate(DateTime startDate, int paymentNumber) {
  return DateTime(
    startDate.year,
    startDate.month + paymentNumber,
    startDate.day,
  );
}

/// Determine if a date is today
bool isToday(DateTime date) {
  final now = DateTime.now();
  return date.year == now.year && date.month == now.month && date.day == now.day;
}

/// Determine if a date is yesterday
bool isYesterday(DateTime date) {
  final yesterday = DateTime.now().subtract(const Duration(days: 1));
  return date.year == yesterday.year && 
         date.month == yesterday.month && 
         date.day == yesterday.day;
}

/// Determine if a date is in the past
bool isPast(DateTime date) {
  return date.isBefore(DateTime.now());
}

/// Determine if a date is overdue (more than 2 days in the past)
bool isOverdue(DateTime date) {
  final twoDaysAgo = DateTime.now().subtract(const Duration(days: 2));
  return date.isBefore(twoDaysAgo);
}

/// Calculate payment status based on due date and payment status
String calculatePaymentStatus(DateTime dueDate, bool isPaid) {
  if (isPaid) {
    return 'оплачено';
  }
  
  if (isOverdue(dueDate)) {
    return 'просрочено';
  }
  
  if (isToday(dueDate) || isYesterday(dueDate)) {
    return 'к оплате';
  }
  
  return 'предстоящий';
} 