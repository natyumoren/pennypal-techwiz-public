import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../data/repositories/engagement_repository.dart';
import '../../state/session_state.dart';
import '../../widgets/common.dart';

class FeedbackScreen extends StatefulWidget {
  const FeedbackScreen({super.key});

  @override
  State<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends State<FeedbackScreen> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _email;
  final _comments = TextEditingController();
  int _rating = 0;
  bool _ratingError = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    final u = context.read<SessionState>().user;
    _name = TextEditingController(text: u?.fullName ?? '');
    _email = TextEditingController(text: u?.email ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _comments.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final ok = _form.currentState!.validate();
    setState(() => _ratingError = _rating == 0);
    if (!ok || _rating == 0) return;
    setState(() => _sending = true);
    await context.read<EngagementRepository>().submitFeedback(
          userId: context.read<SessionState>().user?.id,
          name: _name.text,
          email: _email.text,
          rating: _rating,
          comments: _comments.text,
        );
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        icon: const Icon(Icons.check_circle, color: Colors.green, size: 48),
        title: const Text('Thank you!'),
        content: const Text('Your feedback has been submitted and helps us improve PennyPal.'),
        actions: [FilledButton(onPressed: () => Navigator.pop(ctx), child: const Text('OK'))],
      ),
    );
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Feedback')),
      body: ResponsiveBody(
        maxWidth: 600,
        child: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(16), children: [
            const Text('Tell us what you like and what we can do better.'),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(labelText: 'Name *'),
              validator: Validators.name,
            ),
            const SizedBox(height: 14),
            TextFormField(
              controller: _email,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email *'),
              validator: Validators.email,
            ),
            const SizedBox(height: 16),
            Text('Rating *', style: Theme.of(context).textTheme.titleSmall),
            Row(children: [
              for (var i = 1; i <= 5; i++)
                IconButton(
                  tooltip: '$i star${i == 1 ? '' : 's'}',
                  iconSize: 36,
                  onPressed: () => setState(() {
                    _rating = i;
                    _ratingError = false;
                  }),
                  icon: Icon(i <= _rating ? Icons.star_rounded : Icons.star_outline_rounded,
                      color: Colors.amber.shade700),
                ),
            ]),
            if (_ratingError)
              Text('Please choose a rating',
                  style: TextStyle(color: Theme.of(context).colorScheme.error, fontSize: 12)),
            const SizedBox(height: 14),
            TextFormField(
              controller: _comments,
              minLines: 4,
              maxLines: 8,
              maxLength: 1000,
              decoration: const InputDecoration(
                  labelText: 'Comments *', alignLabelWithHint: true),
              validator: (v) {
                final r = Validators.required(v, 'Comments');
                if (r != null) return r;
                return v!.trim().length < 10 ? 'Please write at least 10 characters' : null;
              },
            ),
            const SizedBox(height: 16),
            FilledButton(
                onPressed: _sending ? null : _submit,
                child: const Text('Submit feedback')),
          ]),
        ),
      ),
    );
  }
}
