import 'package:flutter/material.dart';

import 'app.dart';
import 'data/database.dart';
import 'services/cloud_service.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final db = await AppDatabase.open();
  await CloudService.instance.init();
  await LocalNotifier.init();
  runApp(PennyPalApp(database: db));
}
