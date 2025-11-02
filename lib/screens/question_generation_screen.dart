import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/attachment.dart';
import '../data/question_note.dart';
import '../data/recording_meta.dart';
import '../data/visit_draft.dart';
import '../data/visit_info.dart';
import '../data/visit_record.dart';
import '../models/llm_model.dart';
import '../services/attachment_processor.dart';
import '../services/model_service.dart';
import '../services/visit_repository.dart';
import '../widgets/recording_dock.dart';
import 'visit_detail_screen.dart';

final _idRandom = Random();

class QuestionGenerationScreen extends StatefulWidget {
  const QuestionGenerationScreen({
    super.key,
    required this.model,
    required this.draft,
    this.onChangeModel,
  });

  final LlmModel model;
  final VisitDraft draft;
  final VoidCallback? onChangeModel;

  @override
  State<QuestionGenerationScreen> createState() =>
      _QuestionGenerationScreenState();
}

class _QuestionGenerationScreenState extends State<QuestionGenerationScreen> {
  final _modelService = const ModelService();
  final AttachmentProcessor _attachmentProcessor = const AttachmentProcessor();
  StreamSubscription<ModelResponse>? _subscription;
  InferenceChat? _activeChat;
  String _streamedText = '';
  bool _isGenerating = true;
  String? _error;
  bool _processingAttachments = false;
  AttachmentProcessingResult? _attachmentResult;
  String? _attachmentWarning;
  bool _isSaving = false;
  String? _saveError;
  String? _folderId;
  String? _visitId;
  DateTime? _visitCreatedAt;
  List<QuestionNote> _questionNotes = const [];
  List<RecordingMeta> _recordings = const [];

  @override
  void initState() {
    super.initState();
    _startGeneration();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    _activeChat?.session.close();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    await _subscription?.cancel();
    await _activeChat?.session.close();
    _activeChat = null;
    setState(() {
      _isGenerating = true;
      _error = null;
      _streamedText = '';
      _attachmentWarning = null;
      _processingAttachments = widget.draft.visitInfo.attachments.isNotEmpty;
      _saveError = null;
    });

    String attachmentSection = '';
    String? attachmentWarning;
    AttachmentProcessingResult? attachmentResult;

    if (widget.draft.visitInfo.attachments.isNotEmpty) {
      try {
        attachmentResult = await _attachmentProcessor.process(
          widget.draft.visitInfo.attachments,
        );
        attachmentSection = attachmentResult.buildPromptSection();
      } catch (e) {
        attachmentWarning = 'Failed to read attachments: $e';
      }
    }

    if (!mounted) return;
    setState(() {
      _attachmentResult = attachmentResult;
      _attachmentWarning = attachmentWarning;
      _processingAttachments = false;
    });

    try {
      final chat = await _modelService.createChat(widget.model);
      _activeChat = chat;

      final prompt = _buildPrompt(
        widget.draft.visitInfo,
        attachmentContext: attachmentSection,
      );
      await chat.addQuery(Message(text: prompt, isUser: true));
      final stream = chat.generateChatResponseAsync();
      _subscription = stream.listen(
        (response) {
          if (response is TextResponse) {
            setState(() {
              _streamedText += response.token;
            });
          }
        },
        onError: (error) {
          setState(() {
            _error = error.toString();
            _isGenerating = false;
          });
        },
        onDone: () {
          setState(() {
            _isGenerating = false;
          });
        },
      );
    } on PlatformException catch (e) {
      setState(() {
        _error = _mapPlatformError(e);
        _isGenerating = false;
      });
    } on StateError catch (e) {
      setState(() {
        _error = e.message;
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  String _buildPrompt(VisitInfo info, {String? attachmentContext}) {
    final formattedDate = DateFormat.yMMMMd().format(info.visitDate);
    final buffer = StringBuffer(
      'You are a helpful medical assistant preparing a patient for an upcoming appointment. Using the details provided, craft exactly five succinct questions the patient should ask the doctor. Each question should be actionable, specific, and reflect the patient\'s concerns.\n\n',
    );

    buffer
      ..writeln('VISIT DETAILS:')
      ..writeln('- Visit name: ${info.visitName}')
      ..writeln('- Visit date: $formattedDate')
      ..writeln('- Doctor: ${info.doctorName}')
      ..writeln('- Hospital/Clinic: ${info.hospitalName}')
      ..writeln('- Patient notes: ${info.description}\n');

    if (attachmentContext != null && attachmentContext.trim().isNotEmpty) {
      buffer
        ..writeln(attachmentContext.trim())
        ..writeln();
    }

    buffer
      ..writeln('Guidelines:')
      ..writeln(
        '- Return ONLY the questions as a numbered list from 1 to 5, using the format "1. Question" (digit, period, space).',
      )
      ..writeln('- Avoid introductions or closing remarks.')
      ..writeln(
        '- Write in the patient’s first-person voice addressing the doctor (e.g., "Doctor, could we...?" ).',
      )
      ..writeln(
        '- Focus on what the patient wants the doctor to explain, diagnose, or decide.',
      )
      ..writeln('- Do NOT ask the patient for more information or symptoms.');

    return buffer.toString();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = _parseQuestions(_streamedText);
    final visitInfo = widget.draft.visitInfo;

    return Scaffold(
      appBar: AppBar(title: const Text('Discussion guide')),
      body: RecordingDock(
        enabled: !_isGenerating,
        ensureContext: _ensureRecordingContext,
        onRecordingSaved: _handleRecordingStored,
        onError: (error) {
          if (!mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Recording failed: $error')));
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Questions to ask during "${visitInfo.visitName}"',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (_processingAttachments)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainerHigh,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Processing attachments for additional context…',
                          style: theme.textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              if (!_processingAttachments &&
                  _attachmentResult != null &&
                  _attachmentResult!.details.isNotEmpty)
                _AttachmentChipStrip(details: _attachmentResult!.details),
              if (!_processingAttachments && _attachmentWarning != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.orange.shade50,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(
                        Icons.report_problem_outlined,
                        color: Colors.orange,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          _attachmentWarning!,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.orange.shade900,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_error != null)
                Expanded(
                  child: Center(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                      textAlign: TextAlign.center,
                    ),
                  ),
                )
              else if (questions.isEmpty)
                Expanded(
                  child: Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (_isGenerating)
                          const CircularProgressIndicator()
                        else
                          const Icon(Icons.info_outline, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          _isGenerating
                              ? 'Generating questions…'
                              : 'Waiting for the model output…',
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                Expanded(
                  child: ListView.separated(
                    padding: EdgeInsets.zero,
                    itemCount: questions.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, index) {
                      final text = questions[index];
                      final isFinal =
                          !_isGenerating && index == questions.length - 1;
                      return AnimatedOpacity(
                        opacity: 1,
                        duration: const Duration(milliseconds: 200),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${index + 1}. ',
                                style: theme.textTheme.titleMedium,
                              ),
                              Expanded(
                                child: Text(
                                  text,
                                  style: theme.textTheme.bodyLarge,
                                ),
                              ),
                              if (_isGenerating &&
                                  index == questions.length - 1)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: SizedBox(
                                    width: 16,
                                    height: 16,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  ),
                                ),
                              if (!_isGenerating && isFinal)
                                const Padding(
                                  padding: EdgeInsets.only(left: 8),
                                  child: Icon(
                                    Icons.check_circle,
                                    color: Colors.green,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _isGenerating || _isSaving
                      ? null
                      : () => _saveVisitAndNavigate(questions),
                  icon: _isSaving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_circle_outline),
                  label: Text(_isSaving ? 'Saving…' : 'Save to folder'),
                ),
              ),
              if (_saveError != null) ...[
                const SizedBox(height: 8),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.errorContainer,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _saveError!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onErrorContainer,
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  ElevatedButton.icon(
                    onPressed: _isGenerating ? null : _startGeneration,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Regenerate'),
                  ),
                  const SizedBox(width: 12),
                  Text(
                    _isGenerating
                        ? 'Streaming response…'
                        : 'Generation complete',
                    style: theme.textTheme.bodySmall,
                  ),
                ],
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    );
  }

  Future<RecordingSessionContext?> _ensureRecordingContext() async {
    final questions = _parseQuestions(_streamedText);
    final visit = await _persistVisit(
      questions: questions,
      setSavingState: false,
    );
    if (!mounted || visit == null || _folderId == null) {
      return null;
    }
    return RecordingSessionContext(
      folderId: _folderId!,
      visitId: visit.id,
      visitTitle: widget.draft.visitInfo.visitName,
      visitDate: widget.draft.visitInfo.visitDate,
    );
  }

  Future<void> _handleRecordingStored(
    RecordingSessionContext ctx,
    RecordingMeta recording,
  ) async {
    final repository = context.read<VisitRepository>();
    await repository.addRecording(
      folderId: ctx.folderId,
      visitId: ctx.visitId,
      recording: recording,
    );
    final refreshed = repository.getVisitById(ctx.folderId, ctx.visitId);
    if (!mounted) return;
    setState(() {
      _recordings = refreshed?.recordings ?? [..._recordings, recording];
    });
  }

  Future<VisitRecord?> _persistVisit({
    required List<String> questions,
    required bool setSavingState,
  }) async {
    final visitInfo = widget.draft.visitInfo;
    final repository = context.read<VisitRepository>();

    if (setSavingState) {
      setState(() {
        _isSaving = true;
        _saveError = null;
      });
    }

    try {
      _folderId = await _ensureFolderId(repository);
      final now = DateTime.now();
      final visitId = _visitId ?? _generateId();
      final notes = _hydrateQuestionNotes(questions, now);

      final visit = VisitRecord(
        id: visitId,
        title: visitInfo.visitName,
        visitDate: visitInfo.visitDate,
        description: visitInfo.description,
        questions: notes,
        attachments: visitInfo.attachments,
        recordings: _recordings,
        createdAt: _visitCreatedAt ?? now,
        updatedAt: now,
      );

      await repository.addVisit(folderId: _folderId!, visit: visit);
      _visitId = visitId;
      _visitCreatedAt ??= visit.createdAt;
      return visit;
    } catch (error) {
      if (setSavingState) {
        setState(() {
          _saveError = error.toString();
        });
      } else if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Failed to save visit: $error')));
      }
      return null;
    } finally {
      if (setSavingState && mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Future<String> _ensureFolderId(VisitRepository repository) async {
    if (_folderId != null) {
      return _folderId!;
    }
    if (widget.draft.existingFolderId != null) {
      _folderId = widget.draft.existingFolderId;
      return _folderId!;
    }
    final folder = await repository.createFolder(
      id: _generateId(),
      patientName: widget.draft.patientName!,
      conditionName: widget.draft.conditionName!,
      doctorName: widget.draft.visitInfo.doctorName,
      hospitalName: widget.draft.visitInfo.hospitalName,
    );
    _folderId = folder.id;
    return folder.id;
  }

  List<QuestionNote> _hydrateQuestionNotes(
    List<String> questions,
    DateTime timestamp,
  ) {
    if (questions.isEmpty) {
      _questionNotes = const [];
      return _questionNotes;
    }
    final notes = <QuestionNote>[];
    for (final text in questions) {
      final trimmed = text.trim();
      if (trimmed.isEmpty) continue;
      final existing = _questionNotes.firstWhere(
        (note) => note.text == trimmed,
        orElse: () => QuestionNote(
          id: _generateId(),
          text: trimmed,
          createdAt: timestamp,
        ),
      );
      notes.add(existing);
    }
    _questionNotes = notes;
    return notes;
  }

  Future<void> _saveVisitAndNavigate(List<String> questions) async {
    final visit = await _persistVisit(
      questions: questions,
      setSavingState: true,
    );
    if (!mounted || visit == null || _folderId == null) {
      return;
    }

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => VisitDetailScreen(
          folderId: _folderId!,
          visitId: visit.id,
          model: widget.model,
          onChangeModel: widget.onChangeModel ?? () {},
        ),
      ),
      (route) => route.isFirst,
    );
  }

  List<String> _parseQuestions(String rawText) {
    final lines = rawText
        .split(RegExp(r'\n|\r'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final result = <String>[];
    for (final line in lines) {
      if (line.contains('[tool_response]')) {
        continue;
      }
      final match = RegExp(r'^(?:\d+\s*[-\.\)]\s*)(.*)$').firstMatch(line);
      if (match != null) {
        final question = match.group(1)?.trim();
        if (question != null && question.isNotEmpty) {
          result.add(question);
        }
      } else if (result.isNotEmpty) {
        final last = result.removeLast();
        final merged = '$last ${line.replaceFirst(RegExp(r'^[-•]'), '').trim()}'
            .trim();
        result.add(merged);
      }
    }

    if (result.isEmpty && lines.isNotEmpty) {
      for (final line in lines) {
        final cleaned = line.replaceFirst(RegExp(r'^[-•]'), '').trim();
        if (cleaned.isNotEmpty) {
          result.add(cleaned);
        }
      }
    }

    if (result.length > 5) {
      return result.take(5).toList();
    }
    return result;
  }

  String _mapPlatformError(PlatformException exception) {
    final message = exception.message ?? exception.toString();
    if (message.contains('Cannot allocate memory')) {
      return 'The selected model could not be loaded because the device ran out of memory. '
          'Please close other apps, free up storage space, and try again.';
    }
    return 'Failed to start the model (${exception.code}): $message';
  }

  String _generateId() {
    final randomPart = _idRandom.nextInt(1 << 32);
    return '${DateTime.now().microsecondsSinceEpoch}_$randomPart';
  }
}

class _AttachmentChipStrip extends StatelessWidget {
  const _AttachmentChipStrip({required this.details});

  final List<AttachmentContextDetail> details;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.attachment,
                size: 18,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(width: 6),
              Text('Attachments processed', style: theme.textTheme.titleSmall),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: details
                .map((detail) => _buildChip(context, detail))
                .toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildChip(BuildContext context, AttachmentContextDetail detail) {
    final attachment = detail.attachment;
    final icon = switch (attachment.type) {
      AttachmentType.pdf => Icons.picture_as_pdf,
      AttachmentType.image => Icons.image_outlined,
      AttachmentType.other => Icons.insert_drive_file,
    };

    final badges = <String>[];
    if (detail.extractedText != null && detail.extractedText!.isNotEmpty) {
      badges.add('text');
    }
    if (detail.labels.isNotEmpty) {
      badges.add('vision');
    }
    final status = badges.isEmpty ? null : badges.join(' · ');
    final label = status == null
        ? attachment.name
        : '${attachment.name} · $status';
    final tooltip = _tooltip(detail);

    return InputChip(
      avatar: Icon(icon, size: 18),
      label: Text(label, overflow: TextOverflow.ellipsis),
      tooltip: tooltip.isEmpty ? null : tooltip,
      onPressed: null,
      showCheckmark: false,
    );
  }

  String _tooltip(AttachmentContextDetail detail) {
    final items = <String>[];
    if (detail.extractedText != null && detail.extractedText!.isNotEmpty) {
      items.add(_trim(detail.extractedText!, 140));
    }
    if (detail.labels.isNotEmpty) {
      items.add('Labels: ${detail.labels.take(4).join(', ')}');
    }
    return items.join('\n');
  }

  String _trim(String value, int maxChars) {
    final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (cleaned.length <= maxChars) {
      return cleaned;
    }
    return '${cleaned.substring(0, maxChars)}…';
  }
}
