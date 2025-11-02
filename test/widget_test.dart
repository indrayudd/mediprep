import 'package:doctor_visit_planner/main.dart';
import 'package:doctor_visit_planner/services/local_visit_store.dart';
import 'package:doctor_visit_planner/services/visit_repository.dart';
import 'package:doctor_visit_planner/data/visit_folder.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeVisitStore extends LocalVisitStore {
  _FakeVisitStore() : super(fileName: 'in_memory');

  List<VisitFolder> _folders = const [];

  @override
  Future<List<VisitFolder>> loadFolders() async {
    return _folders;
  }

  @override
  Future<void> saveFolders(List<VisitFolder> folders) async {
    _folders = List<VisitFolder>.from(folders);
  }
}

void main() {
  testWidgets('App builds', (tester) async {
    final repository = VisitRepository(_FakeVisitStore());
    await repository.load();
    await tester.pumpWidget(DoctorVisitPlannerApp(repository: repository));
    expect(find.byType(DoctorVisitPlannerApp), findsOneWidget);
  });
}
