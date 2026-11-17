/// "Decorate town" mode wired into the town shell, with the Menu that
/// toggles it: while decorating, taps place the picked item instead of
/// opening buildings. Decorating opens the outpost (where decorations
/// stand) and ends when a visit to a neighbour starts.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../features/menu/manage_screen.dart';
import '../../../features/rewards/trophy_hall_screen.dart';
import '../../../features/settings/play_mode.dart';
import '../../../features/settings/play_mode_switch.dart';
import '../../domain/decor/catalog.dart';
import '../../domain/decor/decor_values.dart';
import '../../domain/town/districts.dart' show kOutpostDistrictId;
import '../../domain/town/town_layout.dart' show TownCell;
import '../../skin_prefs.dart';
import '../hall_common.dart';
import 'town_book_screen.dart';
import 'town_menu_dialog.dart';
import 'town_shell.dart';

mixin TownDecorateWiring on ConsumerState<TownShell> {
  bool _decorating = false;
  DecorItem? _picked;

  /// Opens a district (from the district wiring).
  void openDistrict(String districtId);

  /// Decorate mode is on.
  bool get decoratingTown => _decorating;

  /// The item a tap will place, if one is picked.
  DecorItem? get pickedDecoration => _picked;

  void pickDecoration(DecorItem item) => setState(() => _picked = item);

  /// Ends decorate mode without a rebuild (call inside a `setState`).
  void endDecorating() {
    _decorating = false;
    _picked = null;
  }

  /// Places the picked item at [cell] through the real command.
  Future<void> placeInTown(TownCell cell) async {
    final picked = _picked;
    if (picked == null) return;
    await runHallCommand(
      context,
      ref,
      (service) => service.placeItem(itemId: picked.id, space: DecorSpace.town, column: cell.column, row: cell.row),
    );
    if (mounted) setState(() => _picked = null);
  }

  /// Decorations stand in the outpost, so decorating opens it.
  void toggleDecorating() {
    if (!_decorating) openDistrict(kOutpostDistrictId);
    setState(() {
      _decorating = !_decorating;
      _picked = null;
    });
  }

  void openTownMenu() => unawaited(
    showTownMenu(
      context,
      TownMenuActions(
        decorating: _decorating,
        openSettings: () => unawaited(ManageScreen.open(context)),
        switchToStandard: () =>
            unawaited(confirmAndSwitchPlayMode(context, ref, PlayMode.standard, returnHome: true)),
        toggleTextMode: () => ref.read(adventureTierProvider.notifier).toggle(),
        toggleDecorating: toggleDecorating,
        openTrophies: () => unawaited(TrophyHallScreen.open(context)),
        openTownBook: () => unawaited(TownBookScreen.open(context)),
      ),
    ),
  );
}
