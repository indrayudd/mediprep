import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/visit_folder.dart';
import '../data/visit_record.dart';
import '../models/llm_model.dart';
import '../services/visit_repository.dart';
import '../widgets/edit_sheets.dart';
import 'visit_detail_screen.dart';
import 'visit_form_screen.dart';

class FolderDetailScreen extends StatelessWidget {
  const FolderDetailScreen({
    super.key,
    required this.folderId,
    required this.model,
    required this.onChangeModel,
  });

  final String folderId;
  final LlmModel model;
  final VoidCallback onChangeModel;

  @override
  Widget build(BuildContext context) {
    return Consumer<VisitRepository>(
      builder: (context, repository, _) {
        final folder = repository.getFolderById(folderId);
        if (folder == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('Folder details')),
            body: const Center(
              child: Text('Folder not found. It may have been removed.'),
            ),
          );
        }

        final messenger = ScaffoldMessenger.of(context);
        final navigator = Navigator.of(context);

        Future<void> handleEditFolder() async {
          final result = await showFolderEditSheet(
            context: context,
            folder: folder,
          );
          if (result == null) return;
          try {
            await repository.updateFolderDetails(
              folderId: folder.id,
              patientName: result.patientName,
              conditionName: result.conditionName,
              primaryDoctor: result.primaryDoctor,
              primaryHospital: result.primaryHospital,
            );
            messenger.showSnackBar(
              const SnackBar(content: Text('Folder updated.')),
            );
          } catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text('Unable to update folder: $error')),
            );
          }
        }

        Future<void> handleDeleteFolder() async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete folder?'),
              content: const Text(
                'This folder and all related visits will be permanently removed.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
          try {
            await repository.deleteFolder(folder.id);
            navigator.pop();
            messenger.showSnackBar(
              const SnackBar(content: Text('Folder deleted.')),
            );
          } catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text('Unable to delete folder: $error')),
            );
          }
        }

        Future<void> handleEditVisit(VisitRecord visit) async {
          final result = await showVisitEditSheet(
            context: context,
            visit: visit,
          );
          if (result == null) return;
          try {
            await repository.updateVisitDetails(
              folderId: folder.id,
              visitId: visit.id,
              title: result.title,
              visitDate: result.visitDate,
              description: result.description,
            );
            messenger.showSnackBar(
              const SnackBar(content: Text('Visit updated.')),
            );
          } catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text('Unable to update visit: $error')),
            );
          }
        }

        Future<void> handleDeleteVisit(VisitRecord visit) async {
          final confirm = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('Delete visit?'),
              content: Text(
                'Remove "${visit.title}" and all its notes/recordings?',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('Cancel'),
                ),
                FilledButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            ),
          );
          if (confirm != true) return;
          try {
            await repository.deleteVisit(
              folderId: folder.id,
              visitId: visit.id,
            );
            messenger.showSnackBar(
              const SnackBar(content: Text('Visit deleted.')),
            );
          } catch (error) {
            messenger.showSnackBar(
              SnackBar(content: Text('Unable to delete visit: $error')),
            );
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(folder.conditionName),
            actions: [
              IconButton(
                tooltip: 'Change AI model',
                onPressed: onChangeModel,
                icon: const Icon(Icons.settings),
              ),
              PopupMenuButton<_FolderAction>(
                tooltip: 'Folder actions',
                onSelected: (action) {
                  switch (action) {
                    case _FolderAction.edit:
                      handleEditFolder();
                      break;
                    case _FolderAction.delete:
                      handleDeleteFolder();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _FolderAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit folder'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _FolderAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete folder'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => VisitFormScreen(
                    model: model,
                    initialFolderId: folderId,
                    onChangeModel: onChangeModel,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add),
            label: const Text('New visit'),
          ),
          body: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _FolderHeader(folder: folder),
              const SizedBox(height: 24),
              Text(
                'Visit details',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              if (folder.visits.isEmpty)
                const _EmptyVisits()
              else
                ...folder.visits.map(
                  (visit) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _VisitTile(
                      visit: visit,
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => VisitDetailScreen(
                              folderId: folderId,
                              visitId: visit.id,
                              model: model,
                              onChangeModel: onChangeModel,
                            ),
                          ),
                        );
                      },
                      onEdit: () => handleEditVisit(visit),
                      onDelete: () => handleDeleteVisit(visit),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _FolderHeader extends StatelessWidget {
  const _FolderHeader({required this.folder});

  final VisitFolder folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
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
            folder.patientName,
            style: theme.textTheme.headlineSmall?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            folder.conditionName,
            style: theme.textTheme.titleMedium?.copyWith(
              color: theme.colorScheme.onPrimaryContainer,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _HeaderChip(
                icon: Icons.medical_services_outlined,
                label: folder.primaryDoctor,
              ),
              _HeaderChip(
                icon: Icons.location_city_outlined,
                label: folder.primaryHospital,
              ),
              _HeaderChip(
                icon: Icons.event_available_outlined,
                label: '${folder.visits.length} visits',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderChip extends StatelessWidget {
  const _HeaderChip({required this.icon, required this.label});

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

class _VisitTile extends StatelessWidget {
  const _VisitTile({
    required this.visit,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  final VisitRecord visit;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final formattedDate = DateFormat.yMMMMd().format(visit.visitDate);
    final questionCount = visit.questions.length;

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.calendar_month,
                  color: theme.colorScheme.primary,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      visit.title,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      formattedDate,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$questionCount questions',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<_VisitAction>(
                tooltip: 'Visit actions',
                onSelected: (action) {
                  switch (action) {
                    case _VisitAction.edit:
                      onEdit();
                      break;
                    case _VisitAction.delete:
                      onDelete();
                      break;
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(
                    value: _VisitAction.edit,
                    child: ListTile(
                      leading: Icon(Icons.edit_outlined),
                      title: Text('Edit visit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                  PopupMenuItem(
                    value: _VisitAction.delete,
                    child: ListTile(
                      leading: Icon(Icons.delete_outline),
                      title: Text('Delete visit'),
                      contentPadding: EdgeInsets.zero,
                    ),
                  ),
                ],
              ),
              Icon(Icons.chevron_right,
                  color: theme.colorScheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyVisits extends StatelessWidget {
  const _EmptyVisits();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          const Icon(Icons.event_note_outlined, size: 40, color: Colors.grey),
          const SizedBox(height: 12),
          Text('No visits yet', style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Use the “New visit” button to add your first appointment notes to this folder.',
            style: Theme.of(context).textTheme.bodySmall,
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

enum _FolderAction { edit, delete }

enum _VisitAction { edit, delete }
