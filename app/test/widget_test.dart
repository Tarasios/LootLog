import 'package:duobudget/data/providers.dart';
import 'package:duobudget/main.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('an unconfigured device boots into first-run setup',
      (tester) async {
    // Drive the setup pointer directly (a plain value stream, no drift timers)
    // so the boot routing is exercised without a live database in the test.
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          localSetupProvider.overrideWith((ref) => Stream.value(null)),
        ],
        child: const DuoBudgetApp(),
      ),
    );
    await tester.pump();
    await tester.pump();

    expect(find.text('Welcome to DuoBudget'), findsOneWidget);
    expect(find.text('Start budgeting'), findsOneWidget);
  });
}
