import 'package:flutter/foundation.dart';

import 'attachment.dart';
import 'question_note.dart';
import 'recording_meta.dart';

@immutable
class VisitRecord {
  const VisitRecord({
    required this.id,
    required this.title,
    required this.visitDate,
    required this.description,
    required this.questions,
    this.attachments = const <VisitAttachment>[],
    this.recordings = const <RecordingMeta>[],
    this.createdAt,
    this.updatedAt,
  });

  final String id;
  final String title;
  final DateTime visitDate;
  final String description;
  final List<QuestionNote> questions;
  final List<VisitAttachment> attachments;
  final List<RecordingMeta> recordings;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VisitRecord copyWith({
    String? id,
    String? title,
    DateTime? visitDate,
    String? description,
    List<QuestionNote>? questions,
    List<VisitAttachment>? attachments,
    List<RecordingMeta>? recordings,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VisitRecord(
      id: id ?? this.id,
      title: title ?? this.title,
      visitDate: visitDate ?? this.visitDate,
      description: description ?? this.description,
      questions: questions ?? this.questions,
      attachments: attachments ?? this.attachments,
      recordings: recordings ?? this.recordings,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'visitDate': visitDate.toIso8601String(),
      'description': description,
      'questions': questions.map((e) => e.toMap()).toList(),
      'attachments': attachments.map((e) => e.toMap()).toList(),
      'recordings': recordings.map((e) => e.toMap()).toList(),
      'createdAt': createdAt?.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  static VisitRecord fromMap(Map<String, dynamic> map) {
    return VisitRecord(
      id: map['id'] as String,
      title: map['title'] as String? ?? '',
      visitDate: DateTime.parse(map['visitDate'] as String),
      description: map['description'] as String? ?? '',
      questions: (map['questions'] as List<dynamic>? ?? const [])
          .map((item) => QuestionNote.fromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      attachments: (map['attachments'] as List<dynamic>? ?? const [])
          .map((item) => VisitAttachment.fromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      recordings: (map['recordings'] as List<dynamic>? ?? const [])
          .map((item) => RecordingMeta.fromMap(item as Map<String, dynamic>))
          .toList(growable: false),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'] as String)
          : null,
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'] as String)
          : null,
    );
  }
}
