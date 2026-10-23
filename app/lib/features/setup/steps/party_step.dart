part of '../setup_screen.dart';

// ---------------------------------------------------------------------------
// Step 2 — the party
// ---------------------------------------------------------------------------

class _PartyStep extends StatelessWidget {
  const _PartyStep({required this.controller, required this.ref});

  final SetupController controller;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const _StepIntro(
          'Add the adults, dependents, and pets in your household. '
          'Adults carry income and a budget; everyone else is shown with them. '
          'A description feeds the text-mode adventure.',
        ),
        for (final role in DraftRole.values) ...[
          _RoleSection(role: role),
          for (final member in controller.members.where((member) => member.role == role))
            _MemberTile(controller: controller, ref: ref, member: member),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => _editMember(context, role),
              icon: const Icon(Icons.add),
              label: Text('Add ${_roleWord(role)}'),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        if (controller.adults.length > 1) ...[
          const Divider(),
          Text('Which adult is this device?',
              style: AppText.sectionLabel(context)),
          const SizedBox(height: AppSpacing.sm),
          for (final adult in controller.adults)
            RadioListTile<String>(
              contentPadding: EdgeInsets.zero,
              value: adult.localId,
              groupValue: controller.meLocalId,
              title: Text(adult.name),
              onChanged: (value) => value == null ? null : controller.setMe(value),
            ),
        ],
      ],
    );
  }

  Future<void> _editMember(BuildContext context, DraftRole role,
      {DraftMember? existing}) async {
    final result = await showMemberEditor(context, ref,
        role: role, existing: existing, adults: controller.adults);
    if (result == null) return;
    if (existing == null) {
      controller.addMember(role, result.name,
          descriptionText: result.description,
          spriteSha256: result.sprite,
          fundedByUserId: result.fundedBy);
    } else {
      controller.updateMember(existing.localId,
          name: result.name,
          descriptionText: result.description,
          spriteSha256: result.sprite,
          fundedByUserId: result.fundedBy);
    }
  }
}

class _RoleSection extends StatelessWidget {
  const _RoleSection({required this.role});
  final DraftRole role;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md, bottom: AppSpacing.xs),
      child: Text(_rolePlural(role), style: AppText.sectionLabel(context)),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.controller, required this.ref, required this.member});
  final SetupController controller;
  final WidgetRef ref;
  final DraftMember member;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(_roleIcon(member.role)),
      title: Text(member.name),
      subtitle: member.descriptionText == null
          ? null
          : Text(member.descriptionText!, maxLines: 1,
              overflow: TextOverflow.ellipsis),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (member.spriteSha256 != null)
            const Icon(Icons.image_outlined, size: 18),
          IconButton(
            icon: const Icon(Icons.edit_outlined),
            onPressed: () async {
              final result = await showMemberEditor(context, ref,
                  role: member.role, existing: member, adults: controller.adults);
              if (result != null) {
                controller.updateMember(member.localId,
                    name: result.name,
                    descriptionText: result.description,
                    spriteSha256: result.sprite,
                    fundedByUserId: result.fundedBy);
              }
            },
          ),
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () => controller.removeMember(member.localId),
          ),
        ],
      ),
    );
  }
}
