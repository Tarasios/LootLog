/// The shared budget-category editor, used from both Settings and Budget setup.
///
/// Every field on a category lives here: ownership (personal to either member,
/// or a group category), main category, monthly limit, per-category pool tithe %,
/// default leftover policy, tax-deductible default, and an optional emergency-
/// fund contribution off the top. A category's pet link (for display) is set
/// elsewhere; any existing link is preserved untouched here. Saving appends a
/// single [BudgetSliceSet] (the wire event name is retained); the reducer treats
/// it as last-writer-wins, so this same screen creates and edits.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/actions.dart';
import '../../data/providers.dart';
import '../../domain/money.dart';
import '../../domain/state.dart';
import '../../domain/value_types.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../household_context.dart';

class CategoryEditorScreen extends ConsumerStatefulWidget {
  const CategoryEditorScreen({super.key, this.existing, this.defaultOwnership});

  /// The category being edited, or null to create a new one.
  final SliceConfig? existing;

  /// Pre-selected ownership when creating (e.g. from a member column in setup).
  final SliceOwnership? defaultOwnership;

  static Future<void> open(
    BuildContext context, {
    SliceConfig? existing,
    SliceOwnership? defaultOwnership,
  }) =>
      Navigator.of(context).push(MaterialPageRoute<void>(
        builder: (_) => CategoryEditorScreen(
          existing: existing,
          defaultOwnership: defaultOwnership,
        ),
      ));

  @override
  ConsumerState<CategoryEditorScreen> createState() =>
      _CategoryEditorScreenState();
}

/// A three-way ownership choice for the editor's segmented control.
enum _OwnerChoice { me, partner, group }

class _CategoryEditorScreenState extends ConsumerState<CategoryEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _limit;
  late final TextEditingController _tithe;
  late final TextEditingController _emergencyAmount;

  _OwnerChoice _owner = _OwnerChoice.me;
  SlicePriority _priority = SlicePriority.important;
  LeftoverDestination _policy = const CarryInSlice();
  String? _policyQuestId;
  String? _mainCategoryId;
  bool _taxDefault = false;
  bool _emergencyOn = false;
  String? _emergencyFundId;
  String? _petId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _limit = TextEditingController(
        text: e == null ? '' : Money(e.limitCents).format());
    _tithe = TextEditingController(text: (e?.poolTithePct ?? 0).toString());
    _emergencyAmount = TextEditingController(
      text: (e?.emergencyContributionCents ?? 0) > 0
          ? Money(e!.emergencyContributionCents).format()
          : '',
    );
    _taxDefault = e?.taxDeductibleByDefault ?? false;
    _mainCategoryId = e?.mainCategoryId;
    _petId = e?.petId;
    _priority = e?.priority ?? SlicePriority.important;
    if (e != null && e.emergencyFundId != null &&
        e.emergencyContributionCents > 0) {
      _emergencyOn = true;
      _emergencyFundId = e.emergencyFundId;
    }
    final policy = e?.defaultLeftoverPolicy ?? const CarryInSlice();
    _policy = policy;
    if (policy is QuestDestination) _policyQuestId = policy.questId;
  }

  @override
  void dispose() {
    _name.dispose();
    _limit.dispose();
    _tithe.dispose();
    _emergencyAmount.dispose();
    super.dispose();
  }

  void _initOwner(String meId, String partnerId) {
    final e = widget.existing;
    final o = e?.ownership ?? widget.defaultOwnership;
    if (o is GroupSlice) {
      _owner = _OwnerChoice.group;
    } else if (o is PersonalSlice) {
      _owner = o.userId == partnerId ? _OwnerChoice.partner : _OwnerChoice.me;
    }
  }

  bool _ownerInitialized = false;

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    if (setup == null || state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_ownerInitialized) {
      _initOwner(setup.me.userId, setup.partner.userId);
      _ownerInitialized = true;
    }
    final names = ref.watch(userNamesProvider);
    final isGroup = _owner == _OwnerChoice.group;
    final quests = state.quests.values
        .where((q) => !q.abandoned)
        .toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final funds = state.emergencyFunds.values.toList()
      ..sort((a, b) => a.name.compareTo(b.name));
    final mainCategories = state.mainCategories.values.toList()
      ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'New category' : 'Edit category'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: 'Name'),
            textCapitalization: TextCapitalization.words,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Priority', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<SlicePriority>(
            initialValue: _priority,
            decoration: const InputDecoration(
              helperText: 'When overspending needs repaying, fun budgets are '
                  'suggested first and necessities protected',
            ),
            items: const [
              DropdownMenuItem(
                  value: SlicePriority.necessity, child: Text('Necessity')),
              DropdownMenuItem(
                  value: SlicePriority.important, child: Text('Important')),
              DropdownMenuItem(value: SlicePriority.fun, child: Text('Fun')),
            ],
            onChanged: (v) =>
                setState(() => _priority = v ?? SlicePriority.important),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Main category', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String?>(
            initialValue: _mainCategoryId,
            decoration: const InputDecoration(
              helperText: 'Groups spending on the monthly report',
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('None'),
              ),
              for (final m in mainCategories)
                DropdownMenuItem<String?>(
                  value: m.id,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Color(m.colorArgb),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(m.name),
                    ],
                  ),
                ),
            ],
            onChanged: (v) => setState(() => _mainCategoryId = v),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Owner', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          SegmentedButton<_OwnerChoice>(
            segments: [
              ButtonSegment(
                value: _OwnerChoice.me,
                label: Text(names[setup.me.userId] ?? 'Me'),
              ),
              ButtonSegment(
                value: _OwnerChoice.partner,
                label: Text(names[setup.partner.userId] ?? 'Partner'),
              ),
              const ButtonSegment(
                value: _OwnerChoice.group,
                label: Text('Group'),
              ),
            ],
            selected: {_owner},
            onSelectionChanged: (s) => setState(() => _owner = s.first),
          ),
          if (isGroup)
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Group categories are funded 50/50 off the top; leftover flows '
                'automatically to the war chest.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          TextField(
            controller: _limit,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Monthly limit',
              prefixText: r'$',
            ),
          ),
          if (!isGroup) ...[
            const SizedBox(height: AppSpacing.lg),
            TextField(
              controller: _tithe,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Shared-savings cut %',
                helperText:
                    'Part of this budget’s leftover kept for shared savings '
                    'instead of personal spending',
                suffixText: '%',
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text('Default leftover policy', style: AppText.sectionLabel(context)),
            const SizedBox(height: AppSpacing.sm),
            _policySelector(quests),
          ],
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tax-deductible by default'),
            value: _taxDefault,
            onChanged: (v) => setState(() => _taxDefault = v),
          ),
          const Divider(height: AppSpacing.xl),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Emergency fund contribution'),
            subtitle: const Text('Fixed amount off the top each month'),
            value: _emergencyOn,
            onChanged: funds.isEmpty
                ? null
                : (v) => setState(() => _emergencyOn = v),
          ),
          if (funds.isEmpty)
            Text(
              'Create an emergency fund in Settings first.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          if (_emergencyOn && funds.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.sm),
            DropdownButtonFormField<String>(
              initialValue: _emergencyFundId ?? funds.first.fundId,
              decoration: const InputDecoration(labelText: 'Fund'),
              items: [
                for (final f in funds)
                  DropdownMenuItem(value: f.fundId, child: Text(f.name)),
              ],
              onChanged: (v) => setState(() => _emergencyFundId = v),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _emergencyAmount,
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Monthly contribution',
                prefixText: r'$',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => _save(setup.me.userId, setup.partner.userId),
            child: const Text('Save category'),
          ),
        ],
      ),
    );
  }

  Widget _policySelector(List<QuestState> quests) {
    // Encode the current selection as a stable token for the dropdown.
    String token() {
      final p = _policy;
      return switch (p) {
        CarryInSlice() => 'carry',
        Discretionary() => 'discretionary',
        QuestDestination() => 'quest',
        // Not offered as a configured policy; debts are paid at the ritual.
        OverbudgetPayment() => 'discretionary',
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: token(),
          items: const [
            DropdownMenuItem(value: 'carry', child: Text('Carry in category')),
            DropdownMenuItem(
                value: 'discretionary', child: Text('Convert to discretionary')),
            DropdownMenuItem(value: 'quest', child: Text('Attack a quest')),
          ],
          onChanged: (v) => setState(() {
            switch (v) {
              case 'carry':
                _policy = const CarryInSlice();
              case 'discretionary':
                _policy = const Discretionary();
              case 'quest':
                _policyQuestId ??= quests.isEmpty ? null : quests.first.questId;
                _policy = _policyQuestId == null
                    ? const CarryInSlice()
                    : QuestDestination(_policyQuestId!);
            }
          }),
        ),
        if (token() == 'quest' && quests.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.md),
            child: DropdownButtonFormField<String>(
              initialValue: _policyQuestId ?? quests.first.questId,
              decoration: const InputDecoration(labelText: 'Quest'),
              items: [
                for (final q in quests)
                  DropdownMenuItem(value: q.questId, child: Text(q.name)),
              ],
              onChanged: (v) => setState(() {
                _policyQuestId = v;
                if (v != null) _policy = QuestDestination(v);
              }),
            ),
          ),
      ],
    );
  }

  Future<void> _save(String meId, String partnerId) async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final actions = ref.read(householdActionsProvider);
    if (actions == null) return;

    final name = _name.text.trim();
    if (name.isEmpty) {
      messenger.showSnackBar(const SnackBar(content: Text('Name is required')));
      return;
    }
    final limit = tryParseMoneyCents(_limit.text);
    if (limit == null) {
      messenger
          .showSnackBar(const SnackBar(content: Text('Enter a valid limit')));
      return;
    }
    final isGroup = _owner == _OwnerChoice.group;
    final ownership = switch (_owner) {
      _OwnerChoice.me => PersonalSlice(meId),
      _OwnerChoice.partner => PersonalSlice(partnerId),
      _OwnerChoice.group => const GroupSlice(),
    };
    final tithe = isGroup ? 0 : (tryParsePercent(_tithe.text) ?? 0);
    final policy = isGroup ? const Discretionary() : _policy;

    EmergencyContribution? emergency;
    if (_emergencyOn && _emergencyFundId != null) {
      final amount = tryParseMoneyCents(_emergencyAmount.text);
      if (amount == null || amount <= 0) {
        messenger.showSnackBar(const SnackBar(
            content: Text('Enter a valid emergency contribution')));
        return;
      }
      emergency =
          EmergencyContribution(fundId: _emergencyFundId!, amountCents: amount);
    }

    await actions.setSlice(
      sliceId: widget.existing?.sliceId,
      name: name,
      ownership: ownership,
      mainCategoryId: _mainCategoryId,
      limitCents: limit,
      poolTithePct: tithe,
      defaultLeftoverPolicy: policy,
      taxDeductibleByDefault: _taxDefault,
      emergencyContribution: emergency,
      petId: _petId,
      priority: _priority,
    );
    navigator.pop();
  }
}
