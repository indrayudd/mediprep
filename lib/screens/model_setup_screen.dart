import 'package:flutter/material.dart';
import '../models/llm_model.dart';
import '../services/model_preferences.dart';
import '../services/model_service.dart';
import 'visit_form_screen.dart';

class ModelSetupScreen extends StatefulWidget {
  const ModelSetupScreen({super.key});

  @override
  State<ModelSetupScreen> createState() => _ModelSetupScreenState();
}

class _ModelSetupScreenState extends State<ModelSetupScreen> {
  final _service = const ModelService();
  final _installProgress = <String, double>{};
  final _installed = <String, bool>{};
  final _tokenController = TextEditingController();
  bool _obscureToken = true;
  bool _loadingStatus = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadStatuses();
  }

  @override
  void dispose() {
    _tokenController.dispose();
    super.dispose();
  }

  Future<void> _loadStatuses() async {
    setState(() {
      _loadingStatus = true;
      _error = null;
    });

    final savedToken = await ModelPreferences.getHfToken();
    if (mounted && savedToken != null && savedToken.isNotEmpty) {
      _tokenController.text = savedToken;
    }

    try {
      for (final model in availableModels) {
        final installed = await _service.isModelInstalled(model);
        _installed[model.id] = installed;
      }
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _loadingStatus = false;
      });
    }
  }

  Future<void> _handleDownload(LlmModel model) async {
    setState(() {
      _error = null;
      _installProgress[model.id] = 0;
    });

    final token = _tokenController.text.trim();
    if (model.needsAuth && token.isEmpty) {
      setState(() {
        _error = 'This model requires a Hugging Face access token.';
        _installProgress.remove(model.id);
      });
      return;
    }

    if (token.isEmpty) {
      await ModelPreferences.clearHfToken();
    } else {
      await ModelPreferences.setHfToken(token);
    }

    var success = false;
    try {
      await _service.downloadModel(
        model,
        token: token.isEmpty ? null : token,
        onProgress: (progress) {
          setState(() {
            _installProgress[model.id] = progress;
          });
        },
      );
      success = true;
      await ModelPreferences.setSelectedModel(model.id);

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => VisitFormScreen(model: model)),
      );
    } catch (e) {
      setState(() {
        _error = e.toString();
      });
    } finally {
      setState(() {
        _installProgress.remove(model.id);
        _installed[model.id] = success;
      });
    }
  }

  Future<void> _handleUseModel(LlmModel model) async {
    await ModelPreferences.setSelectedModel(model.id);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => VisitFormScreen(model: model)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Choose a local model'),
      ),
      body: _loadingStatus
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Download a Gemma model to run fully on-device. You can change it later.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'If a model requires authentication, paste your Hugging Face access token below. It is stored locally on this device.',
                    style: TextStyle(fontSize: 13, color: Colors.black54),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _tokenController,
                    obscureText: _obscureToken,
                    decoration: InputDecoration(
                      labelText: 'Hugging Face token',
                      hintText: 'hf_xxx',
                      helperText: 'Leave blank for public models.',
                      suffixIcon: IconButton(
                        icon: Icon(_obscureToken ? Icons.visibility : Icons.visibility_off),
                        onPressed: () {
                          setState(() {
                            _obscureToken = !_obscureToken;
                          });
                        },
                      ),
                    ),
                  ),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton.icon(
                      onPressed: () async {
                        _tokenController.clear();
                        await ModelPreferences.clearHfToken();
                      },
                      icon: const Icon(Icons.clear),
                      label: const Text('Clear token'),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.red.shade50,
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Icon(Icons.error_outline, color: Colors.red),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              _error!,
                              style: const TextStyle(color: Colors.red),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  const SizedBox(height: 16),
                  Expanded(
                    child: ListView.separated(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      itemCount: availableModels.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final model = availableModels[index];
                        final installed = _installed[model.id] ?? false;
                        final progress = _installProgress[model.id];
                        return Card(
                          elevation: 2,
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  model.displayName,
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                                const SizedBox(height: 8),
                                Text(model.description),
                                const SizedBox(height: 8),
                                Text('Download size: ${model.sizeLabel}'),
                                if (model.licenseUrl != null) ...[
                                  const SizedBox(height: 4),
                                  Text(
                                    model.licenseUrl!,
                                    style: const TextStyle(
                                        fontSize: 12, color: Colors.blueAccent),
                                  ),
                                ],
                                const SizedBox(height: 12),
                                if (progress != null)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      LinearProgressIndicator(value: progress),
                                      const SizedBox(height: 6),
                                      Text('${(progress * 100).clamp(0, 100).toStringAsFixed(0)}%'),
                                    ],
                                  )
                                else
                                  Row(
                                    children: [
                                      ElevatedButton.icon(
                                        onPressed: installed
                                            ? () => _handleUseModel(model)
                                            : () => _handleDownload(model),
                                        icon: Icon(installed
                                            ? Icons.check_circle
                                            : Icons.download),
                                        label: Text(installed
                                            ? 'Use this model'
                                            : 'Download & use'),
                                      ),
                                      const SizedBox(width: 12),
                                      if (installed)
                                        const Text(
                                          'Installed',
                                          style: TextStyle(color: Colors.green),
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
