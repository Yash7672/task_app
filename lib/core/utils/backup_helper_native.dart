import 'dart:io';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

Future<String?> performBackup() async {
  final dbDir = await getDatabasesPath();
  final source = File(p.join(dbDir, 'taskflow.db'));
  if (!await source.exists()) return null;
  final appDir = await getApplicationDocumentsDirectory();
  final backupDir = Directory(p.join(appDir.path, 'backups'));
  await backupDir.create(recursive: true);
  final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
  final target = File(p.join(backupDir.path, 'taskflow_$stamp.db'));
  await source.copy(target.path);
  return target.path;
}
