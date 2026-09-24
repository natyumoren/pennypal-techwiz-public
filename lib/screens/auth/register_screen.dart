import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/validators.dart';
import '../../data/repositories/auth_repository.dart';
import '../../state/session_state.dart';
import '../student/about_screen.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  static const statuses = [
    'High school',
    'Undergraduate',
    'Postgraduate',
    'Vocational / diploma',
    'Other',
  ];

  final _form = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _mobile = TextEditingController();
  final _password = TextEditingController();
  final _confirm = TextEditingController();
  String? _status;
  bool _agreed = false;
  bool _obscure = true;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    for (final c in [_name, _email, _mobile, _password, _confirm]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() => _error = null);
    if (!_form.currentState!.validate()) return;
    if (!_agreed) {
      setState(() => _error = 'Please accept the privacy notice to continue.');
      return;
    }
    setState(() => _busy = true);
    try {
      await context.read<SessionState>().register(
            fullName: _name.text,
            email: _email.text,
            mobile: _mobile.text,
            password: _password.text,
            studentStatus: _status,
          );
      if (mounted) Navigator.of(context).popUntil((r) => r.isFirst);
    } on AuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = 'Could not create your account. ($e)');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Create your account')),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 480),
              child: Form(
                key: _form,
                autovalidateMode: AutovalidateMode.onUserInteraction,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                        'It takes a minute. We only ask for what we need to run your account.',
                        style: TextStyle(color: cs.onSurfaceVariant)),
                    const SizedBox(height: 20),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      autofillHints: const [AutofillHints.name],
                      decoration: const InputDecoration(
                          labelText: 'Full name *',
                          prefixIcon: Icon(Icons.person_outline)),
                      validator: Validators.name,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autofillHints: const [AutofillHints.email],
                      decoration: const InputDecoration(
                          labelText: 'Email *',
                          prefixIcon: Icon(Icons.email_outlined)),
                      validator: Validators.email,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _mobile,
                      keyboardType: TextInputType.phone,
                      autofillHints: const [AutofillHints.telephoneNumber],
                      decoration: const InputDecoration(
                          labelText: 'Mobile number *',
                          hintText: '+15550100200',
                          prefixIcon: Icon(Icons.phone_outlined)),
                      validator: Validators.mobile,
                    ),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      value: _status,
                      decoration: const InputDecoration(
                          labelText: 'Student status (optional)',
                          prefixIcon: Icon(Icons.school_outlined)),
                      items: [
                        for (final s in statuses)
                          DropdownMenuItem(value: s, child: Text(s))
                      ],
                      onChanged: (v) => setState(() => _status = v),
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      autofillHints: const [AutofillHints.newPassword],
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                        labelText: 'Password *',
                        prefixIcon: const Icon(Icons.lock_outline),
                        helperText:
                            '8+ characters with upper & lower case, a number and a symbol',
                        helperMaxLines: 2,
                        suffixIcon: IconButton(
                          tooltip: _obscure ? 'Show password' : 'Hide password',
                          icon: Icon(_obscure
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined),
                          onPressed: () => setState(() => _obscure = !_obscure),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: 14),
                    TextFormField(
                      controller: _confirm,
                      obscureText: _obscure,
                      decoration: const InputDecoration(
                          labelText: 'Confirm password *',
                          prefixIcon: Icon(Icons.lock_reset_outlined)),
                      validator: (v) => Validators.confirm(v, _password.text),
                    ),
                    const SizedBox(height: 8),
                    CheckboxListTile(
                      value: _agreed,
                      contentPadding: EdgeInsets.zero,
                      controlAffinity: ListTileControlAffinity.leading,
                      onChanged: (v) => setState(() => _agreed = v ?? false),
                      title: const Text(
                          'I understand PennyPal is a learning and budgeting tool, not a bank or financial adviser, and I agree to the privacy notice.'),
                      subtitle: Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton(
                          style: TextButton.styleFrom(padding: EdgeInsets.zero),
                          onPressed: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const AboutScreen())),
                          child: const Text('Read the privacy notice'),
                        ),
                      ),
                    ),
                    if (_error != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Semantics(
                            liveRegion: true,
                            child: Text(_error!,
                                style: TextStyle(color: cs.error))),
                      ),
                    const SizedBox(height: 16),
                    FilledButton(
                      onPressed: _busy ? null : _submit,
                      child: _busy
                          ? const SizedBox(
                              height: 20,
                              width: 20,
                              child: CircularProgressIndicator(strokeWidth: 2))
                          : const Text('Create account'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
