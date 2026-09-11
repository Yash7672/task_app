import 'package:flutter_test/flutter_test.dart';
import 'package:task_app/core/utils/notification_helper.dart';

void main() {
  group('AlarmPayload', () {
    test('round-trips task id, title and time without sound', () {
      final alarm = AlarmInfo(
        taskId: 'abc-123',
        taskTitle: 'Stand-Up Court',
        alarmTime: DateTime(2026, 9, 11, 7, 30, 45),
      );

      final payload = AlarmPayload.encode(
        taskId: alarm.taskId,
        taskTitle: alarm.taskTitle,
        alarmTime: alarm.alarmTime,
      );
      final decoded = AlarmPayload.decode(payload);

      expect(decoded, isNotNull);
      expect(decoded!.taskId, alarm.taskId);
      expect(decoded.taskTitle, alarm.taskTitle);
      expect(
        decoded.alarmTime.millisecondsSinceEpoch,
        alarm.alarmTime.millisecondsSinceEpoch,
      );
      expect(decoded.soundId, isNull);
      expect(decoded.customUri, isNull);
    });

    test('round-trips per-task soundId and customUri', () {
      final payload = AlarmPayload.encode(
        taskId: 't1',
        taskTitle: 'Stand-Up',
        alarmTime: DateTime(2026, 9, 11, 8),
        soundId: 'custom',
        customUri:
            'content://com.example.task_app.fileProvider/files/alarms/x.wav',
      );
      final decoded = AlarmPayload.decode(payload);

      expect(decoded, isNotNull);
      expect(decoded!.soundId, 'custom');
      expect(decoded.customUri,
          'content://com.example.task_app.fileProvider/files/alarms/x.wav');
    });

    test('legacy 4-part payload decodes with null sound fields', () {
      final decoded = AlarmPayload.decode(
        'pylo:alarm|t1|Stand-Up|1726032000000',
      );
      expect(decoded, isNotNull);
      expect(decoded!.taskId, 't1');
      expect(decoded.soundId, isNull);
      expect(decoded.customUri, isNull);
    });

    test('escapes separator and percent characters in titles', () {
      final payload = AlarmPayload.encode(
        taskId: 't1',
        taskTitle: 'A|B% special "quoted"',
        alarmTime: DateTime(2026, 9, 11, 8),
      );

      final decoded = AlarmPayload.decode(payload);
      expect(decoded, isNotNull);
      expect(decoded!.taskTitle, 'A|B% special "quoted"');
    });

    test('returns null for non-alarm payloads', () {
      expect(AlarmPayload.decode(null), isNull);
      expect(AlarmPayload.decode(''), isNull);
      expect(AlarmPayload.decode('random text'), isNull);
      expect(AlarmPayload.decode('pylo:alarm|id'), isNull);
      expect(
        AlarmPayload.decode('pylo:alarm|id|title|not-a-number'),
        isNull,
      );
      expect(
        AlarmPayload.decode('other:scheme|id|title|123'),
        isNull,
      );
    });
  });

  group('AlarmInfo.key', () {
    test('is unique per task and alarm time', () {
      final a = AlarmInfo(
        taskId: 't1',
        taskTitle: 'x',
        alarmTime: DateTime(2026, 9, 11, 8),
      );
      final b = AlarmInfo(
        taskId: 't1',
        taskTitle: 'x',
        alarmTime: DateTime(2026, 9, 11, 8, 0, 1),
      );
      final c = AlarmInfo(
        taskId: 't2',
        taskTitle: 'x',
        alarmTime: DateTime(2026, 9, 11, 8),
      );

      expect(a.key, isNot(b.key));
      expect(a.key, isNot(c.key));
      expect(b.key, isNot(c.key));
    });
  });

  group('PyloAlarmSound', () {
    test('fromId maps known ids and falls back to classic', () {
      expect(PyloAlarmSound.fromId('classic'), PyloAlarmSound.classic);
      expect(PyloAlarmSound.fromId('marimba'), PyloAlarmSound.marimba);
      expect(PyloAlarmSound.fromId('gentle'), PyloAlarmSound.gentle);
      expect(PyloAlarmSound.fromId('digital'), PyloAlarmSound.digital);
      expect(PyloAlarmSound.fromId('urgent'), PyloAlarmSound.urgent);
      expect(PyloAlarmSound.fromId('custom'), PyloAlarmSound.custom);
      expect(PyloAlarmSound.fromId('nope'), PyloAlarmSound.classic);
      expect(PyloAlarmSound.fromId(null), PyloAlarmSound.classic);
    });

    test('every built-in sound names a raw resource', () {
      for (final sound in PyloAlarmSound.values) {
        if (sound == PyloAlarmSound.custom) continue;
        expect(sound.rawName, isNotNull);
        expect(sound.rawName!, startsWith('alarm_'));
      }
    });
  });

  group('AlarmChannelConfig', () {
    test('fromPrefs maps stored settings', () {
      final config = AlarmChannelConfig.fromPrefs(
        soundId: 'urgent',
        customUri: null,
        vibrate: false,
      );
      expect(config.sound, PyloAlarmSound.urgent);
      expect(config.vibrate, isFalse);
    });
  });
}
