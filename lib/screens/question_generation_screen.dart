import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/attachment.dart';
import '../data/question_note.dart';
import '../data/visit_draft.dart';
import '../data/visit_info.dart';
import '../data/visit_record.dart';
import '../models/llm_model.dart';
import '../services/attachment_processor.dart';
import '../services/model_service.dart';
import '../services/visit_repository.dart';
import '../theme/app_colors.dart';
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
  final List<String> _manualQuestions = [];
  final Set<String> _dismissedGeneratedQuestions = <String>{};

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
      _dismissedGeneratedQuestions.clear();
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
      'You are a helpful medical assistant preparing a patient for an upcoming appointment. Using the details provided, craft as many succinct questions as needed (no more than 15) that the patient should ask the doctor. Each question should be actionable, specific, and reflect the patient\'s concerns.\n\n',
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
        '- Return ONLY the questions as a numbered list (1., 2., …) and do not exceed fifteen total items.',
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

  List<_QuestionEntry> _buildQuestionEntries() {
    final generated = _parseQuestions(_streamedText)
        .map((text) => _QuestionEntry(text: text.trim()))
        .where(
          (entry) =>
              entry.text.isNotEmpty &&
              !_dismissedGeneratedQuestions.contains(entry.text),
        );
    final manual = _manualQuestions
        .map((text) => _QuestionEntry(text: text.trim(), isCustom: true))
        .where((entry) => entry.text.isNotEmpty);
    return [...generated, ...manual];
  }

  Future<void> _showAddQuestionSheet() async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 24,
            top: 24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Add your own question',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 3,
                decoration: const InputDecoration(
                  hintText: 'What else would you like to ask the doctor?',
                ),
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final value = controller.text.trim();
                    if (value.isEmpty) return;
                    Navigator.of(context).pop(value);
                  },
                  child: const Text('Add question'),
                ),
              ),
            ],
          ),
        );
      },
    );
    if (result != null && result.trim().isNotEmpty) {
      setState(() {
        _manualQuestions.add(result.trim());
      });
    }
  }

  void _removeQuestionEntry(_QuestionEntry entry) {
    setState(() {
      if (entry.isCustom) {
        _manualQuestions.remove(entry.text);
      } else {
        _dismissedGeneratedQuestions.add(entry.text);
      }
    });
  }


  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visitInfo = widget.draft.visitInfo;
    final questionEntries = _buildQuestionEntries();
    final lastGeneratedIndex = questionEntries.lastIndexWhere(
      (entry) => !entry.isCustom,
    );

    Widget questionContent;
    if (_error != null) {
      questionContent = _StatusCard(
        icon: Icons.error_outline,
        message: _error!,
        accentColor: theme.colorScheme.error,
      );
    } else if (questionEntries.isEmpty) {
      questionContent = _StatusCard(
        icon: _isGenerating ? Icons.sync : Icons.info_outline,
        message: _isGenerating
            ? 'Generating your tailored discussion guide…'
            : 'Waiting for the model output…',
      );
    } else {
      questionContent = Column(
        children: questionEntries.asMap().entries.map((entry) {
          final index = entry.key;
          final question = entry.value;
          final showSpinner =
              _isGenerating && index == lastGeneratedIndex && !question.isCustom;
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _QuestionCard(
              index: index + 1,
              entry: question,
              showSpinner: showSpinner,
              onRemove: () => _removeQuestionEntry(question),
            ),
          );
        }).toList(),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discussion guide'),
        actions: [
          IconButton(
            tooltip: 'Change AI model',
            onPressed: widget.onChangeModel,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _VisitHeroCard(
                      info: visitInfo,
                      isGenerating: _isGenerating,
                      processingAttachments: _processingAttachments,
                    ),
                    const SizedBox(height: 16),
                    if (_processingAttachments)
                      _AttachmentStatusCard(
                        message: 'Processing attachments for extra context…',
                        icon: Icons.sync,
                      ),
                    if (!_processingAttachments &&
                        _attachmentResult != null &&
                        _attachmentResult!.details.isNotEmpty) ...[
                      _AttachmentChipStrip(details: _attachmentResult!.details),
                      const SizedBox(height: 8),
                    ],
                    if (!_processingAttachments && _attachmentWarning != null)
                      _AttachmentStatusCard(
                        message: _attachmentWarning!,
                        icon: Icons.warning_amber_rounded,
                        accentColor: Colors.orange,
                      ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Generated questions',
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        TextButton.icon(
                          onPressed: _isSaving ? null : _showAddQuestionSheet,
                          icon: const Icon(Icons.add),
                          label: const Text('Add more'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    questionContent,
                    const SizedBox(height: 24),
                  ],
                ),
              ),
            ),
            _BottomActionBar(
              isSaving: _isSaving,
              onSave: _isGenerating ? null : _saveVisitAndNavigate,
              onRegenerate: _isGenerating ? null : _startGeneration,
              saveError: _saveError,
              isGenerating: _isGenerating,
            ),
          ],
        ),
      ),
    );
  }

  Future<VisitRecord?> _persistVisit({
    required List<_QuestionEntry> entries,
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
      final existingVisit = _folderId == null
          ? null
          : repository.getVisitById(_folderId!, visitId);
      final notes = _hydrateQuestionNotes(entries, now);

      final visit = VisitRecord(
        id: visitId,
        title: visitInfo.visitName,
        visitDate: visitInfo.visitDate,
        description: visitInfo.description,
        questions: notes,
        attachments: visitInfo.attachments,
        recordings: existingVisit?.recordings ?? const [],
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
    List<_QuestionEntry> entries,
    DateTime timestamp,
  ) {
    if (entries.isEmpty) {
      _questionNotes = const [];
      return _questionNotes;
    }
    final notes = <QuestionNote>[];
    for (final entry in entries) {
      final trimmed = entry.text.trim();
      if (trimmed.isEmpty) continue;
      final existingIndex = _questionNotes.indexWhere(
        (note) => note.text == trimmed,
      );
      if (existingIndex != -1) {
        final existing = _questionNotes[existingIndex];
        notes.add(
          existing.isCustom == entry.isCustom
              ? existing
              : existing.copyWith(isCustom: entry.isCustom),
        );
      } else {
        notes.add(
          QuestionNote(
            id: _generateId(),
            text: trimmed,
            createdAt: timestamp,
            isCustom: entry.isCustom,
          ),
        );
      }
    }
    _questionNotes = notes;
    return notes;
  }

  Future<void> _saveVisitAndNavigate() async {
    final visit = await _persistVisit(
      entries: _buildQuestionEntries(),
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
    final normalized = rawText
        .replaceAll('\\n', '\n')
        .replaceAll('\\r', '\n')
        .replaceAll('\r', '\n');

    final numberedRegex = RegExp(
      r'(?:^|\n)\s*\d{1,2}[\.\)\-\s:]*([^\n].*?)(?=(?:\n\s*\d{1,2}[\.\)\-\s:])|\n*$)',
      multiLine: true,
      dotAll: true,
    );

    final matches = numberedRegex.allMatches(normalized);
    final results = <String>[];

    void addClean(String text) {
      var cleaned = text
          .replaceAll('[tool_response]', '')
          .replaceAll('\n', ' ')
          .replaceAll('’', '\'')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trimLeft();
      cleaned = _stripQuestionPrefix(cleaned).trim();
      if (cleaned.isEmpty || cleaned == 's') return;
      results.add(cleaned);
    }

    if (matches.isNotEmpty) {
      for (final match in matches) {
        final text = match.group(1);
        if (text != null) {
          addClean(text);
        }
      }
    } else {
      final lines = normalized
          .split(RegExp(r'\n+'))
          .map((line) => line.trim())
          .where((line) => line.isNotEmpty)
          .toList();
      for (final line in lines) {
        addClean(line);
      }
    }

    if (results.length > 15) {
      return results.take(15).toList();
    }
    return results;
  }

  String _stripQuestionPrefix(String text) {
    var cleaned = text.trimLeft();
    final markerPattern = RegExp(
      r"^\d{1,2}(?:st|nd|rd|th|s|'s)?[\.\)\-:]*\s*",
      caseSensitive: false,
    );
    cleaned = cleaned.replaceFirst(markerPattern, '');
    cleaned = cleaned.replaceFirst(RegExp(r'^[\-\u2022•]+\s*'), '');
    return cleaned.trimLeft();
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

class _QuestionEntry {
  const _QuestionEntry({required this.text, this.isCustom = false});

  final String text;
  final bool isCustom;
}

class _VisitHeroCard extends StatelessWidget {
  const _VisitHeroCard({
    required this.info,
    required this.isGenerating,
    required this.processingAttachments,
  });

  final VisitInfo info;
  final bool isGenerating;
  final bool processingAttachments;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat.yMMMMd().format(info.visitDate);
    final statusText =
        processingAttachments ? 'Enhancing with attachments…' : 'AI is preparing';
    final statusColor =
        processingAttachments ? Colors.orange.shade600 : AppColors.primaryBlue;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE7F0FF), Colors.white],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(28),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  info.visitName,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
              if (isGenerating)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 14,
                        height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: statusColor,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        statusText,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: statusColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            formattedDate,
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeroChip(
                icon: Icons.person_outline,
                label: info.doctorName.isEmpty ? 'Doctor TBD' : info.doctorName,
              ),
              _HeroChip(
                icon: Icons.location_city_outlined,
                label: info.hospitalName.isEmpty
                    ? 'Hospital TBD'
                    : info.hospitalName,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeroChip extends StatelessWidget {
  const _HeroChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: AppColors.primaryBlue),
          const SizedBox(width: 6),
          Text(label),
        ],
      ),
    );
  }
}

class _AttachmentStatusCard extends StatelessWidget {
  const _AttachmentStatusCard({
    required this.message,
    required this.icon,
    this.accentColor,
  });

  final String message;
  final IconData icon;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = accentColor ?? AppColors.primaryBlue;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: color),
            ),
          ),
        ],
      ),
    );
  }
}

class _QuestionCard extends StatelessWidget {
  const _QuestionCard({
    required this.index,
    required this.entry,
    required this.showSpinner,
    this.onRemove,
  });

  final int index;
  final _QuestionEntry entry;
  final bool showSpinner;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: entry.isCustom ? Colors.white : AppColors.lightBlue,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: entry.isCustom
              ? theme.colorScheme.outline.withValues(alpha: 0.4)
              : Colors.transparent,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primaryBlue.withValues(alpha: 0.2),
            child: Text(
              '$index',
              style: theme.textTheme.titleMedium?.copyWith(
                color: AppColors.primaryBlue,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (entry.isCustom)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.primaryBlue),
                      ),
                      child: Text(
                        'Added by you',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: AppColors.primaryBlue,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          if (showSpinner || onRemove != null)
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (onRemove != null)
                  IconButton(
                    tooltip: 'Remove question',
                    onPressed: onRemove,
                    icon: const Icon(Icons.close),
                    visualDensity: VisualDensity.compact,
                    iconSize: 20,
                  ),
                if (showSpinner) ...[
                  if (onRemove != null) const SizedBox(height: 6),
                  const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                ],
              ],
            ),
        ],
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({
    required this.icon,
    required this.message,
    this.accentColor,
  });

  final IconData icon;
  final String message;
  final Color? accentColor;

  @override
  Widget build(BuildContext context) {
    final color = accentColor ?? AppColors.mutedText;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: color,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _BottomActionBar extends StatelessWidget {
  const _BottomActionBar({
    required this.isSaving,
    required this.onSave,
    required this.onRegenerate,
    required this.isGenerating,
    this.saveError,
  });

  final bool isSaving;
  final VoidCallback? onSave;
  final VoidCallback? onRegenerate;
  final bool isGenerating;
  final String? saveError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.05),
            blurRadius: 22,
            offset: const Offset(0, -8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FilledButton.icon(
            onPressed: isSaving ? null : onSave,
            icon: isSaving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check_circle_outline),
            label: Text(isSaving ? 'Saving…' : 'Save to folder'),
          ),
          if (saveError != null) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                saveError!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onErrorContainer,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          TextButton.icon(
            onPressed: onRegenerate,
            icon: const Icon(Icons.refresh),
            label: Text(isGenerating ? 'Generating…' : 'Regenerate'),
          ),
        ],
      ),
    );
  }
}
