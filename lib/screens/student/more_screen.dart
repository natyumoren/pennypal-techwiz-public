import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../state/session_state.dart';
import '../../widgets/common.dart';
import 'about_screen.dart';
import 'categories_screen.dart';
import 'chatbot_screen.dart';
import 'feedback_screen.dart';
import 'learning_screen.dart';
import 'notifications_screen.dart';
import 'profile_screen.dart';
import 'reports_screen.dart';
import 'support_screen.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final user = session.user!;
    void push(Widget w) =>
        Navigator.push(context, MaterialPageRoute(builder: (_) => w));

    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ResponsiveBody(
        maxWidth: 700,
        child: ListView(padding: screenPadding, children: [
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.all(12),
              leading: CircleAvatar(
                radius: 26,
                child: Text(user.fullName.isNotEmpty ? user.fullName[0].toUpperCase() : '?',
                    style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              ),
              title: Text(user.fullName, style: const TextStyle(fontWeight: FontWeight.w700)),
              subtitle: Text(user.email),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => push(const ProfileScreen()),
            ),
          ),
          const SectionHeader('Money tools'),
          Card(
            child: Column(children: [
              _item(Icons.insights, 'Spending reports', () => push(const ReportsScreen())),
              _item(Icons.category_outlined, 'Categories', () => push(const CategoriesScreen())),
              _item(Icons.notifications_outlined, 'Notifications', () => push(const NotificationsScreen())),
            ]),
          ),
          const SectionHeader('Learn & get help'),
          Card(
            child: Column(children: [
              _item(Icons.smart_toy_outlined, 'Ask Penny (chatbot)', () => push(const ChatbotScreen())),
              _item(Icons.menu_book_outlined, 'Learning hub', () => push(const LearningScreen())),
              _item(Icons.rate_review_outlined, 'Feedback', () => push(const FeedbackScreen())),
              _item(Icons.support_agent, 'Contact support', () => push(const SupportScreen())),
              _item(Icons.info_outline, 'About & privacy', () => push(const AboutScreen())),
            ]),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            icon: const Icon(Icons.logout),
            label: const Text('Log out'),
            onPressed: () => confirmLogout(context),
          ),
        ]),
      ),
    );
  }

  Widget _item(IconData icon, String label, VoidCallback onTap) => ListTile(
        leading: Icon(icon),
        title: Text(label),
        trailing: const Icon(Icons.chevron_right),
        onTap: onTap,
      );
}

Future<void> confirmLogout(BuildContext context) async {
  final ok = await confirmDialog(context,
      title: 'Log out?',
      message: 'Your data stays saved on this device.',
      confirmLabel: 'Log out',
      destructive: false);
  if (!ok || !context.mounted) return;
  Navigator.of(context).popUntil((r) => r.isFirst);
  await context.read<SessionState>().logout();
}
