import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/official_codex_theme.dart';

class CodexPopoverController extends ChangeNotifier {
  bool _isOpen = false;
  bool get isOpen => _isOpen;

  void show() {
    if (!_isOpen) {
      _isOpen = true;
      notifyListeners();
    }
  }

  void hide() {
    if (_isOpen) {
      _isOpen = false;
      notifyListeners();
    }
  }

  void toggle() {
    _isOpen = !_isOpen;
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
  late final CodexPopoverController _controller;
  OverlayEntry? _entry;

  @override
  void initState() {
    super.initState();
    _controller = widget.controller ?? CodexPopoverController();
    _controller.addListener(_handleControllerChange);
  }

  @override
  void didUpdateWidget(covariant CodexPopoverAnchor oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.controller != oldWidget.controller) {
      oldWidget.controller?.removeListener(_handleControllerChange);
      _controller = widget.controller ?? CodexPopoverController();
      _controller.addListener(_handleControllerChange);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerChange);
    _hidePopover();
    super.dispose();
  }

  void _handleControllerChange() {
    if (_controller.isOpen) {
      _showPopover();
    } else {
      _hidePopover();
    }
  }

  void _showPopover() {
    if (_entry != null) return;
    final overlay = Overlay.maybeOf(context);
    if (overlay == null) return;

    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;

    _entry = OverlayEntry(
      builder: (context) => Stack(
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
          CompositedTransformFollower(
            link: _link,
            showWhenUnlinked: false,
            targetAnchor: widget.targetAnchor,
            followerAnchor: widget.followerAnchor,
            offset: widget.offset,
            child: Align(
              alignment: widget.followerAnchor,
              child: CallbackShortcuts(
                bindings: {
                  const SingleActivator(LogicalKeyboardKey.escape):
                      _controller.hide,
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
              ),
            ),
          ),
        ],
      ),
    );

    overlay.insert(_entry!);
  }

  void _hidePopover() {
    _entry?.remove();
    _entry = null;
  }

  @override
  Widget build(BuildContext context) {
    return CompositedTransformTarget(link: _link, child: widget.child);
  }
}
