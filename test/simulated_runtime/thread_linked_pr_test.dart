import 'dart:async';
import 'dart:convert';

import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/protocol/thread_attachment_protocol.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'simulated_runtime_harness.dart';

class _LinkedPrSimulatedRuntimeHarness extends SimulatedRuntimeHarness {
  _LinkedPrSimulatedRuntimeHarness({super.initialThreads});

  final StreamController<ThreadAttachmentEvent> _attachmentEvents =
      StreamController<ThreadAttachmentEvent>.broadcast(sync: true);
  final List<String> requestedAttachmentThreadIds = <String>[];
  final List<({String threadId, String url, String? headBranch})>
  linkedPrCalls = <({String threadId, String url, String? headBranch})>[];
  final Map<String, ThreadLinkedPullRequestsSnapshot> snapshotsByThreadId =
      <String, ThreadLinkedPullRequestsSnapshot>{};
  final Map<String, Completer<ThreadLinkedPullRequestsSnapshot>>
  pendingReadCompleters =
      <String, Completer<ThreadLinkedPullRequestsSnapshot>>{};
  final Set<String> failingThreadIds = <String>{};
  var attachmentsSupported = true;
  var attachmentWritesSupported = true;
  var latchUnsupportedOnRead = false;
  var latchWriteUnsupportedOnLink = false;
  var activeInFlightReads = 0;
  var maxConcurrentReads = 0;

  @override
  bool get supportsThreadAttachments =>
      attachmentsSupported && !remoteModeOverride;

  @override
  bool get supportsThreadAttachmentWrites =>
      supportsThreadAttachments && attachmentWritesSupported;

  @override
  Stream<ThreadAttachmentEvent> get threadAttachmentEvents =>
      _attachmentEvents.stream;

  @override
  Future<ThreadLinkedPullRequestsSnapshot> readLinkedPullRequests(
    String threadId,
  ) async {
    requestedAttachmentThreadIds.add(threadId);
    activeInFlightReads += 1;
    if (activeInFlightReads > maxConcurrentReads) {
      maxConcurrentReads = activeInFlightReads;
    }
    try {
      if (latchUnsupportedOnRead) {
        attachmentsSupported = false;
        attachmentWritesSupported = false;
        throw UnsupportedError('Method not found');
      }
      if (pendingReadCompleters.remove(threadId) case final completer?) {
        return await completer.future;
      }
      if (failingThreadIds.contains(threadId)) {
        throw StateError(
          'Simulated attachment read failure\nwith newline and '
          '${'x' * 220} for $threadId',
        );
      }
      return snapshotsByThreadId[threadId] ??
          ThreadLinkedPullRequestsSnapshot(
            threadId: threadId,
            pullRequests: const [],
            scannedAttachmentCount: 0,
            truncated: false,
          );
    } finally {
      activeInFlightReads -= 1;
    }
  }

  @override
  Future<ThreadPullRequestLinkResult> linkPullRequest(
    String threadId, {
    required String url,
    String? headBranch,
  }) async {
    final canonicalParts =
        ThreadAttachmentProtocolAdapter.tryParseCanonicalPullRequestUrl(url);
    if (canonicalParts == null) {
      throw ArgumentError(
        'Enter a valid HTTPS GitHub Pull Request or GitLab Merge Request URL.',
        'url',
      );
    }
    if (utf8.encode(canonicalParts.canonicalIdentityKey).length >
        ThreadAttachmentProtocolAdapter.maxIdentityKeyUtf8Bytes) {
      throw ArgumentError(
        'Canonical pull request identity exceeds 256 UTF-8 bytes.',
        'url',
      );
    }
    final sanitizedBranch = headBranch == null || headBranch.trim().isEmpty
        ? null
        : headBranch.trim();

    if (latchWriteUnsupportedOnLink) {
      attachmentWritesSupported = false;
      throw UnsupportedError('Method not found');
    }

    linkedPrCalls.add((
      threadId: threadId,
      url: canonicalParts.canonicalUrl,
      headBranch: sanitizedBranch,
    ));

    final currentSnapshot =
        snapshotsByThreadId[threadId] ??
        ThreadLinkedPullRequestsSnapshot(
          threadId: threadId,
          pullRequests: const [],
          scannedAttachmentCount: 0,
          truncated: false,
        );
    for (final existing in currentSnapshot.pullRequests) {
      if (existing.canonicalIdentityKey ==
          canonicalParts.canonicalIdentityKey) {
        return ThreadPullRequestLinkResult(
          outcome: ThreadPullRequestLinkOutcome.existing,
          pullRequest: existing,
        );
      }
    }
    if (currentSnapshot.truncated) {
      return ThreadPullRequestLinkResult(
        outcome: ThreadPullRequestLinkOutcome.scanIncomplete,
        pullRequest: ThreadLinkedPullRequest(
          attachmentId: 'unverified',
          canonicalIdentityKey: canonicalParts.canonicalIdentityKey,
          canonicalHost: canonicalParts.canonicalHost,
          owner: canonicalParts.owner,
          repository: canonicalParts.repository,
          number: canonicalParts.number,
          canonicalUrl: canonicalParts.canonicalUrl,
          createdAtSeconds: 0,
          headBranch: sanitizedBranch,
        ),
      );
    }

    final createdPr = ThreadLinkedPullRequest(
      attachmentId: 'att-created-${linkedPrCalls.length}',
      canonicalIdentityKey: canonicalParts.canonicalIdentityKey,
      canonicalHost: canonicalParts.canonicalHost,
      owner: canonicalParts.owner,
      repository: canonicalParts.repository,
      number: canonicalParts.number,
      canonicalUrl: canonicalParts.canonicalUrl,
      createdAtSeconds: 1700001000 + linkedPrCalls.length,
      headBranch: sanitizedBranch,
    );
    snapshotsByThreadId[threadId] = ThreadLinkedPullRequestsSnapshot(
      threadId: threadId,
      pullRequests: [...currentSnapshot.pullRequests, createdPr],
      scannedAttachmentCount: currentSnapshot.scannedAttachmentCount + 1,
      truncated: false,
    );
    return ThreadPullRequestLinkResult(
      outcome: ThreadPullRequestLinkOutcome.created,
      pullRequest: createdPr,
    );
  }

  void emitThreadAttachmentUpdated(ThreadAttachmentUpdatedEvent event) {
    _attachmentEvents.add(event);
  }

  @override
  Future<void> shutdown() async {
    await _attachmentEvents.close();
    await super.shutdown();
  }
}

void main() {
  group('F19B Local Read-Only Linked PR References simulated runtime', () {
    testWidgets(
      'projects linked PRs on a cold thread without resuming, shows scan-limit notice, refreshes on pull_request update, and clears on thread switch',
      (tester) async {
        final harness = _LinkedPrSimulatedRuntimeHarness(
          initialThreads: [
            createTestThread(
              id: 'thread-cold-pr',
              preview: 'Cold PR thread',
              status: ThreadRuntimeStatus.notLoaded,
            ),
            createTestThread(
              id: 'thread-plain',
              preview: 'Plain thread without PRs',
              status: ThreadRuntimeStatus.idle,
            ),
          ],
        );

        harness.snapshotsByThreadId['thread-cold-pr'] =
            const ThreadLinkedPullRequestsSnapshot(
              threadId: 'thread-cold-pr',
              pullRequests: [
                ThreadLinkedPullRequest(
                  attachmentId: 'att-pr-1',
                  canonicalIdentityKey: '["github.com","openai","codex",412]',
                  canonicalHost: 'github.com',
                  owner: 'OpenAI',
                  repository: 'Codex',
                  number: 412,
                  canonicalUrl: 'https://github.com/OpenAI/Codex/pull/412',
                  createdAtSeconds: 1700000001,
                  headBranch: 'feat/linked-pr',
                ),
                ThreadLinkedPullRequest(
                  attachmentId: 'att-mr-2',
                  canonicalIdentityKey:
                      '["gitlab.com","group/sub","client",77]',
                  canonicalHost: 'gitlab.com',
                  owner: 'Group/Sub',
                  repository: 'Client',
                  number: 77,
                  canonicalUrl:
                      'https://gitlab.com/Group/Sub/Client/-/merge_requests/77',
                  createdAtSeconds: 1700000002,
                ),
              ],
              scannedAttachmentCount: 100,
              truncated: true,
            );

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        // No background attachment reads before selecting a thread.
        expect(harness.requestedAttachmentThreadIds, isEmpty);
        expect(
          find.byKey(const ValueKey('thread-linked-pr-pill')),
          findsNothing,
        );

        // Selecting a cold persisted thread reads linked PRs without resuming it.
        await tester.tap(
          find.byKey(const ValueKey('thread-row-thread-cold-pr')),
        );
        await tester.pumpAndSettle();

        expect(harness.requestedAttachmentThreadIds, ['thread-cold-pr']);
        expect(
          harness.threads
              .firstWhere((thread) => thread.id == 'thread-cold-pr')
              .status,
          ThreadRuntimeStatus.notLoaded,
        );
        expect(
          find.byKey(const ValueKey('thread-linked-pr-pill')),
          findsOneWidget,
        );
        expect(find.text('OpenAI/Codex#412'), findsOneWidget);
        expect(find.text('+1+'), findsOneWidget);

        // Open the linked PR popover to inspect sanitized URLs, branch, and scan-limit notice.
        await tester.tap(find.byKey(const ValueKey('thread-linked-pr-pill')));
        await tester.pumpAndSettle();

        expect(
          find.byKey(const ValueKey('thread-linked-pr-popover')),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('thread-linked-pr-branch-0')),
          findsOneWidget,
        );
        expect(find.text('Branch: feat/linked-pr'), findsOneWidget);
        expect(
          find.text('https://github.com/OpenAI/Codex/pull/412'),
          findsOneWidget,
        );
        expect(
          find.text('https://gitlab.com/Group/Sub/Client/-/merge_requests/77'),
          findsOneWidget,
        );
        expect(
          find.byKey(const ValueKey('thread-linked-pr-limit-notice')),
          findsOneWidget,
        );
        expect(
          find.text(
            'Showing first 2 linked pull requests (scanned 100 attachments; limit reached).',
          ),
          findsOneWidget,
        );

        // Tapping Open attempts explicit browser launch for the sanitized URL.
        await tester.tap(find.byKey(const ValueKey('thread-linked-pr-open-0')));
        await tester.pumpAndSettle();

        // Non-PR or other-thread attachment notifications do not trigger a refresh.
        harness.emitThreadAttachmentUpdated(
          const ThreadAttachmentUpdatedEvent(
            threadId: 'thread-cold-pr',
            attachmentId: 'att-wt-1',
            attachmentType: 'worktree',
            identityKey: '/tmp/wt-1',
            operation: ThreadAttachmentUpdateOperation.created,
          ),
        );
        harness.emitThreadAttachmentUpdated(
          const ThreadAttachmentUpdatedEvent(
            threadId: 'thread-plain',
            attachmentId: 'att-pr-other',
            attachmentType: 'pull_request',
            identityKey: '["github.com","openai","codex",999]',
            operation: ThreadAttachmentUpdateOperation.created,
          ),
        );
        await tester.pumpAndSettle();
        expect(harness.requestedAttachmentThreadIds, ['thread-cold-pr']);

        // Matching pull_request update refreshes the active thread projection.
        harness.snapshotsByThreadId['thread-cold-pr'] =
            const ThreadLinkedPullRequestsSnapshot(
              threadId: 'thread-cold-pr',
              pullRequests: [
                ThreadLinkedPullRequest(
                  attachmentId: 'att-pr-500',
                  canonicalIdentityKey: '["github.com","openai","codex",500]',
                  canonicalHost: 'github.com',
                  owner: 'OpenAI',
                  repository: 'Codex',
                  number: 500,
                  canonicalUrl: 'https://github.com/OpenAI/Codex/pull/500',
                  createdAtSeconds: 1700000010,
                ),
              ],
              scannedAttachmentCount: 1,
              truncated: false,
            );
        harness.emitThreadAttachmentUpdated(
          const ThreadAttachmentUpdatedEvent(
            threadId: 'thread-cold-pr',
            attachmentId: 'att-pr-500',
            attachmentType: 'pull_request',
            identityKey: '["github.com","openai","codex",500]',
            operation: ThreadAttachmentUpdateOperation.created,
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.requestedAttachmentThreadIds, [
          'thread-cold-pr',
          'thread-cold-pr',
        ]);
        expect(find.text('OpenAI/Codex#500'), findsWidgets);
        expect(
          find.byKey(const ValueKey('thread-linked-pr-limit-notice')),
          findsNothing,
        );

        // Close the open popover, then switch to a thread without linked PRs.
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-popover-close')),
        );
        await tester.pumpAndSettle();

        // Switching to a thread without linked PRs discards the previous thread's projection
        // and exposes a visible empty state when opened.
        await tester.tap(find.byKey(const ValueKey('thread-row-thread-plain')));
        await tester.pumpAndSettle();

        expect(harness.requestedAttachmentThreadIds, [
          'thread-cold-pr',
          'thread-cold-pr',
          'thread-plain',
        ]);
        expect(find.text('OpenAI/Codex#500'), findsNothing);
        expect(find.text('Linked PRs'), findsOneWidget);

        await tester.tap(find.byKey(const ValueKey('thread-linked-pr-pill')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('thread-linked-pr-empty')),
          findsOneWidget,
        );
        expect(
          find.text('No linked pull requests for this thread.'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'serializes one in-flight scan with one replaceable pending target across rapid switches/update bursts and shows visible error/retry state',
      (tester) async {
        final harness = _LinkedPrSimulatedRuntimeHarness(
          initialThreads: [
            createTestThread(
              id: 'thread-1',
              preview: 'Thread 1',
              status: ThreadRuntimeStatus.idle,
            ),
            createTestThread(
              id: 'thread-2',
              preview: 'Thread 2',
              status: ThreadRuntimeStatus.idle,
            ),
            createTestThread(
              id: 'thread-3',
              preview: 'Thread 3',
              status: ThreadRuntimeStatus.idle,
            ),
          ],
        );

        final thread1Completer = Completer<ThreadLinkedPullRequestsSnapshot>();
        harness.pendingReadCompleters['thread-1'] = thread1Completer;
        harness.failingThreadIds.add('thread-3');

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        // Select thread-1 (starts in-flight read), then rapidly switch thread-2 -> thread-3
        // before thread-1 finishes.
        await tester.tap(find.byKey(const ValueKey('thread-row-thread-1')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('thread-row-thread-2')));
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('thread-row-thread-3')));
        await tester.pump();

        // Only thread-1 is in flight; thread-2 was replaced by thread-3 before starting.
        expect(harness.requestedAttachmentThreadIds, ['thread-1']);
        expect(harness.maxConcurrentReads, 1);

        // Complete thread-1; the queue skips thread-2 and runs thread-3 (which fails).
        thread1Completer.complete(
          const ThreadLinkedPullRequestsSnapshot(
            threadId: 'thread-1',
            pullRequests: [],
            scannedAttachmentCount: 0,
            truncated: false,
          ),
        );
        await tester.pumpAndSettle();

        expect(harness.requestedAttachmentThreadIds, ['thread-1', 'thread-3']);
        expect(harness.maxConcurrentReads, 1);
        expect(find.text('Linked PRs · Error'), findsOneWidget);

        // Opening the popover shows the bounded single-line error and a focusable Retry button.
        await tester.tap(find.byKey(const ValueKey('thread-linked-pr-pill')));
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('thread-linked-pr-error')),
          findsOneWidget,
        );
        final errorText = tester
            .widget<Text>(find.byKey(const ValueKey('thread-linked-pr-error')))
            .data!;
        expect(errorText.length, lessThanOrEqualTo(160));
        expect(errorText.contains('\n'), isFalse);
        expect(errorText.endsWith('…'), isTrue);
        expect(
          find.byKey(const ValueKey('thread-linked-pr-retry')),
          findsOneWidget,
        );

        // Allow thread-3 to succeed on retry and verify a burst of notifications coalesces.
        harness.failingThreadIds.remove('thread-3');
        final retryCompleter = Completer<ThreadLinkedPullRequestsSnapshot>();
        harness.pendingReadCompleters['thread-3'] = retryCompleter;
        harness.snapshotsByThreadId['thread-3'] =
            const ThreadLinkedPullRequestsSnapshot(
              threadId: 'thread-3',
              pullRequests: [
                ThreadLinkedPullRequest(
                  attachmentId: 'att-pr-300',
                  canonicalIdentityKey: '["github.com","openai","codex",300]',
                  canonicalHost: 'github.com',
                  owner: 'OpenAI',
                  repository: 'Codex',
                  number: 300,
                  canonicalUrl: 'https://github.com/OpenAI/Codex/pull/300',
                  createdAtSeconds: 1700000030,
                ),
              ],
              scannedAttachmentCount: 1,
              truncated: false,
            );

        await tester.tap(find.byKey(const ValueKey('thread-linked-pr-retry')));
        await tester.pump();

        // Emit 3 rapid update notifications while the retry scan is in flight.
        for (var i = 0; i < 3; i++) {
          harness.emitThreadAttachmentUpdated(
            ThreadAttachmentUpdatedEvent(
              threadId: 'thread-3',
              attachmentId: 'att-burst-$i',
              attachmentType: 'pull_request',
              identityKey: '["github.com","openai","codex",300]',
              operation: ThreadAttachmentUpdateOperation.created,
            ),
          );
        }
        await tester.pump();
        expect(harness.maxConcurrentReads, 1);

        retryCompleter.complete(harness.snapshotsByThreadId['thread-3']!);
        await tester.pumpAndSettle();

        // Only 1 retry scan + 1 coalesced burst scan ran for thread-3.
        expect(harness.requestedAttachmentThreadIds, [
          'thread-1',
          'thread-3',
          'thread-3',
          'thread-3',
        ]);
        expect(harness.maxConcurrentReads, 1);
        expect(find.text('OpenAI/Codex#300'), findsWidgets);
      },
    );

    testWidgets(
      'fails closed and hides the header pill when an older runtime latches supportsThreadAttachments=false on first read',
      (tester) async {
        final harness = _LinkedPrSimulatedRuntimeHarness(
          initialThreads: [
            createTestThread(
              id: 'thread-legacy-1',
              preview: 'Legacy runtime thread 1',
              status: ThreadRuntimeStatus.idle,
            ),
            createTestThread(
              id: 'thread-legacy-2',
              preview: 'Legacy runtime thread 2',
              status: ThreadRuntimeStatus.idle,
            ),
          ],
        )..latchUnsupportedOnRead = true;

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(
          find.byKey(const ValueKey('thread-row-thread-legacy-1')),
        );
        await tester.pumpAndSettle();

        expect(harness.requestedAttachmentThreadIds, ['thread-legacy-1']);
        expect(harness.supportsThreadAttachments, isFalse);
        expect(
          find.byKey(const ValueKey('thread-linked-pr-pill')),
          findsNothing,
        );
        expect(find.text('Linked PRs · Error'), findsNothing);

        // Switching to another thread does not scan again once latched false.
        await tester.tap(
          find.byKey(const ValueKey('thread-row-thread-legacy-2')),
        );
        await tester.pumpAndSettle();

        expect(harness.requestedAttachmentThreadIds, ['thread-legacy-1']);
        expect(
          find.byKey(const ValueKey('thread-linked-pr-pill')),
          findsNothing,
        );
      },
    );

    testWidgets(
      'links a PR on a cold thread without resuming, preserves existing/duplicate links truthfully, refuses unverified links when truncated, and keeps read capability when writes latch unsupported',
      (tester) async {
        final harness = _LinkedPrSimulatedRuntimeHarness(
          initialThreads: [
            createTestThread(
              id: 'thread-cold-link',
              preview: 'Cold linkable thread',
              status: ThreadRuntimeStatus.notLoaded,
            ),
            createTestThread(
              id: 'thread-truncated-link',
              preview: 'Truncated attachment thread',
              status: ThreadRuntimeStatus.notLoaded,
            ),
          ],
        );

        harness.snapshotsByThreadId['thread-truncated-link'] =
            const ThreadLinkedPullRequestsSnapshot(
              threadId: 'thread-truncated-link',
              pullRequests: [],
              scannedAttachmentCount: 100,
              truncated: true,
            );

        await pumpSimulatedRuntimeApp(tester, harness: harness);

        await tester.tap(
          find.byKey(const ValueKey('thread-row-thread-cold-link')),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const ValueKey('thread-linked-pr-pill')));
        await tester.pumpAndSettle();

        // Open the Link PR form.
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-add-toggle')),
        );
        await tester.pumpAndSettle();
        expect(
          find.byKey(const ValueKey('thread-linked-pr-add-form')),
          findsOneWidget,
        );

        // Secret-bearing invalid URL shows sanitized error without echoing the secret.
        await tester.enterText(
          find.byKey(const ValueKey('thread-linked-pr-url-input')),
          'https://user:secret_tok_777@github.com/openai/codex/pull/10?tok=secret_q_888',
        );
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-add-submit')),
        );
        await tester.pumpAndSettle();

        final errorText = tester
            .widget<Text>(
              find.byKey(const ValueKey('thread-linked-pr-mutation-error')),
            )
            .data!;
        expect(errorText, contains('Invalid pull request link'));
        expect(errorText, isNot(contains('secret_tok_777')));
        expect(errorText, isNot(contains('secret_q_888')));
        expect(harness.linkedPrCalls, isEmpty);

        // Link a valid GitHub PR URL with optional branch on the cold thread.
        await tester.enterText(
          find.byKey(const ValueKey('thread-linked-pr-url-input')),
          'https://www.github.com/OpenAI/Codex/pull/701',
        );
        await tester.enterText(
          find.byKey(const ValueKey('thread-linked-pr-branch-input')),
          'feat/pr-701',
        );
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-add-submit')),
        );
        await tester.pumpAndSettle();

        expect(harness.linkedPrCalls, hasLength(1));
        expect(
          harness.threads.firstWhere((t) => t.id == 'thread-cold-link').status,
          ThreadRuntimeStatus.notLoaded,
        );
        expect(
          find.text('Linked OpenAI/Codex#701 to this thread.'),
          findsOneWidget,
        );
        expect(find.text('OpenAI/Codex#701'), findsWidgets);
        expect(find.text('Branch: feat/pr-701'), findsOneWidget);

        // Linking the same PR again reports existing stored record preserved without duplicating.
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-add-toggle')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('thread-linked-pr-url-input')),
          'https://github.com/openai/codex/pull/701',
        );
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-add-submit')),
        );
        await tester.pumpAndSettle();

        expect(
          find.text(
            'Already linked to OpenAI/Codex#701 (existing stored record preserved).',
          ),
          findsOneWidget,
        );
        expect(
          harness.snapshotsByThreadId['thread-cold-link']!.pullRequests,
          hasLength(1),
        );

        // Close popover and switch to the truncated thread; linking an unverified PR
        // reports the 100-attachment scan limit instead of blindly writing.
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-popover-close')),
        );
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('thread-row-thread-truncated-link')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('thread-linked-pr-pill')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-add-toggle')),
        );
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('thread-linked-pr-url-input')),
          'https://github.com/OpenAI/Codex/pull/702',
        );
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-add-submit')),
        );
        await tester.pumpAndSettle();

        expect(
          find.textContaining(
            'Could not verify existing links for OpenAI/Codex#702 because this thread exceeds the 100-attachment scan limit.',
          ),
          findsOneWidget,
        );

        // If a write returns -32601 (latches supportsThreadAttachmentWrites=false),
        // the Link PR button hides while the read-only header pill and popover remain functional.
        harness.latchWriteUnsupportedOnLink = true;
        await tester.enterText(
          find.byKey(const ValueKey('thread-linked-pr-url-input')),
          'https://github.com/OpenAI/Codex/pull/703',
        );
        await tester.tap(
          find.byKey(const ValueKey('thread-linked-pr-add-submit')),
        );
        await tester.pumpAndSettle();

        expect(harness.supportsThreadAttachmentWrites, isFalse);
        expect(harness.supportsThreadAttachments, isTrue);
        expect(
          find.byKey(const ValueKey('thread-linked-pr-add-toggle')),
          findsNothing,
        );
        expect(
          find.byKey(const ValueKey('thread-linked-pr-pill')),
          findsOneWidget,
        );
        expect(
          find.text('Linking pull requests is unavailable on this runtime.'),
          findsOneWidget,
        );
      },
    );
  });
}
