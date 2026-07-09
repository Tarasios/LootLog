/// The Data → Export screen: the always-available offline `.xlsx` export, plus
/// the opt-in, off-by-default Google Sheets sync.
///
/// The workbook is built by the pure [buildBudgetWorkbook]; this screen only
/// gathers the derived state, picks a save location, and — for Sheets — walks
/// the user through the explicit opt-in (with the [kSheetsPrivacyWarning]) and
/// their own credentials before handing the same workbook to the isolated
/// [SheetsSyncService]. With no Google client bundled, the sync section stays
/// informative and disabled, and nothing ever leaves the device.
library;

import 'dart:async';
import 'dart:io';

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/export/budget_workbook.dart';
import '../../data/export/xlsx.dart';
import '../../data/providers.dart';
import '../../data/sheets/sheets_provider.dart';
import '../../data/sheets/sheets_sync.dart';
import '../../domain/state.dart';

class ExportScreen extends ConsumerStatefulWidget {
  const ExportScreen({super.key});

  @override
  ConsumerState<ExportScreen> createState() => _ExportScreenState();
}

class _ExportScreenState extends ConsumerState<ExportScreen> {
  bool _exporting = false;
  bool _loadingSheets = true;
  bool _pushing = false;

  SheetsSyncSettings _settings = const SheetsSyncSettings();
  SheetsCredentials? _credentials;

  final _spreadsheetController = TextEditingController();
  final _clientIdController = TextEditingController();
  final _clientSecretController = TextEditingController();
  final _refreshTokenController = TextEditingController();

  @override
  void initState() {
    super.initState();
    unawaited(_loadSheets());
  }

  @override
  void dispose() {
    _spreadsheetController.dispose();
    _clientIdController.dispose();
    _clientSecretController.dispose();
    _refreshTokenController.dispose();
    super.dispose();
  }

  Future<void> _loadSheets() async {
    final store = ref.read(sheetsSyncStoreProvider);
    final settings = await store.loadSettings();
    final credentials = await store.loadCredentials();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _credentials = credentials;
      _spreadsheetController.text = settings.spreadsheetId ?? '';
      _clientIdController.text = credentials?.clientId ?? '';
      _clientSecretController.text = credentials?.clientSecret ?? '';
      _refreshTokenController.text = credentials?.refreshToken ?? '';
      _loadingSheets = false;
    });
  }

  /// Builds the workbook from the current derived state, with member names.
  XlsxWorkbook? _buildWorkbook() {
    final state = ref.read(householdStateProvider).value;
    if (state == null) return null;
    return buildBudgetWorkbook(state, userNames: _memberNames(state));
  }

  Map<String, String> _memberNames(HouseholdState state) => {
        for (final m in state.members.values) m.memberId: m.name,
      };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Export')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Spreadsheet (.xlsx)',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text(
            'A workbook with Transactions, Monthly summary, Members & income, '
            'Savings goals, Net worth, and Recurring expenses. Fully offline — '
            'nothing leaves this device.',
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _exporting ? null : _exportXlsx,
            icon: _exporting
                ? const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.table_view_outlined),
            label: Text(_exporting ? 'Exporting…' : 'Export .xlsx'),
          ),
          const Divider(height: 40),
          _buildSheetsSection(context),
        ],
      ),
    );
  }

  Widget _buildSheetsSection(BuildContext context) {
    final client = ref.watch(sheetsClientProvider);
    if (_loadingSheets) {
      return const Center(child: Padding(
        padding: EdgeInsets.all(16),
        child: CircularProgressIndicator(),
      ));
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Google Sheets sync',
            style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 8),
        const Text(
          'The only feature that sends data outside your local network. Off by '
          'default; you supply your own Google credentials.',
        ),
        if (!client.isSupported)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Not available in this build. Your settings are saved for when a '
              'Google Sheets client is present.',
              style: TextStyle(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: const Text('Enable Google Sheets sync'),
          subtitle: const Text('Your data leaves your local network'),
          value: _settings.enabled,
          onChanged: (value) => unawaited(_toggleEnabled(value)),
        ),
        if (_settings.enabled) ...[
          const SizedBox(height: 8),
          TextField(
            controller: _spreadsheetController,
            decoration: const InputDecoration(
              labelText: 'Spreadsheet ID',
              helperText: 'The id from the spreadsheet URL',
            ),
            onChanged: (_) => unawaited(_persistSettings()),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _clientIdController,
            decoration: const InputDecoration(labelText: 'OAuth client ID'),
            onChanged: (_) => unawaited(_persistCredentials()),
          ),
          TextField(
            controller: _clientSecretController,
            decoration: const InputDecoration(labelText: 'OAuth client secret'),
            obscureText: true,
            onChanged: (_) => unawaited(_persistCredentials()),
          ),
          TextField(
            controller: _refreshTokenController,
            decoration: const InputDecoration(labelText: 'OAuth refresh token'),
            obscureText: true,
            onChanged: (_) => unawaited(_persistCredentials()),
          ),
          const SizedBox(height: 12),
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Also push after each sync'),
            value: _settings.pushAfterSync,
            onChanged: (value) => unawaited(_togglePushAfterSync(value ?? false)),
          ),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: _pushing ? null : _pushNow,
            icon: const Icon(Icons.cloud_upload_outlined),
            label: Text(_pushing ? 'Pushing…' : 'Push now'),
          ),
        ],
      ],
    );
  }

  Future<void> _exportXlsx() async {
    final messenger = ScaffoldMessenger.of(context);
    final workbook = _buildWorkbook();
    if (workbook == null) return;
    setState(() => _exporting = true);
    try {
      final bytes = encodeXlsx(workbook);
      final location = await getSaveLocation(
        suggestedName: 'duobudget.xlsx',
        acceptedTypeGroups: const [
          XTypeGroup(label: 'Excel workbook', extensions: ['xlsx']),
        ],
      );
      if (location == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Export cancelled')),
        );
        return;
      }
      await File(location.path).writeAsBytes(bytes, flush: true);
      messenger.showSnackBar(
        SnackBar(content: Text('Exported to ${location.path}')),
      );
    } on Object catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Export failed: $e')));
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  Future<void> _toggleEnabled(bool value) async {
    if (value) {
      final accepted = await _confirmPrivacy();
      if (!accepted) return;
    }
    setState(() => _settings = _settings.copyWith(enabled: value));
    await _persistSettings();
  }

  Future<bool> _confirmPrivacy() async {
    final accepted = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Data leaves your local network'),
        content: const Text(kSheetsPrivacyWarning),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('I understand, turn it on'),
          ),
        ],
      ),
    );
    return accepted ?? false;
  }

  Future<void> _togglePushAfterSync(bool value) async {
    setState(() => _settings = _settings.copyWith(pushAfterSync: value));
    await _persistSettings();
  }

  Future<void> _persistSettings() async {
    _settings = _settings.copyWith(
      spreadsheetId: _spreadsheetController.text.trim(),
    );
    await ref.read(sheetsSyncStoreProvider).saveSettings(_settings);
  }

  Future<void> _persistCredentials() async {
    _credentials = SheetsCredentials(
      clientId: _clientIdController.text.trim(),
      clientSecret: _clientSecretController.text.trim(),
      refreshToken: _refreshTokenController.text.trim(),
    );
    await ref.read(sheetsSyncStoreProvider).saveCredentials(_credentials!);
  }

  Future<void> _pushNow() async {
    final messenger = ScaffoldMessenger.of(context);
    final workbook = _buildWorkbook();
    if (workbook == null) return;
    await _persistSettings();
    await _persistCredentials();
    setState(() => _pushing = true);
    try {
      final outcome = await ref.read(sheetsSyncServiceProvider).pushNow(
            workbook,
            settings: _settings,
            credentials: _credentials,
          );
      messenger.showSnackBar(SnackBar(content: Text(_describe(outcome))));
    } finally {
      if (mounted) setState(() => _pushing = false);
    }
  }

  String _describe(SheetsPushOutcome outcome) => switch (outcome.status) {
        SheetsPushStatus.pushed =>
          'Pushed ${outcome.result?.updatedSheets ?? 0} sheets to Google Sheets',
        SheetsPushStatus.skippedDisabled => 'Sync is turned off',
        SheetsPushStatus.skippedNotConfigured =>
          'Add a spreadsheet ID and your credentials first',
        SheetsPushStatus.unsupported =>
          'Google Sheets sync is not available in this build',
        SheetsPushStatus.failed => 'Push failed: ${outcome.message}',
      };
}
