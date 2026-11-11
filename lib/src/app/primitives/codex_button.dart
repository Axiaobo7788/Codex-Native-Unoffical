import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/official_codex_theme.dart';
import 'codex_tooltip.dart';

enum CodexButtonVariant { primary, secondary, ghost, danger }

enum CodexButtonSize { sm, md, lg, toolbar }

/// A desktop-first, zero-ink-ripple semantic button conforming to official
/// ChatGPT / Codex desktop specifications.
class CodexButton extends StatefulWidget {
  const CodexButton({
    super.key,
    required this.onPressed,
    this.label,
    this.icon,
    this.trailingIcon,
    this.variant = CodexButtonVariant.secondary,
    this.size = CodexButtonSize.md,
    this.loading = false,
    this.selected = false,
    this.width,
    this.tooltip,
    this.child,
  });

  final VoidCallback? onPressed;
  final String? label;
  final Widget? icon;
  final Widget? trailingIcon;
  final CodexButtonVariant variant;
  final CodexButtonSize size;
  final bool loading;
  final bool selected;
  final double? width;
  final String? tooltip;
  final Widget? child;

  bool get isEnabled => onPressed != null && !loading;

  @override
  State<CodexButton> createState() => _CodexButtonState();
}

class _CodexButtonState extends State<CodexButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  void didUpdateWidget(covariant CodexButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEnabled && (_isHovered || _isPressed || _isFocused)) {
      _isHovered = false;
      _isPressed = false;
      _isFocused = false;
    }
  }

  void _handleHover(bool hovering) {
    final next = widget.isEnabled && hovering;
    if (next != _isHovered) {
      setState(() => _isHovered = next);
    }
  }

  void _handleFocus(bool focused) {
    final next = widget.isEnabled && focused;
    if (next != _isFocused) {
      setState(() => _isFocused = next);
    }
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.isEnabled) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;

    final double height;
    final double fontSize;
    final EdgeInsets padding;
    switch (widget.size) {
      case CodexButtonSize.sm:
        height = 28.0;
        fontSize = 12.0;
        padding = const EdgeInsets.symmetric(horizontal: 8.0);
        break;
      case CodexButtonSize.md:
        height = 34.0;
        fontSize = 13.0;
        padding = const EdgeInsets.symmetric(horizontal: 12.0);
        break;
      case CodexButtonSize.lg:
        height = 40.0;
        fontSize = 14.0;
        padding = const EdgeInsets.symmetric(horizontal: 16.0);
        break;
      case CodexButtonSize.toolbar:
        height = 28.0;
        fontSize = 13.0;
        padding = const EdgeInsets.symmetric(horizontal: 8.0);
        break;
    }

    // Resolve surface and text colors based on variant & state
    Color background;
    Color textColor;
    Border? border;

    switch (widget.variant) {
      case CodexButtonVariant.primary:
        background = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0D0D0D);
        textColor = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);
        if (_isPressed) {
          background = isDark
              ? const Color(0xFFE5E5E5)
              : const Color(0xFF262626);
        } else if (_isHovered) {
          background = isDark
              ? const Color(0xFFF2F2F2)
              : const Color(0xFF1F1F1F);
        }
        break;

      case CodexButtonVariant.secondary:
        background = theme.elevatedSurface;
        textColor = theme.textPrimary;
        border = Border.all(
          color: _isFocused ? theme.focusRing : theme.hairlineBorder,
          width: _isFocused ? 1.5 : OfficialCodexTheme.hairlineBorderWidth,
        );
        if (_isPressed) {
          background = isDark
              ? const Color(0xFF383838)
              : const Color(0xFFE5E5E5);
        } else if (_isHovered) {
          background = isDark
              ? const Color(0xFF333333)
              : const Color(0xFFECECEC);
        }
        break;

      case CodexButtonVariant.ghost:
        background = Colors.transparent;
        textColor = theme.textPrimary;
        if (widget.selected) {
          background = theme.selectedTint;
        } else if (_isPressed) {
          background = theme.pressedTint;
        } else if (_isHovered) {
          background = theme.hoverTint;
        }
        if (_isFocused) {
          border = Border.all(color: theme.focusRing, width: 1.5);
        }
        break;

      case CodexButtonVariant.danger:
        background = Colors.transparent;
        textColor = theme.danger;
        border = Border.all(
          color: theme.danger.withValues(alpha: 0.5),
          width: OfficialCodexTheme.hairlineBorderWidth,
        );
        if (_isPressed) {
          background = theme.danger.withValues(alpha: 0.2);
        } else if (_isHovered) {
          background = theme.danger.withValues(alpha: 0.1);
        }
        break;
    }

    final content = Row(
      mainAxisSize: widget.width != null ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.loading) ...[
          SizedBox(
            width: 14.0,
            height: 14.0,
            child: CircularProgressIndicator(
              strokeWidth: 2.0,
              valueColor: AlwaysStoppedAnimation<Color>(textColor),
            ),
          ),
          const SizedBox(width: 8.0),
        ] else if (widget.icon != null) ...[
          IconTheme(
            data: IconThemeData(color: textColor, size: fontSize + 3.0),
            child: widget.icon!,
          ),
          if (widget.label != null || widget.child != null)
            const SizedBox(width: 6.0),
        ],
        if (widget.child != null)
          Flexible(child: widget.child!)
        else if (widget.label != null)
          Flexible(
            child: Text(
              widget.label!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: textColor,
                fontSize: fontSize,
                height: widget.size == CodexButtonSize.toolbar ? 18 / 13 : null,
                fontWeight: widget.size == CodexButtonSize.toolbar
                    ? FontWeight.w400
                    : FontWeight.w500,
                letterSpacing: -0.1,
              ),
            ),
          ),
        if (widget.trailingIcon != null) ...[
          const SizedBox(width: 6.0),
          IconTheme(
            data: IconThemeData(color: textColor, size: fontSize + 2.0),
            child: widget.trailingIcon!,
          ),
        ],
      ],
    );

    Widget result = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      height: height,
      width: widget.width,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(
          widget.size == CodexButtonSize.toolbar
              ? OfficialCodexTheme.iconButtonRadius
              : OfficialCodexTheme.buttonRadius,
        ),
        border: border,
      ),
      child: Transform.scale(scale: _isPressed ? 0.99 : 1.0, child: content),
    );

    if (!widget.isEnabled) {
      result = Opacity(opacity: 0.45, child: result);
    }

    result = FocusableActionDetector(
      enabled: widget.isEnabled,
      onShowHoverHighlight: _handleHover,
      onShowFocusHighlight: _handleFocus,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onPressed?.call(),
        ),
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isEnabled ? widget.onPressed : null,
        onTapDown: widget.isEnabled ? _handleTapDown : null,
        onTapUp: widget.isEnabled ? _handleTapUp : null,
        onTapCancel: widget.isEnabled ? _handleTapCancel : null,
        child: MouseRegion(
          cursor: widget.isEnabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: result,
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      result = CodexTooltip(message: widget.tooltip!, child: result);
    }

    return Semantics(
      button: true,
      enabled: widget.isEnabled,
      label: widget.label,
      child: result,
    );
  }
}

/// A desktop-first semantic icon action button without ink ripples.
class CodexIconButton extends StatefulWidget {
  const CodexIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.size = 32.0,
    this.iconSize,
    this.variant = CodexButtonVariant.ghost,
    this.shape = BoxShape.rectangle,
    this.tooltip,
    this.selected = false,
    this.disabledOpacity = 0.45,
  });

  final VoidCallback? onPressed;
  final Widget icon;
  final double size;
  final double? iconSize;
  final CodexButtonVariant variant;
  final BoxShape shape;
  final String? tooltip;
  final bool selected;
  final double disabledOpacity;

  bool get isEnabled => onPressed != null;

  @override
  State<CodexIconButton> createState() => _CodexIconButtonState();
}

class _CodexIconButtonState extends State<CodexIconButton> {
  bool _isHovered = false;
  bool _isPressed = false;
  bool _isFocused = false;

  @override
  void didUpdateWidget(covariant CodexIconButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isEnabled && (_isHovered || _isPressed || _isFocused)) {
      _isHovered = false;
      _isPressed = false;
      _isFocused = false;
    }
  }

  void _handleHover(bool hovering) {
    final next = widget.isEnabled && hovering;
    if (next != _isHovered) {
      setState(() => _isHovered = next);
    }
  }

  void _handleFocus(bool focused) {
    final next = widget.isEnabled && focused;
    if (next != _isFocused) {
      setState(() => _isFocused = next);
    }
  }

  void _handleTapDown(TapDownDetails _) {
    if (widget.isEnabled) {
      setState(() => _isPressed = true);
    }
  }

  void _handleTapUp(TapUpDetails _) {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  void _handleTapCancel() {
    if (_isPressed) {
      setState(() => _isPressed = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final isDark = theme.isDark;

    Color background = Colors.transparent;
    Color iconColor = theme.textPrimary;
    Border? border;

    switch (widget.variant) {
      case CodexButtonVariant.primary:
        background = isDark ? const Color(0xFFFFFFFF) : const Color(0xFF0D0D0D);
        iconColor = isDark ? const Color(0xFF0D0D0D) : const Color(0xFFFFFFFF);
        if (_isPressed) {
          background = isDark
              ? const Color(0xFFE5E5E5)
              : const Color(0xFF262626);
        } else if (_isHovered) {
          background = isDark
              ? const Color(0xFFF2F2F2)
              : const Color(0xFF1F1F1F);
        }
        break;

      case CodexButtonVariant.secondary:
        background = theme.elevatedSurface;
        iconColor = theme.textPrimary;
        border = Border.all(
          color: _isFocused ? theme.focusRing : theme.hairlineBorder,
          width: _isFocused ? 1.5 : OfficialCodexTheme.hairlineBorderWidth,
        );
        if (_isPressed) {
          background = isDark
              ? const Color(0xFF383838)
              : const Color(0xFFE5E5E5);
        } else if (_isHovered) {
          background = isDark
              ? const Color(0xFF333333)
              : const Color(0xFFECECEC);
        }
        break;

      case CodexButtonVariant.ghost:
        background = Colors.transparent;
        iconColor = theme.textSecondary;
        if (widget.selected) {
          background = theme.selectedTint;
          iconColor = theme.textPrimary;
        } else if (_isPressed) {
          background = theme.pressedTint;
          iconColor = theme.textPrimary;
        } else if (_isHovered) {
          background = theme.hoverTint;
          iconColor = theme.textPrimary;
        }
        if (_isFocused) {
          border = Border.all(color: theme.focusRing, width: 1.5);
        }
        break;

      case CodexButtonVariant.danger:
        background = Colors.transparent;
        iconColor = theme.danger;
        if (_isPressed) {
          background = theme.danger.withValues(alpha: 0.2);
        } else if (_isHovered) {
          background = theme.danger.withValues(alpha: 0.1);
        }
        break;
    }

    final double effectiveIconSize = widget.iconSize ?? (widget.size * 0.52);

    Widget result = AnimatedContainer(
      duration: const Duration(milliseconds: 80),
      curve: Curves.easeOut,
      width: widget.size,
      height: widget.size,
      decoration: BoxDecoration(
        color: background,
        shape: widget.shape,
        borderRadius: widget.shape == BoxShape.rectangle
            ? BorderRadius.circular(OfficialCodexTheme.iconButtonRadius)
            : null,
        border: border,
      ),
      child: Center(
        child: Transform.scale(
          scale: _isPressed ? 0.96 : 1.0,
          child: IconTheme(
            data: IconThemeData(color: iconColor, size: effectiveIconSize),
            child: widget.icon,
          ),
        ),
      ),
    );

    if (!widget.isEnabled) {
      result = Opacity(opacity: widget.disabledOpacity, child: result);
    }

    result = FocusableActionDetector(
      enabled: widget.isEnabled,
      onShowHoverHighlight: _handleHover,
      onShowFocusHighlight: _handleFocus,
      actions: {
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) => widget.onPressed?.call(),
        ),
      },
      shortcuts: const {
        SingleActivator(LogicalKeyboardKey.enter): ActivateIntent(),
        SingleActivator(LogicalKeyboardKey.space): ActivateIntent(),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.isEnabled ? widget.onPressed : null,
        onTapDown: widget.isEnabled ? _handleTapDown : null,
        onTapUp: widget.isEnabled ? _handleTapUp : null,
        onTapCancel: widget.isEnabled ? _handleTapCancel : null,
        child: MouseRegion(
          cursor: widget.isEnabled
              ? SystemMouseCursors.click
              : SystemMouseCursors.basic,
          child: result,
        ),
      ),
    );

    if (widget.tooltip != null && widget.tooltip!.isNotEmpty) {
      result = CodexTooltip(message: widget.tooltip!, child: result);
    }

    return Semantics(
      button: true,
      enabled: widget.isEnabled,
      label: widget.tooltip,
      child: result,
    );
  }
}
