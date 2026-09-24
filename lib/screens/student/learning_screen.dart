import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../data/models/category.dart';
import '../../data/models/misc.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../widgets/common.dart';

/// Learning hub: short finance lessons managed by the administrator.
class LearningScreen extends StatefulWidget {
  const LearningScreen({super.key});

  @override
  State<LearningScreen> createState() => _LearningScreenState();
}

class _LearningScreenState extends State<LearningScreen> {
  late Future<List<LearningItem>> _items =
      context.read<EngagementRepository>().learning();
  String? _topic;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Learning hub')),
      body: FutureBuilder<List<LearningItem>>(
        future: _items,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final all = snap.data!;
          if (all.isEmpty) {
            return const EmptyState(
                icon: Icons.menu_book,
                title: 'No lessons yet',
                message: 'Check back soon for new finance tips.');
          }
          final topics = all.map((e) => e.topic).toSet().toList()..sort();
          final items = _topic == null ? all : all.where((e) => e.topic == _topic).toList();
          return RefreshIndicator(
            onRefresh: () async {
              setState(() => _items = context.read<EngagementRepository>().learning());
              await _items;
            },
            child: ResponsiveBody(
              maxWidth: 900,
              child: ListView(padding: screenPadding, children: [
                Text('Short lessons to build smart money habits.',
                    style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                const SizedBox(height: 12),
                Wrap(spacing: 8, runSpacing: 8, children: [
                  ChoiceChip(
                      label: const Text('All'),
                      selected: _topic == null,
                      onSelected: (_) => setState(() => _topic = null)),
                  for (final t in topics)
                    ChoiceChip(
                        label: Text(t),
                        selected: _topic == t,
                        onSelected: (_) => setState(() => _topic = t)),
                ]),
                const SizedBox(height: 12),
                LayoutBuilder(builder: (context, c) {
                  final cols = c.maxWidth > 640 ? 2 : 1;
                  return GridView.count(
                    crossAxisCount: cols,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 12,
                    crossAxisSpacing: 12,
                    childAspectRatio: cols == 2 ? 2.4 : 2.8,
                    children: [for (final i in items) _LessonCard(item: i)],
                  );
                }),
              ]),
            ),
          );
        },
      ),
    );
  }
}

class _LessonCard extends StatelessWidget {
  const _LessonCard({required this.item});
  final LearningItem item;

  @override
  Widget build(BuildContext context) {
    final icon = item.imageUrl ?? 'misc';
    final color = Category.colorFor(icon);
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => Navigator.push(context,
            MaterialPageRoute(builder: (_) => LessonScreen(item: item))),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(14)),
              child: Icon(Category.iconFor(icon), color: color, size: 30),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text('${item.topic} · ${item.difficulty}',
                        style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
                    const SizedBox(height: 2),
                    Text(item.body.split('\n').first,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontSize: 13)),
                  ]),
            ),
            const Icon(Icons.chevron_right),
          ]),
        ),
      ),
    );
  }
}

class LessonScreen extends StatelessWidget {
  const LessonScreen({super.key, required this.item});
  final LearningItem item;

  @override
  Widget build(BuildContext context) {
    final icon = item.imageUrl ?? 'misc';
    final color = Category.colorFor(icon);
    return Scaffold(
      appBar: AppBar(title: Text(item.topic)),
      body: ResponsiveBody(
        maxWidth: 720,
        child: ListView(padding: const EdgeInsets.all(20), children: [
          Container(
            height: 140,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [color.withValues(alpha: 0.25), color.withValues(alpha: 0.05)]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
                child: Icon(Category.iconFor(icon), size: 72, color: color,
                    semanticLabel: item.topic)),
          ),
          const SizedBox(height: 20),
          Chip(label: Text(item.difficulty)),
          const SizedBox(height: 8),
          Text(item.title,
              style: Theme.of(context)
                  .textTheme
                  .headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800)),
          const SizedBox(height: 16),
          Text(item.body, style: const TextStyle(fontSize: 16, height: 1.55)),
          const SizedBox(height: 24),
          Card(
            color: Theme.of(context).colorScheme.secondaryContainer.withValues(alpha: .5),
            child: const ListTile(
              leading: Icon(Icons.info_outline),
              title: Text('Educational content only'),
              subtitle: Text('These lessons are general guidance, not professional financial advice.'),
            ),
          ),
        ]),
      ),
    );
  }
}
