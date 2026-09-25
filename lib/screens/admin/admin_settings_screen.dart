import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/config.dart';
import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../data/repositories/admin_repository.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../services/report_service.dart';
import '../../widgets/common.dart';
import '../student/more_screen.dart';

/// App settings and the analytics report export.
class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  EngagementRepository get _repo => context.read<EngagementRepository>();
  final _email = TextEditingController();
  final _form = GlobalKey<FormState>();
  double _threshold = 80;
  bool _chatbot = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _repo.settings().then((s) {
      if (!mounted) return;
      setState(() {
        _threshold = double.tryParse(s['default_alert_threshold'] ?? '') ?? 80;
        _chatbot = s['chatbot_enabled'] != '0';
        _email.text = s['support_email'] ?? '';
        _loaded = true;
      });
    });
  }

  @override
  void dispose() {
    _email.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    await _repo.saveSetting('default_alert_threshold', '${_threshold.round()}');
    await _repo.saveSetting('chatbot_enabled', _chatbot ? '1' : '0');
    await _repo.saveSetting('support_email', _email.text.trim());
    if (mounted) showSnack(context, 'Settings saved');
  }

  Future<void> _exportAnalytics() async {
    final admin = context.read<AdminRepository>();
    final s = await admin.stats();
    final students = await admin.students();
    final b = StringBuffer()
      ..writeln('PennyPal analytics report,${Fmt.nowIso()}')
      ..writeln('Students,${s.students}')
      ..writeln('Active accounts,${s.activeStudents}')
      ..writeln('New in last 30 days,${s.newStudents30d}')
      ..writeln('Logged in last 7 days,${s.activeLast7d}')
      ..writeln('Transactions,${s.transactions}')
      ..writeln('Total income tracked,${s.totalIncome.toStringAsFixed(2)}')
      ..writeln('Total expenses tracked,${s.totalExpense.toStringAsFixed(2)}')
      ..writeln('Savings goals,${s.goals}')
      ..writeln('Completed goals,${s.completedGoals}')
      ..writeln('Open support queries,${s.openQueries}')
      ..writeln('Average feedback rating,${s.averageRating.toStringAsFixed(2)}')
      ..writeln()
      ..writeln('Category,Total spent');
    s.spendByCategory.forEach((k, v) => b.writeln('"$k",${v.toStringAsFixed(2)}'));
    b
      ..writeln()
      ..writeln('Student,Email,Active,Joined,Transactions,Income,Expenses');
    for (final st in students) {
      b.writeln('"${st.user.fullName}",${st.user.email},${st.user.isActive},'
          '${st.user.createdAt.substring(0, 10)},${st.transactionCount},'
          '${st.totalIncome.toStringAsFixed(2)},${st.totalExpense.toStringAsFixed(2)}');
    }
    await ReportService.share(b.toString(), 'pennypal_analytics_${Fmt.isoDate(DateTime.now())}.csv');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: !_loaded
          ? const Center(child: CircularProgressIndicator())
          : ResponsiveBody(
              maxWidth: 700,
              child: Form(
                key: _form,
                child: ListView(padding: screenPadding, children: [
                  const SectionHeader('App settings'),
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('Chatbot enabled'),
                          subtitle: Text(AppConfig.aiEnabled
                              ? 'Using Google Gemini (${AppConfig.geminiModel})'
                              : 'No Gemini key configured – offline rule-based answers'),
                          value: _chatbot,
                          onChanged: (v) => setState(() => _chatbot = v),
                        ),
                        const SizedBox(height: 8),
                        Text('Default alert threshold for new budgets: ${_threshold.round()}%'),
                        Slider(
                          value: _threshold,
                          min: 50,
                          max: 100,
                          divisions: 10,
                          label: '${_threshold.round()}%',
                          onChanged: (v) => setState(() => _threshold = v),
                        ),
                        TextFormField(
                          controller: _email,
                          decoration: const InputDecoration(labelText: 'Support email shown to students'),
                          validator: Validators.email,
                        ),
                        const SizedBox(height: 12),
                        Align(
                          alignment: Alignment.centerRight,
                          child: FilledButton(onPressed: _save, child: const Text('Save settings')),
                        ),
                      ]),
                    ),
                  ),
                  const SectionHeader('Reports'),
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.analytics_outlined),
                      title: const Text('Export analytics report'),
                      subtitle: const Text('Usage statistics and per-student summary (CSV)'),
                      trailing: const Icon(Icons.download),
                      onTap: _exportAnalytics,
                    ),
                  ),
                  const SizedBox(height: 24),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.logout),
                    label: const Text('Log out'),
                    onPressed: () => confirmLogout(context),
                  ),
                ]),
              ),
            ),
    );
  }
}
