import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/attachment.dart';
import '../data/visit_info.dart';
import '../models/llm_model.dart';
import '../services/model_preferences.dart';
import 'model_setup_screen.dart';
import 'question_generation_screen.dart';

class VisitFormScreen extends StatefulWidget {
  const VisitFormScreen({super.key, required this.model});

  final LlmModel model;

  @override
  State<VisitFormScreen> createState() => _VisitFormScreenState();
}

class _VisitFormScreenState extends State<VisitFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _visitNameController = TextEditingController();
  final _doctorNameController = TextEditingController();
  final _hospitalNameController = TextEditingController();
  final _descriptionController = TextEditingController();
  DateTime? _visitDate;
  var _attachments = <VisitAttachment>[];
  bool _isPickingAttachments = false;

  @override
  void dispose() {
    _visitNameController.dispose();
    _doctorNameController.dispose();
    _hospitalNameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final initialDate = _visitDate ?? now;
    final picked = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(now.year - 1),
      lastDate: DateTime(now.year + 5),
    );
    if (picked != null) {
      setState(() {
        _visitDate = picked;
      });
    }
  }

  void _submit() {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate() || _visitDate == null) {
      if (_visitDate == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please select a visit date.')),
        );
      }
      return;
    }

    final info = VisitInfo(
      visitName: _visitNameController.text.trim(),
      visitDate: _visitDate!,
      doctorName: _doctorNameController.text.trim(),
      hospitalName: _hospitalNameController.text.trim(),
      description: _descriptionController.text.trim(),
      attachments: List.unmodifiable(_attachments),
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) =>
            QuestionGenerationScreen(model: widget.model, visitInfo: info),
      ),
    );
  }

  Future<void> _changeModel() async {
    await ModelPreferences.clearSelectedModel();
    if (!mounted) return;
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => const ModelSetupScreen()),
      (_) => false,
    );
  }

  Future<void> _showAttachmentSheet() async {
    FocusScope.of(context).unfocus();
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: Theme.of(context).colorScheme.surface,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Add attachments',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: const Icon(Icons.photo_library_outlined),
                  title: const Text('Choose photos'),
                  onTap: () {
                    Navigator.of(context).pop();
                    Future.microtask(() => _selectAttachments(FileType.image));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.insert_drive_file_outlined),
                  title: const Text('Browse files'),
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

  @override
  Widget build(BuildContext context) {
    final dateLabel = _visitDate == null
        ? 'Select date'
        : DateFormat.yMMMMd().format(_visitDate!);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Plan your visit'),
        actions: [
          IconButton(
            icon: const Icon(Icons.swap_horiz),
            tooltip: 'Change model',
            onPressed: _changeModel,
          ),
        ],
      ),
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildTextField(
                  controller: _visitNameController,
                  label: 'Visit name',
                  hint: 'e.g. Follow-up consultation',
                ),
                const SizedBox(height: 12),
                Text(
                  'Visit date',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  icon: const Icon(Icons.calendar_today),
                  label: Text(dateLabel),
                  onPressed: _pickDate,
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
                const SizedBox(height: 12),
                _buildTextField(
                  controller: _descriptionController,
                  label: 'Notes for the visit',
                  hint: 'Provide symptoms, goals, or specific concerns',
                  maxLines: 5,
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Attachments',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                    IconButton(
                      tooltip: 'Add attachments (images, PDFs, scans)',
                      icon: _isPickingAttachments
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.attach_file),
                      onPressed: _isPickingAttachments
                          ? null
                          : _showAttachmentSheet,
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                if (_attachments.isEmpty)
                  Text(
                    'Include scans, lab reports, or reference images to enrich the questions.',
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: _attachments
                        .map(
                          (attachment) => InputChip(
                            label: Text(
                              attachment.name,
                              overflow: TextOverflow.ellipsis,
                            ),
                            avatar: Icon(switch (attachment.type) {
                              AttachmentType.pdf => Icons.picture_as_pdf,
                              AttachmentType.image => Icons.image_outlined,
                              AttachmentType.other => Icons.insert_drive_file,
                            }, size: 18),
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
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.play_arrow),
                    label: const Text('Generate questions'),
                    onPressed: _submit,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Current model: ${widget.model.displayName}',
                  style: const TextStyle(fontSize: 13, color: Colors.black54),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    String? hint,
    int maxLines = 1,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        border: const OutlineInputBorder(),
      ),
      maxLines: maxLines,
      validator: (value) {
        if (value == null || value.trim().isEmpty) {
          return 'Please enter ${label.toLowerCase()}';
        }
        return null;
      },
    );
  }
}
