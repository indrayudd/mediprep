import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'dart:ui';

import '../data/visit_folder.dart';
import '../data/visit_record.dart';

class FolderEditResult {
  const FolderEditResult({
    required this.patientName,
    required this.conditionName,
    required this.primaryDoctor,
    required this.primaryHospital,
  });

  final String patientName;
  final String conditionName;
  final String primaryDoctor;
  final String primaryHospital;
}

class VisitEditResult {
  const VisitEditResult({
    required this.title,
    required this.visitDate,
    required this.description,
  });

  final String title;
  final DateTime visitDate;
  final String description;
}

Future<FolderEditResult?> showFolderEditSheet({
  required BuildContext context,
  required VisitFolder folder,
}) {
  return showModalBottomSheet<FolderEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return AnimatedPadding(
        padding: MediaQuery.of(context).viewInsets,
        duration: const Duration(milliseconds: 100),
        curve: Curves.decelerate,
        child: _FolderEditSheet(folder: folder),
      );
    },
  );
}

Future<VisitEditResult?> showVisitEditSheet({
  required BuildContext context,
  required VisitRecord visit,
}) {
  return showModalBottomSheet<VisitEditResult>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
    ),
    builder: (context) {
      return AnimatedPadding(
        padding: MediaQuery.of(context).viewInsets,
        duration: const Duration(milliseconds: 100),
        curve: Curves.decelerate,
        child: _VisitEditSheet(visit: visit),
      );
    },
  );
}

class _FolderEditSheet extends StatefulWidget {
  const _FolderEditSheet({required this.folder});

  final VisitFolder folder;

  @override
  State<_FolderEditSheet> createState() => _FolderEditSheetState();
}

class _FolderEditSheetState extends State<_FolderEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _patientController;
  late final TextEditingController _conditionController;
  late final TextEditingController _doctorController;
  late final TextEditingController _hospitalController;

  @override
  void initState() {
    super.initState();
    _patientController = TextEditingController(text: widget.folder.patientName);
    _conditionController =
        TextEditingController(text: widget.folder.conditionName);
    _doctorController = TextEditingController(text: widget.folder.primaryDoctor);
    _hospitalController =
        TextEditingController(text: widget.folder.primaryHospital);
  }

  @override
  void dispose() {
    _patientController.dispose();
    _conditionController.dispose();
    _doctorController.dispose();
    _hospitalController.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      FolderEditResult(
        patientName: _patientController.text.trim(),
        conditionName: _conditionController.text.trim(),
        primaryDoctor: _doctorController.text.trim(),
        primaryHospital: _hospitalController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit folder',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _patientController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Patient name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a patient name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _conditionController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Condition or purpose',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a condition';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _doctorController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Primary doctor',
                  ),
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _hospitalController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Primary hospital/clinic',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _VisitEditSheet extends StatefulWidget {
  const _VisitEditSheet({required this.visit});

  final VisitRecord visit;

  @override
  State<_VisitEditSheet> createState() => _VisitEditSheetState();
}

class _VisitEditSheetState extends State<_VisitEditSheet> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _titleController;
  late final TextEditingController _descriptionController;
  late DateTime _selectedDate;
  late final TextEditingController _dateController;

  @override
  void initState() {
    super.initState();
    _selectedDate = widget.visit.visitDate;
    _titleController = TextEditingController(text: widget.visit.title);
    _descriptionController =
        TextEditingController(text: widget.visit.description);
    _dateController = TextEditingController(
      text: DateFormat.yMMMMd().format(widget.visit.visitDate),
    );
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    _dateController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(DateTime.now().year + 5),
    );
    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _dateController.text = DateFormat.yMMMMd().format(picked);
      });
    }
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(
      VisitEditResult(
        title: _titleController.text.trim(),
        visitDate: _selectedDate,
        description: _descriptionController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Theme.of(context).canvasColor.withValues(alpha: 0.8),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
          ),
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).viewInsets.bottom + 20,
            top: 24,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Edit visit',
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _titleController,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Visit name',
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a visit name';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _dateController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: 'Visit date',
                    suffixIcon: Icon(Icons.calendar_today),
                  ),
                  onTap: _pickDate,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _descriptionController,
                  minLines: 3,
                  maxLines: 4,
                  decoration: const InputDecoration(
                    labelText: 'Notes or goals for this visit',
                  ),
                ),
                const SizedBox(height: 20),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.of(context).maybePop(),
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: FilledButton(
                        onPressed: _submit,
                        child: const Text('Save changes'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
