import 'package:flutter_gemma/flutter_gemma.dart';

import '../models/llm_model.dart';
import 'model_preferences.dart';

bool _flutterGemmaInitialized = false;

class ModelService {
  const ModelService();

  Future<bool> isModelInstalled(LlmModel model) {
    return FlutterGemma.isModelInstalled(model.filename);
  }

  Future<void> downloadModel(
    LlmModel model, {
    String? token,
    void Function(double progress)? onProgress,
  }) async {
    final trimmedToken = token?.trim() ?? '';
    if (model.needsAuth && trimmedToken.isEmpty) {
      throw StateError(
        'This model requires a Hugging Face access token. Please provide it above.',
      );
    }

    await _ensureInitialized(trimmedToken.isEmpty ? null : trimmedToken);

    final installer = FlutterGemma.installModel(
      modelType: model.modelType,
      fileType: model.fileType,
    ).fromNetwork(model.url, token: trimmedToken.isEmpty ? null : trimmedToken);

    final installerWithProgress = installer.withProgress((progress) {
      onProgress?.call(progress.toDouble() / 100.0);
    });

    await installerWithProgress.install();
  }

  Future<InferenceChat> createChat(LlmModel model) async {
    await _ensureActiveModel(model);

    final inferenceModel = await FlutterGemma.getActiveModel(
      maxTokens: model.maxTokens,
      preferredBackend: model.preferredBackend,
      supportImage: model.supportImage,
      maxNumImages: model.maxNumImages,
    );

    final tokenBuffer = (model.maxTokens ~/ 12).clamp(32, 160);

    return inferenceModel.createChat(
      temperature: model.temperature,
      randomSeed: 1,
      topK: model.topK,
      topP: model.topP,
      tokenBuffer: tokenBuffer,
      supportImage: model.supportImage,
      supportsFunctionCalls: model.supportsFunctionCalls,
      isThinking: model.isThinking,
      modelType: model.modelType,
    );
  }

  Future<void> _ensureActiveModel(LlmModel model) async {
    final manager = FlutterGemmaPlugin.instance.modelManager;
    final active = manager.activeInferenceModel;
    final expectedFilename = model.filename;
    final matchesActive =
        active is InferenceModelSpec &&
        active.files.any((file) => file.filename == expectedFilename);

    if (matchesActive) {
      return;
    }

    final savedToken = await ModelPreferences.getHfToken();
    final trimmedToken = savedToken?.trim() ?? '';

    if (model.needsAuth && trimmedToken.isEmpty) {
      throw StateError(
        'This model requires a Hugging Face access token. Please add it on the setup screen.',
      );
    }

    await _ensureInitialized(trimmedToken.isEmpty ? null : trimmedToken);

    await FlutterGemma.installModel(
          modelType: model.modelType,
          fileType: model.fileType,
        )
        .fromNetwork(
          model.url,
          token: trimmedToken.isEmpty ? null : trimmedToken,
        )
        .install();
  }

  Future<void> _ensureInitialized(String? token) async {
    if (_flutterGemmaInitialized) {
      return;
    }
    FlutterGemma.initialize(huggingFaceToken: token, maxDownloadRetries: 6);
    _flutterGemmaInitialized = true;
  }
}
