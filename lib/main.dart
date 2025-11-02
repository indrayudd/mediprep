import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/llm_model.dart';
import 'screens/home_screen.dart';
import 'screens/model_setup_screen.dart';
import 'services/local_visit_store.dart';
import 'services/model_preferences.dart';
import 'services/visit_repository.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = VisitRepository(LocalVisitStore());
  await repository.load();
  runApp(DoctorVisitPlannerApp(repository: repository));
}

class DoctorVisitPlannerApp extends StatelessWidget {
  const DoctorVisitPlannerApp({super.key, required this.repository});

  final VisitRepository repository;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: repository,
      child: MaterialApp(
        title: 'MediPrep',
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: Colors.teal),
          useMaterial3: true,
          scaffoldBackgroundColor: const Color(0xFFF7F9FB),
          appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
          inputDecorationTheme: const InputDecorationTheme(
            border: OutlineInputBorder(
              borderRadius: BorderRadius.all(Radius.circular(16)),
            ),
          ),
        ),
        home: const _BootstrapScreen(),
      ),
    );
  }
}

class _BootstrapScreen extends StatefulWidget {
  const _BootstrapScreen();

  @override
  State<_BootstrapScreen> createState() => _BootstrapScreenState();
}

class _BootstrapScreenState extends State<_BootstrapScreen> {
  LlmModel? _selectedModel;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    unawaited(_hydrateModel());
  }

  Future<void> _hydrateModel() async {
    final model = await _loadSelectedModel();
    if (!mounted) return;
    setState(() {
      _selectedModel = model;
      _loading = false;
    });
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

  Future<void> _showModelSetup() async {
    final result = await Navigator.of(context).push<LlmModel>(
      MaterialPageRoute(
        builder: (_) => ModelSetupScreen(
          onModelSelected: (model) {
            Navigator.of(context).pop(model);
          },
        ),
      ),
    );
    if (result != null) {
      setState(() {
        _selectedModel = result;
      });
    }
  }

  void _handleModelSelected(LlmModel model) {
    setState(() {
      _selectedModel = model;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (_selectedModel == null) {
      return ModelSetupScreen(onModelSelected: _handleModelSelected);
    }

    return HomeScreen(model: _selectedModel!, onChangeModel: _showModelSetup);
  }
}
