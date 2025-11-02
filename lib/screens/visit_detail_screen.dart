import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/question_note.dart';
import '../data/recording_meta.dart';
import '../data/visit_folder.dart';
import '../data/visit_record.dart';
import '../models/llm_model.dart';
import '../services/visit_repository.dart';
import '../widgets/recording_dock.dart';

class VisitDetailScreen extends StatelessWidget {
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
  Widget build(BuildContext context) {
    return Consumer<VisitRepository>(
      builder: (_, repository, __) {
        final folder = repository.getFolderById(folderId);
        final visit = repository.getVisitById(folderId, visitId);
        if (folder == null || visit == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Visit details')),
            body: const Center(
              child: Text('This visit is no longer available.'),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(visit.title),
            actions: [
              IconButton(
                tooltip: 'Change AI model',
                onPressed: onChangeModel,
                icon: const Icon(Icons.auto_awesome),
              ),
            ],
          ),
          body: RecordingDock(
            enabled: true,
            ensureContext: () async => RecordingSessionContext(
              folderId: folderId,
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
            onError: (error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('Recording failed: $error')),
              );
            },
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
                _VisitSummaryCard(folder: folder, visit: visit),
                const SizedBox(height: 24),
                _SectionLabel(
                  label: 'Questions',
                  trailing: Text(
                    '${visit.questions.length} items',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
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
                      ),
                    );
                  }),
                const SizedBox(height: 24),
                _SectionLabel(
                  label: 'Recordings',
                  trailing: Text(
                    '${visit.recordings.length} items',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ),
                const SizedBox(height: 12),
                if (visit.recordings.isEmpty)
                  const _EmptyRecordings()
                else
                  ...visit.recordings.map(
                    (recording) => Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _RecordingTile(recording: recording),
                    ),
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
              ],
            ),
          ),
        );
      },
    );
  }
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
  const _QuestionCard({required this.index, required this.question});

  final int index;
  final QuestionNote question;

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
                Container(
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

class _RecordingTile extends StatelessWidget {
  const _RecordingTile({required this.recording});

  final RecordingMeta recording;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final duration = Duration(seconds: recording.durationSeconds);
    final durationText =
        '${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}:${(duration.inSeconds.remainder(60)).toString().padLeft(2, '0')}';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              Icons.play_arrow_rounded,
              size: 32,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  recording.displayName ?? 'Recording',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  durationText,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text(
                    'Playback is coming soon. Recordings are safely stored.',
                  ),
                ),
              );
            },
            icon: const Icon(Icons.play_circle_fill),
          ),
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

class _EmptyRecordings extends StatelessWidget {
  const _EmptyRecordings();

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
          const Icon(Icons.mic_none_outlined, size: 32, color: Colors.grey),
          const SizedBox(height: 8),
          Text(
            'No recordings yet',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 4),
          Text(
            'Capture conversations with your doctor to revisit later.',
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
