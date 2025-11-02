import 'dart:io';

import 'package:mime/mime.dart';
import 'package:path/path.dart' as p;

enum AttachmentType { image, pdf, other }

class VisitAttachment {
  const VisitAttachment({
    required this.path,
    required this.name,
    required this.type,
    this.mimeType,
  });

  final String path;
  final String name;
  final AttachmentType type;
  final String? mimeType;

  bool get exists => File(path).existsSync();

  VisitAttachment copyWith({
    String? path,
    String? name,
    AttachmentType? type,
    String? mimeType,
  }) {
    return VisitAttachment(
      path: path ?? this.path,
      name: name ?? this.name,
      type: type ?? this.type,
      mimeType: mimeType ?? this.mimeType,
    );
  }

  static AttachmentType inferTypeFromMime(String? mime, String? extension) {
    final lowerMime = mime?.toLowerCase() ?? '';
    if (lowerMime.startsWith('image/')) {
      return AttachmentType.image;
    }
    if (lowerMime == 'application/pdf' || extension?.toLowerCase() == 'pdf') {
      return AttachmentType.pdf;
    }
    return AttachmentType.other;
  }

  static VisitAttachment fromPath(String path) {
    final name = p.basename(path);
    final mime = lookupMimeType(path);
    final ext = p.extension(path).replaceFirst('.', '');
    final type = inferTypeFromMime(mime, ext.isEmpty ? null : ext);
    return VisitAttachment(path: path, name: name, type: type, mimeType: mime);
  }

  Map<String, dynamic> toMap() {
    return {
      'path': path,
      'name': name,
      'type': type.name,
      'mimeType': mimeType,
    };
  }

  static VisitAttachment fromMap(Map<String, dynamic> map) {
    final typeName = map['type'] as String? ?? AttachmentType.other.name;
    return VisitAttachment(
      path: map['path'] as String? ?? '',
      name: map['name'] as String? ?? '',
      type: AttachmentType.values.firstWhere(
        (value) => value.name == typeName,
        orElse: () => AttachmentType.other,
      ),
      mimeType: map['mimeType'] as String?,
    );
  }
}
