/// What the town shell's taps and buttons open at home: a plot's sheet, a
/// house's room, the dungeon gate, quick entry, the Goals pane and the shop.
/// A shell mixin so `town_shell.dart` stays a readable build.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/town/districts.dart' show kOutpostDistrictId;
import '../../domain/town/town_view.dart';
import '../building_sheet.dart';
import 'farm_plot_sheet.dart';
import 'town_place_openers.dart';
import 'town_shell.dart';

mixin TownShellActions on ConsumerState<TownShell> {
  /// A tap on [target] in this adult's own town.
  void openHomeTarget(TownTarget target) {
    final openers = widget.openers;
    switch (target) {
      case PlotTarget(:final plotIndex, :final districtId) when districtId != kOutpostDistrictId:
        unawaited(showFarmPlotSheet(context, plotIndex: plotIndex));
      case PlotTarget(:final plotIndex):
        unawaited(
          showBuildingSheet(context, plotIndex: plotIndex, onOpenLedger: widget.onOpenLedger, links: widget.links),
        );
      case HouseTarget(:final personId):
        final openRoom = openers.openRoom;
        if (openRoom != null) {
          openRoom(context, personId);
        } else {
          unawaited(showPlaceComingSheet(context, title: 'Home', body: 'Rooms you can decorate are on their way.'));
        }
      case SignpostTarget():
        break; // The shell opens the signpost before it gets here.
      case GateTarget():
        final openDungeon = openers.openDungeon;
        if (openDungeon != null) {
          openDungeon(context);
        } else {
          unawaited(
            showPlaceComingSheet(
              context,
              title: 'The dungeon gate',
              body: 'Each month the gate opens for dividing your leftovers.',
            ),
          );
        }
    }
  }

  /// Quick entry: one tap from the town (the ledger when no link is wired).
  void logPurchase() {
    final openEntry = widget.links.logPurchase;
    if (openEntry != null) {
      openEntry(context);
    } else {
      widget.onOpenLedger();
    }
  }

  /// The ledger's Goals pane (the ledger when no link is wired).
  void openGoals() {
    final openGoalsPane = widget.links.openGoals;
    if (openGoalsPane != null) {
      openGoalsPane(context);
    } else {
      widget.onOpenLedger();
    }
  }

  void openShop() {
    final openShop = widget.openers.openShop;
    if (openShop != null) {
      openShop(context);
    } else {
      unawaited(
        showPlaceComingSheet(
          context,
          title: 'Shop',
          body: 'A new set of decorations arrives every day — opening soon.',
        ),
      );
    }
  }
}
