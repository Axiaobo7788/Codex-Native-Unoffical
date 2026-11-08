import 'package:flutter/material.dart';

import '../theme/official_codex_theme.dart';
import 'codex_button.dart';

/// Semantic tool and command activity row primitive conforming to official
/// Codex desktop specifications (34px height, 8px radius, hairline border, monospace summary).
class CodexActivityRow extends StatelessWidget {
  const CodexActivityRow({
    super.key,
    required this.summary,
    this.icon,
    this.statusText,
    this.isRunning = false,
    this.isError = false,
    this.onViewOutput,
    this.actionLabel = 'View output',
    this.trailingAction,
    this.textWidget,
  });

  final String summary;
  final Widget? icon;
  final String? statusText;
  final bool isRunning;
  final bool isError;
  final VoidCallback? onViewOutput;
  final String actionLabel;
  final Widget? trailingAction;
  final Widget? textWidget;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);

    return Container(
      height: OfficialCodexTheme.activityRowHeight,
      margin: const EdgeInsets.symmetric(vertical: 3.0),
      padding: const EdgeInsets.symmetric(horizontal: 10.0),
      decoration: BoxDecoration(
        color: theme.elevatedSurface,
        borderRadius: BorderRadius.circular(
          OfficialCodexTheme.activityRowRadius,
        ),
        border: Border.all(
          color: isError
              ? theme.danger.withValues(alpha: 0.5)
              : theme.hairlineBorder,
          width: OfficialCodexTheme.hairlineBorderWidth,
        ),
      ),
      child: Row(
        children: [
          if (isRunning) ...[
            SizedBox(
              width: 14.0,
              height: 14.0,
              child: CircularProgressIndicator(
                strokeWidth: 2.0,
                valueColor: AlwaysStoppedAnimation<Color>(theme.accent),
              ),
            ),
          ] else ...[
            IconTheme(
              data: IconThemeData(
                color: isError ? theme.danger : theme.textMuted,
                size: 14.0,
              ),
              child: icon ?? const Icon(Icons.terminal_rounded),
            ),
          ],
          const SizedBox(width: 8.0),
          Expanded(
            child:
                textWidget ??
                Text(
                  summary,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'monospace',
                    fontSize: 12.5,
                    color: isError ? theme.danger : theme.textPrimary,
                  ),
                ),
          ),
          if (statusText != null && statusText!.isNotEmpty) ...[
            const SizedBox(width: 8.0),
            Text(
              statusText!,
              style: TextStyle(fontSize: 11.5, color: theme.textMuted),
            ),
          ],
          if (trailingAction != null) ...[
            const SizedBox(width: 8.0),
            trailingAction!,
          ] else if (onViewOutput != null) ...[
            const SizedBox(width: 8.0),
            CodexButton(
              onPressed: onViewOutput,
              label: actionLabel,
              variant: CodexButtonVariant.ghost,
              size: CodexButtonSize.sm,
            ),
          ],
        ],
      ),
    );
  }
}

/// Semantic turn work divider primitive ("Worked for Xm Ys ›") with centered hairline rule
/// and interactive collapsible pill button.
class CodexActivityDivider extends StatelessWidget {
  const CodexActivityDivider({
    super.key,
    required this.label,
    required this.isExpanded,
    required this.onToggle,
    this.isLoading = false,
  });

  final String label;
  final bool isExpanded;
  final VoidCallback onToggle;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Divider(
            height: 1.0,
            thickness: OfficialCodexTheme.hairlineBorderWidth,
            color: theme.hairlineBorder,
          ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onToggle,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Container(
                height: OfficialCodexTheme.workDividerHeight,
                padding: const EdgeInsets.symmetric(horizontal: 10.0),
                decoration: BoxDecoration(
                  color: theme.workspaceBackground,
                  borderRadius: BorderRadius.circular(
                    OfficialCodexTheme.workDividerHeight / 2,
                  ),
                  border: Border.all(
                    color: theme.hairlineBorder,
                    width: OfficialCodexTheme.hairlineBorderWidth,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 12.0,
                        color: theme.textMuted,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(width: 4.0),
                    if (isLoading)
                      Padding(
                        padding: const EdgeInsets.only(left: 2.0),
                        child: SizedBox(
                          width: 12.0,
                          height: 12.0,
                          child: CircularProgressIndicator(
                            strokeWidth: 1.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              theme.textMuted,
                            ),
                          ),
                        ),
                      )
                    else
                      Icon(
                        isExpanded
                            ? Icons.keyboard_arrow_up_rounded
                            : Icons.keyboard_arrow_right_rounded,
                        size: 14.0,
                        color: theme.textMuted,
                      ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
