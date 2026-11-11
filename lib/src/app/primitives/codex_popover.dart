import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/official_codex_theme.dart';

class CodexPopoverController extends ChangeNotifier {
  bool _isOpen = false;
  Offset? _globalPosition;
  bool get isOpen => _isOpen;
  Offset? get globalPosition => _globalPosition;

  void show({Offset? globalPosition}) {
    if (!_isOpen || _globalPosition != globalPosition) {
      _isOpen = true;
      _globalPosition = globalPosition;
      notifyListeners();
    }
  }

  void hide() {
    if (_isOpen) {
      _isOpen = false;
      _globalPosition = null;
      notifyListeners();
    }
  }

  void toggle() {
    _isOpen = !_isOpen;
    if (!_isOpen) {
      _globalPosition = null;
    }
    notifyListeners();
  }
}

/// A desktop-first, non-blocking anchored popover conforming to official
/// Codex desktop specifications (16px/20px radius, Tier 2 surface, outside tap & escape dismiss).
class CodexPopoverAnchor extends StatefulWidget {
  const CodexPopoverAnchor({
    super.key,
    required this.popoverBuilder,
    required this.child,
    this.controller,
    this.followerAnchor = Alignment.topLeft,
    this.targetAnchor = Alignment.bottomLeft,
    this.offset = const Offset(0, 6.0),
    this.radius = OfficialCodexTheme.popoverRadius,
    this.width,
  });

  final Widget Function(BuildContext context, VoidCallback close)
  popoverBuilder;
  final Widget child;
  final CodexPopoverController? controller;
  final Alignment followerAnchor;
  final Alignment targetAnchor;
  final Offset offset;
  final double radius;
  final double? width;

  @override
  State<CodexPopoverAnchor> createState() => _CodexPopoverAnchorState();
}

class _CodexPopoverAnchorState extends State<CodexPopoverAnchor> {
  final _link = LayerLink();
  late CodexPopoverController _controller;
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _bindController();
  }

  @override
  void didUpdateWidget(covariant CodexPopoverAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      _unbindController(owned: oldWidget.controller == null);
      _bindController();
    }
  }

  @override
  void dispose() {
    _unbindController(owned: widget.controller == null);
    super.dispose();
  }

  void _bindController() {
    final controller = widget.controller ?? CodexPopoverController();
    _controller = controller;
    controller.addListener(_handleControllerChange);
    if (controller.isOpen) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted &&
            identical(_controller, controller) &&
            controller.isOpen) {
          _showPopover();
        }
      });
    }
  }

  void _unbindController({required bool owned}) {
    _controller.removeListener(_handleControllerChange);
    _hidePopover();
    if (owned) {
      _controller.dispose();
    }
  }

  void _handleControllerChange() {
    if (_controller.isOpen) {
      if (_entry != null) {
        _entry!.markNeedsBuild();
      } else {
        _showPopover();
      }
    } else {
      _hidePopover();
    }
  }

  Widget _buildPopoverSurface(
    BuildContext context,
    OfficialCodexThemeData theme,
  ) {
    final isDark = theme.isDark;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _controller.hide,
      },
      child: FocusScope(
        autofocus: true,
        child: Material(
          type: MaterialType.transparency,
          child: Container(
            width: widget.width,
            decoration: BoxDecoration(
              color: theme.elevatedSurface,
              borderRadius: BorderRadius.circular(widget.radius),
              border: Border.all(
                color: theme.hairlineBorder,
                width: OfficialCodexTheme.hairlineBorderWidth,
              ),
              boxShadow: [
                BoxShadow(
                  color: isDark
                      ? const Color(0x66000000)
                      : const Color(0x24000000),
                  blurRadius: 24.0,
                  offset: const Offset(0, 8.0),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: widget.popoverBuilder(context, _controller.hide),
          ),
        ),
      ),
    );
  }

  void _showPopover() {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final theme = OfficialCodexTheme.of(context);

    _entry = OverlayEntry(
      builder: (context) {
        final surface = _buildPopoverSurface(context, theme);
        final globalPos = _controller.globalPosition;
        final overlayBox = overlay.context.findRenderObject() as RenderBox?;
        final localPos = globalPos != null && overlayBox != null
            ? overlayBox.globalToLocal(globalPos)
            : globalPos;
        return Stack(
          children: [
            // Dismiss on outside tap
            Positioned.fill(
              child: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onTap: _controller.hide,
                child: const SizedBox.expand(),
              ),
            ),
            // Popover body
            if (localPos != null)
              Positioned.fill(
                child: CustomSingleChildLayout(
                  delegate: _PointPopoverLayoutDelegate(localPos),
                  child: surface,
                ),
              )
            else
              CompositedTransformFollower(
                link: _link,
                showWhenUnlinked: false,
                targetAnchor: widget.targetAnchor,
                followerAnchor: widget.followerAnchor,
                offset: widget.offset,
                child: Align(alignment: widget.followerAnchor, child: surface),
              ),
          ],
        );
      },
    );

    overlay.insert(_entry!);
  }

  void _hidePopover() {
    final entry = _entry;
    _entry = null;
    entry?.remove();
    entry?.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _link, child: widget.child);
  }
}

class _PointPopoverLayoutDelegate extends SingleChildLayoutDelegate {
  const _PointPopoverLayoutDelegate(this.position);

  final Offset position;
  static const double _edgePadding = 8.0;

  @override
  BoxConstraints getConstraintsForChild(BoxConstraints constraints) =>
      constraints.loosen();

  @override
  Offset getPositionForChild(Size size, Size childSize) {
    final maxX = math.max(
      _edgePadding,
      size.width - childSize.width - _edgePadding,
    );
    final maxY = math.max(
      _edgePadding,
      size.height - childSize.height - _edgePadding,
    );
    return Offset(
      position.dx.clamp(_edgePadding, maxX),
      position.dy.clamp(_edgePadding, maxY),
    );
  }

  @override
  bool shouldRelayout(covariant _PointPopoverLayoutDelegate oldDelegate) =>
      oldDelegate.position != position;
}
