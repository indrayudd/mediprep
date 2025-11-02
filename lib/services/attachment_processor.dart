import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:google_mlkit_image_labeling/google_mlkit_image_labeling.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:pdf_render/pdf_render.dart';

import '../data/attachment.dart';

class AttachmentContextDetail {
  AttachmentContextDetail({
    required this.attachment,
    this.extractedText,
    this.labels = const <String>[],
  });

  final VisitAttachment attachment;
  final String? extractedText;
  final List<String> labels;

  String toPromptSnippet({int textLimit = 600}) {
    final buffer = StringBuffer()
      ..writeln('File: ${attachment.name}')
      ..writeln('Type: ${attachment.type.name}');
    if (extractedText != null && extractedText!.trim().isNotEmpty) {
      buffer.writeln(
        'Extracted text: ${_trimAndLimit(extractedText!, textLimit)}',
      );
    }
    if (labels.isNotEmpty) {
      buffer.writeln('Detected concepts: ${labels.join(', ')}');
    }
    return buffer.toString().trim();
  }
}

class AttachmentProcessingResult {
  AttachmentProcessingResult({required this.details});

  final List<AttachmentContextDetail> details;

  String buildPromptSection() {
    if (details.isEmpty) {
      return '';
    }
    final parts = details
        .map((detail) => detail.toPromptSnippet())
        .where((snippet) => snippet.isNotEmpty)
        .toList();
    if (parts.isEmpty) {
      return '';
    }
    return [
      'ATTACHMENT CONTEXT (summarised for the model):',
      ...parts.map((p) => '- $p'),
    ].join('\n');
  }
}

class AttachmentProcessor {
  const AttachmentProcessor();

  Future<AttachmentProcessingResult> process(
    List<VisitAttachment> attachments,
  ) async {
    if (attachments.isEmpty) {
      return AttachmentProcessingResult(details: const []);
    }

    final details = <AttachmentContextDetail>[];
    TextRecognizer? recognizer;
    ImageLabeler? labeler;

    try {
      for (final attachment in attachments) {
        if (!attachment.exists) {
          continue;
        }

        switch (attachment.type) {
          case AttachmentType.image:
            recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
            labeler ??= ImageLabeler(
              options: ImageLabelerOptions(confidenceThreshold: 0.45),
            );
            final text = await _extractImageText(recognizer, attachment);
            final labels = await _extractImageLabels(labeler, attachment);
            details.add(
              AttachmentContextDetail(
                attachment: attachment,
                extractedText: text,
                labels: labels,
              ),
            );
            break;
          case AttachmentType.pdf:
            recognizer ??= TextRecognizer(script: TextRecognitionScript.latin);
            final pdfText = await _extractPdfText(recognizer, attachment);
            details.add(
              AttachmentContextDetail(
                attachment: attachment,
                extractedText: pdfText,
              ),
            );
            break;
          case AttachmentType.other:
            details.add(
              AttachmentContextDetail(
                attachment: attachment,
                extractedText: null,
              ),
            );
            break;
        }
      }
    } finally {
      await recognizer?.close();
      await labeler?.close();
    }

    return AttachmentProcessingResult(details: details);
  }

  Future<String?> _extractImageText(
    TextRecognizer recognizer,
    VisitAttachment attachment,
  ) async {
    final inputImage = InputImage.fromFilePath(attachment.path);
    final result = await recognizer.processImage(inputImage);
    final text = result.text.trim();
    if (text.isEmpty) {
      return null;
    }
    return text;
  }

  Future<List<String>> _extractImageLabels(
    ImageLabeler labeler,
    VisitAttachment attachment,
  ) async {
    final inputImage = InputImage.fromFilePath(attachment.path);
    final labels = await labeler.processImage(inputImage);
    return labels
        .where((label) => label.confidence >= 0.4)
        .map((label) => label.label)
        .toSet()
        .toList();
  }

  Future<String?> _extractPdfText(
    TextRecognizer recognizer,
    VisitAttachment attachment,
  ) async {
    try {
      final document = await PdfDocument.openFile(attachment.path);
      final pageCount = document.pageCount;
      if (pageCount == 0) {
        await document.dispose();
        return null;
      }

      final buffer = StringBuffer();
      final tempDir = await getTemporaryDirectory();
      final baseName = p.basenameWithoutExtension(attachment.path);
      final pagesToProcess = math.min(pageCount, 3);

      for (var index = 1; index <= pagesToProcess; index++) {
        final page = await document.getPage(index);
        final pageImage = await page.render(
          width: 1600,
          height: (1600 * page.height / page.width).round(),
          backgroundFill: true,
        );

        final uiImage = await pageImage.createImageIfNotAvailable();
        final byteData = await uiImage.toByteData(
          format: ui.ImageByteFormat.png,
        );
        pageImage.dispose();
        if (byteData == null) {
          continue;
        }

        final pagePath = p.join(tempDir.path, '${baseName}_page_$index.png');
        final imageFile = File(pagePath);
        await imageFile.writeAsBytes(
          byteData.buffer.asUint8List(),
          flush: true,
        );

        final inputImage = InputImage.fromFilePath(pagePath);
        final result = await recognizer.processImage(inputImage);
        final text = result.text.trim();
        if (text.isNotEmpty) {
          buffer.writeln(text);
        }

        await imageFile.delete().catchError((_) => imageFile);
      }

      await document.dispose();

      final combined = buffer.toString().trim();
      if (combined.isEmpty) {
        return null;
      }
      return _trimAndLimit(combined, 1200);
    } catch (_) {
      return null;
    }
  }
}

String _trimAndLimit(String value, int maxCharacters) {
  final cleaned = value.replaceAll(RegExp(r'\s+'), ' ').trim();
  if (cleaned.length <= maxCharacters) {
    return cleaned;
  }
  return '${cleaned.substring(0, maxCharacters)}…';
}
