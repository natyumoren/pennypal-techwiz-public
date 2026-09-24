import 'package:flutter/material.dart';

import '../../core/config.dart';
import 'admin_content_screen.dart';
import 'admin_overview_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_support_screen.dart';
import 'admin_users_screen.dart';

/// Administrator portal: statistics, students, learning content, support
/// and app settings.
class AdminShell extends StatefulWidget {
  const AdminShell({super.key});

  @override
  State<AdminShell> createState() => _AdminShellState();
}

class _AdminShellState extends State<AdminShell> {
  int _index = 0;

  static const _dest = [
    (Icons.bar_chart_outlined, Icons.bar_chart, 'Overview'),
    (Icons.people_outline, Icons.people, 'Students'),
    (Icons.menu_book_outlined, Icons.menu_book, 'Content'),
    (Icons.support_agent_outlined, Icons.support_agent, 'Support'),
    (Icons.settings_outlined, Icons.settings, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    final wide =
        MediaQuery.sizeOf(context).width >= AppConfig.wideLayoutBreakpoint;
    // Pages are rebuilt on each switch so admin always sees fresh data.
    final page = switch (_index) {
      0 => const AdminOverviewScreen(),
      1 => const AdminUsersScreen(),
      2 => const AdminContentScreen(),
      3 => const AdminSupportScreen(),
      _ => const AdminSettingsScreen(),
    };
    if (wide) {
      return Scaffold(
        body: Row(children: [
          NavigationRail(
            selectedIndex: _index,
            onDestinationSelected: (i) => setState(() => _index = i),
            labelType: NavigationRailLabelType.all,
            leading: const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Icon(Icons.admin_panel_settings, size: 32),
            ),
            destinations: [
              for (final d in _dest)
                NavigationRailDestination(
                    icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: Text(d.$3)),
            ],
          ),
          const VerticalDivider(width: 1),
          Expanded(child: page),
        ]),
      );
    }
    return Scaffold(
      body: page,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          for (final d in _dest)
            NavigationDestination(icon: Icon(d.$1), selectedIcon: Icon(d.$2), label: d.$3),
        ],
      ),
    );
  }
}
