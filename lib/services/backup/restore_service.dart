import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../database/database_helper.dart';
import 'backup_service.dart';

class RestoreResult {
  final int itemCount;
  final DateTime? exportedAt;

  const RestoreResult({required this.itemCount, this.exportedAt});
}

class RestoreService {
  /// Maximum backup file size (10 MB) to prevent OOM on malicious files.
  static const int _maxBackupSizeBytes = 10 * 1024 * 1024;

  /// SharedPreferences keys that must NOT be restored from untrusted backups
  /// because they control app security settings.
  static const Set<String> _securityKeys = {
    'app_lock_enabled',
    'pin_hash',
    'pin_salt',
    'biometric_enabled',
    'lock_timeout',
    'pin_failed_attempts',
    'pin_lockout_until_ms',
  };

  static Future<Map<String, dynamic>?> pickAndParse() async {
    if (kIsWeb) return null;

    final file = await FilePicker.pickFile(
      dialogTitle: 'Import PYLO backup',
      type: FileType.custom,
      allowedExtensions: ['pylobackup', 'json'],
    );

    if (file == null) return null;

    // Enforce size limit to prevent OOM.
    final filePath = file.path;
    if (filePath != null) {
      final fileEntity = File(filePath);
      final fileSize = await fileEntity.length();
      if (fileSize > _maxBackupSizeBytes) {
        throw Exception('Backup file is too large (${fileSize ~/ 1024} KB). Maximum is ${_maxBackupSizeBytes ~/ 1024} KB.');
      }
    }

    String content;
    try {
      content = utf8.decode(await file.readAsBytes());
    } catch (_) {
      final path = file.path;
      if (path == null) rethrow;
      content = await File(path).readAsString();
    }

    try {
      return jsonDecode(content) as Map<String, dynamic>;
    } catch (e) {
      debugPrint('Backup parse failed: $e');
      return null;
    }
  }

  static bool validateEnvelope(Map<String, dynamic> envelope) {
    final metadata = envelope['metadata'];
    if (metadata is! Map<String, dynamic>) return false;
    return metadata['app'] == BackupMetadata.appName;
  }

  static Future<RestoreResult?> restore(WidgetRef ref) async {
    final envelope = await pickAndParse();
    if (envelope == null) return null;
    if (!validateEnvelope(envelope)) {
      throw Exception('This file is not a valid PYLO backup.');
    }

    final data = envelope['data'];
    if (data is! Map<String, dynamic>) {
      throw Exception('Backup data section is missing.');
    }

    final parsed = <String, List<Map<String, dynamic>>>{};
    for (final entry in data.entries) {
      final rows = entry.value;
      if (rows is List) {
        parsed[entry.key] =
            rows.map((r) => Map<String, dynamic>.from(r as Map)).toList();
      }
    }

    await DatabaseHelper.instance.importAllTables(parsed);

    final prefsData = envelope['preferences'];
    if (prefsData is Map<String, dynamic>) {
      final prefs = await SharedPreferences.getInstance();
      for (final entry in prefsData.entries) {
        // Skip security-sensitive keys from untrusted backups.
        if (_securityKeys.contains(entry.key)) continue;
        final value = entry.value;
        if (value is bool) {
          await prefs.setBool(entry.key, value);
        } else if (value is int) {
          await prefs.setInt(entry.key, value);
        } else if (value is double) {
          await prefs.setDouble(entry.key, value);
        } else if (value is String) {
          await prefs.setString(entry.key, value);
        }
      }
    }

    var count = 0;
    for (final rows in parsed.values) {
      count += rows.length;
    }

    DateTime? exportedAt;
    final metadata = envelope['metadata'];
    if (metadata is Map<String, dynamic> &&
        metadata['exportedAt'] is String) {
      exportedAt = DateTime.tryParse(metadata['exportedAt']);
    }

    return RestoreResult(itemCount: count, exportedAt: exportedAt);
  }
}
