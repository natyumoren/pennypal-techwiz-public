import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/repositories/engagement_repository.dart';
import '../data/repositories/finance_repository.dart';
import '../services/sync_service.dart';
import 'finance_state.dart';
import 'session_state.dart';

/// Placed above the Navigator (MaterialApp.builder) so every pushed route
/// can read the logged-in student's [FinanceState]. A fresh state is
/// created per student and disposed on logout.
class FinanceScope extends StatefulWidget {
  const FinanceScope({super.key, required this.child});
  final Widget child;

  @override
  State<FinanceScope> createState() => _FinanceScopeState();
}

class _FinanceScopeState extends State<FinanceScope> {
  FinanceState? _state;

  void _release() {
    final old = _state;
    _state = null;
    if (old != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
    }
  }

  @override
  void dispose() {
    _state?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    final user = session.user;
    if (user == null || user.isAdmin) {
      _release();
      return widget.child;
    }
    if (_state?.userId != user.id) {
      _release();
      _state = FinanceState(
        userId: user.id,
        finance: context.read<FinanceRepository>(),
        engagement: context.read<EngagementRepository>(),
        sync: context.read<SyncService>(),
        currencyOf: () => session.currency,
        notificationsEnabled: () => session.profile?.notificationsOn ?? true,
      )..load();
    }
    return ChangeNotifierProvider<FinanceState>.value(
        value: _state!, child: widget.child);
  }
}
