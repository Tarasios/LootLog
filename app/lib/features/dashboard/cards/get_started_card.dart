part of '../dashboard_view.dart';

/// The new-household empty state: a warm, single-call-to-action card shown when
/// no budgets or quests exist yet.
class _GetStartedCard extends StatelessWidget {
  const _GetStartedCard({this.onGetStarted});

  final VoidCallback? onGetStarted;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return AppCard(
      color: scheme.primaryContainer,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.rocket_launch_outlined, color: scheme.onPrimaryContainer),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Welcome to your household',
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: scheme.onPrimaryContainer,
                        fontWeight: FontWeight.w700,
                      ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Start by carving your monthly budget into categories — one each for '
            'the household’s adults, plus shared ones like groceries. Everything '
            'else (savings goals, shared savings, receipts) builds from there.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: scheme.onPrimaryContainer,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.icon(
            onPressed: onGetStarted,
            icon: const Icon(Icons.tune),
            label: const Text('Set up budgets'),
          ),
        ],
      ),
    );
  }
}
