import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../data/models/category.dart';
import '../../state/finance_state.dart';
import '../../widgets/common.dart';

/// Default categories plus the student's own custom categories.
class CategoriesScreen extends StatelessWidget {
  const CategoriesScreen({super.key});

  Future<void> _add(BuildContext context) async {
    final name = TextEditingController();
    final key = GlobalKey<FormState>();
    var icon = 'misc';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: const Text('New category'),
          content: Form(
            key: key,
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              TextFormField(
                controller: name,
                autofocus: true,
                maxLength: 30,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) => Validators.required(v, 'Name'),
              ),
              const SizedBox(height: 8),
              Wrap(spacing: 6, runSpacing: 6, children: [
                for (final k in Category.iconKeys.keys)
                  ChoiceChip(
                    label: Icon(Category.iconFor(k), size: 20, color: Category.colorFor(k), semanticLabel: k),
                    selected: icon == k,
                    onSelected: (_) => setState(() => icon = k),
                  ),
              ]),
            ]),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (key.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || !context.mounted) return;
    try {
      await context.read<FinanceState>().addCategory(name.text, icon);
      if (context.mounted) showSnack(context, 'Category added');
    } catch (e) {
      if (context.mounted) {
        showSnack(context, e.toString().replaceFirst('Bad state: ', ''), error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final defaults = f.categories.where((c) => c.isDefault);
    final custom = f.categories.where((c) => !c.isDefault);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('New category'),
      ),
      body: ResponsiveBody(
        maxWidth: 640,
        child: ListView(padding: screenPadding, children: [
          const SectionHeader('Default categories'),
          Card(
            child: Column(children: [
              for (final c in defaults)
                ListTile(leading: CategoryAvatar(c), title: Text(c.name)),
            ]),
          ),
          const SectionHeader('My categories'),
          if (custom.isEmpty)
            const Card(
                child: EmptyState(
                    icon: Icons.category_outlined,
                    title: 'No custom categories',
                    message: 'Add your own, e.g. "Gym" or "Pet care".'))
          else
            Card(
              child: Column(children: [
                for (final c in custom)
                  ListTile(
                    leading: CategoryAvatar(c),
                    title: Text(c.name),
                    trailing: IconButton(
                      tooltip: 'Delete ${c.name}',
                      icon: const Icon(Icons.delete_outline),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            title: 'Delete "${c.name}"?',
                            message: 'Its expenses will move to Miscellaneous and its budgets will be removed.');
                        if (ok) await f.deleteCategory(c);
                      },
                    ),
                  ),
              ]),
            ),
        ]),
      ),
    );
  }
}
