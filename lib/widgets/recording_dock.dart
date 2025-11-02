import 'dart:async';
import 'dart:math';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';

import '../data/recording_meta.dart';
import '../services/audio_recorder_service.dart';

class RecordingSessionContext {
  RecordingSessionContext({
    required this.folderId,
    required this.visitId,
    required this.visitTitle,
    required this.visitDate,
  });

  final String folderId;
  final String visitId;
  final String visitTitle;
  final DateTime visitDate;
}

typedef EnsureRecordingContext = Future<RecordingSessionContext?> Function();
typedef RecordingSavedCallback =
    Future<void> Function(
      RecordingSessionContext context,
      RecordingMeta recording,
    );

class RecordingDock extends StatefulWidget {
  const RecordingDock({
    super.key,
    required this.child,
    required this.enabled,
    required this.ensureContext,
    required this.onRecordingSaved,
    this.onError,
    this.initialRecordings = const <RecordingMeta>[],
  });

  final Widget child;
  final bool enabled;
  final EnsureRecordingContext ensureContext;
  final RecordingSavedCallback onRecordingSaved;
  final void Function(Object error)? onError;
  final List<RecordingMeta> initialRecordings;

  @override
  State<RecordingDock> createState() => _RecordingDockState();
}

enum _DockMode { idle, recording, playback }

class _RecordingDockState extends State<RecordingDock> {
  final AudioRecorderService _recorder = AudioRecorderService();
  final ValueNotifier<Duration> _elapsed = ValueNotifier(Duration.zero);
  final ValueNotifier<double> _amplitude = ValueNotifier(0);
  final _player = AudioPlayer();

  RecordingSessionContext? _context;
  _DockMode _mode = _DockMode.idle;
  RecordingMeta? _activeRecording;
  Timer? _timer;
  bool _isBusy = false;

  @override
  void initState() {
    super.initState();
    _amplitude.value = 0;
    _recorder.amplitude.addListener(_handleAmplitudeChange);
  }

  @override
  void dispose() {
    _timer?.cancel();
    _elapsed.dispose();
    _recorder.amplitude.removeListener(_handleAmplitudeChange);
    unawaited(_recorder.dispose());
    unawaited(_player.dispose());
    super.dispose();
  }

  void _handleAmplitudeChange() {
    _amplitude.value = _recorder.amplitude.value;
  }

  double get _bottomInset {
    switch (_mode) {
      case _DockMode.idle:
        return 100;
      case _DockMode.recording:
      case _DockMode.playback:
        return 280;
    }
  }

  @override
  Widget build(BuildContext context) {
    final overlay = _buildOverlay(context);
    return Stack(
      children: [
        AnimatedPadding(
          duration: const Duration(milliseconds: 240),
          curve: Curves.easeOut,
          padding: EdgeInsets.only(bottom: _bottomInset),
          child: widget.child,
        ),
        Positioned(left: 0, right: 0, bottom: 0, child: overlay),
      ],
    );
  }

  Widget _buildOverlay(BuildContext context) {
    switch (_mode) {
      case _DockMode.idle:
        return _IdleRecordButton(
          enabled: widget.enabled && !_isBusy,
          onTap: _startRecording,
        );
      case _DockMode.recording:
        return _RecordingPanel(
          context: _context!,
          elapsed: _elapsed,
          amplitude: _amplitude,
          onStop: _stopRecording,
        );
      case _DockMode.playback:
        return _PlaybackPanel(
          context: _context!,
          recording: _activeRecording!,
          player: _player,
          onDismiss: _closePlayback,
          onReRecord: _restartRecording,
        );
    }
  }

  Future<void> _startRecording() async {
    if (_isBusy) return;
    setState(() {
      _isBusy = true;
    });
    try {
      final ctx = await widget.ensureContext();
      if (!mounted) return;
      if (ctx == null) {
        return;
      }
      _context = ctx;
      await _player.stop();
      if (!mounted) return;
      final started = await _recorder.start(
        folderId: ctx.folderId,
        visitId: ctx.visitId,
      );
      if (!mounted) return;
      if (!started) {
        if (widget.onError != null) {
          widget.onError!(Exception('Microphone permission denied'));
        } else {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'MediPrep needs access to the microphone to record your visits.',
              ),
            ),
          );
        }
        return;
      }
      _elapsed.value = Duration.zero;
      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) => _elapsed.value = Duration(seconds: timer.tick),
      );
      setState(() {
        _mode = _DockMode.recording;
      });
    } catch (error) {
      if (widget.onError != null) {
        widget.onError!(error);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Unable to start recording: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isBusy = false;
        });
      }
    }
  }

  Future<void> _stopRecording() async {
    final result = await _recorder.stop();
    _timer?.cancel();
    _elapsed.value = Duration.zero;

    if (!mounted) {
      return;
    }
    if (result == null || _context == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Recording cancelled.')));
      setState(() => _mode = _DockMode.idle);
      return;
    }

    final recordedAt = DateTime.now();
    final recording = RecordingMeta(
      id: '${recordedAt.microsecondsSinceEpoch}_${Random().nextInt(1 << 16)}',
      filePath: result.path,
      createdAt: recordedAt,
      durationSeconds: max(1, result.duration.inSeconds),
      displayName:
          'Recording (${DateFormat.yMMMd().format(_context!.visitDate)})',
    );

    try {
      await widget.onRecordingSaved(_context!, recording);
      await _player.setFilePath(recording.filePath);
      if (!mounted) return;
      setState(() {
        _activeRecording = recording;
        _mode = _DockMode.playback;
      });
    } catch (error) {
      if (widget.onError != null) {
        widget.onError!(error);
      } else if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to save recording: $error')),
        );
      }
      if (mounted) {
        setState(() {
          _mode = _DockMode.idle;
        });
      }
    }
  }

  Future<void> _closePlayback() async {
    await _player.stop();
    if (mounted) {
      setState(() {
        _mode = _DockMode.idle;
      });
    }
  }

  Future<void> _restartRecording() async {
    await _player.stop();
    await _startRecording();
  }
}

class _IdleRecordButton extends StatelessWidget {
  const _IdleRecordButton({required this.enabled, required this.onTap});

  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      minimum: const EdgeInsets.only(bottom: 24),
      child: Center(
        child: GestureDetector(
          onTap: enabled ? onTap : null,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
            decoration: BoxDecoration(
              color: theme.colorScheme.surface,
              borderRadius: BorderRadius.circular(48),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: Container(
              width: 72,
              height: 72,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: Center(
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: enabled
                        ? theme.colorScheme.error
                        : theme.colorScheme.onSurface.withValues(alpha: 0.3),
                    boxShadow: enabled
                        ? [
                            BoxShadow(
                              color: theme.colorScheme.error.withValues(
                                alpha: 0.35,
                              ),
                              blurRadius: 22,
                              offset: const Offset(0, 12),
                            ),
                          ]
                        : const [],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _RecordingPanel extends StatelessWidget {
  const _RecordingPanel({
    required this.context,
    required this.elapsed,
    required this.amplitude,
    required this.onStop,
  });

  final RecordingSessionContext context;
  final ValueListenable<Duration> elapsed;
  final ValueListenable<double> amplitude;
  final VoidCallback onStop;

  @override
  Widget build(BuildContext contextWidget) {
    final theme = Theme.of(contextWidget);
    return SafeArea(
      top: false,
      child: Container(
        height: 260,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${context.visitTitle} (${DateFormat.yMMMd().format(context.visitDate)})',
              style: theme.textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            ValueListenableBuilder<Duration>(
              valueListenable: elapsed,
              builder: (_, value, __) => Text(
                _format(value),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: Center(
                child: ValueListenableBuilder<double>(
                  valueListenable: amplitude,
                  builder: (_, value, __) => _Waveform(intensity: value),
                ),
              ),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: onStop,
              child: Container(
                width: 76,
                height: 76,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Center(
                  child: Container(
                    width: 46,
                    height: 46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.error,
                    ),
                    child: const Icon(Icons.stop, color: Colors.white),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _format(Duration duration) {
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }
}

class _Waveform extends StatelessWidget {
  const _Waveform({required this.intensity});

  final double intensity;

  @override
  Widget build(BuildContext context) {
    final bars = List.generate(28, (index) {
      final value =
          sin((intensity * 8) + index / 1.4) * 0.5 + 0.5; // normalize 0..1
      return 12 + (60 * value);
    });
    return SizedBox(
      height: 72,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: bars
            .map(
              (height) => Container(
                width: 6,
                height: height,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(3),
                  gradient: LinearGradient(
                    begin: Alignment.bottomCenter,
                    end: Alignment.topCenter,
                    colors: [Colors.red.shade400, Colors.red.shade200],
                  ),
                ),
              ),
            )
            .toList(),
      ),
    );
  }
}

class _PlaybackPanel extends StatefulWidget {
  const _PlaybackPanel({
    required this.context,
    required this.recording,
    required this.player,
    required this.onDismiss,
    required this.onReRecord,
  });

  final RecordingSessionContext context;
  final RecordingMeta recording;
  final AudioPlayer player;
  final VoidCallback onDismiss;
  final VoidCallback onReRecord;

  @override
  State<_PlaybackPanel> createState() => _PlaybackPanelState();
}

class _PlaybackPanelState extends State<_PlaybackPanel> {
  late StreamSubscription<Duration> _positionSub;
  StreamSubscription<PlayerState>? _stateSub;
  Duration _duration = Duration.zero;
  Duration _position = Duration.zero;
  bool _playing = false;

  @override
  void initState() {
    super.initState();
    _duration = Duration(seconds: widget.recording.durationSeconds);
    _positionSub = widget.player.positionStream.listen((event) {
      setState(() {
        _position = event;
      });
    });
    _stateSub = widget.player.playerStateStream.listen((state) {
      setState(() {
        _playing = state.playing;
        _duration = widget.player.duration ?? _duration;
      });
    });
  }

  @override
  void dispose() {
    _positionSub.cancel();
    _stateSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final clampedPosition = _position > _duration ? _duration : _position;
    final sliderMax = max(_duration.inMilliseconds.toDouble(), 1.0);

    return SafeArea(
      top: false,
      child: Container(
        height: 290,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.08),
              blurRadius: 22,
              offset: const Offset(0, -6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 46,
              height: 4,
              decoration: BoxDecoration(
                color: theme.colorScheme.outlineVariant,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox(width: 24),
                Expanded(
                  child: Text(
                    widget.recording.displayName ?? 'Visit recording',
                    style: theme.textTheme.titleMedium,
                    textAlign: TextAlign.center,
                  ),
                ),
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Slider(
              value: clampedPosition.inMilliseconds.toDouble().clamp(
                0,
                sliderMax,
              ),
              max: sliderMax,
              onChanged: (value) {
                widget.player.seek(Duration(milliseconds: value.round()));
              },
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  _format(clampedPosition),
                  style: theme.textTheme.bodySmall,
                ),
                Text(_format(_duration), style: theme.textTheme.bodySmall),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                IconButton(
                  onPressed: () => _seek(const Duration(seconds: -15)),
                  icon: const Icon(Icons.replay_10),
                ),
                const SizedBox(width: 12),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    shape: const CircleBorder(),
                    padding: const EdgeInsets.all(18),
                  ),
                  onPressed: _togglePlayback,
                  child: Icon(_playing ? Icons.pause : Icons.play_arrow),
                ),
                const SizedBox(width: 12),
                IconButton(
                  onPressed: () => _seek(const Duration(seconds: 15)),
                  icon: const Icon(Icons.forward_10),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: null,
                    child: const Text('Read AI Summary'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton(
                    onPressed: null,
                    child: const Text('View Transcript'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 18),
            GestureDetector(
              onTap: widget.onReRecord,
              child: Container(
                width: 70,
                height: 70,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Colors.white,
                ),
                child: Center(
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _format(Duration duration) {
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    final hours = duration.inHours;
    if (hours > 0) {
      return '${hours.toString().padLeft(2, '0')}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
  }

  Future<void> _togglePlayback() async {
    if (_playing) {
      await widget.player.pause();
    } else {
      await widget.player.play();
    }
  }

  Future<void> _seek(Duration delta) async {
    final target = _position + delta;
    final clamped = target < Duration.zero ? Duration.zero : target;
    await widget.player.seek(clamped);
  }
}
