import 'package:flutter_test/flutter_test.dart';

import 'package:doctor_visit_planner/main.dart';

void main() {
  testWidgets('App builds', (tester) async {
    await tester.pumpWidget(const DoctorVisitPlannerApp());
    expect(find.byType(DoctorVisitPlannerApp), findsOneWidget);
  });
}
