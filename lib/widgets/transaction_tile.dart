import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/formatters.dart';
import '../core/theme.dart';
import '../data/models/transaction.dart';
import '../screens/student/transaction_form_screen.dart';
import '../state/finance_state.dart';
import 'common.dart';

class TransactionTile extends StatelessWidget {
  const TransactionTile({super.key, required this.transaction});
  final TransactionRecord transaction;

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final t = transaction;
    final cat = f.categoryOf(t);
    final title = t.isIncome
        ? (t.source ?? 'Income')
        : (t.description?.isNotEmpty == true ? t.description! : cat.name);
    final subtitle = [
      t.isIncome ? 'Income' : cat.name,
      Fmt.prettyDate(t.date),
      if (t.receiptImageUrl != null) '📎',
    ].join(' · ');
    return ListTile(
      leading: t.isIncome
          ? const CircleAvatar(
              backgroundColor: Color(0x221E8E4E),
              child: Icon(Icons.arrow_downward, color: AppTheme.income))
          : CategoryAvatar(cat),
      title: Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
      subtitle: Text(subtitle),
      trailing: Text(
        '${t.isIncome ? '+' : '−'}${Fmt.money(t.amount, f.currency)}',
        style: TextStyle(
            fontWeight: FontWeight.w700,
            color: t.isIncome ? AppTheme.income : AppTheme.expense),
      ),
      onTap: () => showTransactionDetails(context, t),
    );
  }
}

Future<void> showTransactionDetails(
    BuildContext context, TransactionRecord t) async {
  final f = context.read<FinanceState>();
  final cat = f.categoryOf(t);
  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              t.isIncome
                  ? const CircleAvatar(child: Icon(Icons.arrow_downward))
                  : CategoryAvatar(cat),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '${t.isIncome ? '+' : '−'}${Fmt.money(t.amount, f.currency)}',
                  style: TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: t.isIncome ? AppTheme.income : AppTheme.expense),
                ),
              ),
            ]),
            const SizedBox(height: 16),
            _row('Type', t.isIncome ? 'Income' : 'Expense'),
            if (t.isIncome) _row('Source', t.source ?? '-'),
            if (t.isExpense) _row('Category', cat.name),
            _row('Date', Fmt.prettyDate(t.date)),
            _row('Payment mode', t.paymentMode ?? '-'),
            _row('Description',
                t.description?.isNotEmpty == true ? t.description! : '-'),
            if (t.receiptImageUrl != null) ...[
              const SizedBox(height: 12),
              ReceiptImage(t.receiptImageUrl!),
            ],
            const SizedBox(height: 20),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Delete'),
                  style: OutlinedButton.styleFrom(
                      foregroundColor: AppTheme.expense),
                  onPressed: () async {
                    final ok = await confirmDialog(ctx,
                        title: 'Delete transaction?',
                        message: 'This record will be removed permanently.');
                    if (!ok) return;
                    await f.deleteTransaction(t);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      showSnack(context, 'Transaction deleted');
                    }
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  icon: const Icon(Icons.edit_outlined),
                  label: const Text('Edit'),
                  onPressed: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => TransactionFormScreen(
                                type: t.type, existing: t)));
                  },
                ),
              ),
            ]),
          ],
        ),
      ),
    ),
  );
}

Widget _row(String label, String value) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SizedBox(
            width: 120,
            child: Text(label, style: const TextStyle(color: Colors.grey))),
        Expanded(
            child: Text(value,
                style: const TextStyle(fontWeight: FontWeight.w600))),
      ]),
    );
