/// Onboarding step 1: joining a party that already exists on another device.
///
/// Pairs with a hub over the LAN, runs one sync cycle to pull the party's
/// events, then lets this device claim which adult it is and finishes setup.
/// This runs *before* first-run setup exists, so it builds a [SyncClient]
/// directly (the household sync service is still null until this device is
/// named) and writes the device-local [LocalSetup] to complete onboarding.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/setup/local_setup.dart';
import '../../data/sync/sync_client.dart';
import '../../domain/state.dart';
import '../../ui/theme.dart';
import '../sync/pairing_qr.dart';

class JoinPartyScreen extends ConsumerStatefulWidget {
  const JoinPartyScreen({super.key});

  static Future<void> open(BuildContext context) => Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => const JoinPartyScreen()),
      );

  @override
  ConsumerState<JoinPartyScreen> createState() => _JoinPartyScreenState();
}

class _JoinPartyScreenState extends ConsumerState<JoinPartyScreen> {
  final _deviceName = TextEditingController();
  final _url = TextEditingController();
  final _secret = TextEditingController();
  bool _busy = false;
  bool _paired = false;
  String? _error;

  @override
  void dispose() {
    _deviceName.dispose();
    _url.dispose();
    _secret.dispose();
    super.dispose();
  }

  Future<void> _pair() async {
    final name = _deviceName.text.trim();
    final url = _url.text.trim();
    final secret = _secret.text.trim();
    if (name.isEmpty || url.isEmpty || secret.isEmpty) {
      setState(() => _error = 'Fill in your device name, the address, and secret.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final client = SyncClient(
      db: ref.read(appDatabaseProvider),
      blobs: ref.read(blobStoreProvider),
      deviceName: name,
    );
    try {
      await client.pair(url, secret);
      await client.syncOnce();
      setState(() => _paired = true);
    } on Object catch (e) {
      setState(() => _error = 'Could not pair: $e');
    } finally {
      client.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final payload = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScanPairingQrScreen()),
    );
    if (payload == null || !mounted) return;
    final parsed = parsePairingQr(payload);
    if (parsed == null) {
      setState(() => _error = "That QR code isn't a LootLog pairing code.");
      return;
    }
    setState(() {
      _url.text = parsed.url;
      _secret.text = parsed.pairingSecret;
      _error = null;
    });
    if (_deviceName.text.trim().isNotEmpty) {
      await _pair();
    } else {
      setState(() =>
          _error = 'Scanned! Now give this device a name and tap Pair & sync.');
    }
  }

  Future<void> _claim(MemberState adult, HouseholdState state) async {
    final adults = state.members.values.where((m) => m.isAdult && m.active);
    final other = adults.firstWhere(
      (m) => m.memberId != adult.memberId,
      orElse: () => adult,
    );
    final setup = LocalSetup(
      timezone: 'America/Vancouver',
      user1: UserProfile(userId: adult.memberId, name: adult.name),
      user2: UserProfile(userId: other.memberId, name: other.name),
      meUserId: adult.memberId,
    );
    // Saving flips isSetUpProvider; the router hands off to the main shell.
    await ref.read(appDatabaseProvider).localSetupDao.save(setup);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Join an existing party')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: _paired ? _claimStep() : _pairStep(),
          ),
        ),
      ),
    );
  }

  Widget _pairStep() {
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        const Text(
          'On the hosting device (a desktop running a hub), open Sync & hubs. '
          'Scan its QR code — or read off its address and pairing secret and '
          'enter them here.',
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _deviceName,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            labelText: 'This device\'s name',
            hintText: 'e.g. Robin\'s phone',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _url,
          decoration: const InputDecoration(
            labelText: 'Hub address',
            hintText: 'http://192.168.1.20:8787',
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        TextField(
          controller: _secret,
          decoration: const InputDecoration(labelText: 'Pairing secret'),
        ),
        if (_error != null) ...[
          const SizedBox(height: AppSpacing.md),
          Text(_error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: AppSpacing.lg),
        if (canScanPairingQr) ...[
          FilledButton.icon(
            onPressed: _busy ? null : _scan,
            icon: const Icon(Icons.qr_code_scanner),
            label: const Text('Scan the hub\'s QR code'),
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        FilledButton.icon(
          onPressed: _busy ? null : _pair,
          icon: _busy
              ? const SizedBox(
                  width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.link),
          label: const Text('Pair & sync'),
        ),
      ],
    );
  }

  Widget _claimStep() {
    final state = ref.watch(householdStateProvider).value;
    final adults = state == null
        ? const <MemberState>[]
        : (state.members.values.where((m) => m.isAdult && m.active).toList()
          ..sort((a, b) => a.name.compareTo(b.name)));
    return ListView(
      padding: const EdgeInsets.all(AppSpacing.lg),
      children: [
        Row(
          children: [
            Icon(Icons.check_circle,
                color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: AppSpacing.md),
            const Expanded(child: Text('Paired and synced.')),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        Text('Which adult are you?', style: AppText.sectionLabel(context)),
        const SizedBox(height: AppSpacing.sm),
        if (adults.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: AppSpacing.lg),
            child: Text(
              'No party members have synced yet. Give the hub a moment, then '
              'try pairing again.',
            ),
          )
        else
          for (final a in adults)
            Card(
              child: ListTile(
                leading: const Icon(Icons.person_outline),
                title: Text(a.name),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => _claim(a, state!),
              ),
            ),
      ],
    );
  }
}
