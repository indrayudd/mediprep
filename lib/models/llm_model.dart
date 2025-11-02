import 'package:flutter_gemma/core/model.dart';
import 'package:flutter_gemma/pigeon.g.dart';

class LlmModel {
  const LlmModel({
    required this.id,
    required this.displayName,
    required this.description,
    required this.url,
    required this.filename,
    required this.sizeLabel,
    required this.modelType,
    required this.preferredBackend,
    required this.maxTokens,
    this.fileType = ModelFileType.task,
    this.maxNumImages,
    this.temperature = 0.8,
    this.topK = 40,
    this.topP = 0.9,
    this.supportImage = false,
    this.supportsFunctionCalls = false,
    this.isThinking = false,
    this.needsAuth = false,
    this.licenseUrl,
  });

  final String id;
  final String displayName;
  final String description;
  final String url;
  final String filename;
  final String sizeLabel;
  final ModelType modelType;
  final PreferredBackend preferredBackend;
  final int maxTokens;
  final ModelFileType fileType;
  final int? maxNumImages;
  final double temperature;
  final int topK;
  final double topP;
  final bool supportImage;
  final bool supportsFunctionCalls;
  final bool isThinking;
  final bool needsAuth;
  final String? licenseUrl;
}

const availableModels = <LlmModel>[
  LlmModel(
    id: 'gemma3_1b',
    displayName: 'Gemma 3 1B (text only)',
    description:
        'Smaller text-focused Gemma 3 model. Great for quick setups and devices with tighter memory budgets.',
    url:
        'https://huggingface.co/litert-community/Gemma3-1B-IT/resolve/main/Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task',
    filename: 'Gemma3-1B-IT_multi-prefill-seq_q4_ekv2048.task',
    sizeLabel: '≈0.5 GB download',
    modelType: ModelType.gemmaIt,
    preferredBackend: PreferredBackend.gpu,
    maxTokens: 1024,
    supportsFunctionCalls: false,
    temperature: 0.8,
    topK: 64,
    topP: 0.95,
    needsAuth: true,
    licenseUrl: 'https://huggingface.co/litert-community/Gemma3-1B-IT',
  ),
];
