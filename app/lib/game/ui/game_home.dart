/// The guild hall — the Adventure-mode home screen.
///
/// A sectioned home: the party (gems, freeze tokens, streak, members, the
/// supply caravan), today's habits (the Scribe's Desk into the ledger, the
/// no-spend check-in, the weekly reconcile), the inbox of chests and rewards,
/// the spoils-ritual callout, the shared stores, the plots, and the places to
/// go (Forge & hero, Expeditions, Vault, the ritual). A "Log a purchase"
/// button is always on screen, so logging stays one tap from launch.
///
/// One column on a phone, two on a desktop. Renders fully in the text tier
/// (the first-class text-adventure look) and in the pixel tier through
/// `GameSprite` asset keys.
///
/// Built only behind the Adventure mode gate (`features/shell/home_gate.dart`);
/// Standard mode never constructs it. Every way into the ledger is handed in
/// ([onOpenLedger], [links]) so the game layer never depends on the app shell;
/// the overflow menu holds the shared Adventure / Standard switch.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/play_mode_switch.dart';
import '../../ui/glossary.dart';
import '../../ui/theme.dart';
import '../data/game_providers.dart';
import '../domain/game_state.dart';
import '../skin_prefs.dart';
import 'hall_common.dart';
import 'hall_home_sections.dart';
import 'hall_ledger_view.dart';
import 'hall_voice.dart';

export 'hall_common.dart' show HallLinks;

/// The width at or above which the hall lays out in two columns.
const double kHallWideBreakpoint = 840;

class GameHome extends StatelessWidget {
  const GameHome({
    super.key,
    required this.onOpenLedger,
    this.links = const HallLinks(),
  });

  /// Opens the budgeting ledger (logging, budgets, settings).
  final VoidCallback onOpenLedger;

  /// Direct links into ledger screens (quick entry, the ritual's steps).
  final HallLinks links;

  @override
  Widget build(BuildContext context) => HallScope(
        child: _HallScaffold(onOpenLedger: onOpenLedger, links: links),
      );
}

class _HallScaffold extends ConsumerWidget {
  const _HallScaffold({required this.onOpenLedger, required this.links});

  final VoidCallback onOpenLedger;
  final HallLinks links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final game = ref.watch(gameStateProvider);
    final tier = ref.watch(adventureTierProvider);
    final textTier = tier == AdventureTier.text;
    return Scaffold(
      appBar: AppBar(
        title: Text(_cap(Glossary.guildHall.adventure)),
        automaticallyImplyLeading: false,
        actions: [
          IconButton(
            tooltip: textTier ? 'Pixel mode' : 'Text mode',
            icon: Icon(textTier ? Icons.grid_on : Icons.notes),
            onPressed: () => ref.read(adventureTierProvider.notifier).toggle(),
          ),
          TextButton.icon(
            onPressed: onOpenLedger,
            icon: const Icon(Icons.menu_book),
            label: const Text('Ledger'),
          ),
          const PlayModeMenuButton(),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          final log = links.logPurchase;
          if (log != null) {
            log(context);
          } else {
            onOpenLedger();
          }
        },
        icon: const Icon(Icons.add),
        label: const Text('Log a purchase'),
      ),
      body: switch (game) {
        AsyncData(:final value) => _HallBody(
            game: value, onOpenLedger: onOpenLedger, links: links),
        AsyncError() => _HallBody(
            game: GameState.initial(), onOpenLedger: onOpenLedger, links: links),
        _ => const Center(child: Text('Lighting the hall lamps…')),
      },
    );
  }
}

class _HallBody extends ConsumerWidget {
  const _HallBody({
    required this.game,
    required this.onOpenLedger,
    required this.links,
  });

  final GameState game;
  final VoidCallback onOpenLedger;
  final HallLinks links;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final view = ref.watch(hallLedgerViewProvider);
    final voice = ref.watch(hallVoiceProvider).value ?? HallVoice.empty;
    final clock = ref.watch(gameClockProvider);
    return HallTicker(builder: (context) {
      final data = HallHomeData(
        game: game,
        view: view,
        voice: voice,
        now: clock.now(),
        onOpenLedger: onOpenLedger,
        links: links,
      );
      final left = [
        PartyHeader(data),
        HabitPanel(data),
        InboxPanel(data),
        RitualCallout(data),
      ];
      final right = [
        PlotsPanel(data),
        StoresPanel(data),
        PlacesPanel(data),
      ];
      // Room under the last section for the floating "Log a purchase".
      const fabRoom = SizedBox(height: 88);
      return LayoutBuilder(builder: (context, constraints) {
        if (constraints.maxWidth >= kHallWideBreakpoint) {
          return SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 1200),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: left,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [...right, fabRoom],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          );
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [...left, ...right, fabRoom],
          ),
        );
      });
    });
  }
}

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
