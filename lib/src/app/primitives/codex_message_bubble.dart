import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../features/conversation/assistant_markdown.dart';
import '../theme/official_codex_theme.dart';

/// Semantic user message bubble primitive translated from official Codex
/// Desktop `.bubble-vBnidZ` / `14353.dKZq` / `189497.oQwr` / `225284.y5H2`:
/// - `70%` max width of the actual containing reading column (`--user-chat-width: 70%`)
/// - `22px` borderless radius (`--radius-2xl`), `16×10` padding, `5%` ink fill
/// - `14px` `.text-size-chat` (`sansFontSize.default = 14`) with `1.625`
///   `leading-relaxed` line box and zero compact-only negative letter-spacing
/// - `20`-line collapse (`D = 20`, bounded measurement slice `B = 512 * D = 10,240`):
///   in official `14353.dKZq`, `P($ ? R.slice(0, B) : R)` slices child source
///   only when `R.length > B`; for `<= 10,240` chars, `dKZq` clips full children
///   via CSS `max-height: 19lh` + `overflow-hidden`, toggles `inert` /
///   `aria-hidden="true"` via `IntersectionObserver` only on clipped interactive
///   descendants (`a[href]`, `button`, inputs, `[tabindex]`), appends an
///   `aria-hidden` `'…'` line, and renders a `data-markdown-copy="exclude"`
///   `'Show more'` / `'Show less'` button (`ghostUserMessage` + rotating
///   `.icon-2xs` chevron), while `225284.y5H2` toolbar Copy copies the full
///   prompt in both states.
/// - Calibrated Flutter `SelectableText` tradeoff: because `SelectableText`
///   (`EditableText`) scrolls internally under bounded `maxLines`/`maxHeight`
///   and projects root-overlay selection handles outside a `ClipRect` if
///   offscreen lines remain laid out, collapsed mode renders the measured
///   `19`-line visible prefix (scoping collapsed selection to visible lines
///   until expanded, while toolbar Copy still copies the full prompt).
class CodexMessageBubble extends StatefulWidget {
  const CodexMessageBubble({
    super.key,
    required this.text,
    this.attachments = const [],
    this.maxColumnWidth = OfficialCodexTheme.maxContentWidth,
    this.radius = OfficialCodexTheme.userMessageRadius,
    this.maxCollapsedLines = OfficialCodexTheme.userMessageCollapsedLines,
    this.maxExpandedCharacters = defaultMaxExpandedCharacters,
    this.plainTextOnly = false,
    this.forceExpanded = false,
    this.externalLinkLauncher,
    this.expandKey,
  });

  /// Matches live `ConversationController.maxEntryCharacters` / `TurnProtocol`
  /// `64 KiB` bound so direct callers cannot force unbounded paragraph layout.
  static const int defaultMaxExpandedCharacters = 64 * 1024;

  final String text;
  final List<Widget> attachments;
  final double maxColumnWidth;
  final double radius;
  final int maxCollapsedLines;
  final int maxExpandedCharacters;
  final bool plainTextOnly;
  final bool forceExpanded;
  final ExternalLinkLauncher? externalLinkLauncher;
  final Key? expandKey;

  @override
  State<CodexMessageBubble> createState() => _CodexMessageBubbleState();
}

class _CodexMessageBubbleState extends State<CodexMessageBubble> {
  bool _isExpanded = false;
  _CollapseLayoutCache? _layoutCache;

  @override
  void didUpdateWidget(covariant CodexMessageBubble oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.text != oldWidget.text) {
      _isExpanded = false;
      _layoutCache = null;
    } else if (widget.maxCollapsedLines != oldWidget.maxCollapsedLines) {
      _layoutCache = null;
    }
  }

  void _toggleExpanded() {
    setState(() {
      _isExpanded = !_isExpanded;
    });
  }

  _CollapseLayoutCache _resolveCollapseLayout({
    required TextStyle effectiveStyle,
    required TextDirection textDirection,
    required TextScaler textScaler,
    required double maxTextWidth,
  }) {
    final safeCollapsedLines = math.max(1, widget.maxCollapsedLines);
    final cached = _layoutCache;
    if (cached != null &&
        (identical(cached.sourceText, widget.text) ||
            cached.sourceText == widget.text) &&
        cached.maxCollapsedLines == safeCollapsedLines &&
        (cached.maxTextWidth - maxTextWidth).abs() < 0.01 &&
        cached.effectiveStyle == effectiveStyle &&
        cached.textDirection == textDirection &&
        cached.textScaler == textScaler) {
      return cached;
    }

    final collapsedBudget =
        safeCollapsedLines *
        OfficialCodexTheme.userMessageCollapsedCharsPerLine;
    final measurementSource = _sliceCodeUnitsSafe(widget.text, collapsedBudget);
    final exceededBudget = widget.text.length > measurementSource.length;

    bool isCollapsible;
    String collapsedText;

    if (measurementSource.isEmpty) {
      isCollapsible = false;
      collapsedText = '';
    } else {
      final painter = TextPainter(
        text: TextSpan(text: measurementSource, style: effectiveStyle),
        textDirection: textDirection,
        textScaler: textScaler,
        maxLines: safeCollapsedLines,
      );
      try {
        painter.layout(maxWidth: maxTextWidth);
        final exceededLines = painter.didExceedMaxLines;
        if (!exceededBudget && !exceededLines) {
          isCollapsible = false;
          collapsedText = widget.text;
        } else {
          isCollapsible = true;
          final visibleLines = safeCollapsedLines > 2
              ? safeCollapsedLines - 1
              : safeCollapsedLines;
          final metrics = painter.computeLineMetrics();
          if (metrics.isEmpty) {
            collapsedText = '';
          } else {
            final lastLineIndex = math.min(visibleLines, metrics.length) - 1;
            var lineCenterY = 0.0;
            for (var i = 0; i < lastLineIndex; i += 1) {
              lineCenterY += metrics[i].height;
            }
            lineCenterY += metrics[lastLineIndex].height * 0.5;
            final edgeX = textDirection == TextDirection.rtl
                ? 0.0
                : maxTextWidth;
            final endOffset = painter
                .getPositionForOffset(Offset(edgeX, lineCenterY))
                .offset
                .clamp(0, measurementSource.length);
            collapsedText = _sliceCodeUnitsSafe(
              measurementSource,
              endOffset,
            ).trimRight();
          }
        }
      } finally {
        painter.dispose();
      }
    }

    final nextCache = _CollapseLayoutCache(
      sourceText: widget.text,
      maxCollapsedLines: safeCollapsedLines,
      maxTextWidth: maxTextWidth,
      effectiveStyle: effectiveStyle,
      textDirection: textDirection,
      textScaler: textScaler,
      isCollapsible: isCollapsible,
      collapsedText: collapsedText,
    );
    _layoutCache = nextCache;
    return nextCache;
  }

  static String _sliceCodeUnitsSafe(String text, int maxCodeUnits) {
    if (maxCodeUnits <= 0 || text.isEmpty) {
      return '';
    }
    if (text.length <= maxCodeUnits) {
      return text;
    }
    var end = maxCodeUnits;
    final prev = text.codeUnitAt(end - 1);
    if (prev >= 0xD800 && prev <= 0xDBFF) {
      end -= 1;
    }
    return text.substring(0, end);
  }

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    const horizontalPadding = OfficialCodexTheme.userMessageHorizontalPadding;
    const verticalPadding = OfficialCodexTheme.userMessageVerticalPadding;
    const fontSize = OfficialCodexTheme.userMessageFontSize;

    final messageStyle = TextStyle(
      color: theme.textPrimary,
      fontSize: fontSize,
      height: OfficialCodexTheme.userMessageLineHeight,
    );
    final effectiveStyle = DefaultTextStyle.of(context).style
        .merge(messageStyle);
    final textDirection = Directionality.of(context);
    final textScaler = MediaQuery.textScalerOf(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final availableColumnWidth = constraints.hasBoundedWidth
            ? math.min(constraints.maxWidth, widget.maxColumnWidth)
            : widget.maxColumnWidth;
        final rawMaxBubbleWidth =
            availableColumnWidth * OfficialCodexTheme.maxUserBubbleWidthFactor;
        final maxBubbleWidth = math.max(
          rawMaxBubbleWidth,
          horizontalPadding * 2 + 1.0,
        );
        final maxTextWidth = maxBubbleWidth - horizontalPadding * 2;

        final collapseLayout = _resolveCollapseLayout(
          effectiveStyle: effectiveStyle,
          textDirection: textDirection,
          textScaler: textScaler,
          maxTextWidth: maxTextWidth,
        );

        final isCollapsible =
            collapseLayout.isCollapsible && !widget.forceExpanded;
        final showFull = _isExpanded || !isCollapsible || widget.forceExpanded;
        final safeMaxExpanded = math.max(1, widget.maxExpandedCharacters);
        final expandedTruncated =
            showFull && widget.text.length > safeMaxExpanded;
        final displayText = showFull
            ? _sliceCodeUnitsSafe(widget.text, safeMaxExpanded)
            : collapseLayout.collapsedText;
        final showEllipsisLine =
            (!showFull && isCollapsible) || expandedTruncated;
        final usePlainText =
            displayText.isEmpty ||
            widget.plainTextOnly ||
            displayText.length > UserMessageMarkdown.maxSourceCharacters;

        return Align(
          alignment: Alignment.centerRight,
          child: ConstrainedBox(
            constraints: BoxConstraints(maxWidth: maxBubbleWidth),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: horizontalPadding,
                vertical: verticalPadding,
              ),
              decoration: BoxDecoration(
                color: theme.userBubbleBackground,
                borderRadius: BorderRadius.circular(widget.radius),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (widget.attachments.isNotEmpty) ...[
                    Wrap(
                      spacing: 6.0,
                      runSpacing: 6.0,
                      children: widget.attachments,
                    ),
                    const SizedBox(
                      height: OfficialCodexTheme.userMessageAttachmentGap,
                    ),
                  ],
                  if (usePlainText)
                    SelectableText(
                      displayText,
                      key: const ValueKey('user-bounded-text'),
                      style: messageStyle,
                    )
                  else
                    UserMessageMarkdown(
                      data: displayText,
                      externalLinkLauncher: widget.externalLinkLauncher,
                    ),
                  if (showEllipsisLine)
                    ExcludeSemantics(child: Text('…', style: messageStyle)),
                  if (isCollapsible) ...[
                    const SizedBox(
                      height: OfficialCodexTheme.userMessageExpandGap,
                    ),
                    _UserMessageExpandButton(
                      key: widget.expandKey,
                      isExpanded: _isExpanded,
                      onPressed: _toggleExpanded,
                    ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

final class _CollapseLayoutCache {
  const _CollapseLayoutCache({
    required this.sourceText,
    required this.maxCollapsedLines,
    required this.maxTextWidth,
    required this.effectiveStyle,
    required this.textDirection,
    required this.textScaler,
    required this.isCollapsible,
    required this.collapsedText,
  });

  final String sourceText;
  final int maxCollapsedLines;
  final double maxTextWidth;
  final TextStyle effectiveStyle;
  final TextDirection textDirection;
  final TextScaler textScaler;
  final bool isCollapsible;
  final String collapsedText;
}

class _UserMessageExpandButton extends StatefulWidget {
  const _UserMessageExpandButton({
    super.key,
    required this.isExpanded,
    required this.onPressed,
  });

  final bool isExpanded;
  final VoidCallback onPressed;

  @override
  State<_UserMessageExpandButton> createState() =>
      _UserMessageExpandButtonState();
}

class _UserMessageExpandButtonState extends State<_UserMessageExpandButton> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final theme = OfficialCodexTheme.of(context);
    final label = widget.isExpanded ? 'Show less' : 'Show more';

    return Semantics(
      button: true,
      toggled: widget.isExpanded,
      label: label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: FocusableActionDetector(
        mouseCursor: SystemMouseCursors.click,
        onShowFocusHighlight: (focused) => setState(() => _focused = focused),
        actions: <Type, Action<Intent>>{
          ActivateIntent: CallbackAction<ActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
          ButtonActivateIntent: CallbackAction<ButtonActivateIntent>(
            onInvoke: (_) {
              widget.onPressed();
              return null;
            },
          ),
        },
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(6.0),
              border: _focused
                  ? Border.all(
                      color: theme.focusRing,
                      width: 1.5,
                      strokeAlign: BorderSide.strokeAlignOutside,
                    )
                  : null,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: theme.textPrimary,
                    fontSize: OfficialCodexTheme.userMessageFontSize,
                    height: 1.5,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(width: 4.0),
                AnimatedRotation(
                  turns: widget.isExpanded ? 0.5 : 0.0,
                  duration: const Duration(milliseconds: 150),
                  curve: Curves.easeOutCubic,
                  child: Icon(
                    Icons.keyboard_arrow_down_rounded,
                    size: OfficialCodexTheme.activityInlineIconSize,
                    color: theme.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Asynchronous bounded local-file [ImageProvider] for externalized user image
/// thumbnails and modal previews (`182735.smHt.RP` / `early-bootstrap-815`
/// bounded file reads + bounded `pendingNativeThumbnailCount` queue).
///
/// Unlike SDK [FileImage], which reads the entire file via
/// `ImmutableBuffer.fromFilePath` after only rejecting `length == 0`,
/// [BoundedLocalFileImage]:
/// 1. Asynchronously checks `File.stat()` before opening, requiring a regular
///    `FileSystemEntityType.file` (following symlinks while rejecting missing
///    paths, directories, FIFOs/pipes, sockets, and device nodes) whose size
///    satisfies `0 < size <= maxEncodedBytes`.
/// 2. Opens a single [RandomAccessFile] inside `try / finally`, re-verifies
///    `raf.length()` (`fstat`) on that descriptor, and reads in `<= 64 KiB`
///    chunks capped at `maxEncodedBytes + 1` bytes so concurrent mid-read file
///    growth aborts immediately without reading the remainder of the file.
/// 3. Bounds both concurrent encoded-byte loads ([maxConcurrentLoads] = 4) and
///    queued pending waiters ([maxPendingLoads] = 64, sized above normal
///    multi-message `16`-attachment working sets), retiring detached
///    queued/in-flight sessions on listener removal or widget disposal
///    ([retainWidgetInterest] / [releaseWidgetInterest]) and evicting failed
///    keys from [ImageCache] so later valid writes or remounts recover cleanly.
@immutable
class BoundedLocalFileImage extends ImageProvider<BoundedLocalFileImage> {
  const BoundedLocalFileImage(
    this.file, {
    this.scale = 1.0,
    this.maxEncodedBytes = OfficialCodexTheme.userImageMaxEncodedBytes,
  }) : assert(maxEncodedBytes > 0);

  static const int maxConcurrentLoads = 4;
  static const int maxPendingLoads = 64;
  static const int _maxReadChunkBytes = 64 * 1024;
  static int _activeLoads = 0;
  static final Queue<_BoundedImageLoadSession> _pendingLoadWaiters =
      Queue<_BoundedImageLoadSession>();
  static final Set<_BoundedImageLoadSession> _inFlightSessions =
      <_BoundedImageLoadSession>{};
  static final Map<String, int> _interestCountByPath = <String, int>{};

  final File file;
  final double scale;
  final int maxEncodedBytes;

  @visibleForTesting
  static int get debugActiveLoadCount => _activeLoads;

  @visibleForTesting
  static int get debugPendingLoadCount => _pendingLoadWaiters.length;

  @visibleForTesting
  static int get debugTrackedInterestCount => _interestCountByPath.length;

  /// Increments mounted widget interest for [path] so queued/in-flight reads
  /// can be retired immediately when all mounted tiles/dialogs for [path]
  /// dispose during virtualization scroll or thread switches.
  static void retainWidgetInterest(String path) {
    _interestCountByPath[path] = (_interestCountByPath[path] ?? 0) + 1;
  }

  /// Decrements mounted widget interest for [path]; when interest reaches `0`,
  /// retires any queued or in-flight load sessions for [path] and evicts
  /// pending [ImageCache] entries for [evictProviders] without disturbing
  /// already-decoded cached thumbnails.
  static void releaseWidgetInterest(
    String path, {
    Iterable<ImageProvider<Object>> evictProviders = const [],
  }) {
    final current = _interestCountByPath[path];
    if (current == null) {
      return;
    }
    if (current > 1) {
      _interestCountByPath[path] = current - 1;
      return;
    }
    _interestCountByPath.remove(path);

    var retiredPendingOrInFlight = false;
    final matchingQueued = _pendingLoadWaiters
        .where((session) => session.key.file.path == path)
        .toList(growable: false);
    for (final session in matchingQueued) {
      retiredPendingOrInFlight = true;
      _retireSession(
        session,
        reason: 'Local image load retired after widget disposal',
      );
    }
    final matchingInFlight = _inFlightSessions
        .where((session) => session.key.file.path == path)
        .toList(growable: false);
    for (final session in matchingInFlight) {
      retiredPendingOrInFlight = true;
      _retireSession(
        session,
        reason: 'Local image load retired after widget disposal',
      );
    }
    if (retiredPendingOrInFlight) {
      for (final provider in evictProviders) {
        unawaited(provider.evict());
      }
    }
  }

  static Future<bool> _acquireLoadSlot(_BoundedImageLoadSession session) {
    if (session.canceled) {
      return SynchronousFuture<bool>(false);
    }
    if (_activeLoads < maxConcurrentLoads) {
      _activeLoads += 1;
      session.hasActiveSlot = true;
      _inFlightSessions.add(session);
      return SynchronousFuture<bool>(true);
    }
    while (_pendingLoadWaiters.length >= maxPendingLoads) {
      _BoundedImageLoadSession? detachedVictim;
      for (final candidate in _pendingLoadWaiters) {
        if (candidate.canceled ||
            !_interestCountByPath.containsKey(candidate.key.file.path)) {
          detachedVictim = candidate;
          break;
        }
      }
      final victim = detachedVictim ?? _pendingLoadWaiters.first;
      _pendingLoadWaiters.remove(victim);
      victim.canceled = true;
      victim.cancelReason =
          'Local image load queue capacity exceeded ($maxPendingLoads pending)';
      final waiter = victim.waiter;
      victim.waiter = null;
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete(false);
      }
    }
    final waiter = Completer<bool>();
    session.waiter = waiter;
    _pendingLoadWaiters.addLast(session);
    return waiter.future;
  }

  static void _retireSession(
    _BoundedImageLoadSession session, {
    required String reason,
  }) {
    session.canceled = true;
    session.cancelReason ??= reason;
    if (_pendingLoadWaiters.remove(session)) {
      final waiter = session.waiter;
      session.waiter = null;
      if (waiter != null && !waiter.isCompleted) {
        waiter.complete(false);
      }
    }
    // Never release an active slot while OS file I/O or engine codec work is
    // still running; if neither is active (e.g., retired between phases in a
    // FakeAsync zone), release the idle slot immediately.
    if (session.hasActiveSlot && !session.inIo && !session.inDecode) {
      _releaseLoadSlot(session);
    }
  }

  static void _releaseLoadSlot(_BoundedImageLoadSession completedSession) {
    if (!completedSession.hasActiveSlot) {
      return;
    }
    completedSession.hasActiveSlot = false;
    _inFlightSessions.remove(completedSession);
    while (_pendingLoadWaiters.isNotEmpty) {
      final next = _pendingLoadWaiters.removeFirst();
      final waiter = next.waiter;
      next.waiter = null;
      if (next.canceled || waiter == null || waiter.isCompleted) {
        if (waiter != null && !waiter.isCompleted) {
          waiter.complete(false);
        }
        continue;
      }
      next.hasActiveSlot = true;
      _inFlightSessions.add(next);
      waiter.complete(true);
      return;
    }
    if (_activeLoads > 0) {
      _activeLoads -= 1;
    }
  }

  @override
  Future<BoundedLocalFileImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<BoundedLocalFileImage>(this);

  @override
  ImageStreamCompleter loadImage(
    BoundedLocalFileImage key,
    ImageDecoderCallback decode,
  ) {
    final session = _BoundedImageLoadSession(key: key);
    final completer = MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, session: session, decode: decode),
      scale: key.scale,
      debugLabel: key.file.path,
      informationCollector: () => <DiagnosticsNode>[
        ErrorDescription('Path: ${file.path}'),
        IntProperty('maxEncodedBytes', maxEncodedBytes),
      ],
    );
    completer.addOnLastListenerRemovedCallback(() {
      _retireSession(
        session,
        reason: 'Local image load retired after last listener detached',
      );
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    completer.addEphemeralErrorListener((Object error, StackTrace? stackTrace) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
    });
    return completer;
  }

  /// Reads at most [maxEncodedBytes] encoded image bytes from [file], throwing
  /// a [FileSystemException] or [StateError] when missing, non-regular, empty,
  /// canceled via [isCanceled], or larger than [maxEncodedBytes].
  @visibleForTesting
  static Future<Uint8List> readBoundedEncodedBytes(
    File file, {
    int maxEncodedBytes = OfficialCodexTheme.userImageMaxEncodedBytes,
    bool Function()? isCanceled,
  }) async {
    if (maxEncodedBytes <= 0) {
      throw RangeError.value(maxEncodedBytes, 'maxEncodedBytes');
    }
    if (isCanceled != null && isCanceled()) {
      throw StateError('Local image load canceled: ${file.path}');
    }
    final stat = await file.stat();
    if (isCanceled != null && isCanceled()) {
      throw StateError('Local image load canceled: ${file.path}');
    }
    if (stat.type == FileSystemEntityType.notFound) {
      throw PathNotFoundException(
        file.path,
        const OSError('Local image file does not exist'),
      );
    }
    if (stat.type != FileSystemEntityType.file) {
      throw FileSystemException(
        'Local image path is not a regular file (${stat.type})',
        file.path,
      );
    }
    if (stat.size <= 0) {
      throw StateError('Local image file is empty: ${file.path}');
    }
    if (stat.size > maxEncodedBytes) {
      throw FileSystemException(
        'Local image exceeds $maxEncodedBytes-byte preview limit (${stat.size} bytes)',
        file.path,
      );
    }

    final raf = await file.open(mode: FileMode.read);
    try {
      if (isCanceled != null && isCanceled()) {
        throw StateError('Local image load canceled: ${file.path}');
      }
      final openedLength = await raf.length();
      if (openedLength <= 0) {
        throw StateError('Local image file is empty: ${file.path}');
      }
      if (openedLength > maxEncodedBytes) {
        throw FileSystemException(
          'Local image exceeds $maxEncodedBytes-byte preview limit ($openedLength bytes)',
          file.path,
        );
      }

      final builder = BytesBuilder(copy: false);
      var totalRead = 0;
      final readCap = maxEncodedBytes + 1;
      while (totalRead < readCap) {
        if (isCanceled != null && isCanceled()) {
          throw StateError('Local image load canceled: ${file.path}');
        }
        final requestBytes = math.min(_maxReadChunkBytes, readCap - totalRead);
        final chunk = await raf.read(requestBytes);
        if (chunk.isEmpty) {
          break;
        }
        totalRead += chunk.length;
        if (totalRead > maxEncodedBytes) {
          throw FileSystemException(
            'Local image grew past $maxEncodedBytes-byte preview limit while reading',
            file.path,
          );
        }
        builder.add(chunk);
      }
      if (totalRead == 0) {
        throw StateError('Local image file is empty: ${file.path}');
      }
      return builder.takeBytes();
    } finally {
      await raf.close();
    }
  }

  Future<ui.Codec> _loadAsync(
    BoundedLocalFileImage key, {
    required _BoundedImageLoadSession session,
    required ImageDecoderCallback decode,
  }) async {
    assert(key == this);
    final acquired = await _acquireLoadSlot(session);
    if (!acquired) {
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError(
        session.cancelReason ?? 'Local image load canceled: ${file.path}',
      );
    }
    if (session.canceled) {
      _releaseLoadSlot(session);
      PaintingBinding.instance.imageCache.evict(key);
      throw StateError(
        session.cancelReason ?? 'Local image load canceled: ${file.path}',
      );
    }
    try {
      session.inIo = true;
      final ioCompleter =
          Completer<({Uint8List? bytes, Object? error, StackTrace? stack})>();
      Zone.root.run(() async {
        try {
          final data = await readBoundedEncodedBytes(
            file,
            maxEncodedBytes: maxEncodedBytes,
            isCanceled: () => session.canceled,
          );
          session.inIo = false;
          if (session.canceled) {
            _releaseLoadSlot(session);
            ioCompleter.complete((
              bytes: null,
              error: StateError(
                session.cancelReason ??
                    'Local image load canceled: ${file.path}',
              ),
              stack: StackTrace.current,
            ));
            return;
          }
          ioCompleter.complete((bytes: data, error: null, stack: null));
        } on Object catch (error, stackTrace) {
          session.inIo = false;
          _releaseLoadSlot(session);
          ioCompleter.complete((bytes: null, error: error, stack: stackTrace));
        }
      });

      final ioResult = await ioCompleter.future;
      if (ioResult.error != null) {
        PaintingBinding.instance.imageCache.evict(key);
        Error.throwWithStackTrace(ioResult.error!, ioResult.stack!);
      }
      final bytes = ioResult.bytes!;
      if (session.canceled) {
        PaintingBinding.instance.imageCache.evict(key);
        throw StateError(
          session.cancelReason ?? 'Local image load canceled: ${file.path}',
        );
      }

      session.inDecode = true;
      try {
        final ui.ImmutableBuffer buffer;
        try {
          buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
        } on Object {
          PaintingBinding.instance.imageCache.evict(key);
          rethrow;
        }
        // Ownership of `buffer` transfers to `decode` (`instantiateImageCodecWithSize`
        // disposes `buffer` in its `finally` block; see `dart:ui` painting.dart).
        try {
          return await decode(buffer);
        } on Object {
          PaintingBinding.instance.imageCache.evict(key);
          rethrow;
        }
      } finally {
        session.inDecode = false;
      }
    } finally {
      _releaseLoadSlot(session);
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BoundedLocalFileImage &&
          other.runtimeType == runtimeType &&
          other.file.path == file.path &&
          other.scale == scale &&
          other.maxEncodedBytes == maxEncodedBytes);

  @override
  int get hashCode => Object.hash(file.path, scale, maxEncodedBytes);

  @override
  String toString() =>
      '${objectRuntimeType(this, 'BoundedLocalFileImage')}("${file.path}", '
      'scale: ${scale.toStringAsFixed(1)}, maxEncodedBytes: $maxEncodedBytes)';
}

final class _BoundedImageLoadSession {
  _BoundedImageLoadSession({required this.key});

  final BoundedLocalFileImage key;
  Completer<bool>? waiter;
  bool hasActiveSlot = false;
  bool inIo = false;
  bool inDecode = false;
  bool canceled = false;
  String? cancelReason;
}
