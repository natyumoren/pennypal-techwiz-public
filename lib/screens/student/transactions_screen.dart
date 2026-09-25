import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../data/models/transaction.dart';
import '../../services/analytics.dart';
import '../../state/finance_state.dart';
import '../../widgets/common.dart';
import '../../widgets/transaction_tile.dart';

/// Transaction history with search and filters by date, category and type.
class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key});

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  final _search = TextEditingController();
  String _type = 'all'; // all | income | expense
  String? _categoryId;
  DateTimeRange? _range;

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  bool get _hasFilters =>
      _type != 'all' || _categoryId != null || _range != null || _search.text.isNotEmpty;

  List<TransactionRecord> _apply(FinanceState f) {
    final q = _search.text.trim().toLowerCase();
    return f.transactions.where((t) {
      if (_type != 'all' && t.type != _type) return false;
      if (_categoryId != null && t.categoryId != _categoryId) return false;
      if (_range != null) {
        final from = Fmt.isoDate(_range!.start), to = Fmt.isoDate(_range!.end);
        if (t.date.compareTo(from) < 0 || t.date.compareTo(to) > 0) return false;
      }
      if (q.isNotEmpty) {
        final hay = [
          t.description,
          t.source,
          f.categoryOf(t).name,
          t.paymentMode,
          t.amount.toStringAsFixed(2),
        ].whereType<String>().join(' ').toLowerCase();
        if (!hay.contains(q)) return false;
      }
      return true;
    }).toList();
  }

  Future<void> _pickRange() async {
    final now = DateTime.now();
    final r = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime(now.year + 1),
      initialDateRange: _range ??
          DateTimeRange(start: DateTime(now.year, now.month, 1), end: now),
    );
    if (r != null) setState(() => _range = r);
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final items = _apply(f);
    final summary = Analytics.summarize(items);

    // Group by date for readable daily sections.
    final groups = <String, List<TransactionRecord>>{};
    for (final t in items) {
      groups.putIfAbsent(t.date, () => []).add(t);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Transaction history')),
      body: ResponsiveBody(
        maxWidth: 900,
        child: Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: TextField(
              controller: _search,
              onChanged: (_) => setState(() {}),
              decoration: InputDecoration(
                hintText: 'Search description, source, category...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _search.text.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Clear search',
                        icon: const Icon(Icons.clear),
                        onPressed: () => setState(_search.clear)),
              ),
            ),
          ),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(children: [
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'all', label: Text('All')),
                  ButtonSegment(value: 'income', label: Text('Income')),
                  ButtonSegment(value: 'expense', label: Text('Expenses')),
                ],
                selected: {_type},
                showSelectedIcon: false,
                onSelectionChanged: (s) => setState(() {
                  _type = s.first;
                  if (_type == 'income') _categoryId = null;
                }),
              ),
              const SizedBox(width: 8),
              PopupMenuButton<String?>(
                tooltip: 'Filter by category',
                onSelected: (v) => setState(() {
                  _categoryId = v == '' ? null : v;
                  if (_categoryId != null) _type = 'expense';
                }),
                itemBuilder: (_) => [
                  const PopupMenuItem(value: '', child: Text('All categories')),
                  for (final c in f.categories)
                    PopupMenuItem(
                      value: c.id,
                      child: Row(children: [
                        Icon(c.iconData, color: c.color, size: 18),
                        const SizedBox(width: 8),
                        Text(c.name),
                      ]),
                    ),
                ],
                child: Chip(
                  avatar: const Icon(Icons.category_outlined, size: 18),
                  label: Text(_categoryId == null
                      ? 'Category'
                      : f.categoryById[_categoryId]?.name ?? 'Category'),
                ),
              ),
              const SizedBox(width: 8),
              ActionChip(
                avatar: const Icon(Icons.date_range, size: 18),
                label: Text(_range == null
                    ? 'Date range'
                    : '${Fmt.shortDate(_range!.start)} – ${Fmt.shortDate(_range!.end)}'),
                onPressed: _pickRange,
              ),
              if (_hasFilters) ...[
                const SizedBox(width: 8),
                TextButton(
                  onPressed: () => setState(() {
                    _type = 'all';
                    _categoryId = null;
                    _range = null;
                    _search.clear();
                  }),
                  child: const Text('Clear filters'),
                ),
              ],
            ]),
          ),
          if (items.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
              child: Row(children: [
                Text('${items.length} result${items.length == 1 ? '' : 's'}'),
                const Spacer(),
                if (summary.income > 0)
                  Text('+${Fmt.money(summary.income, f.currency)}  ',
                      style: const TextStyle(color: AppTheme.income, fontWeight: FontWeight.w600)),
                if (summary.expense > 0)
                  Text('−${Fmt.money(summary.expense, f.currency)}',
                      style: const TextStyle(color: AppTheme.expense, fontWeight: FontWeight.w600)),
              ]),
            ),
          Expanded(
            child: items.isEmpty
                ? SingleChildScrollView(
                    child: EmptyState(
                      icon: _hasFilters ? Icons.search_off : Icons.receipt_long_outlined,
                      title: _hasFilters ? 'No matching transactions' : 'No transactions yet',
                      message: _hasFilters
                          ? 'Try a different search or clear the filters.'
                          : 'Tap "Add" to record your first income or expense.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.fromLTRB(16, 4, 16, 96),
                    children: [
                      for (final e in groups.entries) ...[
                        Padding(
                          padding: const EdgeInsets.only(top: 12, bottom: 6),
                          child: Text(Fmt.prettyDate(e.key),
                              style: Theme.of(context).textTheme.labelLarge),
                        ),
                        Card(
                          child: Column(children: [
                            for (final t in e.value)
                              Dismissible(
                                key: ValueKey(t.id),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  alignment: Alignment.centerRight,
                                  padding: const EdgeInsets.only(right: 20),
                                  color: AppTheme.expense,
                                  child: const Icon(Icons.delete, color: Colors.white),
                                ),
                                confirmDismiss: (_) => confirmDialog(context,
                                    title: 'Delete transaction?',
                                    message: 'This record will be removed permanently.'),
                                onDismissed: (_) async {
                                  await f.deleteTransaction(t);
                                  if (context.mounted) showSnack(context, 'Transaction deleted');
                                },
                                child: TransactionTile(transaction: t),
                              ),
                          ]),
                        ),
                      ],
                    ],
                  ),
          ),
        ]),
      ),
    );
  }
}
