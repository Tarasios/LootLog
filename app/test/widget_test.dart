import 'package:duobudget/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app boots and shows its name', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: DuoBudgetApp()));

    expect(find.text('DuoBudget'), findsWidgets);
  });
}
