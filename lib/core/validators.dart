/// Form validators shared by every screen. Each returns an error message,
/// or null when the value is valid (the contract Flutter's FormField expects).
class Validators {
  Validators._();

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$');
  static final _mobile = RegExp(r'^\+?[0-9]{7,15}$');

  static String? required(String? v, [String field = 'This field']) =>
      (v == null || v.trim().isEmpty) ? '$field is required' : null;

  static String? name(String? v) {
    final r = required(v, 'Name');
    if (r != null) return r;
    if (v!.trim().length < 2) return 'Name must have at least 2 characters';
    return null;
  }

  static String? email(String? v) {
    final r = required(v, 'Email');
    if (r != null) return r;
    return _email.hasMatch(v!.trim()) ? null : 'Enter a valid email address';
  }

  static String? mobile(String? v) {
    final r = required(v, 'Mobile number');
    if (r != null) return r;
    final cleaned = v!.replaceAll(RegExp(r'[\s-]'), '');
    return _mobile.hasMatch(cleaned)
        ? null
        : 'Enter 7-15 digits (a leading + is allowed)';
  }

  /// Password rules: at least 8 characters with upper case, lower case,
  /// a digit and a symbol.
  static String? password(String? v) {
    if (v == null || v.isEmpty) return 'Password is required';
    final problems = <String>[];
    if (v.length < 8) problems.add('8+ characters');
    if (!v.contains(RegExp(r'[A-Z]'))) problems.add('an upper-case letter');
    if (!v.contains(RegExp(r'[a-z]'))) problems.add('a lower-case letter');
    if (!v.contains(RegExp(r'[0-9]'))) problems.add('a number');
    if (!v.contains(RegExp(r'[^A-Za-z0-9]'))) problems.add('a symbol');
    return problems.isEmpty ? null : 'Password needs ${problems.join(', ')}';
  }

  static String? confirm(String? v, String original) {
    if (v == null || v.isEmpty) return 'Please confirm your password';
    return v == original ? null : 'Passwords do not match';
  }

  static String? amount(String? v, {bool allowZero = false}) {
    final r = required(v, 'Amount');
    if (r != null) return r;
    final value = double.tryParse(v!.trim().replaceAll(',', ''));
    if (value == null) return 'Enter a number, e.g. 12.50';
    if (value < 0 || (!allowZero && value == 0)) {
      return 'Amount must be greater than zero';
    }
    if (value > 1000000000) return 'Amount is too large';
    return null;
  }

  static double parseAmount(String v) =>
      double.parse(v.trim().replaceAll(',', ''));
}
