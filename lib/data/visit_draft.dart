import 'visit_info.dart';

class VisitDraft {
  const VisitDraft({
    required this.visitInfo,
    this.existingFolderId,
    this.patientName,
    this.conditionName,
  }) : assert(
         (existingFolderId != null) ^
             (patientName != null && conditionName != null),
         'Provide either an existing folder ID or patient and condition names for a new folder.',
       );

  final VisitInfo visitInfo;
  final String? existingFolderId;
  final String? patientName;
  final String? conditionName;

  bool get isNewFolder => existingFolderId == null;
}
