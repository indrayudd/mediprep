import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:just_audio/just_audio.dart';
import 'package:provider/provider.dart';
import 'package:flutter/scheduler.dart';
import 'package:cupertino_native/cupertino_native.dart';
import 'package:liquid_glass_renderer/liquid_glass_renderer.dart';

import '../data/recording_meta.dart';
import '../theme/app_colors.dart';
import '../services/audio_recorder_service.dart';
import 'animated_waveform.dart';

// --- Data Models & Typedefs ---

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
typedef RecordingSavedCallback = Future<void> Function(
  RecordingSessionContext context,
  RecordingMeta recording,
);

class RecordingOverlayConfig {
  const RecordingOverlayConfig({
    required this.ensureContext,
    required this.onRecordingSaved,
    required this.title,
    required this.date,
    required this.visitId,
    this.onOpenVisit,
  });

  final EnsureRecordingContext ensureContext;
  final RecordingSavedCallback onRecordingSaved;
  final String title;
  final DateTime date;
  final String visitId;
  final Future<void> Function(NavigatorState navigator)? onOpenVisit;
}

// --- Controller ---

enum _OverlayMode { idle, recording, playing }

class RecordingOverlayController extends ChangeNotifier {
  RecordingOverlayController(
    this._navigatorKey,
    this._messengerKey,
  ) {
    _recorder.amplitude.addListener(_handleAmplitude);
    _positionSub = _player.positionStream.listen((position) {
      _playbackPosition = position;
      if (_mode == _OverlayMode.playing && _isPlaybackActive) {
        _emitChange();
      }
    });
    _playerStateSub = _player.playerStateStream.listen((state) {
      final playing = state.playing &&
          state.processingState != ProcessingState.completed;
      if (_isPlaybackActive != playing) {
        _isPlaybackActive = playing;
        _updatePanelVisibility();
      }
      if (state.processingState == ProcessingState.completed) {
        _playbackPosition = _playbackDuration;
        _playbackCompleted = true;
        _emitChange();
      }
    });
  }

  final GlobalKey<NavigatorState> _navigatorKey;
  final GlobalKey<ScaffoldMessengerState> _messengerKey;
  final AudioRecorderService _recorder = AudioRecorderService();
  final AudioPlayer _player = AudioPlayer();
  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<PlayerState>? _playerStateSub;

  String? _panelOwnerId;
  RecordingOverlayConfig? _panelConfig;
  RecordingOverlayConfig? _sessionConfig;
  String? _panelVisitId;
  String? _sessionVisitId;
  _OverlayMode _mode = _OverlayMode.idle;
  bool _panelVisible = false;
  bool _isBusy = false;
  bool _isRecording = false;
  double _amplitude = 0;
  Duration _elapsed = Duration.zero;
  Timer? _timer;

  RecordingSessionContext? _activeSession;
  RecordingMeta? _playbackRecording;
  Duration _playbackDuration = Duration.zero;
  Duration _playbackPosition = Duration.zero;
  bool _isPlaybackActive = false;
  bool _playbackCompleted = false;
  bool _notifyScheduled = false;

  bool get showPanel =>
      _panelOwnerId != null && _panelConfig != null && _panelVisible;
  bool get showBanner {
    final hasSession = _sessionVisitId != null;
    if (!hasSession) return false;
    final isRecordingState = _mode == _OverlayMode.recording;
    final isPlayingState = _mode == _OverlayMode.playing && _isPlaybackActive;
    if (!isRecordingState && !isPlayingState) {
      return false;
    }
    if (!_panelVisible) return true;
    return _panelVisitId != _sessionVisitId;
  }
  bool get isRecording => _mode == _OverlayMode.recording;
  bool get isPlaying => _mode == _OverlayMode.playing;
  bool get isPlaybackActive => _mode == _OverlayMode.playing && _isPlaybackActive;
  bool get isPlaybackCompleted =>
      _mode == _OverlayMode.playing && _playbackCompleted;
  bool get busy => _isBusy;
  double get amplitude => _amplitude;
  Duration get elapsed => _elapsed;
  RecordingOverlayConfig? get activeConfig =>
      showPanel ? _panelConfig : _sessionConfig;
  RecordingMeta? get playbackRecording => _playbackRecording;
  Duration get playbackDuration => _playbackDuration;
  Duration get playbackPosition => _playbackPosition;
  bool isPanelVisibleFor(String ownerId) =>
      _panelVisible && _panelOwnerId == ownerId;
  bool shouldShowOpenVisitButton(String visitId) {
    if (_sessionVisitId == null) return false;
    return _sessionVisitId != visitId;
  }
  bool isSessionVisit(String visitId) => _sessionVisitId == visitId;

  void _updatePanelVisibility({bool force = false}) {
    final visitId = _panelVisitId;
    bool nextVisible = false;
    if (visitId != null) {
      nextVisible = _shouldShowPanelForVisit(visitId);
    }
    if (force || nextVisible != _panelVisible) {
      _panelVisible = nextVisible;
      _emitChange();
    }
  }

  bool _shouldShowPanelForVisit(String visitId) {
    if (_mode == _OverlayMode.recording &&
        _sessionVisitId != null &&
        _sessionVisitId != visitId) {
      return false;
    }
    return true;
  }

  void _emitChange() {
    if (!hasListeners) return;
    final phase = SchedulerBinding.instance.schedulerPhase;
    if (phase == SchedulerPhase.idle ||
        phase == SchedulerPhase.postFrameCallbacks) {
      notifyListeners();
    } else if (!_notifyScheduled) {
      _notifyScheduled = true;
      SchedulerBinding.instance.addPostFrameCallback((_) {
        _notifyScheduled = false;
        if (hasListeners) {
          notifyListeners();
        }
      });
    }
  }

  void attachPanel(String ownerId, RecordingOverlayConfig config) {
    final unchanged =
        _panelOwnerId == ownerId && _panelConfig == config && _panelVisible;
    _panelOwnerId = ownerId;
    _panelConfig = config;
    _panelVisitId = config.visitId;
    _sessionConfig ??= config;
    _updatePanelVisibility(force: !unchanged);
  }

  void detachPanel(String ownerId) {
    if (_panelOwnerId != ownerId) return;
    _panelOwnerId = null;
    _panelConfig = null;
    _panelVisitId = null;
    _panelVisible = false;
    if (_mode == _OverlayMode.idle) {
      _sessionConfig = null;
    }
    _emitChange();
  }

  Future<void> handlePrimaryButton(RecordingOverlayConfig config) async {
    final isSessionVisit = _sessionVisitId == config.visitId;
    if (_mode == _OverlayMode.playing) {
      if (isSessionVisit) {
        await _togglePlayback();
      } else {
        await stopPlayback();
        await _startRecording(config);
      }
      return;
    }

    if (_mode == _OverlayMode.recording) {
      if (!isSessionVisit) {
        _showSnack('Finish the active recording before starting a new one.');
        return;
      }
      await _stopRecording();
      return;
    }

    await _startRecording(config);
  }

  Future<void> _togglePlayback() async {
    if (_playbackRecording == null) return;
    if (_isPlaybackActive) {
      await _player.pause();
    } else {
      if (_playbackCompleted) {
        await _player.seek(Duration.zero);
        _playbackPosition = Duration.zero;
        _playbackCompleted = false;
      }
      await _player.play();
    }
  }

  Future<void> startPlayback(
    RecordingOverlayConfig config,
    RecordingMeta recording,
  ) async {
    try {
      await _player.stop();
      await _player.setFilePath(recording.filePath);
      _playbackDuration =
          _player.duration ?? Duration(seconds: recording.durationSeconds);
      _playbackPosition = Duration.zero;
      _playbackRecording = recording;
      _sessionConfig = config;
      _sessionVisitId = config.visitId;
      _mode = _OverlayMode.playing;
      _playbackCompleted = false;
      _panelConfig ??= config;
      _updatePanelVisibility(force: true);
      await _player.play();
    } catch (error) {
      _showSnack('Unable to play recording: $error');
      _mode = _OverlayMode.idle;
      _sessionVisitId = null;
      _updatePanelVisibility(force: true);
    }
  }

  Future<void> stopPlayback() async {
    await _player.stop();
    _playbackRecording = null;
    _playbackPosition = Duration.zero;
    _playbackCompleted = false;
    _isPlaybackActive = false;
    if (_isRecording) {
      _mode = _OverlayMode.recording;
    } else {
      _mode = _OverlayMode.idle;
      _sessionVisitId = null;
    }
    _updatePanelVisibility(force: true);
  }

  Future<void> _startRecording(RecordingOverlayConfig config) async {
    if (_isBusy) return;
    _panelConfig ??= config;
    _isBusy = true;
    _emitChange();

    try {
      final session = await config.ensureContext();
      if (session == null) {
        _showSnack('Unable to start recording yet.');
        return;
      }
      _activeSession = session;
      _sessionVisitId = session.visitId;
      final started = await _recorder.start(
        folderId: session.folderId,
        visitId: session.visitId,
      );
      if (!started) {
        _showSnack('Microphone permission is required to record.');
        return;
      }
      _sessionConfig = config;
      _mode = _OverlayMode.recording;
      _isRecording = true;
      _elapsed = Duration.zero;
      _timer?.cancel();
      _timer = Timer.periodic(
        const Duration(seconds: 1),
        (timer) {
          _elapsed = Duration(seconds: timer.tick);
          _emitChange();
        },
      );
      _updatePanelVisibility(force: true);
    } catch (error) {
      _showSnack('Unable to start recording: $error');
    } finally {
      _isBusy = false;
      _updatePanelVisibility();
    }
  }

  Future<void> _stopRecording() async {
    if (_isBusy) return;
    _isBusy = true;
    _emitChange();

    try {
      final output = await _recorder.stop();
      _timer?.cancel();
      if (output == null || _sessionConfig == null || _activeSession == null) {
        _showSnack('Recording cancelled.');
        return;
      }
      final recordedAt = DateTime.now();
      final recording = RecordingMeta(
        id: '${recordedAt.microsecondsSinceEpoch}_${Random().nextInt(1 << 16)}',
        filePath: output.path,
        createdAt: recordedAt,
        durationSeconds: max(1, output.duration.inSeconds),
        displayName: DateFormat('MMM d · h:mm a').format(recordedAt),
      );
      await _sessionConfig!.onRecordingSaved(
        _activeSession!,
        recording,
      );
      _showSnack('Recording saved.');
    } catch (error) {
      _showSnack('Failed to save recording: $error');
    } finally {
      _mode = _OverlayMode.idle;
      _isRecording = false;
      _elapsed = Duration.zero;
      _activeSession = null;
      _sessionVisitId = null;
      _isBusy = false;
      _updatePanelVisibility(force: true);
    }
  }

  void _handleAmplitude() {
    _amplitude = _recorder.amplitude.value;
    if (_isRecording) {
      _emitChange();
    }
  }

  Future<void> openVisit() async {
    final navigator = _navigatorKey.currentState;
    final config = _sessionConfig ?? _panelConfig;
    if (navigator == null || config?.onOpenVisit == null) return;
    await config!.onOpenVisit!(navigator);
  }

  void _showSnack(String message) {
    _messengerKey.currentState?.showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  Future<void> stopCurrentSession() async {
    if (_mode == _OverlayMode.playing) {
      await stopPlayback();
    } else if (_mode == _OverlayMode.recording && _isRecording) {
      await _stopRecording();
    }
  }


  Future<void> seekPlayback(Duration delta) async {
    if (_mode != _OverlayMode.playing) return;
    final total = _playbackDuration.inMilliseconds;
    if (total <= 0) return;
    final target = _playbackPosition + delta;
    Duration clamped;
    if (target < Duration.zero) {
      clamped = Duration.zero;
    } else if (target > _playbackDuration) {
      clamped = _playbackDuration;
    } else {
      clamped = target;
    }
    await _player.seek(clamped);
    _playbackPosition = clamped;
    _emitChange();
  }

  Future<void> closePlaybackPanel() async {
    await stopPlayback();
  }

  @override
  Future<void> dispose() async {
    _timer?.cancel();
    _positionSub?.cancel();
    _playerStateSub?.cancel();
    await _recorder.dispose();
    await _player.dispose();
    super.dispose();
  }
}

// --- Host Widget ---

class RecordingOverlayHost extends StatelessWidget {
  const RecordingOverlayHost({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final controller = context.watch<RecordingOverlayController>();
    final showBanner = controller.showBanner;
    final bannerWidget = showBanner
        ? Padding(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Material(
              color: Colors.transparent,
              child: _RecordingBanner(controller: controller),
            ),
          )
        : const SizedBox.shrink();

    final backgroundColor = Theme.of(context).scaffoldBackgroundColor;
    return Container(
      color: backgroundColor,
      child: Column(
        mainAxisSize: MainAxisSize.max,
        children: [
          SafeArea(
            bottom: false,
            child: AnimatedSize(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              child: bannerWidget,
            ),
          ),
          Expanded(child: child),
        ],
      ),
    );
  }
}

// --- UI Components ---

class _RecordingBanner extends StatelessWidget {
  const _RecordingBanner({required this.controller});

  final RecordingOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final isRecording = controller.isRecording;
    return GestureDetector(
      onTap: () => controller.openVisit(),
      child: LiquidGlass.withOwnLayer(
        shape: const LiquidRoundedRectangle(borderRadius: 16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: (isRecording ? Colors.red : AppColors.primaryBlue).withValues(
              alpha: 0.15,
            ),
            border: Border.all(
              color:
                  (isRecording ? Colors.red : AppColors.primaryBlue).withValues(
                alpha: 0.35,
              ),
            ),
          ),
          child: Row(
            children: [
              Icon(
                isRecording ? Icons.mic : Icons.play_circle_fill,
                color: isRecording ? Colors.red : AppColors.primaryBlue,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  isRecording ? 'Recording in progress' : 'Playing recording',
                  style: const TextStyle(
                    color: Colors.black87,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              TextButton(
                onPressed: controller.isRecording || controller.isPlaying
                    ? controller.stopCurrentSession
                    : null,
                child: const Text('Stop'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class RecordingOverlayPanel extends StatelessWidget {
  const RecordingOverlayPanel({super.key, required this.controller});

  final RecordingOverlayController controller;

  @override
  Widget build(BuildContext context) {
    final config = controller.activeConfig;
    if (config == null) {
      return const SizedBox.shrink();
    }
    final theme = Theme.of(context);
    final bool isSessionVisit = controller.isSessionVisit(config.visitId);
    final bool showRecordingState =
        controller.isRecording && isSessionVisit;
    final bool showPlaybackState = controller.isPlaying && isSessionVisit;
    final bool isPlaybackActive =
        controller.isPlaybackActive && showPlaybackState;
    final bool isPlaybackCompleted =
        controller.isPlaybackCompleted && showPlaybackState;
    final bool showIdleState = !showRecordingState && !showPlaybackState;
    final showOpenButton =
        controller.shouldShowOpenVisitButton(config.visitId);

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 10),
      child: LiquidGlass.withOwnLayer(
        shape: const LiquidRoundedRectangle(borderRadius: 28),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withAlpha(51)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          config.title,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          DateFormat.yMMMMd().format(config.date),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (showOpenButton)
                    IconButton(
                      onPressed: controller.openVisit,
                      icon: const Icon(Icons.open_in_new),
                    ),
                  if (showPlaybackState)
                    IconButton(
                      onPressed: controller.closePlaybackPanel,
                      icon: const Icon(Icons.close),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              if (showRecordingState)
                Row(
                  children: [
                    Expanded(
                      child: AnimatedWaveform(amplitude: controller.amplitude),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      _format(controller.elapsed),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                )
              else if (showPlaybackState)
                Column(
                  children: [
                    const SizedBox(height: 4),
                    _PlaybackProgressBar(controller: controller),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(_format(controller.playbackPosition)),
                        Text(_format(controller.playbackDuration)),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.replay_5),
                          onPressed: () => controller.seekPlayback(
                            const Duration(seconds: -5),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.forward_5),
                          onPressed: () => controller.seekPlayback(
                            const Duration(seconds: 5),
                          ),
                        ),
                      ],
                    ),
                  ],
                )
              else if (showIdleState)
                Text(
                  'Tap to capture answers or summaries in your own voice.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                  textAlign: TextAlign.center,
                ),
              const SizedBox(height: 12),
              GestureDetector(
                onTap: () => controller.handlePrimaryButton(config),
                child: Container(
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color:
                        showPlaybackState ? AppColors.primaryBlue : Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withAlpha((255 * 0.08).round()),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: Center(
                    child: Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      child: _PrimaryGlyph(
                        showPlaybackState: showPlaybackState,
                        isPlaybackActive: isPlaybackActive,
                        isPlaybackCompleted: isPlaybackCompleted,
                        showRecordingState: showRecordingState,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
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
}

class _PrimaryGlyph extends StatelessWidget {
  const _PrimaryGlyph({
    required this.showPlaybackState,
    required this.isPlaybackActive,
    required this.isPlaybackCompleted,
    required this.showRecordingState,
  });

  final bool showPlaybackState;
  final bool isPlaybackActive;
  final bool isPlaybackCompleted;
  final bool showRecordingState;

  @override
  Widget build(BuildContext context) {
    if (showRecordingState) {
      return Container(
        width: 16,
        height: 16,
        decoration: BoxDecoration(
          color: Colors.red,
          borderRadius: BorderRadius.circular(3),
        ),
      );
    }

    if (!showPlaybackState) {
      return Container(
        width: 14,
        height: 14,
        decoration: const BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
        ),
      );
    }

    final icon = isPlaybackCompleted
        ? Icons.replay
        : (isPlaybackActive ? Icons.pause : Icons.play_arrow);

    return Icon(
      icon,
      size: 26,
      color: AppColors.primaryBlue,
    );
  }
}

class _PlaybackProgressBar extends StatelessWidget {
  const _PlaybackProgressBar({required this.controller});

  final RecordingOverlayController controller;

  @override
  Widget build(BuildContext context) {
    return CNSlider(
      value: controller.playbackPosition.inSeconds.toDouble(),
      min: 0,
      max: controller.playbackDuration.inSeconds.toDouble(),
      onChanged: (value) {
        controller.seekPlayback(Duration(seconds: value.toInt()));
      },
    );
  }
}


class RecordingListSection extends StatefulWidget {
  const RecordingListSection({
    super.key,
    required this.config,
    required this.recordings,
  });

  final RecordingOverlayConfig config;
  final List<RecordingMeta> recordings;

  @override
  State<RecordingListSection> createState() => _RecordingListSectionState();
}

class _RecordingListSectionState extends State<RecordingListSection>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 500),
    );
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.recordings.isEmpty) {
      return Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.lightBlue),
        ),
        child: Text(
          'No recordings yet. Capture summaries after each visit to revisit later.',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: widget.recordings.length,
      itemBuilder: (context, index) {
        final recording = widget.recordings[index];
        final animation = Tween<double>(begin: 0.0, end: 1.0).animate(
          CurvedAnimation(
            parent: _controller,
            curve: Interval(
              (1 / widget.recordings.length) * index,
              1.0,
              curve: Curves.easeOut,
            ),
          ),
        );
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.5),
              end: Offset.zero,
            ).animate(animation),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _RecordingTile(
                recording: recording,
                config: widget.config,
              ),
            ),
          ),
        );
      },
    );
  }
}

class _RecordingTile extends StatefulWidget {
  const _RecordingTile({required this.recording, required this.config});

  final RecordingMeta recording;
  final RecordingOverlayConfig config;

  @override
  State<_RecordingTile> createState() => _RecordingTileState();
}

class _RecordingTileState extends State<_RecordingTile> {
  bool _isPressed = false;
  bool _hasPlayed = false;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = Duration(seconds: widget.recording.durationSeconds);
    final durationText =
        '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(duration.inSeconds.remainder(60)).toString().padLeft(2, '0')}';
    final recordedOn = DateFormat.MMMd().format(widget.recording.createdAt);

    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: () async {
        final controller = context.read<RecordingOverlayController>();
        await controller.startPlayback(
          widget.config,
          widget.recording,
        );
        if (!mounted) return;
        setState(() {
          _hasPlayed = true;
        });
      },
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 1.0, end: _isPressed ? 0.95 : 1.0),
        duration: const Duration(milliseconds: 100),
        builder: (context, scale, child) {
          return Transform.scale(
            scale: scale,
            child: Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withAlpha((255 * 0.04).round()),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: AppColors.lightBlue,
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: const Icon(Icons.graphic_eq, color: AppColors.primaryBlue),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.recording.displayName ?? 'Recording',
                          style: theme.textTheme.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$recordedOn · $durationText',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    onPressed: () async {
                      final controller = context.read<RecordingOverlayController>();
                      await controller.startPlayback(
                        widget.config,
                        widget.recording,
                      );
                      if (!mounted) return;
                      setState(() {
                        _hasPlayed = true;
                      });
                    },
                    icon: Icon(
                      _hasPlayed ? Icons.replay_circle_filled : Icons.play_circle_fill,
                      size: 32,
                      color: AppColors.primaryBlue,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
