import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

class AudioRecorderService {
  AudioRecorderService({AudioRecorder? recorder})
    : _recorder = recorder ?? AudioRecorder();

  final AudioRecorder _recorder;
  Timer? _amplitudeTimer;
  DateTime? _startedAt;
  final ValueNotifier<double> amplitude = ValueNotifier<double>(0);

  Future<bool> start({
    required String folderId,
    required String visitId,
  }) async {
    if (!await _recorder.hasPermission()) {
      return false;
    }

    final directory = await _resolveVisitDirectory(folderId, visitId);
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }
    final fileName = 'recording_${DateTime.now().millisecondsSinceEpoch}.m4a';
    final path = p.join(directory.path, fileName);

    await _recorder.start(
      RecordConfig(
        encoder: AudioEncoder.aacLc,
        bitRate: 128000,
        sampleRate: 44100,
      ),
      path: path,
    );
    _startedAt = DateTime.now();
    _startAmplitudeTimer();
    return true;
  }

  Future<RecordingOutput?> stop() async {
    if (!await _recorder.isRecording()) {
      return null;
    }
    final path = await _recorder.stop();
    _amplitudeTimer?.cancel();
    amplitude.value = 0;

    if (path == null) {
      return null;
    }
    final started = _startedAt ?? DateTime.now();
    final duration = DateTime.now().difference(started);
    return RecordingOutput(path: path, duration: duration);
  }

  Future<void> dispose() async {
    _amplitudeTimer?.cancel();
    amplitude.dispose();
    await _recorder.dispose();
  }

  void _startAmplitudeTimer() {
    _amplitudeTimer?.cancel();
    _amplitudeTimer = Timer.periodic(const Duration(milliseconds: 160), (
      _,
    ) async {
      try {
        final amp = await _recorder.getAmplitude();
        final normalized = (amp.current + 45).clamp(0, 60) / 60;
        amplitude.value = normalized.toDouble();
      } catch (_) {
        amplitude.value = 0;
      }
    });
  }

  Future<Directory> _resolveVisitDirectory(
    String folderId,
    String visitId,
  ) async {
    final root = await getApplicationDocumentsDirectory();
    return Directory(p.join(root.path, 'recordings', folderId, visitId));
  }
}

class RecordingOutput {
  RecordingOutput({required this.path, required this.duration});

  final String path;
  final Duration duration;
}
