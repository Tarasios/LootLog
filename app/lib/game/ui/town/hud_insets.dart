/// How much of a phone's town the HUD covers, measured as it lays out, so
/// the scene's camera can centre the district between the HUD rows and pan
/// far enough to bring every plot clear of them (`CameraControls.setInsets`).
library;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// The HUD's top and bottom cover, in screen pixels. The HUDs write it; the
/// scene listens.
class HudInsets extends ValueNotifier<EdgeInsets> {
  HudInsets() : super(EdgeInsets.zero);

  final Map<Object, double> _tops = {};

  /// One piece hanging from the top (a corner of chips) reaches [bottomEdge]
  /// screen pixels down; the top cover is the lowest of them.
  void reportTop(Object piece, double bottomEdge) {
    _tops[piece] = bottomEdge;
    final top = _tops.values.fold(0.0, (lowest, edge) => edge > lowest ? edge : lowest);
    if (value.top != top) value = value.copyWith(top: top);
  }

  void setBottom(double bottom) {
    if (value.bottom != bottom) value = value.copyWith(bottom: bottom);
  }

  /// A wide window's HUD sits in the corners: no cover to account for.
  void clear() {
    _tops.clear();
    if (value != EdgeInsets.zero) value = EdgeInsets.zero;
  }
}

/// Reports [child]'s laid-out size after the frame whenever it changes.
class ReportSize extends SingleChildRenderObjectWidget {
  const ReportSize({super.key, required this.onSize, super.child});

  final ValueChanged<Size> onSize;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderReportSize(onSize);

  @override
  void updateRenderObject(BuildContext context, _RenderReportSize renderObject) =>
      renderObject.onSize = onSize;
}

class _RenderReportSize extends RenderProxyBox {
  _RenderReportSize(this.onSize);

  ValueChanged<Size> onSize;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final laidOut = size;
    if (laidOut == _reported) return;
    _reported = laidOut;
    WidgetsBinding.instance.addPostFrameCallback((_) => onSize(laidOut));
  }
}
