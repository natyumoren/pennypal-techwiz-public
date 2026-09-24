import 'package:intl/intl.dart';

/// Currency / date helpers. Dates are stored as ISO strings in SQLite.
class Fmt {
  Fmt._();

  static const currencies = <String, String>{
    'USD': '\$',
    'EUR': '€',
    'GBP': '£',
    'INR': '₹',
    'NGN': '₦',
    'PKR': 'Rs ',
    'KES': 'KSh ',
    'ZAR': 'R ',
    'AED': 'AED ',
  };

  static String money(double value, [String currency = 'USD']) {
    final f = NumberFormat.currency(
        symbol: currencies[currency] ?? '$currency ', decimalDigits: 2);
    return f.format(value);
  }

  static String compactMoney(double value, [String currency = 'USD']) {
    final f = NumberFormat.compactCurrency(
        symbol: currencies[currency] ?? '$currency ', decimalDigits: 1);
    return value.abs() < 10000 ? money(value, currency) : f.format(value);
  }

  static String isoDate(DateTime d) => DateFormat('yyyy-MM-dd').format(d);
  static String monthKey(DateTime d) => DateFormat('yyyy-MM').format(d);
  static String nowIso() => DateTime.now().toIso8601String();

  static String prettyDate(String iso) =>
      DateFormat('d MMM yyyy').format(DateTime.parse(iso));
  static String shortDate(DateTime d) => DateFormat('d MMM').format(d);
  static String monthLabel(String monthKey) =>
      DateFormat('MMMM yyyy').format(DateTime.parse('$monthKey-01'));
  static String shortMonth(String monthKey) =>
      DateFormat('MMM').format(DateTime.parse('$monthKey-01'));
  static String timeAgo(String iso) {
    final diff = DateTime.now().difference(DateTime.parse(iso));
    if (diff.inMinutes < 1) return 'just now';
    if (diff.inHours < 1) return '${diff.inMinutes} min ago';
    if (diff.inDays < 1) return '${diff.inHours} h ago';
    if (diff.inDays < 7) return '${diff.inDays} d ago';
    return prettyDate(iso);
  }

  static String percent(double ratio) => '${(ratio * 100).round()}%';
}
