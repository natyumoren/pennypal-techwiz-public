import 'dart:io';

import 'package:pennypal/data/database.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Opens a fresh in-memory database built from the real SQL script.
Future<AppDatabase> openTestDatabase({bool seedDemoData = true}) {
  sqfliteFfiInit();
  return AppDatabase.open(
    factory: databaseFactoryFfi,
    path: inMemoryDatabasePath,
    schemaSql: File('database/pennypal_schema.sql').readAsStringSync(),
    seedDemoData: seedDemoData,
  );
}
