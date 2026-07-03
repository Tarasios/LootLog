import 'package:duobudget/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app shell builds and shows its title', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const DuoBudgetApp());

    expect(find.text('DuoBudget'), findsOneWidget);
    expect(find.text('Setup complete.'), findsOneWidget);
  });
}
