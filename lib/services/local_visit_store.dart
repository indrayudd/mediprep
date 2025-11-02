import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../data/visit_folder.dart';

class LocalVisitStore {
  LocalVisitStore({this.fileName = 'medi_prep_data.json'});

  final String fileName;

  Future<File> _resolveFile() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = p.join(directory.path, fileName);
    return File(path);
  }

  Future<List<VisitFolder>> loadFolders() async {
    try {
      final file = await _resolveFile();
      if (!await file.exists()) {
        return const <VisitFolder>[];
      }
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) {
        return const <VisitFolder>[];
      }
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final folders = (decoded['folders'] as List<dynamic>? ?? const [])
          .map((item) => VisitFolder.fromMap(item as Map<String, dynamic>))
          .toList();
      return folders;
    } catch (error) {
      stderr.writeln('Failed to load visit data: $error');
      return const <VisitFolder>[];
    }
  }

  Future<void> saveFolders(List<VisitFolder> folders) async {
    final file = await _resolveFile();
    final payload = jsonEncode({
      'folders': folders.map((folder) => folder.toMap()).toList(),
      'timestamp': DateTime.now().toIso8601String(),
    });
    await file.writeAsString(payload);
  }
}
