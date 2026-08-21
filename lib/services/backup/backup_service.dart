import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/database_helper.dart';

class BackupMetadata {
  static const formatVersion = 1;
  static const appName = 'PYLO';
}

class BackupResult {
  final String path;
  final int itemCount;

  const BackupResult({required this.path, required this.itemCount});
}

class BackupService {
  static Future<Map<String, dynamic>> buildEnvelope() async {
    final db = DatabaseHelper.instance;
    final tables = await db.exportAllTables();
    final prefs = await SharedPreferences.getInstance();

    final prefKeys = [
      'theme_mode',
      'notifications_enabled',
      'birthday_reminders_enabled',
      'app_lock_enabled',
      'biometric_enabled',
      'lock_timeout',
      'reminder_minutes',
      'daily_reminder_enabled',
      'daily_reminder_hour',
      'daily_reminder_minute',
      'profile_name',
      'profile_email',
      'profile_phone',
      'profile_bio',
    ];
    final prefsMap = <String, dynamic>{};
    for (final key in prefKeys) {
      final value = prefs.get(key);
      if (value != null) prefsMap[key] = value;
    }

    return {
      'metadata': {
        'app': BackupMetadata.appName,
        'formatVersion': BackupMetadata.formatVersion,
        'schemaVersion': DatabaseHelper.schemaVersion,
        'exportedAt': DateTime.now().toIso8601String(),
      },
      'data': tables,
      'preferences': prefsMap,
    };
  }

  static String _defaultFileName(String ext) {
    final stamp = DateTime.now().toIso8601String().substring(0, 10);
    return 'PYLO_backup_$stamp.$ext';
  }

  static Future<BackupResult?> _exportAs({
    required String ext,
    required String dialogTitle,
  }) async {
    if (kIsWeb) return null;

    final envelope = await buildEnvelope();
    final json = const JsonEncoder.withIndent('  ').convert(envelope);
    final bytes = Uint8List.fromList(utf8.encode(json));
    final itemCount = envelope['data'] is Map
        ? (envelope['data'] as Map)
            .values
            .fold<int>(0, (sum, rows) => sum + (rows as List).length)
        : 0;

    final uri = await FilePicker.saveFile(
      dialogTitle: dialogTitle,
      fileName: _defaultFileName(ext),
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: [ext],
    );

    if (uri == null) return null;

    return BackupResult(path: uri.toString(), itemCount: itemCount);
  }

  static Future<BackupResult?> exportBackup() {
    return _exportAs(
      ext: 'pylobackup',
      dialogTitle: 'Export PYLO backup',
    );
  }

  static Future<BackupResult?> exportJson() {
    return _exportAs(
      ext: 'json',
      dialogTitle: 'Export PYLO JSON',
    );
  }

  static Future<String?> legacyDatabaseCopy() async {
    if (kIsWeb) return null;
    final dbPath = await DatabaseHelper.instance.databasePath;
    final source = File(dbPath);
    if (!await source.exists()) return null;
    final docs = await getApplicationDocumentsDirectory();
    final backupDir = Directory(p.join(docs.path, 'backups'));
    await backupDir.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(':', '-');
    final target = File(p.join(backupDir.path, 'taskflow_$stamp.db'));
    await source.copy(target.path);
    return target.path;
  }
}
