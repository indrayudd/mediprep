import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_gemma/flutter_gemma.dart';
import 'package:intl/intl.dart';

import '../data/visit_info.dart';
import '../models/llm_model.dart';
import '../services/model_service.dart';

class QuestionGenerationScreen extends StatefulWidget {
  const QuestionGenerationScreen({
    super.key,
    required this.model,
    required this.visitInfo,
  });

  final LlmModel model;
  final VisitInfo visitInfo;

  @override
  State<QuestionGenerationScreen> createState() =>
      _QuestionGenerationScreenState();
}

class _QuestionGenerationScreenState extends State<QuestionGenerationScreen> {
  final _modelService = const ModelService();
  StreamSubscription<ModelResponse>? _subscription;
  String _streamedText = '';
  bool _isGenerating = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _startGeneration();
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }

  Future<void> _startGeneration() async {
    setState(() {
      _isGenerating = true;
      _error = null;
      _streamedText = '';
    });

    try {
      final chat = await _modelService.createChat(widget.model);
      final prompt = _buildPrompt(widget.visitInfo);
      await chat.addQuery(Message(text: prompt, isUser: true));
      final stream = chat.generateChatResponseAsync();
      _subscription = stream.listen(
        (response) {
          if (response is TextResponse) {
            setState(() {
              _streamedText += response.token;
            });
          }
        },
        onError: (error) {
          setState(() {
            _error = error.toString();
            _isGenerating = false;
          });
        },
        onDone: () {
          setState(() {
            _isGenerating = false;
          });
        },
      );
    } on PlatformException catch (e) {
      setState(() {
        _error = _mapPlatformError(e);
        _isGenerating = false;
      });
    } on StateError catch (e) {
      setState(() {
        _error = e.message ?? e.toString();
        _isGenerating = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isGenerating = false;
      });
    }
  }

  String _buildPrompt(VisitInfo info) {
    final formattedDate = DateFormat.yMMMMd().format(info.visitDate);
    return '''You are a helpful medical assistant preparing a patient for an upcoming appointment. Using the details provided, craft exactly five succinct questions the patient should ask the doctor. Each question should be actionable, specific, and reflect the patient's concerns.

VISIT DETAILS:
- Visit name: ${info.visitName}
- Visit date: $formattedDate
- Doctor: ${info.doctorName}
- Hospital/Clinic: ${info.hospitalName}
- Patient notes: ${info.description}

Guidelines:
- Return ONLY the questions as a numbered list from 1 to 5.
- Avoid introductions or closing remarks.
- Make sure the questions feel natural for a patient preparing for this visit.
''';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final questions = _parseQuestions(_streamedText);

    return Scaffold(
      appBar: AppBar(title: const Text('Discussion guide')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Questions to ask during "${widget.visitInfo.visitName}"',
              style: theme.textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (_error != null)
              Expanded(
                child: Center(
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                    textAlign: TextAlign.center,
                  ),
                ),
              )
            else if (questions.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isGenerating)
                        const CircularProgressIndicator()
                      else
                        const Icon(Icons.info_outline, size: 48),
                      const SizedBox(height: 16),
                      Text(
                        _isGenerating
                            ? 'Generating questions…'
                            : 'Waiting for the model output…',
                        textAlign: TextAlign.center,
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.separated(
                  itemCount: questions.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final text = questions[index];
                    final isFinal =
                        !_isGenerating && index == questions.length - 1;
                    return AnimatedOpacity(
                      opacity: 1,
                      duration: const Duration(milliseconds: 200),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${index + 1}. ',
                              style: theme.textTheme.titleMedium,
                            ),
                            Expanded(
                              child: Text(
                                text,
                                style: theme.textTheme.bodyLarge,
                              ),
                            ),
                            if (_isGenerating && index == questions.length - 1)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                ),
                              ),
                            if (!_isGenerating && isFinal)
                              const Padding(
                                padding: EdgeInsets.only(left: 8),
                                child: Icon(
                                  Icons.check_circle,
                                  color: Colors.green,
                                ),
                              ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            const SizedBox(height: 16),
            Row(
              children: [
                ElevatedButton.icon(
                  onPressed: _isGenerating ? null : _startGeneration,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Regenerate'),
                ),
                const SizedBox(width: 12),
                Text(
                  _isGenerating ? 'Streaming response…' : 'Generation complete',
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  List<String> _parseQuestions(String rawText) {
    final lines = rawText
        .split(RegExp(r'\n|\r'))
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();

    final result = <String>[];
    for (final line in lines) {
      if (line.contains('[tool_response]')) {
        continue;
      }
      final match = RegExp(r'^(?:\d+\.\s*)(.*)$').firstMatch(line);
      if (match != null) {
        final question = match.group(1)?.trim();
        if (question != null && question.isNotEmpty) {
          result.add(question);
        }
      } else if (result.isNotEmpty) {
        final last = result.removeLast();
        final merged = '$last ${line.replaceFirst(RegExp(r'^[-•]'), '').trim()}'
            .trim();
        result.add(merged);
      }
    }

    // If the model hasn't numbered yet, attempt to split by hyphen/bullet
    if (result.isEmpty && lines.isNotEmpty) {
      for (final line in lines) {
        final cleaned = line.replaceFirst(RegExp(r'^[-•]'), '').trim();
        if (cleaned.isNotEmpty) {
          result.add(cleaned);
        }
      }
    }

    if (result.length > 5) {
      return result.take(5).toList();
    }
    return result;
  }

  String _mapPlatformError(PlatformException exception) {
    final message = exception.message ?? exception.toString();
    if (message.contains('Cannot allocate memory')) {
      return 'The selected model could not be loaded because the device ran out of memory. '
          'Try switching to the smaller Gemma 3 270M model from the setup screen, then retry.';
    }
    return 'Failed to start the model (${exception.code}): $message';
  }
}
