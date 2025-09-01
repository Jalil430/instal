import 'package:intl/intl.dart';

/// Returns currency string without trailing ",00"/".00" when amount has no cents.
/// Keeps the currency symbol and spacing intact.
String stripTrailingZeroMoney(String formatted) {
  // Matches ',00' or '.00' right before optional space + currency symbol at end.
  final regex = RegExp(r'([\.,]00)(\s?[\p{Sc}₽$€£])?$', unicode: true);
  return formatted.replaceFirstMapped(regex, (m) => m.group(2) ?? '');
}

/// Convenience: format amount with given locale/symbol and hide trailing zeros when not needed.
String formatMoneySmart(num amount, {required String locale, required String symbol}) {
  // Decide decimals dynamically to avoid floating artefacts.
  final double d = amount.toDouble();
  final bool hasCents = (d.toStringAsFixed(2).split('.').last != '00');
  final nf = NumberFormat.currency(locale: locale, symbol: symbol, decimalDigits: hasCents ? 2 : 0);
  return nf.format(d);
}

