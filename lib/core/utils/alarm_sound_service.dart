import 'dart:async';
import 'dart:io';

import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

import 'notification_helper.dart';

/// A user-picked alarm audio file lives in the app's private `alarms/`
/// directory so the in-app alarm engine can play it directly from disk.
///
/// The `files-path name="files" path="."` registration in file_paths.xml maps
/// `content://com.example.task_app.fileProvider/files/<subpath>` onto
/// `getFilesDir()/<subpath>` — exactly where getApplicationSupportDirectory()
/// points on Android.  Content URIs are used as *identity* (they survive app
/// restarts when stored in the task/preferences), but the sound itself is
/// always played by [startAlarmPlayback] reading the local file — never handed
/// to the OS notification system, which cannot open FileProvider URIs while the
/// app process is dead and silently falls back to the default notification tone.
class AlarmSoundService {
  /// Tag name registered in `res/xml/file_paths.xml` for <files-path>.
  static const String authority = 'com.example.task_app.fileProvider';
  static const String filesTag = 'files';
  static const String alarmsSubpath = 'alarms';

  static const List<String> allowedExtensions = [
    'wav',
    'mp3',
    'ogg',
    'm4a',
    'opus',
  ];

  /// Singleton audio player used for alarm previews. Only one preview should
  /// play at a time; stopPreview() must be called before leaving any screen
  /// that uses preview to avoid leaked audio streams.
  static AudioPlayer? _previewPlayer;

  /// Timer for the preview's auto-stop. Held so a new preview can cancel the
  /// previous one and so stopPreview() never leaves a dangling runnable that
  /// later fires against a null/replaced player.
  static Timer? _previewAutoStop;

  /// Asks the user for an audio file, copies it into `alarms/` inside the app
  /// files directory, and returns the resulting content:// URI.
  /// Returns null when the picker is dismissed or any step fails.
  static Future<String?> pickAndImportCustomSound() async {
    if (kIsWeb) return null;
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: allowedExtensions,
      );
      if (file == null) return null;
      final path = file.path;
      if (path == null) return null;

      // Validate the source file is readable before copying.
      final source = File(path);
      if (!await source.exists()) {
        debugPrint('Selected audio file no longer exists');
        return null;
      }

      final ext = path.split('.').last.toLowerCase();
      final fileName = 'pylo_alarm_custom.$ext';
      final dir = await getApplicationSupportDirectory();
      final alarmsDir = Directory(
          '${dir.path}${Platform.pathSeparator}$alarmsSubpath');
      await alarmsDir.create(recursive: true);
      final dest =
          '${alarmsDir.path}${Platform.pathSeparator}$fileName';
      await File(path).copy(dest);

      return 'content://$authority/$filesTag/$alarmsSubpath/$fileName';
    } catch (e) {
      debugPrint('AlarmSoundService.pickAndImportCustomSound failed: $e');
      return null;
    }
  }

  /// Validates that a content URI is still accessible. Falls back to the
  /// default alarm sound if the referenced file is missing.
  static Future<bool> isUriAccessible(String uri) async {
    if (kIsWeb) return true;
    try {
      if (!uri.startsWith('content://')) return false;
      final pathPart = uri
          .replaceFirst('content://$authority/$filesTag/$alarmsSubpath/', '');
      final dir = await getApplicationSupportDirectory();
      final file = File(
          '${dir.path}${Platform.pathSeparator}$alarmsSubpath${Platform.pathSeparator}$pathPart');
      return await file.exists();
    } catch (_) {
      return false;
    }
  }

  /// Returns the file path on disk for a content URI, or null if unavailable.
  static Future<String?> resolveContentUri(String uri) async {
    if (kIsWeb) return null;
    try {
      if (!uri.startsWith('content://')) return null;
      final pathPart = uri
          .replaceFirst('content://$authority/$filesTag/$alarmsSubpath/', '');
      final dir = await getApplicationSupportDirectory();
      final filePath =
          '${dir.path}${Platform.pathSeparator}$alarmsSubpath${Platform.pathSeparator}$pathPart';
      final file = File(filePath);
      if (await file.exists()) return filePath;
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Plays [soundId] (a PyloAlarmSound id) on the Android ALARM audio stream
  /// with full audio focus, looping until the caller stops and disposes the
  /// returned player.  A custom sound is opened from the app's private files
  /// directory; a missing/unreadable custom file falls back to the built-in
  /// classic sound.  Returns null on failure.
  ///
  /// This is the single source of truth for how a ring sounds: real alarms,
  /// snoozes and previews all route through it, while the notification that
  /// triggers an alarm carries no sound at all.
  static Future<AudioPlayer?> startAlarmPlayback({
    required String? soundId,
    required String? customUri,
  }) async {
    if (kIsWeb) return null;
    try {
      final player = AudioPlayer(
          playerId: 'pylo_alarm_${DateTime.now().microsecondsSinceEpoch}');
      await player.setAudioContext(
        AudioContext(
          android: const AudioContextAndroid(
            isSpeakerphoneOn: false,
            audioMode: AndroidAudioMode.normal,
            stayAwake: false,
            contentType: AndroidContentType.sonification,
            usageType: AndroidUsageType.alarm,
            audioFocus: AndroidAudioFocus.gain,
          ),
        ),
      );

      final sound = PyloAlarmSound.fromId(soundId);
      final useCustom = sound == PyloAlarmSound.custom &&
          customUri != null &&
          customUri.isNotEmpty;

      // Resolve a concrete playable source: the user's custom file, an
      // extracted built-in asset, or (last resort) the raw asset stream.
      Source source;
      if (useCustom) {
        final path = await resolveContentUri(customUri);
        if (path != null) {
          source = DeviceFileSource(path);
          debugPrint(
              'AlarmSoundService.playback device=$path (sound $soundId)');
        } else {
          debugPrint('AlarmSoundService customUri unresolved; falling back');
          final rawName = sound.rawName ?? PyloAlarmSound.classic.rawName!;
          final assetPath = 'raw/$rawName.wav';
          final assetFile = await _extractAssetToFile('assets/$assetPath');
          source = assetFile != null
              ? DeviceFileSource(assetFile)
              : AssetSource(assetPath);
          debugPrint('AlarmSoundService.playback asset=$assetPath '
              '(sound $soundId)');
        }
      } else {
        final rawName = sound.rawName ?? PyloAlarmSound.classic.rawName!;
        final assetPath = 'raw/$rawName.wav';
        final assetFile = await _extractAssetToFile('assets/$assetPath');
        source = assetFile != null
            ? DeviceFileSource(assetFile)
            : AssetSource(assetPath);
        debugPrint('AlarmSoundService.playback asset=$assetPath '
            '(sound $soundId)');
      }

      // Manual looping instead of ReleaseMode.loop: on several OEM ROMs (this
      // vivo included) MediaPlayer raises MEDIA_ERROR_UNKNOWN {what:-38} right
      // after ONE loop of a short track, killing the alarm sooner than the
      // user expects.  Re-trigger play() on completion for gapless-enough
      // looping.
      await player.setReleaseMode(ReleaseMode.stop);
      player.onPlayerComplete.listen((_) async {
        try {
          await player.play(source);
          debugPrint('AlarmSoundService playback loop restarted');
        } catch (e) {
          debugPrint('AlarmSoundService loop restart failed: $e');
        }
      });
      await player.play(source);
      return player;
    } catch (e) {
      debugPrint('AlarmSoundService.startAlarmPlayback failed: $e');
      return null;
    }
  }

  /// Plays the configured alarm sound for preview using the SAME engine as a
  /// real alarm ([startAlarmPlayback]), so the preview always sounds faithful.
  /// Auto-stops after [durationSeconds] seconds (default 6).
  static Future<void> playPreview({
    required String? soundId,
    required String? customUri,
    int durationSeconds = 6,
  }) async {
    if (kIsWeb) return;
    await stopPreview();
    try {
      final player =
          await startAlarmPlayback(soundId: soundId, customUri: customUri);
      if (player == null) return;
      _previewPlayer = player;

      // Auto-stop after duration to avoid infinite preview. Replace any prior
      // auto-stop so a short-preview-then-long-preview sequence cannot cut the
      // second one short.
      _previewAutoStop?.cancel();
      _previewAutoStop =
          Timer(Duration(seconds: durationSeconds), stopPreview);
    } catch (e) {
      debugPrint('AlarmSoundService.playPreview failed: $e');
      await stopPreview();
    }
  }

  /// Stops any playing preview and releases the audio player resources.
  static Future<void> stopPreview() async {
    _previewAutoStop?.cancel();
    _previewAutoStop = null;
    try {
      await _previewPlayer?.stop();
      await _previewPlayer?.dispose();
    } catch (_) {}
    _previewPlayer = null;
  }

  /// Copies a bundled Flutter asset into the app's `alarms/` directory and
  /// returns the on-disk path, reusing an already-extracted copy.  This lets
  /// built-in sounds use the same proven DeviceFileSource playback path as
  /// custom files (avoids an Android MediaPlayer/AssetSource loop bug).
  static Future<String?> _extractAssetToFile(String assetPath) async {
    if (kIsWeb) return null;
    try {
      final data = await rootBundle.load(assetPath);
      final dir = await getApplicationSupportDirectory();
      final alarmsDir =
          Directory('${dir.path}${Platform.pathSeparator}$alarmsSubpath');
      await alarmsDir.create(recursive: true);
      final dest =
          '${alarmsDir.path}${Platform.pathSeparator}${assetPath.split('/').last}';
      if (await File(dest).exists()) return dest;
      await File(dest).writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
      return dest;
    } catch (e) {
      debugPrint('AlarmSoundService._extractAssetToFile failed: $e');
      return null;
    }
  }
}
