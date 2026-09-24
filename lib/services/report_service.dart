import 'dart:convert';

import 'package:share_plus/share_plus.dart';

import '../core/formatters.dart';
import '../data/models/category.dart';
import '../data/models/transaction.dart';
import 'analytics.dart';

/// Builds spending reports and exports them as CSV (opens the share sheet
/// on mobile, downloads on the Web).
class ReportService {
  ReportService._();

  static String buildCsv({
    required List<TransactionRecord> txs,
    required Map<String, Category> categories,
    required DateTime from,
    required DateTime to,
    required String currency,
  }) {
    final summary = Analytics.summarize(txs);
    final byCat = Analytics.spendByCategory(txs);
    String esc(String? v) => '"${(v ?? '').replaceAll('"', '""')}"';
    final b = StringBuffer()
      ..writeln('PennyPal spending report')
      ..writeln('Period,${Fmt.isoDate(from)},${Fmt.isoDate(to)}')
      ..writeln('Currency,$currency')
      ..writeln()
      ..writeln('Total income,${summary.income.toStringAsFixed(2)}')
      ..writeln('Total expenses,${summary.expense.toStringAsFixed(2)}')
      ..writeln('Net balance,${summary.balance.toStringAsFixed(2)}')
      ..writeln()
      ..writeln('Category,Amount,Share');
    byCat.forEach((id, amount) {
      final share = summary.expense == 0 ? 0 : amount / summary.expense * 100;
      b.writeln(
          '${esc(categories[id]?.name ?? 'Other')},${amount.toStringAsFixed(2)},${share.toStringAsFixed(1)}%');
    });
    b
      ..writeln()
      ..writeln('Date,Type,Category/Source,Description,Payment mode,Amount');
    for (final t in txs) {
      b.writeln([
        t.date,
        t.type,
        esc(t.isIncome ? t.source : categories[t.categoryId]?.name),
        esc(t.description),
        esc(t.paymentMode),
        (t.isIncome ? t.amount : -t.amount).toStringAsFixed(2),
      ].join(','));
    }
    return b.toString();
  }

  static Future<String> share(String csv, String fileName) async {
    final file = XFile.fromData(utf8.encode(csv),
        mimeType: 'text/csv', name: fileName);
    await Share.shareXFiles([file],
        subject: 'PennyPal report', text: 'My PennyPal spending report');
    return fileName;
  }
}
