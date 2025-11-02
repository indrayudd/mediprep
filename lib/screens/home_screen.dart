import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../data/visit_folder.dart';
import '../models/llm_model.dart';
import '../services/visit_repository.dart';
import 'folder_detail_screen.dart';
import 'visit_form_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    required this.model,
    required this.onChangeModel,
  });

  final LlmModel model;
  final VoidCallback onChangeModel;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void initState() {
    super.initState();
    _searchController.addListener(_handleQueryChanged);
  }

  @override
  void dispose() {
    _searchController
      ..removeListener(_handleQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleQueryChanged() {
    setState(() {
      _query = _searchController.text.trim().toLowerCase();
    });
  }

  void _openVisitForm({String? folderId}) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => VisitFormScreen(
          model: widget.model,
          initialFolderId: folderId,
          onChangeModel: widget.onChangeModel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<VisitRepository>();
    final folders = repository.folders;
    final filtered = folders.where((folder) {
      if (_query.isEmpty) return true;
      final haystack =
          '${folder.patientName} '
                  '${folder.conditionName} '
                  '${folder.primaryDoctor} '
                  '${folder.primaryHospital}'
              .toLowerCase();
      return haystack.contains(_query);
    }).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('MediPrep'),
        actions: [
          IconButton(
            tooltip: 'Change AI model',
            onPressed: widget.onChangeModel,
            icon: const Icon(Icons.auto_awesome),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openVisitForm,
        icon: const Icon(Icons.add),
        label: const Text('New visit'),
      ),
      body: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _searchController,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.search),
                hintText: 'Search by date, doctor, patient, or condition',
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyState(onCreate: _openVisitForm)
                  : ListView.separated(
                      itemBuilder: (_, index) {
                        final folder = filtered[index];
                        return _FolderCard(
                          folder: folder,
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => FolderDetailScreen(
                                  model: widget.model,
                                  folderId: folder.id,
                                  onChangeModel: widget.onChangeModel,
                                ),
                              ),
                            );
                          },
                        );
                      },
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemCount: filtered.length,
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onCreate});

  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.folder_open, size: 48, color: Colors.grey),
          const SizedBox(height: 16),
          Text(
            'Start your preparation',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Create your first visit folder to capture questions, notes, and recordings.',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 16),
          FilledButton(onPressed: onCreate, child: const Text('Create visit')),
        ],
      ),
    );
  }
}

class _FolderCard extends StatelessWidget {
  const _FolderCard({required this.folder, required this.onTap});

  final VisitFolder folder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final visitCount = folder.visits.length;
    final recentVisit = folder.visits.isEmpty
        ? null
        : folder.visits.reduce(
            (current, next) =>
                current.visitDate.isAfter(next.visitDate) ? current : next,
          );
    final date = recentVisit?.visitDate;
    final formattedDate = date == null
        ? 'No visits yet'
        : DateFormat.yMMMd().format(date);

    return Material(
      color: theme.colorScheme.surface,
      elevation: 1,
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          folder.patientName,
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          folder.conditionName,
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.arrow_forward_ios,
                    size: 16,
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _InfoChip(
                    label: folder.primaryDoctor,
                    icon: Icons.local_hospital_outlined,
                  ),
                  _InfoChip(
                    label: folder.primaryHospital,
                    icon: Icons.location_city_outlined,
                  ),
                  _InfoChip(
                    label: visitCount == 1 ? '1 visit' : '$visitCount visits',
                    icon: Icons.event_available_outlined,
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                'Last visit: $formattedDate',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.label, required this.icon});

  final String label;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.primaryContainer,
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
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}
