import 'package:flutter/foundation.dart';

@immutable
class RecordingMeta {
  const RecordingMeta({
    required this.id,
    required this.filePath,
    required this.createdAt,
    required this.durationSeconds,
    this.displayName,
  });

  final String id;
  final String filePath;
  final DateTime createdAt;
  final int durationSeconds;
  final String? displayName;

  RecordingMeta copyWith({
    String? id,
    String? filePath,
    DateTime? createdAt,
    int? durationSeconds,
    String? displayName,
  }) {
    return RecordingMeta(
      id: id ?? this.id,
      filePath: filePath ?? this.filePath,
      createdAt: createdAt ?? this.createdAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      displayName: displayName ?? this.displayName,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'filePath': filePath,
      'createdAt': createdAt.toIso8601String(),
      'durationSeconds': durationSeconds,
      'displayName': displayName,
    };
  }

  static RecordingMeta fromMap(Map<String, dynamic> map) {
    return RecordingMeta(
      id: map['id'] as String,
      filePath: map['filePath'] as String,
      createdAt: DateTime.parse(map['createdAt'] as String),
      durationSeconds: map['durationSeconds'] as int? ?? 0,
      displayName: map['displayName'] as String?,
    );
  }
}
