import 'package:flutter/foundation.dart';

import 'visit_record.dart';

@immutable
class VisitFolder {
  const VisitFolder({
    required this.id,
    required this.patientName,
    required this.conditionName,
    required this.primaryDoctor,
    required this.primaryHospital,
    required this.createdAt,
    required this.updatedAt,
    this.visits = const <VisitRecord>[],
  });

  final String id;
  final String patientName;
  final String conditionName;
  final String primaryDoctor;
  final String primaryHospital;
  final DateTime createdAt;
  final DateTime updatedAt;
  final List<VisitRecord> visits;

  VisitFolder copyWith({
    String? id,
    String? patientName,
    String? conditionName,
    String? primaryDoctor,
    String? primaryHospital,
    DateTime? createdAt,
    DateTime? updatedAt,
    List<VisitRecord>? visits,
  }) {
    return VisitFolder(
      id: id ?? this.id,
      patientName: patientName ?? this.patientName,
      conditionName: conditionName ?? this.conditionName,
      primaryDoctor: primaryDoctor ?? this.primaryDoctor,
      primaryHospital: primaryHospital ?? this.primaryHospital,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      visits: visits ?? this.visits,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'patientName': patientName,
      'conditionName': conditionName,
      'primaryDoctor': primaryDoctor,
      'primaryHospital': primaryHospital,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'visits': visits.map((visit) => visit.toMap()).toList(),
    };
  }

  static VisitFolder fromMap(Map<String, dynamic> map) {
    return VisitFolder(
      id: map['id'] as String,
      patientName: map['patientName'] as String? ?? '',
      conditionName: map['conditionName'] as String? ?? '',
      primaryDoctor: map['primaryDoctor'] as String? ?? '',
      primaryHospital: map['primaryHospital'] as String? ?? '',
      createdAt: DateTime.parse(map['createdAt'] as String),
      updatedAt: DateTime.parse(map['updatedAt'] as String),
      visits: (map['visits'] as List<dynamic>? ?? const [])
          .map((item) => VisitRecord.fromMap(item as Map<String, dynamic>))
          .toList(growable: false),
    );
  }
}
