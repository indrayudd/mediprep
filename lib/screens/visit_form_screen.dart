import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../data/attachment.dart';
import '../data/visit_draft.dart';
import '../data/visit_folder.dart';
import '../data/visit_info.dart';
import '../models/llm_model.dart';
import '../services/visit_repository.dart';
import '../theme/app_colors.dart';
import 'question_generation_screen.dart';

enum _FormStage { selectType, selectFolder, fillDetails }

enum _VisitFlowType { newFolder, followUp }

class VisitFormScreen extends StatefulWidget {
  const VisitFormScreen({
    super.key,
    required this.model,
    this.initialFolderId,
    this.onChangeModel,
  });

  final LlmModel model;
  final String? initialFolderId;
  final VoidCallback? onChangeModel;

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visitNameController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _patientNameController = TextEditingController();
  final _conditionNameController = TextEditingController();
  final _folderSearchController = TextEditingController();

  DateTime? _visitDate;
  var _attachments = <VisitAttachment>[];
  bool _isPickingAttachments = false;

  _FormStage _stage = _FormStage.selectType;
  _VisitFlowType? _selectedFlowType;
  String? _selectedFolderId;
  bool _syncedInitialState = false;
  String _folderQuery = '';

  @override
  void initState() {
    super.initState();
    _folderSearchController.addListener(_handleFolderQueryChanged);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_syncedInitialState) return;
    final repository = context.read<VisitRepository>();
    final folders = repository.folders;

    if (folders.isEmpty) {
      _selectedFlowType = _VisitFlowType.newFolder;
      _stage = _FormStage.fillDetails;
    } else if (widget.initialFolderId != null) {
      final folder = _findFolder(folders, widget.initialFolderId!);
      if (folder != null) {
        _selectedFlowType = _VisitFlowType.followUp;
        _selectedFolderId = folder.id;
        _applyFolderDetails(folder);
        _stage = _FormStage.fillDetails;
      }
    }

    _syncedInitialState = true;
  }

  @override
  void dispose() {
    _visitNameController.dispose();
    _doctorNameController.dispose();
    _hospitalNameController.dispose();
    _descriptionController.dispose();
    _patientNameController.dispose();
    _conditionNameController.dispose();
    _folderSearchController
      ..removeListener(_handleFolderQueryChanged)
      ..dispose();
    super.dispose();
  }

  void _handleFolderQueryChanged() {
    setState(() {
      _folderQuery = _folderSearchController.text.trim().toLowerCase();
    });
  }

  VisitFolder? _findFolder(List<VisitFolder> folders, String id) {
    try {
      return folders.firstWhere((folder) => folder.id == id);
    } catch (_) {
      return null;
    }
  }

  void _applyFolderDetails(VisitFolder folder) {
    _patientNameController.text = folder.patientName;
    _conditionNameController.text = folder.conditionName;
    _doctorNameController.text = folder.primaryDoctor;
    _hospitalNameController.text = folder.primaryHospital;
  }

  void _resetFolderContext() {
    _selectedFolderId = null;
    _patientNameController.clear();
    _conditionNameController.clear();
    _doctorNameController.clear();
    _hospitalNameController.clear();
  }

  void _setFlowType(_VisitFlowType type) {
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedFlowType = type;
      if (type == _VisitFlowType.newFolder) {
        _resetFolderContext();
      }
    });
  }

  void _goForwardFromType(List<VisitFolder> folders) {
    if (_selectedFlowType == null) {
      _showSnack('Select a visit type to continue.');
      return;
    }
    if (_selectedFlowType == _VisitFlowType.followUp && folders.isEmpty) {
      _showSnack('You need at least one folder to log a follow-up visit.');
      return;
    }
    setState(() {
      _stage = _selectedFlowType == _VisitFlowType.followUp
          ? _FormStage.selectFolder
          : _FormStage.fillDetails;
    });
  }

  void _confirmFolderSelection() {
    if (_selectedFolderId == null) {
      _showSnack('Select a folder to continue.');
      return;
    }
    setState(() {
      _stage = _FormStage.fillDetails;
    });
  }

  void _handleFolderTapped(
    String folderId,
    List<VisitFolder> folders,
  ) {
    final folder = _findFolder(folders, folderId);
    if (folder == null) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _selectedFolderId = folder.id;
      _applyFolderDetails(folder);
    });
  }

  void _showSnack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  bool _handleStageBack(List<VisitFolder> folders) {
    final hasFolders = folders.isNotEmpty;
    if (_stage == _FormStage.fillDetails) {
      if (_selectedFlowType == _VisitFlowType.followUp && hasFolders) {
        setState(() {
          _stage = _FormStage.selectFolder;
          _selectedFolderId = null;
        });
        return true;
      }
      if (_selectedFlowType == _VisitFlowType.newFolder && hasFolders) {
        setState(() {
          _stage = _FormStage.selectType;
        });
        return true;
      }
    } else if (_stage == _FormStage.selectFolder) {
      setState(() {
        _stage = _FormStage.selectType;
        _selectedFolderId = null;
      });
      return true;
    }
    return false;
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _visitDate ?? now,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  Future<void> _showAttachmentSheet() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add attachments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                _AttachmentOption(
                  icon: Icons.photo_library_outlined,
                  label: 'Choose photos',
                  onTap: () {
                    Navigator.of(context).pop();
                    Future.microtask(() => _selectAttachments(FileType.image));
                  },
                ),
                _AttachmentOption(
                  icon: Icons.insert_drive_file_outlined,
                  label: 'Browse files (PDF, PNG, JPG)',
                  onTap: () {
                    Navigator.of(context).pop();
                    Future.microtask(
                      () => _selectAttachments(
                        FileType.custom,
                        extensions: const [
                          'pdf',
                          'png',
                          'jpg',
                          'jpeg',
                          'heic',
                          'tif',
                          'tiff',
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _selectAttachments(
    FileType fileType, {
    List<String>? extensions,
  }) async {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _isPickingAttachments = true;
    });

    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: false,
        type: fileType,
        allowedExtensions: extensions,
      );
      if (result == null) {
        return;
      }

      final additions = <VisitAttachment>[];
      for (final file in result.files) {
        final resolvedPath = await _resolvePath(file);
        if (resolvedPath == null) {
          continue;
        }
        final attachment = VisitAttachment.fromPath(resolvedPath).copyWith(
          name: file.name.isNotEmpty ? file.name : p.basename(resolvedPath),
        );
        additions.add(attachment);
      }

      if (additions.isNotEmpty) {
        setState(() {
          final existingPaths = _attachments.map((item) => item.path).toSet();
          _attachments = [
            ..._attachments,
            ...additions.where((item) => !existingPaths.contains(item.path)),
          ];
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isPickingAttachments = false;
        });
      }
    }
  }

  Future<String?> _resolvePath(PlatformFile file) async {
    if (file.path != null && file.path!.isNotEmpty) {
      return file.path!;
    }
    if (file.bytes == null) {
      return null;
    }
    final tempDir = await getTemporaryDirectory();
    final safeName = file.name.isNotEmpty
        ? file.name
        : 'attachment_${DateTime.now().millisecondsSinceEpoch}';
    final safePath = p.join(tempDir.path, safeName);
    final outFile = File(safePath);
    await outFile.writeAsBytes(file.bytes!, flush: true);
    return outFile.path;
  }

  bool get _isNewFolderFlow =>
      _selectedFlowType == null || _selectedFlowType == _VisitFlowType.newFolder;

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || _visitDate == null) {
      if (_visitDate == null) {
        _showSnack('Please select a visit date.');
      }
      return;
    }

    final repository = context.read<VisitRepository>();
    final folders = repository.folders;
    final isNewFolder = _isNewFolderFlow || folders.isEmpty;

    if (!isNewFolder && _selectedFolderId == null) {
      _showSnack('Select a folder to continue.');
      return;
    }

    final patientName = _patientNameController.text.trim();
    final conditionName = _conditionNameController.text.trim();

    if (isNewFolder) {
      if (patientName.isEmpty || conditionName.isEmpty) {
        _showSnack('Enter patient and condition details for the folder.');
        return;
      }
    }

    final info = VisitInfo(
      visitName: _visitNameController.text.trim(),
      visitDate: _visitDate!,
      doctorName: _doctorNameController.text.trim(),
      hospitalName: _hospitalNameController.text.trim(),
      description: _descriptionController.text.trim(),
      attachments: List.unmodifiable(_attachments),
    );

    final draft = isNewFolder
        ? VisitDraft(
            visitInfo: info,
            patientName: patientName,
            conditionName: conditionName,
          )
        : VisitDraft(visitInfo: info, existingFolderId: _selectedFolderId);

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionGenerationScreen(
          model: widget.model,
          draft: draft,
          onChangeModel: widget.onChangeModel,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final repository = context.watch<VisitRepository>();
    final folders = repository.folders;
    final hasFolders = folders.isNotEmpty;
    final stage = _stage;
    final isNewFolderFlow = _selectedFlowType == null
        ? !hasFolders
        : _selectedFlowType == _VisitFlowType.newFolder;

    final stageContent = switch (stage) {
      _FormStage.selectType => _buildVisitTypeStage(hasFolders),
      _FormStage.selectFolder => _buildFolderSelectionStage(folders),
      _FormStage.fillDetails => _buildDetailsStage(
          isNewFolderFlow: isNewFolderFlow || !hasFolders,
          folders: folders,
        ),
    };

    final primaryAction = switch (stage) {
      _FormStage.selectType => (
          label: 'Next',
          enabled: _selectedFlowType != null &&
              (_selectedFlowType == _VisitFlowType.newFolder || hasFolders),
          onPressed: () => _goForwardFromType(folders),
        ),
      _FormStage.selectFolder => (
          label: 'Next',
          enabled: _selectedFolderId != null,
          onPressed: _confirmFolderSelection,
        ),
      _FormStage.fillDetails => (
          label: 'Generate questions',
          enabled: true,
          onPressed: _submit,
        ),
    };

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) {
          return;
        }
        final handled = _handleStageBack(folders);
        if (!handled) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(_titleForStage(stage, isNewFolderFlow || !hasFolders)),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () {
              final handled = _handleStageBack(folders);
              if (!handled) {
                Navigator.of(context).pop();
              }
            },
          ),
        ),
        body: Column(
          children: [
            Expanded(
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 220),
                switchInCurve: Curves.easeInOut,
                child: SingleChildScrollView(
                  key: ValueKey(stage),
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                  child: stageContent,
                ),
              ),
            ),
            _PrimaryActionBar(
              label: primaryAction.label,
              enabled: primaryAction.enabled,
              onPressed: primaryAction.enabled ? primaryAction.onPressed : null,
              supportingText: stage == _FormStage.fillDetails
                  ? 'Current model: ${widget.model.displayName}'
                  : null,
            ),
          ],
        ),
      ),
    );
  }

  String _titleForStage(_FormStage stage, bool isNewFolderFlow) {
    switch (stage) {
      case _FormStage.selectType:
        return 'Select visit type';
      case _FormStage.selectFolder:
        return 'Follow-up visit';
      case _FormStage.fillDetails:
        return isNewFolderFlow ? 'Create new folder' : 'Follow-up visit';
    }
  }

  Widget _buildVisitTypeStage(bool hasFolders) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Plan your visit',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Tell MediPrep what kind of visit you\'re preparing for.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 24),
        _VisitTypeCard(
          title: 'First-time visit',
          description:
              'Create a new folder with patient, doctor, and hospital details.',
          icon: Icons.auto_awesome,
          isSelected: _selectedFlowType == _VisitFlowType.newFolder,
          onTap: () => _setFlowType(_VisitFlowType.newFolder),
        ),
        const SizedBox(height: 12),
        _VisitTypeCard(
          title: 'Follow-up visit',
          description: hasFolders
              ? 'Attach this visit to an existing folder and reuse the saved context.'
              : 'You need at least one folder before creating a follow-up.',
          icon: Icons.history,
          isSelected: _selectedFlowType == _VisitFlowType.followUp,
          onTap: hasFolders ? () => _setFlowType(_VisitFlowType.followUp) : null,
          disabled: !hasFolders,
        ),
        if (!hasFolders)
          Padding(
            padding: const EdgeInsets.only(top: 16),
            child: _InfoBanner(
              text:
                  'You do not have any folders yet. Create one to unlock follow-up visits.',
              icon: Icons.info_outline,
            ),
          ),
      ],
    );
  }

  Widget _buildFolderSelectionStage(List<VisitFolder> folders) {
    final theme = Theme.of(context);
    final filtered = folders.where((folder) {
      if (_folderQuery.isEmpty) return true;
      final haystack =
          '${folder.patientName} ${folder.conditionName} ${folder.primaryDoctor} ${folder.primaryHospital}'
              .toLowerCase();
      return haystack.contains(_folderQuery);
    }).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Attach this visit to a folder',
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Search by patient, doctor, hospital, or condition to narrow it down.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        TextField(
          controller: _folderSearchController,
          decoration: InputDecoration(
            hintText: 'Search by date, doctor, patient',
            prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
            ),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: theme.colorScheme.outline),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(28),
              borderSide: BorderSide(color: theme.colorScheme.primary, width: 1.4),
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (filtered.isEmpty)
          _InfoBanner(
            text:
                'No folders match that search. Try a different doctor, date, or patient name.',
            icon: Icons.search_off_outlined,
          )
        else
          ...filtered.map(
            (folder) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FolderSelectTile(
                folder: folder,
                selected: _selectedFolderId == folder.id,
                onTap: () => _handleFolderTapped(folder.id, folders),
              ),
            ),
          ),
      ],
    );
  }

  Widget _buildDetailsStage({
    required bool isNewFolderFlow,
    required List<VisitFolder> folders,
  }) {
    final theme = Theme.of(context);
    final selectedFolder = !isNewFolderFlow && _selectedFolderId != null
        ? _findFolder(folders, _selectedFolderId!)
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (selectedFolder != null) ...[
          _FolderSummary(folder: selectedFolder),
          const SizedBox(height: 20),
        ],
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (isNewFolderFlow) ...[
                _SectionCard(
                  title: 'Folder details',
                  subtitle:
                      'We use these details to keep every visit organized.',
                  child: Column(
                    children: [
                      _buildTextField(
                        controller: _patientNameController,
                        label: 'Patient name',
                        hint: 'e.g. Jane Doe',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please enter patient name';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _conditionNameController,
                        label: 'Condition / folder title',
                        hint: 'e.g. Viral fever',
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) {
                            return 'Please describe the condition';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _doctorNameController,
                        label: 'Doctor name',
                        hint: 'e.g. Dr. Priya Nair',
                      ),
                      const SizedBox(height: 12),
                      _buildTextField(
                        controller: _hospitalNameController,
                        label: 'Hospital / Clinic name',
                        hint: 'e.g. Lakeside Medical Center',
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
              ],
              _SectionCard(
                title: 'Visit details',
                subtitle:
                    'Share what you\'re preparing for so we can tailor the questions.',
                child: Column(
                  children: [
                    _buildTextField(
                      controller: _visitNameController,
                      label: 'Visit name',
                      hint: 'e.g. Follow-up consultation',
                    ),
                    const SizedBox(height: 12),
                    _DatePickerField(
                      label: 'Visit date',
                      value: _visitDate == null
                          ? 'Select date'
                          : DateFormat.yMMMMd().format(_visitDate!),
                      onTap: _pickDate,
                    ),
                    const SizedBox(height: 12),
                    _buildTextField(
                      controller: _descriptionController,
                      label: 'Notes for the visit',
                      hint: 'Symptoms, goals, or specific concerns',
                      maxLines: 4,
                      validator: (value) {
                        if (value == null || value.trim().isEmpty) {
                          return 'Share a short note to guide the AI';
                        }
                        return null;
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              _SectionCard(
                title: 'Attachments',
                subtitle:
                    'Bring labs, scans, or prior transcripts to give the AI more context.',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    OutlinedButton.icon(
                      onPressed: _isPickingAttachments ? null : _showAttachmentSheet,
                      icon: _isPickingAttachments
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file),
                      label: const Text('Add attachments'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: theme.colorScheme.primary,
                        side: BorderSide(color: theme.colorScheme.primary),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (_attachments.isEmpty)
                      Text(
                        'Include scans, lab reports, or reference images to enrich the questions.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      )
                    else
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: _attachments
                            .map(
                              (attachment) => Chip(
                                label: Text(
                                  attachment.name,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                avatar: Icon(
                                  switch (attachment.type) {
                                    AttachmentType.pdf => Icons.picture_as_pdf,
                                    AttachmentType.image => Icons.image_outlined,
                                    AttachmentType.other =>
                                      Icons.insert_drive_file_outlined,
                                  },
                                  size: 18,
                                ),
                                deleteIcon: const Icon(Icons.close, size: 18),
                                onDeleted: () {
                                  setState(() {
                                    _attachments = _attachments
                                        .where((item) => item != attachment)
                                        .toList();
                                  });
                                },
                              ),
                            )
                            .toList(),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
    TextInputType? keyboardType,
    String? Function(String?)? validator,
  }) {
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      keyboardType: keyboardType,
      validator: validator ??
          (value) {
            if (value == null || value.trim().isEmpty) {
              return 'Please enter ${label.toLowerCase()}';
            }
            return null;
          },
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
      ),
    );
  }
}

class _AttachmentOption extends StatelessWidget {
  const _AttachmentOption({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon),
      title: Text(label),
      onTap: onTap,
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.text, required this.icon});

  final String text;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppColors.primaryBlue),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.mutedText,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VisitTypeCard extends StatelessWidget {
  const _VisitTypeCard({
    required this.title,
    required this.description,
    required this.icon,
    required this.isSelected,
    this.onTap,
    this.disabled = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final bool isSelected;
  final VoidCallback? onTap;
  final bool disabled;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final activeColor = theme.colorScheme.primary;
    final borderColor = isSelected ? activeColor : theme.colorScheme.outline;
    final textColor =
        disabled ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4) : null;

    return GestureDetector(
      onTap: disabled ? null : onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: isSelected ? AppColors.lightBlue : Colors.white,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: borderColor,
            width: isSelected ? 1.6 : 1,
          ),
          boxShadow: [
            if (isSelected)
              BoxShadow(
                color: activeColor.withValues(alpha: 0.15),
                blurRadius: 20,
                offset: const Offset(0, 8),
              ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: activeColor.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(
                icon,
                color: activeColor,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: textColor ?? theme.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (isSelected)
              Icon(Icons.check_circle, color: activeColor)
            else
              Icon(
                Icons.radio_button_unchecked,
                color: disabled
                    ? theme.colorScheme.onSurfaceVariant.withValues(alpha: 0.4)
                    : theme.colorScheme.outline,
              ),
          ],
        ),
      ),
    );
  }
}

class _FolderSelectTile extends StatelessWidget {
  const _FolderSelectTile({
    required this.folder,
    required this.selected,
    required this.onTap,
  });

  final VisitFolder folder;
  final bool selected;
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
    final formattedDate = recentVisit == null
        ? 'No visits yet'
        : DateFormat.yMMMd().format(recentVisit.visitDate);

    return Material(
      color: selected ? AppColors.lightBlue : Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                selected
                    ? Icons.radio_button_checked
                    : Icons.radio_button_unchecked,
                color: selected
                    ? theme.colorScheme.primary
                    : theme.colorScheme.outline,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      folder.patientName,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
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
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _InfoChip(
                          icon: Icons.local_hospital_outlined,
                          label: folder.primaryDoctor,
                        ),
                        _InfoChip(
                          icon: Icons.location_city_outlined,
                          label: folder.primaryHospital,
                        ),
                        _InfoChip(
                          icon: Icons.event_available_outlined,
                          label:
                              visitCount == 1 ? '1 visit' : '$visitCount visits',
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Last visit: $formattedDate',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FolderSummary extends StatelessWidget {
  const _FolderSummary({required this.folder});

  final VisitFolder folder;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.lightBlue,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            folder.patientName,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
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
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _InfoChip(
                icon: Icons.medical_services_outlined,
                label: folder.primaryDoctor,
              ),
              _InfoChip(
                icon: Icons.location_city_outlined,
                label: folder.primaryHospital,
              ),
              _InfoChip(
                icon: Icons.event_note_outlined,
                label: '${folder.visits.length} visits logged',
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InfoChip extends StatelessWidget {
  const _InfoChip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: theme.colorScheme.primary),
          const SizedBox(width: 6),
          Text(
            label,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: theme.colorScheme.surfaceContainerHighest),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }
}

class _DatePickerField extends StatelessWidget {
  const _DatePickerField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isPlaceholder = value == 'Select date';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 8),
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: theme.colorScheme.outline),
            ),
            child: Row(
              children: [
                Icon(Icons.calendar_today, color: theme.colorScheme.primary),
                const SizedBox(width: 12),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    color: isPlaceholder
                        ? theme.colorScheme.onSurfaceVariant
                        : theme.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _PrimaryActionBar extends StatelessWidget {
  const _PrimaryActionBar({
    required this.label,
    required this.enabled,
    this.onPressed,
    this.supportingText,
  });

  final String label;
  final bool enabled;
  final VoidCallback? onPressed;
  final String? supportingText;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(20, 12, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: enabled ? onPressed : null,
              child: Text(label),
            ),
          ),
          if (supportingText != null) ...[
            const SizedBox(height: 8),
            Text(
              supportingText!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
