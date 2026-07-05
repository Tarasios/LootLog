/// Quests (savings-goal monsters): a list of goals with progress, a detail view
/// with contribution and purchase history, a create/edit editor, and an abandon
/// flow whose confirmation states the exact dissolution tithe and per-funder
/// returns before anything is appended.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/format.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import '../shared/sprite_picker.dart';
import 'quests_model.dart';

class QuestsScreen extends ConsumerWidget {
  const QuestsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final names = ref.watch(userNamesProvider);
    if (state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final quests = state.quests.values.toList()
      ..sort((a, b) {
        // Active first, then completed, then abandoned; name within.
        int rank(QuestState q) => q.abandoned ? 2 : (q.completed ? 1 : 0);
        final r = rank(a).compareTo(rank(b));
        return r != 0 ? r : a.name.compareTo(b.name);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Quests')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => QuestEditorScreen.open(context),
        icon: const Icon(Icons.add),
        label: const Text('New quest'),
      ),
      body: quests.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.xl),
                child: Text(
                  'No quests yet.\nSet a savings goal to hunt.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                        color: Theme.of(context).colorScheme.onSurfaceVariant,
                      ),
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.only(bottom: 96),
              itemCount: quests.length,
              separatorBuilder: (_, _) => const Divider(height: 1),
              itemBuilder: (context, i) =>
                  _QuestTile(quest: quests[i], names: names),
            ),
    );
  }
}

class _QuestTile extends StatelessWidget {
  const _QuestTile({required this.quest, required this.names});

  final QuestState quest;
  final Map<String, String> names;

  @override
  Widget build(BuildContext context) {
    final owner = switch (quest.ownership) {
      SharedParty() => 'Shared',
      PersonalParty(:final userId) => names[userId] ?? 'Personal',
    };
    final pct = quest.targetCents == 0
        ? 0.0
        : (quest.totalContributedCents / quest.targetCents).clamp(0.0, 1.0);
    final status = quest.abandoned
        ? 'Abandoned'
        : quest.completed
            ? 'Complete'
            : '$owner · ${money(quest.balanceCents)} on hand';
    return ListTile(
      leading: Icon(quest.completed
          ? Icons.emoji_events
          : quest.abandoned
              ? Icons.cancel_outlined
              : Icons.flag_outlined),
      title: Text(quest.name),
      subtitle: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(status),
          const SizedBox(height: AppSpacing.xs),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(value: pct, minHeight: 6),
          ),
        ],
      ),
      trailing: Text(
        '${money(quest.totalContributedCents)}\n/ ${money(quest.targetCents)}',
        textAlign: TextAlign.right,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      isThreeLine: true,
      onTap: () => Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => QuestDetailScreen(questId: quest.questId),
      )),
    );
  }
}

class QuestDetailScreen extends ConsumerWidget {
  const QuestDetailScreen({super.key, required this.questId});

  final String questId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(householdStateProvider).value;
    final events = ref.watch(eventLogProvider).value ?? const [];
    final names = ref.watch(userNamesProvider);
    final quest = state?.quests[questId];
    if (state == null || quest == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final fundings = questFundings(events, questId);
    final drawdowns = state.purchases.values
        .where((p) =>
            !p.voided && p.target == QuestCharge(questId))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));

    final pct = quest.targetCents == 0
        ? 0.0
        : (quest.totalContributedCents / quest.targetCents).clamp(0.0, 1.0);

    return Scaffold(
      appBar: AppBar(
        title: Text(quest.name),
        actions: [
          if (!quest.abandoned && !quest.completed)
            IconButton(
              tooltip: 'Edit',
              onPressed: () =>
                  QuestEditorScreen.open(context, existing: quest),
              icon: const Icon(Icons.edit_outlined),
            ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '${money(quest.totalContributedCents)} of '
                    '${money(quest.targetCents)}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(value: pct, minHeight: 10),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text('${money(quest.balanceCents)} available to spend',
                      style: Theme.of(context).textTheme.bodyMedium),
                  if (quest.completed)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Text('🏆 Target reached'),
                    ),
                  if (quest.abandoned)
                    const Padding(
                      padding: EdgeInsets.only(top: AppSpacing.sm),
                      child: Text('This quest was abandoned.'),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Contributions', style: AppText.sectionLabel(context)),
          for (final e in quest.contributions.entries)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.person_outline),
              title: Text(names[e.key] ?? e.key),
              trailing: Text(money(e.value)),
            ),
          if (quest.contributions.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('No contributions yet.'),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Funding history', style: AppText.sectionLabel(context)),
          for (final f in fundings)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.add_circle_outline),
              title: Text('${names[f.userId] ?? f.userId} · ${f.month}'),
              trailing: Text(signedMoney(f.amountCents)),
            ),
          if (fundings.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('No fundings recorded.'),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text('Purchases against this quest',
              style: AppText.sectionLabel(context)),
          for (final p in drawdowns)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.shopping_bag_outlined),
              title: Text(p.merchant ?? 'Purchase'),
              subtitle: Text(isoDay(p.occurredAt)),
              trailing: Text('-${money(p.amountCents)}'),
            ),
          if (drawdowns.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Text('Nothing bought from this quest yet.'),
            ),
          if (!quest.abandoned) ...[
            const SizedBox(height: AppSpacing.xl),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: () => _confirmAbandon(context, ref, state, quest),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Abandon quest'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _confirmAbandon(
    BuildContext context,
    WidgetRef ref,
    HouseholdState state,
    QuestState quest,
  ) async {
    final names = ref.read(userNamesProvider);
    final tithePct = state.settings.dissolutionTithePct;
    final preview =
        previewAbandon(quest.balanceCents, quest.contributions, tithePct);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Abandon quest?'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('“${quest.name}” has ${money(quest.balanceCents)} on hand.'),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'A $tithePct% dissolution tithe of '
              '${money(preview.titheCents)} goes to the war chest.',
            ),
            const SizedBox(height: AppSpacing.sm),
            const Text('Returned to funders:'),
            for (final e in preview.returnsByUser.entries)
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.xxs),
                child: Text('• ${names[e.key] ?? e.key}: ${money(e.value)}'),
              ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Keep'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Abandon'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await ref.read(householdActionsProvider)?.abandonQuest(quest.questId);
      if (context.mounted) Navigator.of(context).pop();
    }
  }
}

class QuestEditorScreen extends ConsumerStatefulWidget {
  const QuestEditorScreen({super.key, this.existing});

  final QuestState? existing;

  static Future<void> open(BuildContext context, {QuestState? existing}) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => QuestEditorScreen(existing: existing),
      ));

  @override
  ConsumerState<QuestEditorScreen> createState() => _QuestEditorScreenState();
}

enum _OwnerChoice { me, partner, shared }

class _QuestEditorScreenState extends ConsumerState<QuestEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  _OwnerChoice _owner = _OwnerChoice.shared;
  String? _spriteSha;
  bool _ownerInit = false;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _target = TextEditingController(
        text: e == null ? '' : (e.targetCents / 100).toStringAsFixed(2));
    _spriteSha = e?.customSpriteSha256;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(localSetupProvider).value;
    final names = ref.watch(userNamesProvider);
    if (setup == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_ownerInit) {
      final o = widget.existing?.ownership;
      if (o is PersonalParty) {
        _owner = o.userId == setup.partner.userId
            ? _OwnerChoice.partner
            : _OwnerChoice.me;
      }
      _ownerInit = true;
    }

    return Scaffold(
      appBar: AppBar(
          title: Text(widget.existing == null ? 'New quest' : 'Edit quest')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _target,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
                labelText: 'Target', prefixText: r'$'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Owner', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<_OwnerChoice>(
            segments: [
              ButtonSegment(
                  value: _OwnerChoice.me,
                  label: Text(names[setup.me.userId] ?? 'Me')),
              ButtonSegment(
                  value: _OwnerChoice.partner,
                  label: Text(names[setup.partner.userId] ?? 'Partner')),
              const ButtonSegment(
                  value: _OwnerChoice.shared, label: Text('Shared')),
            ],
            selected: {_owner},
            onSelectionChanged: (s) => setState(() => _owner = s.first),
          ),
          const SizedBox(height: AppSpacing.lg),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.image_outlined),
            title: Text(
                _spriteSha == null ? 'Default sprite' : 'Custom sprite set'),
            trailing: Wrap(
              spacing: AppSpacing.xs,
              children: [
                if (_spriteSha != null)
                  IconButton(
                    tooltip: 'Remove',
                    onPressed: () => setState(() => _spriteSha = null),
                    icon: const Icon(Icons.close),
                  ),
                TextButton(
                  onPressed: () async {
                    final sha = await pickAndIngestSprite(
                        ref, ScaffoldMessenger.of(context));
                    if (sha != null) setState(() => _spriteSha = sha);
                  },
                  child: const Text('Choose PNG'),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => _save(setup.me.userId, setup.partner.userId),
            child: const Text('Save quest'),
          ),
        ],
      ),
    );
  }

  Future<void> _save(String meId, String partnerId) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final name = _name.text.trim();
    final target = tryParseMoneyCents(_target.text);
    if (name.isEmpty || target == null || target <= 0) {
      messenger.showSnackBar(
          const SnackBar(content: Text('Enter a name and a positive target')));
      return;
    }
    final ownership = switch (_owner) {
      _OwnerChoice.me => PersonalParty(meId),
      _OwnerChoice.partner => PersonalParty(partnerId),
      _OwnerChoice.shared => const SharedParty(),
    };
    await ref.read(householdActionsProvider)?.setQuest(
          questId: widget.existing?.questId,
          name: name,
          targetCents: target,
          ownership: ownership,
          sliceHint: widget.existing?.sliceHint,
          customSpriteSha256: _spriteSha,
        );
    navigator.pop();
  }
}
