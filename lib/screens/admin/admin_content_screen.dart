import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../data/models/category.dart';
import '../../data/models/misc.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../widgets/common.dart';

/// Manage learning content / financial literacy resources.
class AdminContentScreen extends StatefulWidget {
  const AdminContentScreen({super.key});

  @override
  State<AdminContentScreen> createState() => _AdminContentScreenState();
}

class _AdminContentScreenState extends State<AdminContentScreen> {
  EngagementRepository get _repo => context.read<EngagementRepository>();
  late Future<List<LearningItem>> _future = _repo.learning(includeInactive: true);

  void _reload() => setState(() => _future = _repo.learning(includeInactive: true));

  Future<void> _edit([LearningItem? item]) async {
    final saved = await Navigator.push<bool>(context,
        MaterialPageRoute(builder: (_) => _ContentForm(item: item)));
    if (saved == true) _reload();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning content')),
      floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _edit(), icon: const Icon(Icons.add), label: const Text('New lesson')),
      body: FutureBuilder<List<LearningItem>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final items = snap.data!;
          if (items.isEmpty) {
            return const EmptyState(icon: Icons.menu_book, title: 'No lessons', message: 'Create the first lesson for students.');
          }
          return ResponsiveBody(
            maxWidth: 900,
            child: ListView(padding: screenPadding, children: [
              for (final i in items)
                Card(
                  margin: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    leading: Icon(Category.iconFor(i.imageUrl ?? 'misc'),
                        color: Category.colorFor(i.imageUrl ?? 'misc')),
                    title: Text(i.title),
                    subtitle: Text('${i.topic} · ${i.difficulty}${i.isActive ? '' : ' · hidden'}'),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Switch(
                        value: i.isActive,
                        onChanged: (v) async {
                          await _repo.saveLearning(LearningItem(
                              id: i.id, title: i.title, topic: i.topic, body: i.body,
                              difficulty: i.difficulty, imageUrl: i.imageUrl, isActive: v));
                          _reload();
                        },
                      ),
                      IconButton(
                        tooltip: 'Delete lesson',
                        icon: const Icon(Icons.delete_outline),
                        onPressed: () async {
                          final ok = await confirmDialog(context,
                              title: 'Delete lesson?', message: '"${i.title}" will be removed.');
                          if (ok) {
                            await _repo.deleteLearning(i.id);
                            _reload();
                          }
                        },
                      ),
                    ]),
                    onTap: () => _edit(i),
                  ),
                ),
            ]),
          );
        },
      ),
    );
  }
}

class _ContentForm extends StatefulWidget {
  const _ContentForm({this.item});
  final LearningItem? item;

  @override
  State<_ContentForm> createState() => _ContentFormState();
}

class _ContentFormState extends State<_ContentForm> {
  static const topics = ['Budgeting', 'Saving', 'Income', 'Expenses', 'Requirements'];
  static const levels = ['Beginner', 'Intermediate', 'Advanced'];

  final _form = GlobalKey<FormState>();
  late final _title = TextEditingController(text: widget.item?.title ?? '');
  late final _body = TextEditingController(text: widget.item?.body ?? '');
  late String _topic = widget.item?.topic ?? topics.first;
  late String _level = widget.item?.difficulty ?? levels.first;
  late String _icon = widget.item?.imageUrl ?? 'education';
  late bool _active = widget.item?.isActive ?? true;

  @override
  void dispose() {
    _title.dispose();
    _body.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final repo = context.read<EngagementRepository>();
    await repo.saveLearning(LearningItem(
      id: widget.item?.id ?? repo.newId(),
      title: _title.text.trim(),
      topic: _topic,
      body: _body.text.trim(),
      difficulty: _level,
      imageUrl: _icon,
      isActive: _active,
    ));
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.item == null ? 'New lesson' : 'Edit lesson')),
      body: ResponsiveBody(
        maxWidth: 720,
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            TextFormField(
              controller: _title,
              decoration: const InputDecoration(labelText: 'Title *'),
              validator: (v) => Validators.required(v, 'Title'),
            ),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: topics.contains(_topic) ? _topic : null,
                  decoration: const InputDecoration(labelText: 'Topic'),
                  items: [for (final t in topics) DropdownMenuItem(value: t, child: Text(t))],
                  onChanged: (v) => setState(() => _topic = v!),
                  validator: (v) => v == null ? 'Choose a topic' : null,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: DropdownButtonFormField<String>(
                  value: _level,
                  decoration: const InputDecoration(labelText: 'Difficulty'),
                  items: [for (final l in levels) DropdownMenuItem(value: l, child: Text(l))],
                  onChanged: (v) => setState(() => _level = v!),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            const Text('Illustration'),
            const SizedBox(height: 6),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final k in Category.iconKeys.keys)
                ChoiceChip(
                  label: Icon(Category.iconFor(k), color: Category.colorFor(k), size: 20, semanticLabel: k),
                  selected: _icon == k,
                  onSelected: (_) => setState(() => _icon = k),
                ),
            ]),
            const SizedBox(height: 14),
            TextFormField(
              controller: _body,
              minLines: 8,
              maxLines: 20,
              decoration: const InputDecoration(
                  labelText: 'Lesson text *',
                  alignLabelWithHint: true,
                  helperText: 'Keep it short and use simple examples. Blank lines start new paragraphs.'),
              validator: (v) {
                final r = Validators.required(v, 'Lesson text');
                if (r != null) return r;
                return v!.trim().length < 40 ? 'Write at least 40 characters' : null;
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Visible to students'),
              value: _active,
              onChanged: (v) => setState(() => _active = v),
            ),
            const SizedBox(height: 12),
            FilledButton(onPressed: _save, child: const Text('Save lesson')),
          ]),
        ),
      ),
    );
  }
}
