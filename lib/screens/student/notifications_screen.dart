import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/theme.dart';
import '../../state/finance_state.dart';
import '../../widgets/common.dart';

class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  @override
  void initState() {
    super.initState();
    context.read<FinanceState>().refreshNotifications();
  }

  @override
  Widget build(BuildContext context) {
    final f = context.watch<FinanceState>();
    final items = f.notifications;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (f.unreadCount > 0)
            TextButton(onPressed: f.markAllRead, child: const Text('Mark all read')),
          if (items.isNotEmpty)
            IconButton(
              tooltip: 'Clear all',
              icon: const Icon(Icons.delete_sweep_outlined),
              onPressed: () async {
                final ok = await confirmDialog(context,
                    title: 'Clear notifications?',
                    message: 'All notifications will be removed.',
                    confirmLabel: 'Clear');
                if (ok) await f.clearNotifications();
              },
            ),
        ],
      ),
      body: items.isEmpty
          ? const EmptyState(
              icon: Icons.notifications_none,
              title: 'You are all caught up',
              message: 'Budget alerts, goal milestones and support replies show up here.')
          : ResponsiveBody(
              maxWidth: 700,
              child: ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: items.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (_, i) {
                  final n = items[i];
                  final (icon, color) = switch (n.type) {
                    'budget' => (Icons.warning_amber_rounded, AppTheme.warning),
                    'goal' => (Icons.emoji_events_outlined, AppTheme.income),
                    _ => (Icons.info_outline, Colors.blue),
                  };
                  return Card(
                    color: n.read
                        ? null
                        : Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .35),
                    child: ListTile(
                      leading: CircleAvatar(
                          backgroundColor: color.withValues(alpha: .15),
                          child: Icon(icon, color: color)),
                      title: Text(n.title,
                          style: TextStyle(fontWeight: n.read ? FontWeight.w500 : FontWeight.w700)),
                      subtitle: Text('${n.message}\n${Fmt.timeAgo(n.createdAt)}'),
                      isThreeLine: true,
                    ),
                  );
                },
              ),
            ),
    );
  }
}
