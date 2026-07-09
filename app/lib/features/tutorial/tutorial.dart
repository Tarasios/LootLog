/// The first-use tour: a skippable, replayable walkthrough of DuoBudget's core
/// flows. It shows once automatically on a fresh device (via [TutorialGate]) and
/// can be replayed any time from Settings → Tutorial (via [TutorialTour.show]).
///
/// The tour is purely presentational — it explains the app, it never touches the
/// ledger. Its wording comes from [tutorialSteps], which reads the [Glossary],
/// so Classic and Adventure narrate the same tour in their own vocabulary.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../game/skin_prefs.dart';
import '../../ui/theme.dart';
import 'tutorial_content.dart';
import 'tutorial_prefs.dart';

export 'tutorial_content.dart';
export 'tutorial_prefs.dart';

/// Presents and marks the first-use tour.
abstract final class TutorialTour {
  /// Shows the tour as a dialog and records it as seen when it closes (whether
  /// finished or skipped). Safe to call from Settings for a replay.
  static Future<void> show(BuildContext context, WidgetRef ref) async {
    final isAdventure = ref.read(appSkinProvider) == AppSkin.adventure;
    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) => _TutorialDialog(
        steps: tutorialSteps(isAdventure: isAdventure),
      ),
    );
    await ref.read(tutorialSeenProvider.notifier).markSeen();
  }
}

/// Wraps [child] and shows the tour once, on the first run of a fresh device.
class TutorialGate extends ConsumerStatefulWidget {
  const TutorialGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<TutorialGate> createState() => _TutorialGateState();
}

class _TutorialGateState extends ConsumerState<TutorialGate> {
  bool _triggered = false;

  void _maybeTrigger(bool seen) {
    if (seen || _triggered) return;
    _triggered = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(TutorialTour.show(context, ref));
    });
  }

  @override
  Widget build(BuildContext context) {
    // React both to the value already resolved at first build and to the async
    // restore flipping it to not-seen on a fresh install.
    ref.listen<bool>(tutorialSeenProvider, (_, next) => _maybeTrigger(next));
    _maybeTrigger(ref.watch(tutorialSeenProvider));
    return widget.child;
  }
}

class _TutorialDialog extends StatefulWidget {
  const _TutorialDialog({required this.steps});

  final List<TutorialStep> steps;

  @override
  State<_TutorialDialog> createState() => _TutorialDialogState();
}

class _TutorialDialogState extends State<_TutorialDialog> {
  int _index = 0;

  bool get _isLast => _index == widget.steps.length - 1;

  void _next() {
    if (_isLast) {
      Navigator.of(context).pop();
    } else {
      setState(() => _index++);
    }
  }

  void _back() {
    if (_index > 0) setState(() => _index--);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final step = widget.steps[_index];
    return Dialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadii.sheet),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.xl),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  CircleAvatar(
                    backgroundColor: scheme.primaryContainer,
                    child: Icon(step.icon, color: scheme.onPrimaryContainer),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Skip'),
                  ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(
                step.title,
                style: Theme.of(context)
                    .textTheme
                    .headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                step.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: scheme.onSurfaceVariant,
                      height: 1.4,
                    ),
              ),
              const SizedBox(height: AppSpacing.xl),
              _Dots(count: widget.steps.length, index: _index),
              const SizedBox(height: AppSpacing.lg),
              Row(
                children: [
                  if (_index > 0)
                    TextButton(
                      onPressed: _back,
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _next,
                    child: Text(_isLast ? 'Done' : 'Next'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          Container(
            width: 8,
            height: 8,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i == index ? scheme.primary : scheme.surfaceContainerHighest,
            ),
          ),
      ],
    );
  }
}
