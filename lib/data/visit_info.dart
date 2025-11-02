import 'attachment.dart';

class VisitInfo {
  const VisitInfo({
    required this.visitName,
    required this.visitDate,
    required this.doctorName,
    required this.hospitalName,
    required this.description,
    this.attachments = const <VisitAttachment>[],
  });

  final String visitName;
  final DateTime visitDate;
  final String doctorName;
  final String hospitalName;
  final String description;
  final List<VisitAttachment> attachments;
}
