part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Step 3 — income
// ---------------------------------------------------------------------------

class _IncomeStep extends StatelessWidget {
  const _IncomeStep({required this.controller});
  final SetupController controller;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Set each adult\'s usual monthly income. It carries forward every '
          'month until you change it. Zero is fine — enter it and move on.',
        ),
        for (final adult in controller.adults)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            child: _MoneyField(
              label: '${adult.name}\'s monthly income',
              cents: controller.incomeOf(adult.localId),
              onChanged: (value) => controller.setIncome(adult.localId, value),
            ),
          ),
      ],
    );
  }
}
