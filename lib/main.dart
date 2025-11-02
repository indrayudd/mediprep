import 'package:flutter/material.dart';

import 'models/llm_model.dart';
import 'screens/model_setup_screen.dart';
import 'screens/visit_form_screen.dart';
import 'services/model_preferences.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DoctorVisitPlannerApp());
}

class DoctorVisitPlannerApp extends StatelessWidget {
  const DoctorVisitPlannerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Doctor Visit Planner',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
        useMaterial3: true,
      ),
      home: const _BootstrapScreen(),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  late Future<LlmModel?> _modelFuture;

  @override
  void initState() {
    super.initState();
    _modelFuture = _loadSelectedModel();
  }

  Future<LlmModel?> _loadSelectedModel() async {
    final selectedId = await ModelPreferences.getSelectedModel();
    if (selectedId == null) return null;
    for (final model in availableModels) {
      if (model.id == selectedId) {
        return model;
      }
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<LlmModel?>(
      future: _modelFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final selectedModel = snapshot.data;
        if (selectedModel == null) {
          return const ModelSetupScreen();
        }
        return VisitFormScreen(model: selectedModel);
      },
    );
  }
}
