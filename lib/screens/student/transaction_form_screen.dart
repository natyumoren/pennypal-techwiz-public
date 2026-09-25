import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../core/validators.dart';
import '../../data/models/transaction.dart';
import '../../services/budget_monitor.dart';
import '../../services/categorizer.dart';
import '../../services/receipt_service.dart';
import '../../state/finance_state.dart';
import '../../widgets/common.dart';

/// Add or edit an income / expense entry.
class TransactionFormScreen extends StatefulWidget {
  const TransactionFormScreen({super.key, required this.type, this.existing});
  final String type; // income | expense
  final TransactionRecord? existing;

  @override
  State<TransactionFormScreen> createState() => _TransactionFormScreenState();
}

class _TransactionFormScreenState extends State<TransactionFormScreen> {
  static const paymentModes = [
    'Cash',
    'Card',
    'Bank transfer',
    'Mobile money',
    'Transfer',
    'Other'
  ];
  static const incomeSources = [
    'Monthly allowance',
    'Scholarship',
    'Part-time job',
    'Internship',
    'Gift',
    'Freelance',
  ];

  final _form = GlobalKey<FormState>();
  late final TextEditingController _amount;
  late final TextEditingController _description;
  late final TextEditingController _source;
  late DateTime _date;
  String? _categoryId;
  String _paymentMode = 'Cash';
  String? _receipt;
  CategorySuggestion? _suggestion;
  bool _userPickedCategory = false;
  bool _saving = false;
  Timer? _debounce;

  bool get isIncome => widget.type == 'income';
  bool get isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _amount = TextEditingController(
        text: e == null ? '' : e.amount.toStringAsFixed(2));
    _description = TextEditingController(text: e?.description ?? '');
    _source = TextEditingController(text: e?.source ?? '');
    _date = e?.dateTime ?? DateTime.now();
    _categoryId = e?.categoryId;
    _userPickedCategory = e != null;
    _paymentMode = e?.paymentMode ?? 'Cash';
    if (!paymentModes.contains(_paymentMode)) _paymentMode = 'Other';
    _receipt = e?.receiptImageUrl;
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _amount.dispose();
    _description.dispose();
    _source.dispose();
    super.dispose();
  }

  void _onDescriptionChanged(String text) {
    if (isIncome) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 350), () {
      final f = context.read<FinanceState>();
      final s = ExpenseCategorizer.suggest(text, f.categories,
          history: f.transactions);
      if (!mounted) return;
      setState(() {
        _suggestion = s;
        // Auto-fill only until the student chooses a category themselves.
        if (s != null && !_userPickedCategory) _categoryId = s.category.id;
      });
    });
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _date = d);
  }

  Future<void> _pickReceipt() async {
    final source = await showModalBottomSheet<ImageSource>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera)),
          ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery)),
        ]),
      ),
    );
    if (source == null) return;
    try {
      final path = await ReceiptService.pick(source);
      if (path != null) setState(() => _receipt = path);
    } catch (e) {
      if (mounted) showSnack(context, 'Could not attach image: $e', error: true);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final f = context.read<FinanceState>();
    setState(() => _saving = true);
    final t = TransactionRecord(
      id: widget.existing?.id ?? f.newId(),
      userId: f.userId,
      type: widget.type,
      amount: Validators.parseAmount(_amount.text),
      categoryId: isIncome ? null : _categoryId,
      source: isIncome ? _source.text.trim() : null,
      description: _description.text.trim().isEmpty ? null : _description.text.trim(),
      date: Fmt.isoDate(_date),
      paymentMode: _paymentMode,
      receiptImageUrl: _receipt,
      createdAt: widget.existing?.createdAt ?? Fmt.nowIso(),
    );
    try {
      final alerts = await f.saveTransaction(t);
      if (!mounted) return;
      Navigator.pop(context);
      _showResult(context, alerts);
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        showSnack(context, 'Could not save: $e', error: true);
      }
    }
  }

  void _showResult(BuildContext ctx, List<BudgetAlert> alerts) {
    if (alerts.isEmpty) {
      showSnack(ctx, isEdit ? 'Changes saved' : '${isIncome ? 'Income' : 'Expense'} added');
      return;
    }
    // Instant spending alert (SRS: real-time processing).
    final worst = alerts.firstWhere((a) => a.exceeded, orElse: () => alerts.first);
    showSnack(ctx, '${worst.title}: ${worst.message}',
        color: worst.exceeded ? AppTheme.expense : AppTheme.warning);
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(
        title: Text('${isEdit ? 'Edit' : 'Add'} ${isIncome ? 'income' : 'expense'}'),
      ),
      body: SafeArea(
        child: ResponsiveBody(
          maxWidth: 640,
          child: Form(
            key: _form,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                TextFormField(
                  controller: _amount,
                  autofocus: !isEdit,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  decoration: InputDecoration(
                    labelText: 'Amount *',
                    prefixText: Fmt.currencies[f.currency] ?? '${f.currency} ',
                  ),
                  validator: Validators.amount,
                ),
                const SizedBox(height: 14),
                if (isIncome) ...[
                  TextFormField(
                    controller: _source,
                    textCapitalization: TextCapitalization.sentences,
                    decoration: const InputDecoration(
                        labelText: 'Source *',
                        hintText: 'e.g. Monthly allowance',
                        prefixIcon: Icon(Icons.work_outline)),
                    validator: (v) => Validators.required(v, 'Source'),
                  ),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final s in incomeSources)
                      ChoiceChip(
                        label: Text(s),
                        selected: _source.text == s,
                        onSelected: (_) => setState(() => _source.text = s),
                      ),
                  ]),
                  const SizedBox(height: 14),
                ],
                TextFormField(
                  controller: _description,
                  textCapitalization: TextCapitalization.sentences,
                  onChanged: _onDescriptionChanged,
                  maxLength: 120,
                  decoration: InputDecoration(
                    labelText: isIncome ? 'Description' : 'What was it for?',
                    hintText: isIncome ? 'Optional note' : 'e.g. Pizza with friends',
                    prefixIcon: const Icon(Icons.notes),
                  ),
                ),
                if (!isIncome) ...[
                  if (_suggestion != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(children: [
                        Icon(Icons.auto_awesome, size: 16, color: cs.primary),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            'Smart category: ${_suggestion!.category.name} '
                            '(${_suggestion!.reason})',
                            style: TextStyle(fontSize: 12, color: cs.primary),
                          ),
                        ),
                        if (_categoryId != _suggestion!.category.id)
                          TextButton(
                            onPressed: () => setState(
                                () => _categoryId = _suggestion!.category.id),
                            child: const Text('Use'),
                          ),
                      ]),
                    ),
                  DropdownButtonFormField<String>(
                    value: f.categoryById.containsKey(_categoryId) ? _categoryId : null,
                    decoration: const InputDecoration(
                        labelText: 'Category *',
                        prefixIcon: Icon(Icons.category_outlined)),
                    items: [
                      for (final c in f.categories)
                        DropdownMenuItem(
                          value: c.id,
                          child: Row(children: [
                            Icon(c.iconData, color: c.color, size: 20),
                            const SizedBox(width: 10),
                            Text(c.name),
                          ]),
                        ),
                    ],
                    onChanged: (v) => setState(() {
                      _categoryId = v;
                      _userPickedCategory = true;
                    }),
                    validator: (v) => v == null ? 'Please choose a category' : null,
                  ),
                  const SizedBox(height: 14),
                ],
                Row(children: [
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: BorderRadius.circular(12),
                      child: InputDecorator(
                        decoration: const InputDecoration(
                            labelText: 'Date *',
                            prefixIcon: Icon(Icons.calendar_today_outlined)),
                        child: Text(Fmt.prettyDate(Fmt.isoDate(_date))),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _paymentMode,
                      isExpanded: true,
                      decoration: const InputDecoration(labelText: 'Payment mode'),
                      items: [
                        for (final m in paymentModes)
                          DropdownMenuItem(value: m, child: Text(m))
                      ],
                      onChanged: (v) => setState(() => _paymentMode = v ?? 'Cash'),
                    ),
                  ),
                ]),
                const SizedBox(height: 16),
                Text('Receipt (optional)',
                    style: Theme.of(context).textTheme.titleSmall),
                const SizedBox(height: 8),
                if (_receipt != null) ...[
                  ReceiptImage(_receipt!),
                  Row(children: [
                    TextButton.icon(
                        onPressed: _pickReceipt,
                        icon: const Icon(Icons.refresh),
                        label: const Text('Replace')),
                    TextButton.icon(
                        onPressed: () => setState(() => _receipt = null),
                        icon: const Icon(Icons.close),
                        label: const Text('Remove')),
                  ]),
                ] else
                  OutlinedButton.icon(
                    onPressed: _pickReceipt,
                    icon: const Icon(Icons.add_a_photo_outlined),
                    label: const Text('Attach receipt photo'),
                  ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : Text(isEdit ? 'Save changes' : 'Save'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
