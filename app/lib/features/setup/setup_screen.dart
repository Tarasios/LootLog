/// Minimal first-run setup: names the two household members and marks which one
/// this device is. Written to device-local storage (never an event, never
/// synced). Budgets, quests, and funds are created elsewhere.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/setup/local_setup.dart';
import '../../domain/ids.dart';
import '../../ui/theme.dart';

class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({super.key});

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  final _me = TextEditingController(text: 'Me');
  final _partner = TextEditingController(text: 'Partner');
  bool _busy = false;

  @override
  void dispose() {
    _me.dispose();
    _partner.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy) return;
    setState(() => _busy = true);
    final meName = _me.text.trim().isEmpty ? 'Me' : _me.text.trim();
    final partnerName =
        _partner.text.trim().isEmpty ? 'Partner' : _partner.text.trim();
    final meId = uuidv7();
    final setup = LocalSetup(
      timezone: 'America/Vancouver',
      user1: UserProfile(userId: meId, name: meName),
      user2: UserProfile(userId: uuidv7(), name: partnerName),
      meUserId: meId,
    );
    await ref.read(appDatabaseProvider).localSetupDao.save(setup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Welcome to DuoBudget')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(AppSpacing.xl),
            children: [
              Text(
                'Two people, one budget.',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: AppSpacing.lg),
              TextField(
                controller: _me,
                decoration: const InputDecoration(labelText: 'Your name'),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.md),
              TextField(
                controller: _partner,
                decoration: const InputDecoration(labelText: "Partner's name"),
                textCapitalization: TextCapitalization.words,
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: _busy ? null : _save,
                child: const Text('Start budgeting'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
