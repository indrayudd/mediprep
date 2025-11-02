import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => QuestionGenerationScreen(
          model: widget.model,
          visitInfo: info,
        ),
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
      body: SingleChildScrollView(
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
              Text('Visit date', style: Theme.of(context).textTheme.titleSmall),
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
