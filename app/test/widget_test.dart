import 'package:flutter_test/flutter_test.dart';
import 'package:dokonpro/app.dart';

void main() {
  testWidgets('App smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const DokonProApp());
    expect(find.text('DokonPro'), findsAny);
  });
}
