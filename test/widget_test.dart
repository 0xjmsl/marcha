import 'package:flutter_test/flutter_test.dart';
import 'package:marcha/app.dart';

void main() {
  testWidgets('App launches smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MarchaApp());
    expect(find.text('Home'), findsOneWidget);
  });
}
