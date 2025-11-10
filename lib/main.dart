import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'models/llm_model.dart';
import 'screens/home_screen.dart';
import 'screens/model_setup_screen.dart';
import 'services/local_visit_store.dart';
import 'services/model_preferences.dart';
import 'services/visit_repository.dart';
import 'theme/app_theme.dart';
import 'widgets/recording_overlay.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final repository = VisitRepository(LocalVisitStore());
  await repository.load();
  runApp(DoctorVisitPlannerApp(repository: repository));
}

class DoctorVisitPlannerApp extends StatelessWidget {
  const DoctorVisitPlannerApp({super.key, required this.repository});

  final VisitRepository repository;
  static final GlobalKey<NavigatorState> navigatorKey =
      GlobalKey<NavigatorState>();
  static final GlobalKey<ScaffoldMessengerState> scaffoldMessengerKey =
      GlobalKey<ScaffoldMessengerState>();

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: repository),
        ChangeNotifierProvider(
          create: (_) => RecordingOverlayController(
            navigatorKey,
            scaffoldMessengerKey,
          ),
        ),
      ],
      child: MaterialApp(
        title: 'MediPrep',
        theme: AppTheme.build(),
        navigatorKey: navigatorKey,
        scaffoldMessengerKey: scaffoldMessengerKey,
        builder: (context, child) => RecordingOverlayHost(
          child: child ?? const SizedBox.shrink(),
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
