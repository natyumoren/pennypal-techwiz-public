import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/models/budget.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../services/budget_monitor.dart';
import '../../state/finance_state.dart';
import '../../widgets/common.dart';

/// Monthly budget + category-wise spending limits with alert thresholds.
class BudgetScreen extends StatefulWidget {
  const BudgetScreen({super.key});

  @override
  State<BudgetScreen> createState() => _BudgetScreenState();
}

class _BudgetScreenState extends State<BudgetScreen> {
  DateTime _month = DateTime(DateTime.now().year, DateTime.now().month);

  String get _key => Fmt.monthKey(_month);
  void _shift(int m) =>
      setState(() => _month = DateTime(_month.year, _month.month + m));

  Future<void> _edit({Budget? budget, bool overall = false}) async {
    final alerts = await showModalBottomSheet<List<BudgetAlert>>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) =>
          _BudgetForm(month: _key, budget: budget, overall: overall),
    );
    if (!mounted || alerts == null) return;
    if (alerts.isEmpty) {
      showSnack(context, 'Budget saved');
    } else {
      showSnack(context, '${alerts.first.title}: ${alerts.first.message}',
          color: alerts.first.exceeded ? AppTheme.expense : AppTheme.warning);
    }
  }

  Future<void> _delete(Budget b) async {
    final ok = await confirmDialog(context,
        title: 'Delete budget?',
        message: b.isOverall
            ? 'Remove the overall budget for ${Fmt.monthLabel(b.month)}?'
            : 'Remove this category limit?');
    if (!ok || !mounted) return;
    await context.read<FinanceState>().deleteBudget(b);
    if (mounted) showSnack(context, 'Budget deleted');
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final usage = f.usageFor(_key);
    final overall = usage.where((u) => u.budget.isOverall).firstOrNull;
    final categories = usage.where((u) => !u.budget.isOverall).toList();
    final prevKey = Fmt.monthKey(DateTime(_month.year, _month.month - 1));
    final canCopy = usage.isEmpty && f.budgets.any((b) => b.month == prevKey);
    final cur = f.currency;

    return Scaffold(
      appBar: AppBar(title: const Text('Budget')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _edit(),
        icon: const Icon(Icons.add),
        label: const Text('Category limit'),
      ),
      body: ResponsiveBody(
        maxWidth: 800,
        child: ListView(
          padding: screenPadding,
          children: [
            Row(children: [
              IconButton(
                  tooltip: 'Previous month',
                  onPressed: () => _shift(-1),
                  icon: const Icon(Icons.chevron_left)),
              Expanded(
                child: Text(Fmt.monthLabel(_key),
                    textAlign: TextAlign.center,
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.w700)),
              ),
              IconButton(
                  tooltip: 'Next month',
                  onPressed: () => _shift(1),
                  icon: const Icon(Icons.chevron_right)),
            ]),
            const SizedBox(height: 8),
            if (overall == null)
              Card(
                child: EmptyState(
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'No monthly budget',
                  message:
                      'Set the total amount you plan to spend in ${Fmt.monthLabel(_key)}.',
                  action: Wrap(spacing: 8, runSpacing: 8, alignment: WrapAlignment.center, children: [
                    FilledButton(
                        onPressed: () => _edit(overall: true),
                        child: const Text('Create monthly budget')),
                    if (canCopy)
                      OutlinedButton(
                        onPressed: () async {
                          final n = await f.copyBudgets(prevKey, _key);
                          if (context.mounted) {
                            showSnack(context, 'Copied $n budget(s) from last month');
                          }
                        },
                        child: const Text('Copy last month'),
                      ),
                  ]),
                ),
              )
            else
              _OverallCard(
                usage: overall,
                currency: cur,
                onEdit: () => _edit(budget: overall.budget, overall: true),
                onDelete: () => _delete(overall.budget),
              ),
            SectionHeader('Category limits',
                action: Text('${categories.length} set',
                    style: TextStyle(
                        color: Theme.of(context).colorScheme.onSurfaceVariant))),
            if (categories.isEmpty)
              const Card(
                child: EmptyState(
                  icon: Icons.tune,
                  title: 'No category limits',
                  message:
                      'Add limits for categories like Food or Entertainment to get an alert when you get close.',
                ),
              )
            else
              for (final u in categories)
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: _CategoryLimitCard(
                    usage: u,
                    currency: cur,
                    onEdit: () => _edit(budget: u.budget),
                    onDelete: () => _delete(u.budget),
                  ),
                ),
          ],
        ),
      ),
    );
  }
}

class _OverallCard extends StatelessWidget {
  const _OverallCard(
      {required this.usage,
      required this.currency,
      required this.onEdit,
      required this.onDelete});
  final BudgetUsage usage;
  final String currency;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final color = AppTheme.usageColor(usage.ratio,
        thresholdPercent: usage.budget.alertThreshold);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            const Expanded(
                child: Text('Monthly budget',
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16))),
            IconButton(
                tooltip: 'Edit budget',
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined)),
            IconButton(
                tooltip: 'Delete budget',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline)),
          ]),
          Text.rich(TextSpan(children: [
            TextSpan(
                text: Fmt.money(usage.spent, currency),
                style: TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, color: color)),
            TextSpan(
                text: ' of ${Fmt.money(usage.budget.limitAmount, currency)}',
                style: const TextStyle(fontSize: 16)),
          ])),
          const SizedBox(height: 12),
          UsageBar(ratio: usage.ratio, threshold: usage.budget.alertThreshold, height: 14),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(
              child: Text(
                usage.isOver
                    ? 'Overspent by ${Fmt.money(-usage.remaining, currency)}'
                    : 'Remaining: ${Fmt.money(usage.remaining, currency)}',
                style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: usage.isOver ? AppTheme.expense : null),
              ),
            ),
            Text('${Fmt.percent(usage.ratio)} used · alert at ${usage.budget.alertThreshold}%',
                style: const TextStyle(fontSize: 12)),
          ]),
          if (usage.isOver || usage.isNearLimit) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                Icon(Icons.warning_amber_rounded, color: color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(usage.isOver
                      ? 'You have spent more than planned this month. Review optional expenses.'
                      : 'You are close to your monthly limit. Spend carefully until the month ends.'),
                ),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _CategoryLimitCard extends StatelessWidget {
  const _CategoryLimitCard(
      {required this.usage,
      required this.currency,
      required this.onEdit,
      required this.onDelete});
  final BudgetUsage usage;
  final String currency;
  final VoidCallback onEdit, onDelete;

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final cat = f.categoryById[usage.budget.categoryId];
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 14),
        child: Column(children: [
          Row(children: [
            if (cat != null) CategoryAvatar(cat, radius: 18),
            const SizedBox(width: 10),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(cat?.name ?? 'Category',
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                Text(
                    '${Fmt.money(usage.spent, currency)} of ${Fmt.money(usage.budget.limitAmount, currency)}',
                    style: const TextStyle(fontSize: 13)),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: 'Options',
              onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit')),
                PopupMenuItem(value: 'delete', child: Text('Delete')),
              ],
            ),
          ]),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: UsageBar(ratio: usage.ratio, threshold: usage.budget.alertThreshold),
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: Row(children: [
              Text(
                usage.isOver
                    ? 'Over by ${Fmt.money(-usage.remaining, currency)}'
                    : '${Fmt.money(usage.remaining, currency)} left',
                style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: usage.isOver
                        ? AppTheme.expense
                        : usage.isNearLimit
                            ? AppTheme.warning
                            : null),
              ),
              const Spacer(),
              Text('Alert at ${usage.budget.alertThreshold}%',
                  style: const TextStyle(fontSize: 12)),
            ]),
          ),
        ]),
      ),
    );
  }
}

class _BudgetForm extends StatefulWidget {
  const _BudgetForm({required this.month, this.budget, this.overall = false});
  final String month;
  final Budget? budget;
  final bool overall;

  @override
  State<_BudgetForm> createState() => _BudgetFormState();
}

class _BudgetFormState extends State<_BudgetForm> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _limit = TextEditingController(
      text: widget.budget?.limitAmount.toStringAsFixed(2) ?? '');
  late String? _categoryId = widget.budget?.categoryId;
  late double _threshold = (widget.budget?.alertThreshold ?? 80).toDouble();
  bool _saving = false;

  bool get _isOverall => widget.overall || (widget.budget?.isOverall ?? false);

  @override
  void initState() {
    super.initState();
    // New budgets start from the administrator's suggested alert threshold.
    if (widget.budget == null) {
      context.read<EngagementRepository>().settings().then((s) {
        final t = double.tryParse(s['default_alert_threshold'] ?? '');
        if (mounted && t != null) setState(() => _threshold = t.clamp(50, 100));
      });
    }
  }

  @override
  void dispose() {
    _limit.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final alerts = await context.read<FinanceState>().saveBudget(
            id: widget.budget?.id,
            month: widget.month,
            categoryId: _isOverall ? null : _categoryId,
            limit: Validators.parseAmount(_limit.text),
            threshold: _threshold.round(),
          );
      if (mounted) Navigator.pop(context, alerts);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) showSnack(context, e.toString().replaceFirst('Bad state: ', ''), error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final taken = f.budgets
        .where((b) => b.month == widget.month && !b.isOverall && b.id != widget.budget?.id)
        .map((b) => b.categoryId)
        .toSet();
    final available = f.categories.where((c) => !taken.contains(c.id)).toList();

    return Padding(
      padding: EdgeInsets.fromLTRB(
          20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${widget.budget == null ? 'New' : 'Edit'} ${_isOverall ? 'monthly budget' : 'category limit'} · ${Fmt.monthLabel(widget.month)}',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 16),
            if (!_isOverall) ...[
              DropdownButtonFormField<String>(
                value: available.any((c) => c.id == _categoryId) ? _categoryId : null,
                decoration: const InputDecoration(labelText: 'Category *'),
                items: [
                  for (final c in available)
                    DropdownMenuItem(
                        value: c.id,
                        child: Row(children: [
                          Icon(c.iconData, color: c.color, size: 20),
                          const SizedBox(width: 8),
                          Text(c.name),
                        ])),
                ],
                onChanged: (v) => setState(() => _categoryId = v),
                validator: (v) => v == null ? 'Choose a category' : null,
              ),
              const SizedBox(height: 14),
            ],
            TextFormField(
              controller: _limit,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                labelText: _isOverall ? 'Total budget amount *' : 'Spending limit *',
                prefixText: Fmt.currencies[f.currency] ?? '${f.currency} ',
              ),
              validator: Validators.amount,
            ),
            const SizedBox(height: 16),
            Text('Alert me at ${_threshold.round()}% of the limit'),
            Slider(
              value: _threshold,
              min: 50,
              max: 100,
              divisions: 10,
              label: '${_threshold.round()}%',
              onChanged: (v) => setState(() => _threshold = v),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
