/// The shared budget-category editor, used from both Settings and Budget setup.
///
/// Every field on a category lives here: ownership (personal to any adult, or a
/// group category), the pets that own a group category, main category, monthly
/// limit, per-category pool tithe %, default leftover policy, tax-deductible
/// default, and an optional emergency-fund contribution off the top. The
/// legacy single-pet display link is preserved untouched. Saving appends a
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
import '../../domain/time.dart';
import '../../ui/glossary.dart';
import '../../ui/money_input.dart';
import '../../ui/theme.dart';
import '../household_context.dart';
import '../settings/play_mode_providers.dart';
import '../shared/owner_picker.dart';

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
  }) => Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => CategoryEditorScreen(
        existing: existing,
        defaultOwnership: defaultOwnership,
      ),
    ),
  );

  @override
  ConsumerState<CategoryEditorScreen> createState() =>
      _CategoryEditorScreenState();
}

class _CategoryEditorScreenState extends ConsumerState<CategoryEditorScreen> {
  late final TextEditingController _name;
  late final TextEditingController _limit;
  late final TextEditingController _tithe;
  late final TextEditingController _emergencyAmount;

  /// The owning adult, or null for a group category.
  String? _ownerUserId;
  bool _ownerInitialized = false;

  /// The pets that own this (group) category, in the order they were chosen.
  final List<String> _petOwners = [];
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
    final existing = widget.existing;
    _name = TextEditingController(text: existing?.name ?? '');
    _limit = TextEditingController(
      text: existing == null ? '' : Money(existing.limitCents).format(),
    );
    _tithe = TextEditingController(
      text: (existing?.poolTithePct ?? 0).toString(),
    );
    _emergencyAmount = TextEditingController(
      text: (existing?.emergencyContributionCents ?? 0) > 0
          ? Money(existing!.emergencyContributionCents).format()
          : '',
    );
    _taxDefault = existing?.taxDeductibleByDefault ?? false;
    _mainCategoryId = existing?.mainCategoryId;
    _petId = existing?.petId;
    _petOwners.addAll(existing?.petOwnerIds ?? const []);
    _priority = existing?.priority ?? SlicePriority.important;
    if (existing != null &&
        existing.emergencyFundId != null &&
        existing.emergencyContributionCents > 0) {
      _emergencyOn = true;
      _emergencyFundId = existing.emergencyFundId;
    }
    final policy = existing?.defaultLeftoverPolicy ?? const CarryInSlice();
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

  void _initOwner(String meId) {
    final ownership = widget.existing?.ownership ?? widget.defaultOwnership;
    _ownerUserId = switch (ownership) {
      GroupSlice() => null,
      PersonalSlice(:final userId) => userId,
      null => meId,
    };
  }

  @override
  Widget build(BuildContext context) {
    final setup = ref.watch(localSetupProvider).value;
    final state = ref.watch(householdStateProvider).value;
    if (setup == null || state == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (!_ownerInitialized) {
      _initOwner(setup.meUserId);
      _ownerInitialized = true;
    }
    final adults = ref.watch(partyAdultsProvider);
    final pets = ref.watch(partyPetsProvider);
    final isGroup = _ownerUserId == null;
    final savingsRulesOn =
        state.savingsRules?.appliesTo(Month.fromInstant(DateTime.now())) ??
        false;
    final quests =
        state.quests.values.where((quest) => !quest.abandoned).toList()
          ..sort((first, second) => first.name.compareTo(second.name));
    final funds = state.emergencyFunds.values.toList()
      ..sort((first, second) => first.name.compareTo(second.name));
    final mainCategories = state.mainCategories.values.toList()
      ..sort((first, second) => first.sortOrder.compareTo(second.sortOrder));

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
              helperText:
                  'When overspending needs repaying, fun budgets are '
                  'suggested first and necessities protected',
            ),
            items: const [
              DropdownMenuItem(
                value: SlicePriority.necessity,
                child: Text('Necessity'),
              ),
              DropdownMenuItem(
                value: SlicePriority.important,
                child: Text('Important'),
              ),
              DropdownMenuItem(value: SlicePriority.fun, child: Text('Fun')),
            ],
            onChanged: (value) =>
                setState(() => _priority = value ?? SlicePriority.important),
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
              const DropdownMenuItem<String?>(value: null, child: Text('None')),
              for (final mainCategory in mainCategories)
                DropdownMenuItem<String?>(
                  value: mainCategory.id,
                  child: Row(
                    children: [
                      Container(
                        width: 14,
                        height: 14,
                        decoration: BoxDecoration(
                          color: Color(mainCategory.colorArgb),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(mainCategory.name),
                    ],
                  ),
                ),
            ],
            onChanged: (value) => setState(() => _mainCategoryId = value),
          ),
          const SizedBox(height: AppSpacing.lg),
          Text('Owner', style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          OwnerPicker(
            adults: adults,
            selectedUserId: _ownerUserId,
            onChanged: (id) => setState(() => _ownerUserId = id),
          ),
          if (isGroup) ...[
            Padding(
              padding: const EdgeInsets.only(top: AppSpacing.sm),
              child: Text(
                'Group categories are funded by everyone’s shares off the top; '
                'leftover flows automatically to '
                '${Glossary.warChest.label(isAdventure: ref.watch(isAdventureProvider))}.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ),
            if (pets.isNotEmpty) ...[
              const SizedBox(height: AppSpacing.lg),
              Text('Owned by pets', style: AppText.sectionLabel(context)),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: [
                  for (final pet in pets)
                    FilterChip(
                      label: Text(pet.name),
                      selected: _petOwners.contains(pet.id),
                      onSelected: (selected) => setState(
                        () => selected
                            ? _petOwners.add(pet.id)
                            : _petOwners.remove(pet.id),
                      ),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Text(
                  'Pick the pets this budget is for. Several pets share it '
                  'equally, and each pet’s share is paid by whoever funds that '
                  'pet (set on the pet in Members).',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
          ],
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
              decoration: savingsRulesOn
                  ? InputDecoration(
                      labelText: 'Carry tax %',
                      helperText: Glossary.carryTax.helper,
                      helperMaxLines: 3,
                      suffixText: '%',
                    )
                  : const InputDecoration(
                      labelText: 'Shared-savings cut %',
                      helperText:
                          'Part of this budget’s leftover kept for shared '
                          'savings instead of personal spending',
                      suffixText: '%',
                    ),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Default leftover policy',
              style: AppText.sectionLabel(context),
            ),
            const SizedBox(height: AppSpacing.sm),
            _policySelector(quests),
          ],
          const SizedBox(height: AppSpacing.lg),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Tax-deductible by default'),
            value: _taxDefault,
            onChanged: (value) => setState(() => _taxDefault = value),
          ),
          const Divider(height: AppSpacing.xl),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Emergency fund contribution'),
            subtitle: const Text('Fixed amount off the top each month'),
            value: _emergencyOn,
            onChanged: funds.isEmpty
                ? null
                : (value) => setState(() => _emergencyOn = value),
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
                for (final fund in funds)
                  DropdownMenuItem(value: fund.fundId, child: Text(fund.name)),
              ],
              onChanged: (value) => setState(() => _emergencyFundId = value),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: _emergencyAmount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Monthly contribution',
                prefixText: r'$',
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(onPressed: _save, child: const Text('Save category')),
        ],
      ),
    );
  }

  Widget _policySelector(List<QuestState> quests) {
    // Encode the current selection as a stable token for the dropdown.
    String token() {
      final policy = _policy;
      return switch (policy) {
        CarryInSlice() => 'carry',
        Discretionary() => 'discretionary',
        QuestDestination() => 'quest',
        // Not offered as a configured policy; debts are paid at the ritual.
        OverbudgetPayment() => 'discretionary',
      };
    }

    final adventure = ref.watch(isAdventureProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          initialValue: token(),
          items: [
            const DropdownMenuItem(
              value: 'carry',
              child: Text('Carry in category'),
            ),
            const DropdownMenuItem(
              value: 'discretionary',
              child: Text('Convert to discretionary'),
            ),
            DropdownMenuItem(
              value: 'quest',
              child: Text(Glossary.attackQuest.label(isAdventure: adventure)),
            ),
          ],
          onChanged: (value) => setState(() {
            switch (value) {
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
              decoration: InputDecoration(
                labelText: adventure ? 'Quest' : 'Savings goal',
              ),
              items: [
                for (final quest in quests)
                  DropdownMenuItem(
                    value: quest.questId,
                    child: Text(quest.name),
                  ),
              ],
              onChanged: (value) => setState(() {
                _policyQuestId = value;
                if (value != null) _policy = QuestDestination(value);
              }),
            ),
          ),
      ],
    );
  }

  Future<void> _save() async {
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
      messenger.showSnackBar(
        const SnackBar(content: Text('Enter a valid limit')),
      );
      return;
    }
    final owner = _ownerUserId;
    final isGroup = owner == null;
    final SliceOwnership ownership = isGroup
        ? const GroupSlice()
        : PersonalSlice(owner);
    final tithe = isGroup ? 0 : (tryParsePercent(_tithe.text) ?? 0);
    final policy = isGroup ? const Discretionary() : _policy;

    EmergencyContribution? emergency;
    if (_emergencyOn && _emergencyFundId != null) {
      final amount = tryParseMoneyCents(_emergencyAmount.text);
      if (amount == null || amount <= 0) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Enter a valid emergency contribution')),
        );
        return;
      }
      emergency = EmergencyContribution(
        fundId: _emergencyFundId!,
        amountCents: amount,
      );
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
      petOwnerIds: isGroup ? List.unmodifiable(_petOwners) : const [],
      priority: _priority,
    );
    navigator.pop();
  }
}
