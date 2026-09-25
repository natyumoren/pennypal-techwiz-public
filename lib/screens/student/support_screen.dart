import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../data/models/misc.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../state/finance_state.dart';
import '../../state/session_state.dart';
import '../../widgets/common.dart';

/// Contact support: submit a query and follow the administrator's replies.
class SupportScreen extends StatefulWidget {
  const SupportScreen({super.key});

  @override
  State<SupportScreen> createState() => _SupportScreenState();
}

class _SupportScreenState extends State<SupportScreen> {
  final _form = GlobalKey<FormState>();
  final _subject = TextEditingController();
  final _message = TextEditingController();
  List<SupportQuery> _queries = [];
  String? _supportEmail;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final repo = context.read<EngagementRepository>();
    final userId = context.read<SessionState>().user!.id;
    final q = await repo.queriesFor(userId);
    final s = await repo.settings();
    if (mounted) {
      setState(() {
        _queries = q;
        _supportEmail = s['support_email'];
      });
    }
  }

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _sending = true);
    await context.read<EngagementRepository>().submitQuery(
        context.read<SessionState>().user!.id, _subject.text, _message.text);
    _subject.clear();
    _message.clear();
    await _load();
    if (!mounted) return;
    setState(() => _sending = false);
    FocusScope.of(context).unfocus();
    showSnack(context, 'Your message was sent. We will reply here and notify you.');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact support')),
      body: RefreshIndicator(
        onRefresh: () async {
          await _load();
          if (context.mounted) await context.read<FinanceState>().refreshNotifications();
        },
        child: ResponsiveBody(
          maxWidth: 700,
          child: ListView(padding: screenPadding, children: [
            Form(
              key: _form,
              child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                Text('Having trouble or a question? Send us a message.'
                    '${_supportEmail != null ? ' You can also email $_supportEmail.' : ''}'),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _subject,
                  maxLength: 100,
                  decoration: const InputDecoration(labelText: 'Subject *'),
                  validator: (v) => Validators.required(v, 'Subject'),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _message,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 2000,
                  decoration: const InputDecoration(
                      labelText: 'Message *', alignLabelWithHint: true),
                  validator: (v) {
                    final r = Validators.required(v, 'Message');
                    if (r != null) return r;
                    return v!.trim().length < 10 ? 'Please describe the issue in at least 10 characters' : null;
                  },
                ),
                const SizedBox(height: 12),
                FilledButton.icon(
                  onPressed: _sending ? null : _submit,
                  icon: const Icon(Icons.send),
                  label: const Text('Send message'),
                ),
              ]),
            ),
            const SectionHeader('My requests'),
            if (_queries.isEmpty)
              const Card(
                  child: EmptyState(
                      icon: Icons.forum_outlined,
                      title: 'No requests yet',
                      message: 'Messages you send appear here with our replies.'))
            else
              for (final q in _queries)
                Card(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: ExpansionTile(
                    shape: const Border(),
                    leading: Icon(
                      q.status == 'resolved' ? Icons.check_circle : Icons.schedule,
                      color: q.status == 'resolved' ? Colors.green : Colors.orange,
                    ),
                    title: Text(q.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text('${q.statusLabel} · ${Fmt.timeAgo(q.submittedOn)}'),
                    childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                    expandedCrossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(q.message),
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Theme.of(context).colorScheme.primaryContainer.withValues(alpha: .4),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(q.adminResponse == null
                            ? 'Waiting for a reply from the PennyPal team.'
                            : 'Reply: ${q.adminResponse}'),
                      ),
                    ],
                  ),
                ),
          ]),
        ),
      ),
    );
  }
}
