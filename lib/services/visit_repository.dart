import 'dart:async';

import 'package:flutter/foundation.dart';

import '../data/question_note.dart';
import '../data/recording_meta.dart';
import '../data/visit_folder.dart';
import '../data/visit_record.dart';
import 'local_visit_store.dart';

class VisitRepository extends ChangeNotifier {
  VisitRepository(this._store);

  final LocalVisitStore _store;
  var _folders = <VisitFolder>[];
  bool _isInitialized = false;
  bool _loading = false;
  Object? _lastError;

  List<VisitFolder> get folders => List.unmodifiable(_folders);
  bool get isInitialized => _isInitialized;
  bool get isLoading => _loading;
  Object? get lastError => _lastError;

  Future<void> load() async {
    if (_loading) return;
    _loading = true;
    notifyListeners();
    try {
      _folders = await _store.loadFolders();
      _folders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
      _lastError = null;
    } catch (error) {
      _lastError = error;
    } finally {
      _loading = false;
      _isInitialized = true;
      notifyListeners();
    }
  }

  Future<void> _persist() async {
    unawaited(_store.saveFolders(_folders));
  }

  VisitFolder? getFolderById(String id) {
    try {
      return _folders.firstWhere((folder) => folder.id == id);
    } catch (_) {
      return null;
    }
  }

  VisitRecord? getVisitById(String folderId, String visitId) {
    final folder = getFolderById(folderId);
    if (folder == null) return null;
    try {
      return folder.visits.firstWhere((visit) => visit.id == visitId);
    } catch (_) {
      return null;
    }
  }

  Future<VisitFolder> upsertFolder(VisitFolder folder) async {
    final index = _folders.indexWhere((item) => item.id == folder.id);
    if (index >= 0) {
      final updated = folder.copyWith(updatedAt: DateTime.now());
      _folders[index] = updated;
    } else {
      _folders = [..._folders, folder.copyWith(updatedAt: DateTime.now())];
    }
    _folders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    await _persist();
    return folder;
  }

  Future<VisitFolder> createFolder({
    required String id,
    required String patientName,
    required String conditionName,
    required String doctorName,
    required String hospitalName,
  }) async {
    final now = DateTime.now();
    final folder = VisitFolder(
      id: id,
      patientName: patientName,
      conditionName: conditionName,
      primaryDoctor: doctorName,
      primaryHospital: hospitalName,
      createdAt: now,
      updatedAt: now,
      visits: const [],
    );
    _folders = [..._folders, folder];
    _folders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    await _persist();
    return folder;
  }

  Future<VisitRecord> addVisit({
    required String folderId,
    required VisitRecord visit,
  }) async {
    final index = _folders.indexWhere((folder) => folder.id == folderId);
    if (index == -1) {
      throw StateError('Folder $folderId not found');
    }
    final folder = _folders[index];
    final updatedVisits = [
      ...folder.visits.where((item) => item.id != visit.id),
      visit.copyWith(
        createdAt: visit.createdAt ?? DateTime.now(),
        updatedAt: visit.updatedAt ?? DateTime.now(),
      ),
    ]..sort((a, b) => b.visitDate.compareTo(a.visitDate));

    final updatedFolder = folder.copyWith(
      visits: updatedVisits,
      updatedAt: DateTime.now(),
    );
    _folders[index] = updatedFolder;
    _folders.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    notifyListeners();
    await _persist();
    return visit;
  }

  Future<void> updateQuestions({
    required String folderId,
    required String visitId,
    required List<QuestionNote> questions,
  }) async {
    final folderIndex = _folders.indexWhere((item) => item.id == folderId);
    if (folderIndex == -1) {
      throw StateError('Folder $folderId not found');
    }
    final visitIndex = _folders[folderIndex].visits.indexWhere(
      (item) => item.id == visitId,
    );
    if (visitIndex == -1) {
      throw StateError('Visit $visitId not found');
    }
    final visit = _folders[folderIndex].visits[visitIndex];
    final updatedVisit = visit.copyWith(
      questions: List.unmodifiable(questions),
      updatedAt: DateTime.now(),
    );
    final visits = [..._folders[folderIndex].visits];
    visits[visitIndex] = updatedVisit;
    visits.sort((a, b) => b.visitDate.compareTo(a.visitDate));
    _folders[folderIndex] = _folders[folderIndex].copyWith(
      visits: visits,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persist();
  }

  Future<void> addRecording({
    required String folderId,
    required String visitId,
    required RecordingMeta recording,
  }) async {
    final folderIndex = _folders.indexWhere((item) => item.id == folderId);
    if (folderIndex == -1) {
      throw StateError('Folder $folderId not found');
    }
    final visits = [..._folders[folderIndex].visits];
    final visitIndex = visits.indexWhere((item) => item.id == visitId);
    if (visitIndex == -1) {
      throw StateError('Visit $visitId not found');
    }
    final visit = visits[visitIndex];
    final recordings = [
      ...visit.recordings.where((item) => item.id != recording.id),
      recording,
    ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    visits[visitIndex] = visit.copyWith(
      recordings: recordings,
      updatedAt: DateTime.now(),
    );
    _folders[folderIndex] = _folders[folderIndex].copyWith(
      visits: visits,
      updatedAt: DateTime.now(),
    );
    notifyListeners();
    await _persist();
  }
}
