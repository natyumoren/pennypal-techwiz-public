import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/formatters.dart';
import '../../core/validators.dart';
import '../../data/repositories/auth_repository.dart';
import '../../services/sync_service.dart';
import '../../state/session_state.dart';
import '../../widgets/common.dart';
import 'more_screen.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _form = GlobalKey<FormState>();
  late final SessionState _session = context.read<SessionState>();
  late final _name = TextEditingController(text: _session.user!.fullName);
  late final _mobile = TextEditingController(text: _session.user!.mobile);

  @override
  void dispose() {
    _name.dispose();
    _mobile.dispose();
    super.dispose();
  }

  Future<void> _saveDetails() async {
    if (!_form.currentState!.validate()) return;
    await _session.updateDetails(_name.text, _mobile.text);
    if (mounted) showSnack(context, 'Profile updated');
  }

  Future<void> _changePassword() async {
    final current = TextEditingController();
    final next = TextEditingController();
    final key = GlobalKey<FormState>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Change password'),
        content: Form(
          key: key,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            TextFormField(
              controller: current,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Current password'),
              validator: (v) => Validators.required(v, 'Current password'),
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: next,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'New password', errorMaxLines: 3),
              validator: Validators.password,
            ),
          ]),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(
              onPressed: () {
                if (key.currentState!.validate()) Navigator.pop(ctx, true);
              },
              child: const Text('Change')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await _session.changePassword(current.text, next.text);
      if (mounted) showSnack(context, 'Password changed');
    } on AuthException catch (e) {
      if (mounted) showSnack(context, e.message, error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final sync = context.watch<SyncService>();
    final profile = session.profile!;
    return Scaffold(
      appBar: AppBar(title: const Text('Profile & settings')),
      body: ResponsiveBody(
        maxWidth: 640,
        child: ListView(padding: screenPadding, children: [
          Form(
            key: _form,
            child: Column(children: [
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Full name'),
                validator: Validators.name,
              ),
              const SizedBox(height: 12),
              TextFormField(
                initialValue: session.user!.email,
                enabled: false,
                decoration: const InputDecoration(labelText: 'Email (cannot be changed)'),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _mobile,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(labelText: 'Mobile number'),
                validator: Validators.mobile,
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton.tonal(
                    onPressed: _saveDetails, child: const Text('Save details')),
              ),
            ]),
          ),
          const SectionHeader('Preferences'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.payments_outlined),
                title: const Text('Currency'),
                trailing: DropdownButton<String>(
                  value: profile.currency,
                  underline: const SizedBox(),
                  items: [
                    for (final c in Fmt.currencies.keys)
                      DropdownMenuItem(value: c, child: Text(c)),
                  ],
                  onChanged: (v) => session.saveProfile(profile.copyWith(currency: v)),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.school_outlined),
                title: const Text('Student status'),
                trailing: DropdownButton<String>(
                  value: profile.studentStatus,
                  hint: const Text('Not set'),
                  underline: const SizedBox(),
                  items: [
                    for (final s in const [
                      'High school',
                      'Undergraduate',
                      'Postgraduate',
                      'Vocational / diploma',
                      'Other'
                    ])
                      DropdownMenuItem(value: s, child: Text(s)),
                  ],
                  onChanged: (v) =>
                      session.saveProfile(profile.copyWith(studentStatus: v)),
                ),
              ),
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: const Text('Push notifications'),
                subtitle: const Text('Budget alerts and goal milestones on this device'),
                value: profile.notificationsOn,
                onChanged: (v) =>
                    session.saveProfile(profile.copyWith(notificationsOn: v)),
              ),
            ]),
          ),
          const SectionHeader('Security & data'),
          Card(
            child: Column(children: [
              ListTile(
                leading: const Icon(Icons.lock_reset),
                title: const Text('Change password'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _changePassword,
              ),
              ListTile(
                leading: const Icon(Icons.cloud_sync_outlined),
                title: const Text('Cloud sync'),
                subtitle: Text(switch (sync.status) {
                  SyncStatus.localOnly =>
                    'Not configured – data is saved on this device only',
                  SyncStatus.offline => 'Offline – ${sync.pending} change(s) queued',
                  SyncStatus.syncing => 'Syncing...',
                  SyncStatus.error => 'Last sync failed – will retry',
                  SyncStatus.idle => sync.pending == 0
                      ? 'Up to date${sync.lastSynced != null ? ' (${Fmt.timeAgo(sync.lastSynced!.toIso8601String())})' : ''}'
                      : '${sync.pending} change(s) waiting',
                }),
                trailing: sync.status == SyncStatus.localOnly
                    ? null
                    : IconButton(
                        tooltip: 'Sync now',
                        onPressed: sync.syncNow,
                        icon: const Icon(Icons.sync)),
              ),
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
}
