import 'package:flutter/foundation.dart';

@immutable
class QuestionNote {
  const QuestionNote({
    required this.id,
    required this.text,
    required this.createdAt,
    this.answer,
    this.isCustom = false,
  });

  final String id;
  final String text;
  final DateTime createdAt;
  final String? answer;
  final bool isCustom;

  QuestionNote copyWith({
    String? id,
    String? text,
    DateTime? createdAt,
    String? answer,
    bool? isCustom,
  }) {
    return QuestionNote(
      id: id ?? this.id,
      text: text ?? this.text,
      createdAt: createdAt ?? this.createdAt,
      answer: answer ?? this.answer,
      isCustom: isCustom ?? this.isCustom,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'text': text,
      'createdAt': createdAt.toIso8601String(),
      'answer': answer,
      'isCustom': isCustom,
    };
  }

  static QuestionNote fromMap(Map<String, dynamic> map) {
    return QuestionNote(
      id: map['id'] as String,
      text: map['text'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      answer: map['answer'] as String?,
      isCustom: map['isCustom'] as bool? ?? false,
    );
  }
}
