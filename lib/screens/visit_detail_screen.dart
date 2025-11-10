import 'dart:math';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/question_note.dart';
import '../data/visit_folder.dart';
import '../data/visit_record.dart';
import '../models/llm_model.dart';
import '../services/visit_repository.dart';
import '../widgets/recording_overlay.dart';

class VisitDetailScreen extends StatefulWidget {
  const VisitDetailScreen({
    super.key,
    required this.folderId,
    required this.visitId,
    required this.model,
    required this.onChangeModel,
  });

  final String folderId;
  final String visitId;
  final LlmModel model;
  final VoidCallback onChangeModel;

  @override
  State<VisitDetailScreen> createState() => _VisitDetailScreenState();
}

class _VisitDetailScreenState extends State<VisitDetailScreen> {
  late final String _overlayOwnerId =
      'visit_${widget.visitId}_${DateTime.now().microsecondsSinceEpoch}';
  RecordingOverlayController? _overlayController;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _overlayController ??= context.read<RecordingOverlayController>();
  }

  @override
  void dispose() {
    _overlayController?.detachPanel(_overlayOwnerId);
    super.dispose();
  }

  @override
  void deactivate() {
    _overlayController?.detachPanel(_overlayOwnerId);
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VisitRepository>(
      builder: (_, repository, __) {
        final folder = repository.getFolderById(widget.folderId);
        final visit = repository.getVisitById(widget.folderId, widget.visitId);
        if (folder == null || visit == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Visit details')),
            body: const Center(
              child: Text('This visit is no longer available.'),
            ),
          );
        }
        final overlayConfig = RecordingOverlayConfig(
          ensureContext: () async => RecordingSessionContext(
            folderId: widget.folderId,
            visitId: visit.id,
            visitTitle: visit.title,
            visitDate: visit.visitDate,
          ),
          onRecordingSaved: (ctx, recording) async {
            await repository.addRecording(
              folderId: ctx.folderId,
              visitId: ctx.visitId,
              recording: recording,
            );
          },
          title: visit.title,
          date: visit.visitDate,
          visitId: visit.id,
          onOpenVisit: (navigator) async {
            await navigator.push(
              MaterialPageRoute(
                builder: (_) => VisitDetailScreen(
                  folderId: widget.folderId,
                  visitId: widget.visitId,
                  model: widget.model,
                  onChangeModel: widget.onChangeModel,
                ),
              ),
            );
          },
        );
        _scheduleOverlayAttach(visit, overlayConfig);

        return Consumer<RecordingOverlayController>(
          builder: (context, overlayController, _) {
            final bottomInset =
                overlayController.isPanelVisibleFor(_overlayOwnerId)
                    ? 110.0
                    : 80.0;
            return Scaffold(
              appBar: AppBar(
                title: Text(visit.title),
                actions: [
              IconButton(
                tooltip: 'Change AI model',
                onPressed: widget.onChangeModel,
                icon: const Icon(Icons.settings),
              ),
                ],
              ),
              body: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  _VisitSummaryCard(folder: folder, visit: visit),
                  const SizedBox(height: 24),
                  Row(
                    children: [
                      Expanded(
                        child: _SectionLabel(
                          label: 'Questions',
                          trailing: Text(
                            '${visit.questions.length} items',
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                        ),
                      ),
                      TextButton.icon(
                        onPressed: () => _showAddQuestionSheet(
                          repository,
                          visit,
                          overlayConfig,
                        ),
                        icon: const Icon(Icons.add),
                        label: const Text('Add more'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  if (visit.questions.isEmpty)
                    const _EmptyQuestions()
                  else
                    ...visit.questions.asMap().entries.map((entry) {
                      final index = entry.key;
                      final question = entry.value;
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: _QuestionCard(
                          index: index + 1,
                          question: question,
                          onRemove: () => _removeQuestion(
                            repository,
                            visit,
                            question,
                          ),
                        ),
                      );
                    }),
                  const SizedBox(height: 24),
                  _SectionLabel(
                    label: 'Recorded answers',
                    trailing: Text(
                      '${visit.recordings.length} items',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ),
                  const SizedBox(height: 12),
                  RecordingListSection(
                    recordings: visit.recordings,
                    config: overlayConfig,
                  ),
                  if (visit.attachments.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(
                      label: 'Attachments',
                      trailing: Text(
                        '${visit.attachments.length} files',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: visit.attachments
                          .map(
                            (attachment) => Chip(
                              avatar: const Icon(Icons.attach_file, size: 18),
                              label: Text(attachment.name),
                            ),
                          )
                          .toList(),
                    ),
                  ],
                  if (visit.description.isNotEmpty) ...[
                    const SizedBox(height: 24),
                    _SectionLabel(label: 'Notes'),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surface,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Text(
                        visit.description,
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ),
                  ],
                  SizedBox(height: bottomInset),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _removeQuestion(
    VisitRepository repository,
    VisitRecord visit,
    QuestionNote question,
  ) async {
    final updated = List<QuestionNote>.from(visit.questions)
      ..removeWhere((note) => note.id == question.id);
    if (updated.length == visit.questions.length) {
      return;
    }
    try {
      await repository.updateQuestions(
        folderId: widget.folderId,
        visitId: visit.id,
        questions: updated,
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to remove question: $error')),
      );
    }
  }

  void _scheduleOverlayAttach(
    VisitRecord visit,
    RecordingOverlayConfig config,
  ) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final overlay = _overlayController;
      if (overlay == null) return;
      overlay.attachPanel(_overlayOwnerId, config);
    });
  }

  Future<void> _showAddQuestionSheet(
    VisitRepository repository,
    VisitRecord visit,
    RecordingOverlayConfig overlayConfig,
  ) async {
    final controller = TextEditingController();
    _overlayController?.detachPanel(_overlayOwnerId);
    String? result;
    try {
      result = await showModalBottomSheet<String>(
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
                  'Add a custom question',
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
    } finally {
      if (mounted) {
        _overlayController?.attachPanel(_overlayOwnerId, overlayConfig);
      }
    }

    if (result == null || result.trim().isEmpty) return;
    final newQuestion = QuestionNote(
      id: _generateId(),
      text: result.trim(),
      createdAt: DateTime.now(),
      isCustom: true,
    );
    final questions = [...visit.questions, newQuestion];
    await repository.updateQuestions(
      folderId: widget.folderId,
      visitId: visit.id,
      questions: questions,
    );
  }

  String _generateId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random().nextInt(1 << 16)}';
}

class _VisitSummaryCard extends StatelessWidget {
  const _VisitSummaryCard({required this.folder, required this.visit});

  final VisitFolder folder;
  final VisitRecord visit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat.yMMMMd().format(visit.visitDate);
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            folder.conditionName,
            style: theme.textTheme.titleLarge?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            formattedDate,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _SummaryChip(
                icon: Icons.person_outline,
                label: folder.patientName,
              ),
              _SummaryChip(
                icon: Icons.medical_services_outlined,
                label: folder.primaryDoctor,
              ),
              _SummaryChip(
                icon: Icons.location_city_outlined,
                label: folder.primaryHospital,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryChip extends StatelessWidget {
  const _SummaryChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.onPrimaryContainer.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.onPrimaryContainer),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
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
    required this.question,
    this.onRemove,
  });

  final int index;
  final QuestionNote question;
  final VoidCallback? onRemove;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              CircleAvatar(
                radius: 16,
                backgroundColor: theme.colorScheme.primary.withValues(
                  alpha: 0.15,
                ),
                child: Text(
                  '$index',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.primary,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  question.text,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (question.isCustom)
                Padding(
                  padding: const EdgeInsets.only(right: 4),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.secondaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      'You',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSecondaryContainer,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
              if (onRemove != null)
                IconButton(
                  tooltip: 'Remove question',
                  icon: const Icon(Icons.close),
                  onPressed: onRemove,
                  visualDensity: VisualDensity.compact,
                ),
            ],
          ),
          if (question.answer?.isNotEmpty == true) ...[
            const SizedBox(height: 12),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                question.answer!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmptyQuestions extends StatelessWidget {
  const _EmptyQuestions();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(Icons.quiz_outlined, size: 32, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'No questions yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Generate or add your questions to prepare for the appointment.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.label, this.trailing});

  final String label;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      Text(
        label,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
      ),
    ];
    if (trailing != null) {
      children.add(trailing!);
    }
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: children,
    );
  }
}
