import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import 'package:task_app/core/utils/alarm_sound_service.dart';
import 'package:task_app/core/utils/notification_helper.dart';

/// Writes a real WAV into the app's private `alarms/` directory (the same
/// location `pickAndImportCustomSound` uses) and returns the FileProvider
/// content URI the engine is expected to resolve.
Future<String> _installCustomAlarmFile() async {
  final dir = await getApplicationSupportDirectory();
  final alarmsDir =
      Directory('${dir.path}${Platform.pathSeparator}alarms');
  await alarmsDir.create(recursive: true);
  final bytes = (await rootBundle
          .load('assets/raw/alarm_urgent.wav'))
      .buffer
      .asUint8List();
  const fileName = 'pylo_alarm_custom.wav';
  await File('${alarmsDir.path}${Platform.pathSeparator}$fileName')
      .writeAsBytes(bytes, flush: true);
  return 'content://${AlarmSoundService.authority}/${AlarmSoundService.filesTag}/'
      '${AlarmSoundService.alarmsSubpath}/$fileName';
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  tz_data.initializeTimeZones();

  setUpAll(() async {
    final tzInfo = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(tzInfo.identifier));
  });

  testWidgets('built-in sound engine starts on the device',
      (tester) async {
    final player = await AlarmSoundService.startAlarmPlayback(
      soundId: 'urgent',
      customUri: null,
    );
    expect(player, isNotNull,
        reason: 'built-in AssetSource must resolve to a playable file');
    await player!.stop();
    await player.dispose();
  });

  testWidgets('custom content-URI sound engine starts on the device',
      (tester) async {
    final uri = await _installCustomAlarmFile();
    final player = await AlarmSoundService.startAlarmPlayback(
      soundId: 'custom',
      customUri: uri,
    );
    expect(player, isNotNull,
        reason: 'DeviceFileSource must resolve from the FileProvider URI');
    await player!.stop();
    await player.dispose();
  });

  testWidgets('schedules a native full-screen alarm for the cold-start test',
      (tester) async {
    final uri = await _installCustomAlarmFile();
    // Configure the GLOBAL alarm settings the way Settings > Alarm does. The
    // native AlarmActivity reads these at ring time from the
    // shared_preferences plugin store.
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('alarm_sound_id', 'custom');
    await prefs.setString('custom_alarm_uri', uri);
    await prefs.setBool('alarm_vibrate', true);
    await prefs.setInt('alarm_snooze_minutes', 5);

    final alarmTime = DateTime.now().add(const Duration(seconds: 40));
    await NotificationHelper.scheduleTaskAlarm(
      taskId: 'e2e-custom-sound',
      taskTitle: 'PYLO E2E Custom Sound',
      alarmTime: alarmTime,
    );
    debugPrint('PYLO_E2E_SCHEDULED ${alarmTime.toIso8601String()}');
    await tester.pump(const Duration(seconds: 1));
    expect(true, isTrue);
  });
}