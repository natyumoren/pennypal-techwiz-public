import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/models/savings_goal.dart';
import '../../state/finance_state.dart';
import '../../widgets/common.dart';

class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Savings goals'),
          bottom: TabBar(tabs: [
            Tab(text: 'Active (${f.activeGoals.length})'),
            Tab(text: 'History (${f.completedGoals.length})'),
          ]),
        ),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => Navigator.push(context,
              MaterialPageRoute(builder: (_) => const GoalFormScreen())),
          icon: const Icon(Icons.flag_outlined),
          label: const Text('New goal'),
        ),
        body: TabBarView(children: [
          _GoalList(
            goals: f.activeGoals,
            empty: const EmptyState(
              icon: Icons.savings_outlined,
              title: 'No active goals',
              message:
                  'Saving for a laptop, a trip or an emergency fund? Create a goal and track your progress.',
            ),
          ),
          _GoalList(
            goals: f.completedGoals,
            empty: const EmptyState(
              icon: Icons.emoji_events_outlined,
              title: 'No completed goals yet',
              message: 'Goals you complete are archived here.',
            ),
          ),
        ]),
      ),
    );
  }
}

class _GoalList extends StatelessWidget {
  const _GoalList({required this.goals, required this.empty});
  final List<SavingsGoal> goals;
  final Widget empty;

  @override
  Widget build(BuildContext context) {
    if (goals.isEmpty) return SingleChildScrollView(child: empty);
    return ResponsiveBody(
      maxWidth: 800,
      child: ListView.separated(
        padding: screenPadding.copyWith(top: 16),
        itemCount: goals.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => GoalCard(goal: goals[i]),
      ),
    );
  }
}

String _motivation(SavingsGoal g) {
  final p = g.progress;
  if (g.isCompleted) return 'Goal achieved – well done! 🎉';
  if (p >= 0.75) return 'Almost there! One last push. 🚀';
  if (p >= 0.5) return 'Halfway there – great consistency! 💪';
  if (p >= 0.25) return 'Nice start! Keep the habit going. 🌱';
  return 'Every contribution counts. Start small! ✨';
}

class GoalCard extends StatelessWidget {
  const GoalCard({super.key, required this.goal});
  final SavingsGoal goal;

  @override
  Widget build(BuildContext context) {
    final f = context.read<FinanceState>();
    final cur = f.currency;
    final g = goal;
    final cs = Theme.of(context).colorScheme;
    final est = g.estimatedCompletion;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            SizedBox(
              width: 64,
              height: 64,
              child: Stack(alignment: Alignment.center, children: [
                SizedBox.expand(
                  child: CircularProgressIndicator(
                    value: g.progress,
                    strokeWidth: 7,
                    backgroundColor: cs.surfaceContainerHighest,
                    color: g.isCompleted ? AppTheme.income : cs.primary,
                    semanticsLabel: '${g.name} progress',
                    semanticsValue: Fmt.percent(g.progress),
                  ),
                ),
                Text(Fmt.percent(g.progress),
                    style: const TextStyle(fontWeight: FontWeight.w800)),
              ]),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(g.name,
                    style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
                const SizedBox(height: 2),
                Text('${Fmt.money(g.currentAmount, cur)} of ${Fmt.money(g.targetAmount, cur)}'),
                Text(_motivation(g),
                    style: TextStyle(fontSize: 12, color: cs.onSurfaceVariant)),
              ]),
            ),
            PopupMenuButton<String>(
              tooltip: 'Goal options',
              onSelected: (v) async {
                if (v == 'edit') {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => GoalFormScreen(existing: g)));
                } else if (v == 'delete') {
                  final ok = await confirmDialog(context,
                      title: 'Delete goal?',
                      message: '"${g.name}" and its progress will be removed.');
                  if (ok) await f.deleteGoal(g);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text('Edit goal')),
                PopupMenuItem(value: 'delete', child: Text('Delete goal')),
              ],
            ),
          ]),
          const SizedBox(height: 14),
          Wrap(spacing: 16, runSpacing: 8, children: [
            _fact(Icons.hourglass_bottom, 'Remaining', Fmt.money(g.remaining, cur)),
            _fact(Icons.event, 'Target date', Fmt.prettyDate(g.targetDate)),
            _fact(Icons.repeat, 'Monthly', Fmt.money(g.monthlyContribution, cur)),
            if (g.isCompleted && g.completedAt != null)
              _fact(Icons.emoji_events, 'Completed', Fmt.prettyDate(g.completedAt!))
            else
              _fact(
                  Icons.schedule,
                  'Est. completion',
                  est == null
                      ? 'Set a monthly amount'
                      : '${Fmt.prettyDate(Fmt.isoDate(est))} (${g.monthsToGo} mo)'),
          ]),
          if (!g.isCompleted && g.isBehindSchedule) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: AppTheme.warning.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10)),
              child: Row(children: [
                const Icon(Icons.info_outline, color: AppTheme.warning),
                const SizedBox(width: 8),
                Expanded(
                    child: Text(
                        'Behind schedule: save about ${Fmt.money(g.requiredMonthly, cur)} a month to finish by the target date.')),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          Text('Milestones', style: Theme.of(context).textTheme.labelLarge),
          const SizedBox(height: 6),
          Wrap(spacing: 8, children: [
            for (final m in SavingsGoal.milestoneSteps)
              FilterChip(
                avatar: Icon(
                    g.milestones.contains(m)
                        ? Icons.military_tech
                        : Icons.flag_outlined,
                    size: 18,
                    color: g.milestones.contains(m) ? Colors.amber.shade800 : null),
                label: Text('$m%'),
                selected: g.milestones.contains(m),
                showCheckmark: false,
                tooltip: g.milestones.contains(m)
                    ? 'Milestone reached (tap to unmark)'
                    : 'Mark milestone',
                onSelected: g.isCompleted ? null : (_) => f.toggleMilestone(g, m),
              ),
          ]),
          if (!g.isCompleted) ...[
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: () => _contribute(context, g),
                icon: const Icon(Icons.add),
                label: const Text('Add contribution'),
              ),
            ),
          ],
        ]),
      ),
    );
  }

  Widget _fact(IconData icon, String label, String value) => SizedBox(
        width: 150,
        child: Row(children: [
          Icon(icon, size: 18, color: Colors.grey),
          const SizedBox(width: 6),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(label, style: const TextStyle(fontSize: 11, color: Colors.grey)),
              Text(value,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
            ]),
          ),
        ]),
      );
}

Future<void> _contribute(BuildContext context, SavingsGoal g) async {
  final f = context.read<FinanceState>();
  final ctrl = TextEditingController(
      text: g.monthlyContribution > 0 ? g.monthlyContribution.toStringAsFixed(2) : '');
  final key = GlobalKey<FormState>();
  var record = true;
  final amount = await showDialog<double>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setState) => AlertDialog(
        title: Text('Add to "${g.name}"'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: ctrl,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Amount',
                  prefixText: Fmt.currencies[f.currency] ?? '${f.currency} '),
              validator: Validators.amount,
            ),
            CheckboxListTile(
              value: record,
              contentPadding: EdgeInsets.zero,
              onChanged: (v) => setState(() => record = v ?? false),
              title: const Text('Also record as a Savings expense',
                  style: TextStyle(fontSize: 14)),
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          FilledButton(
            onPressed: () {
              if (key.currentState!.validate()) {
                Navigator.pop(ctx, Validators.parseAmount(ctrl.text));
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    ),
  );
  if (amount == null) return;
  final updated = await f.contribute(g, amount, recordAsExpense: record);
  if (!context.mounted) return;
  showSnack(
    context,
    updated.isCompleted
        ? '🎉 Goal completed! "${g.name}" moved to history.'
        : 'Added ${Fmt.money(amount, f.currency)} – now at ${Fmt.percent(updated.progress)}',
    color: updated.isCompleted ? AppTheme.income : null,
  );
}

class GoalFormScreen extends StatefulWidget {
  const GoalFormScreen({super.key, this.existing});
  final SavingsGoal? existing;

  @override
  State<GoalFormScreen> createState() => _GoalFormScreenState();
}

class _GoalFormScreenState extends State<GoalFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.existing?.name ?? '');
  late final _target = TextEditingController(
      text: widget.existing?.targetAmount.toStringAsFixed(2) ?? '');
  late final _current = TextEditingController(
      text: widget.existing?.currentAmount.toStringAsFixed(2) ?? '0');
  late final _monthly = TextEditingController(
      text: widget.existing?.monthlyContribution.toStringAsFixed(2) ?? '');
  late DateTime _date = widget.existing != null
      ? DateTime.parse(widget.existing!.targetDate)
      : DateTime(DateTime.now().year, DateTime.now().month + 6, DateTime.now().day);

  @override
  void dispose() {
    for (final c in [_name, _target, _current, _monthly]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final f = context.read<FinanceState>();
    final base = widget.existing;
    final g = SavingsGoal(
      id: base?.id ?? f.newId(),
      userId: f.userId,
      name: _name.text.trim(),
      targetAmount: Validators.parseAmount(_target.text),
      currentAmount: Validators.parseAmount(_current.text),
      targetDate: Fmt.isoDate(_date),
      monthlyContribution: Validators.parseAmount(_monthly.text),
      status: base?.status ?? 'active',
      milestones: base?.milestones ?? const [],
      createdAt: base?.createdAt ?? Fmt.nowIso(),
      completedAt: base?.completedAt,
    );
    await f.saveGoal(g);
    if (mounted) {
      Navigator.pop(context);
      showSnack(context, base == null ? 'Goal created' : 'Goal updated');
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final prefix = Fmt.currencies[f.currency] ?? '${f.currency} ';
    // Live preview of the estimate while typing.
    final target = double.tryParse(_target.text) ?? 0;
    final current = double.tryParse(_current.text) ?? 0;
    final monthly = double.tryParse(_monthly.text) ?? 0;
    final remaining = (target - current).clamp(0, double.infinity);
    final months = monthly > 0 ? (remaining / monthly).ceil() : null;

    return Scaffold(
      appBar: AppBar(title: Text(widget.existing == null ? 'New savings goal' : 'Edit goal')),
      body: ResponsiveBody(
        maxWidth: 600,
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _name,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                  labelText: 'Goal name *', hintText: 'e.g. New laptop'),
              validator: (v) => Validators.required(v, 'Goal name'),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _target,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Target amount *', prefixText: prefix),
              validator: Validators.amount,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _current,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(labelText: 'Current savings', prefixText: prefix),
              validator: (v) => Validators.amount(v, allowZero: true),
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _monthly,
              onChanged: (_) => setState(() {}),
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                  labelText: 'Monthly contribution *', prefixText: prefix),
              validator: (v) => Validators.amount(v, allowZero: true),
            ),
            const SizedBox(height: 14),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
                );
                if (d != null) setState(() => _date = d);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                    labelText: 'Target date *', prefixIcon: Icon(Icons.event)),
                child: Text(Fmt.prettyDate(Fmt.isoDate(_date))),
              ),
            ),
            const SizedBox(height: 16),
            if (target > 0)
              Card(
                child: ListTile(
                  leading: const Icon(Icons.calculate_outlined),
                  title: Text('Remaining: ${Fmt.money(remaining.toDouble(), f.currency)}'),
                  subtitle: Text(months == null
                      ? 'Add a monthly contribution to see when you will reach your goal.'
                      : months == 0
                          ? 'You have already reached this target!'
                          : 'At this rate you will reach it in about $months month${months == 1 ? '' : 's'}.'),
                ),
              ),
            const SizedBox(height: 16),
            FilledButton(onPressed: _save, child: const Text('Save goal')),
          ]),
        ),
      ),
    );
  }
}
