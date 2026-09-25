import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../data/repositories/admin_repository.dart';
import '../../widgets/common.dart';

class AdminUsersScreen extends StatefulWidget {
  const AdminUsersScreen({super.key});

  @override
  State<AdminUsersScreen> createState() => _AdminUsersScreenState();
}

class _AdminUsersScreenState extends State<AdminUsersScreen> {
  late Future<List<StudentSummary>> _future = _repo.students();
  AdminRepository get _repo => context.read<AdminRepository>();
  final _search = TextEditingController();

  void _reload() => setState(() => _future = _repo.students());

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  Future<void> _toggle(StudentSummary s) async {
    final activate = !s.user.isActive;
    final ok = await confirmDialog(context,
        title: activate ? 'Activate account?' : 'Deactivate account?',
        message: activate
            ? '${s.user.fullName} will be able to log in again.'
            : '${s.user.fullName} will not be able to log in until reactivated. Their data is kept.',
        confirmLabel: activate ? 'Activate' : 'Deactivate',
        destructive: !activate);
    if (!ok) return;
    await _repo.setActive(s.user.id, activate);
    _reload();
  }

  Future<void> _delete(StudentSummary s) async {
    final ok = await confirmDialog(context,
        title: 'Delete ${s.user.fullName}?',
        message: 'This permanently deletes the account and all of its transactions, budgets and goals.');
    if (!ok) return;
    await _repo.deleteStudent(s.user.id);
    _reload();
    if (mounted) showSnack(context, 'Student deleted');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Students')),
      body: FutureBuilder<List<StudentSummary>>(
        future: _future,
        builder: (context, snap) {
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          final q = _search.text.trim().toLowerCase();
          final list = snap.data!
              .where((s) =>
                  q.isEmpty ||
                  s.user.fullName.toLowerCase().contains(q) ||
                  s.user.email.toLowerCase().contains(q) ||
                  s.user.mobile.contains(q))
              .toList();
          return ResponsiveBody(
            maxWidth: 900,
            child: ListView(padding: screenPadding, children: [
              TextField(
                controller: _search,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                    hintText: 'Search by name, email or mobile',
                    prefixIcon: Icon(Icons.search)),
              ),
              const SizedBox(height: 8),
              Text('${list.length} of ${snap.data!.length} students'),
              const SizedBox(height: 8),
              if (list.isEmpty)
                const EmptyState(icon: Icons.people_outline, title: 'No students found', message: 'Registered students appear here.')
              else
                for (final s in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ExpansionTile(
                      shape: const Border(),
                      leading: CircleAvatar(
                        backgroundColor: s.user.isActive ? null : Colors.grey.shade300,
                        child: Text(s.user.fullName[0].toUpperCase()),
                      ),
                      title: Text(s.user.fullName, style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text('${s.user.email}${s.user.isActive ? '' : ' · DEACTIVATED'}'),
                      childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      expandedCrossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Mobile: ${s.user.mobile}'),
                        Text('Joined: ${Fmt.prettyDate(s.user.createdAt)}'),
                        Text('Last login: ${s.user.lastLogin == null ? 'never' : Fmt.timeAgo(s.user.lastLogin!)}'),
                        Text('Transactions: ${s.transactionCount} · income ${Fmt.money(s.totalIncome)} · expenses ${Fmt.money(s.totalExpense)}'),
                        const SizedBox(height: 8),
                        Wrap(spacing: 8, children: [
                          OutlinedButton.icon(
                            onPressed: () => _toggle(s),
                            icon: Icon(s.user.isActive ? Icons.block : Icons.check_circle_outline),
                            label: Text(s.user.isActive ? 'Deactivate' : 'Activate'),
                          ),
                          TextButton.icon(
                            onPressed: () => _delete(s),
                            icon: const Icon(Icons.delete_outline),
                            label: const Text('Delete'),
                            style: TextButton.styleFrom(foregroundColor: Colors.red),
                          ),
                        ]),
                      ],
                    ),
                  ),
            ]),
          );
        },
      ),
    );
  }
}
