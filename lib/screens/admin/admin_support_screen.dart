import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../data/models/misc.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../widgets/common.dart';

/// Support queries (reply / change status) and student feedback.
class AdminSupportScreen extends StatefulWidget {
  const AdminSupportScreen({super.key});

  @override
  State<AdminSupportScreen> createState() => _AdminSupportScreenState();
}

class _AdminSupportScreenState extends State<AdminSupportScreen> {
  EngagementRepository get _repo => context.read<EngagementRepository>();
  late Future<List<SupportQuery>> _queries = _repo.allQueries();
  late Future<List<FeedbackEntry>> _feedback = _repo.allFeedback();

  void _reload() => setState(() {
        _queries = _repo.allQueries();
        _feedback = _repo.allFeedback();
      });

  Future<void> _respond(SupportQuery q) async {
    final ctrl = TextEditingController(text: q.adminResponse ?? '');
    var status = q.status == 'open' ? 'resolved' : q.status;
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          title: Text(q.subject),
          content: SizedBox(
            width: 480,
            child: Form(
              key: key,
              child: SingleChildScrollView(
                child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('From ${q.userName ?? 'student'} · ${Fmt.timeAgo(q.submittedOn)}',
                      style: const TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  Text(q.message),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: ctrl,
                    minLines: 3,
                    maxLines: 6,
                    decoration: const InputDecoration(labelText: 'Response', alignLabelWithHint: true),
                    validator: (v) => Validators.required(v, 'Response'),
                  ),
                  const SizedBox(height: 12),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: const InputDecoration(labelText: 'Status'),
                    items: const [
                      DropdownMenuItem(value: 'open', child: Text('Open')),
                      DropdownMenuItem(value: 'in_progress', child: Text('In progress')),
                      DropdownMenuItem(value: 'resolved', child: Text('Resolved')),
                    ],
                    onChanged: (v) => setState(() => status = v!),
                  ),
                ]),
              ),
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            FilledButton(
                onPressed: () {
                  if (key.currentState!.validate()) Navigator.pop(ctx, true);
                },
                child: const Text('Send reply')),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await _repo.respondToQuery(q, ctrl.text, status);
    _reload();
    if (mounted) showSnack(context, 'Reply sent – the student has been notified');
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Support & feedback'),
          bottom: const TabBar(tabs: [Tab(text: 'Support queries'), Tab(text: 'Feedback')]),
        ),
        body: TabBarView(children: [
          FutureBuilder<List<SupportQuery>>(
            future: _queries,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.isEmpty) {
                return const EmptyState(icon: Icons.inbox_outlined, title: 'No support queries', message: 'Student messages will appear here.');
              }
              return ResponsiveBody(
                maxWidth: 900,
                child: ListView(padding: screenPadding.copyWith(top: 16), children: [
                  for (final q in snap.data!)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        leading: Icon(
                          switch (q.status) {
                            'resolved' => Icons.check_circle,
                            'in_progress' => Icons.pending,
                            _ => Icons.mark_email_unread,
                          },
                          color: switch (q.status) {
                            'resolved' => Colors.green,
                            'in_progress' => Colors.blue,
                            _ => Colors.orange,
                          },
                        ),
                        title: Text(q.subject, style: const TextStyle(fontWeight: FontWeight.w600)),
                        subtitle: Text('${q.userName ?? 'Student'} · ${q.statusLabel} · ${Fmt.timeAgo(q.submittedOn)}\n${q.message}',
                            maxLines: 3, overflow: TextOverflow.ellipsis),
                        isThreeLine: true,
                        trailing: const Icon(Icons.reply),
                        onTap: () => _respond(q),
                      ),
                    ),
                ]),
              );
            },
          ),
          FutureBuilder<List<FeedbackEntry>>(
            future: _feedback,
            builder: (context, snap) {
              if (!snap.hasData) return const Center(child: CircularProgressIndicator());
              if (snap.data!.isEmpty) {
                return const EmptyState(icon: Icons.rate_review_outlined, title: 'No feedback yet', message: 'Student feedback will appear here.');
              }
              return ResponsiveBody(
                maxWidth: 900,
                child: ListView(padding: screenPadding.copyWith(top: 16), children: [
                  for (final f in snap.data!)
                    Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Row(children: [
                          Expanded(child: Text(f.name, style: const TextStyle(fontWeight: FontWeight.w600))),
                          for (var i = 1; i <= 5; i++)
                            Icon(i <= f.rating ? Icons.star : Icons.star_border, size: 16, color: Colors.amber.shade700),
                        ]),
                        subtitle: Text('${f.email} · ${Fmt.timeAgo(f.submittedOn)}\n${f.comments}'),
                        isThreeLine: true,
                      ),
                    ),
                ]),
              );
            },
          ),
        ]),
      ),
    );
  }
}
