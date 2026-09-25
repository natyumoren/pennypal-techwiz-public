import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/config.dart';
import 'core/theme.dart';
import 'data/database.dart';
import 'data/repositories/admin_repository.dart';
import 'data/repositories/auth_repository.dart';
import 'data/repositories/engagement_repository.dart';
import 'data/repositories/finance_repository.dart';
import 'screens/admin/admin_shell.dart';
import 'screens/auth/login_screen.dart';
import 'screens/student/student_shell.dart';
import 'services/cloud_service.dart';
import 'services/sync_service.dart';
import 'state/finance_scope.dart';
import 'state/session_state.dart';
import 'widgets/common.dart';

class PennyPalApp extends StatelessWidget {
  const PennyPalApp({super.key, required this.database});
  final AppDatabase database;

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider.value(value: database),
        Provider(create: (_) => AuthRepository(database)),
        Provider(create: (_) => FinanceRepository(database)),
        Provider(create: (_) => EngagementRepository(database)),
        Provider(create: (_) => AdminRepository(database)),
        ChangeNotifierProvider(
            create: (_) =>
                SyncService(database, CloudService.instance)..start()),
        ChangeNotifierProvider(
            create: (ctx) => SessionState(ctx.read<AuthRepository>(),
                sync: ctx.read<SyncService>())
              ..restore()),
      ],
      child: MaterialApp(
        title: AppConfig.appName,
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        builder: (context, child) => FinanceScope(child: child!),
        home: const AuthGate(),
      ),
    );
  }
}

/// Routes to the right experience based on who is logged in.
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionState>();
    if (session.restoring) {
      return const Scaffold(body: Center(child: BrandLogo(size: 64)));
    }
    final user = session.user;
    if (user == null) return const LoginScreen();
    if (user.isAdmin) return AdminShell(key: ValueKey(user.id));
    return StudentShell(key: ValueKey(user.id));
  }
}
