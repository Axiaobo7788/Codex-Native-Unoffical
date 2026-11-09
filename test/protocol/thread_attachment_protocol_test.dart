import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/thread_attachment_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/thread_attachment_protocol.dart';
import 'package:codex_native_unofficial/src/transport/process/child_process.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ThreadAttachmentProtocolAdapter', () {
    test('projects canonical GitHub PR and GitLab MR attachments while ignoring non-PR rows and deduplicating', () async {
      final recordedCalls = <({String method, JsonObject params})>[];
      final adapter = ThreadAttachmentProtocolAdapter(
        request: (method, [params = const {}]) async {
          recordedCalls.add((method: method, params: params));
          return {
            'data': [
              {
                'id': 'att-wt-1',
                'attachmentType': 'worktree',
                'identityKey': '/tmp/wt-1',
                'payload': {'root': '/tmp/wt-1', 'workspaceRoot': '/tmp/wt-1'},
                'createdAt': 1700000001,
              },
              {
                'id': 'att-pr-1',
                'attachmentType': 'pull_request',
                'identityKey': '["github.com","openai","codex",412]',
                'payload': {
                  'url': 'https://www.github.com/OpenAI/Codex/pull/412',
                  'headBranch': 'feat/linked-pr',
                },
                'createdAt': 1700000002,
              },
              {
                'id': 'att-pr-dup',
                'attachmentType': 'pull_request',
                'identityKey': 'https://github.com/openai/codex/pull/412',
                'payload': {'url': 'https://github.com/openai/codex/pull/412'},
                'createdAt': 1700000003,
              },
              {
                'id': 'att-mr-1',
                'attachmentType': 'pull_request',
                'identityKey': '["gitlab.com","group/sub","client",77]',
                'payload': {
                  'url':
                      'https://gitlab.com/Group/Sub/Client/-/merge_requests/77',
                  'headBranch': 'fix/mr-77',
                },
                'createdAt': 1700000004,
              },
            ],
            'nextCursor': null,
          };
        },
      );

      final snapshot = await adapter.readLinkedPullRequests('thread-1');

      expect(recordedCalls, hasLength(1));
      expect(recordedCalls.single.method, 'thread/attachment/list');
      expect(recordedCalls.single.params, {
        'threadId': 'thread-1',
        'limit': 16,
      });
      expect(snapshot.threadId, 'thread-1');
      expect(snapshot.scannedAttachmentCount, 4);
      expect(snapshot.truncated, isFalse);
      expect(snapshot.pullRequests, hasLength(2));

      final githubPr = snapshot.pullRequests[0];
      expect(githubPr.attachmentId, 'att-pr-1');
      expect(githubPr.canonicalHost, 'github.com');
      expect(githubPr.owner, 'OpenAI');
      expect(githubPr.repository, 'Codex');
      expect(githubPr.number, 412);
      expect(githubPr.displayLabel, 'OpenAI/Codex#412');
      expect(githubPr.canonicalUrl, 'https://github.com/OpenAI/Codex/pull/412');
      expect(githubPr.headBranch, 'feat/linked-pr');

      final gitlabMr = snapshot.pullRequests[1];
      expect(gitlabMr.attachmentId, 'att-mr-1');
      expect(gitlabMr.canonicalHost, 'gitlab.com');
      expect(gitlabMr.owner, 'Group/Sub');
      expect(gitlabMr.repository, 'Client');
      expect(gitlabMr.number, 77);
      expect(gitlabMr.displayLabel, 'Group/Sub/Client#77');
      expect(
        gitlabMr.canonicalUrl,
        'https://gitlab.com/Group/Sub/Client/-/merge_requests/77',
      );
      expect(gitlabMr.headBranch, 'fix/mr-77');
    });

    test('rejects unsafe URLs (userinfo, query, fragment, http, port, path traversal) and identityKey mismatches', () async {
      final adapter = ThreadAttachmentProtocolAdapter(
        request: (method, [params = const {}]) async => {
          'data': [
            {
              'id': 'bad-scheme',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",1]',
              'payload': {'url': 'http://github.com/openai/codex/pull/1'},
              'createdAt': 1,
            },
            {
              'id': 'bad-userinfo',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",2]',
              'payload': {
                'url': 'https://token:secret@github.com/openai/codex/pull/2',
              },
              'createdAt': 2,
            },
            {
              'id': 'bad-query',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",3]',
              'payload': {
                'url': 'https://github.com/openai/codex/pull/3?redirect=1',
              },
              'createdAt': 3,
            },
            {
              'id': 'bad-empty-query',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",4]',
              'payload': {'url': 'https://github.com/openai/codex/pull/4?'},
              'createdAt': 4,
            },
            {
              'id': 'bad-fragment',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",5]',
              'payload': {
                'url': 'https://github.com/openai/codex/pull/5#files',
              },
              'createdAt': 5,
            },
            {
              'id': 'bad-port',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",6]',
              'payload': {'url': 'https://github.com:443/openai/codex/pull/6'},
              'createdAt': 6,
            },
            {
              'id': 'bad-mismatch-number',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",7]',
              'payload': {'url': 'https://github.com/openai/codex/pull/999'},
              'createdAt': 7,
            },
            {
              'id': 'bad-mismatch-repo',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",8]',
              'payload': {'url': 'https://github.com/openai/other/pull/8'},
              'createdAt': 8,
            },
            {
              'id': 'bad-percent-ff',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","%ff","repo",1]',
              'payload': {'url': 'https://github.com/%ff/repo/pull/1'},
              'createdAt': 9,
            },
            {
              'id': 'bad-percent-overlong',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","%c0%af","repo",1]',
              'payload': {'url': 'https://github.com/%C0%AF/repo/pull/1'},
              'createdAt': 10,
            },
            {'attachmentType': 'worktree', 'identityKey': 'w' * 2048},
            {
              'id': 'good-pr',
              'attachmentType': 'pull_request',
              'identityKey': '["github.com","openai","codex",9]',
              'payload': {'url': 'https://github.com/openai/codex/pull/9'},
              'createdAt': 11,
            },
          ],
          'nextCursor': null,
        },
      );

      final snapshot = await adapter.readLinkedPullRequests('thread-safe');
      expect(snapshot.scannedAttachmentCount, 12);
      expect(snapshot.pullRequests, hasLength(1));
      expect(snapshot.pullRequests.single.attachmentId, 'good-pr');
      expect(
        snapshot.pullRequests.single.canonicalUrl,
        'https://github.com/openai/codex/pull/9',
      );
    });

    test(
      'stops at maxScannedPages when server returns many 1-row pages',
      () async {
        var pageCalls = 0;
        final adapter = ThreadAttachmentProtocolAdapter(
          request: (method, [params = const {}]) async {
            pageCalls += 1;
            return {
              'data': [
                {
                  'id': 'wt-$pageCalls',
                  'attachmentType': 'worktree',
                  'identityKey': '/tmp/wt-$pageCalls',
                  'payload': const <String, Object?>{},
                  'createdAt': pageCalls,
                },
              ],
              'nextCursor': 'cursor-$pageCalls',
            };
          },
        );

        final snapshot = await adapter.readLinkedPullRequests(
          'thread-tiny-pages',
        );
        expect(pageCalls, ThreadAttachmentProtocolAdapter.maxScannedPages);
        expect(
          snapshot.scannedAttachmentCount,
          ThreadAttachmentProtocolAdapter.maxScannedPages,
        );
        expect(snapshot.truncated, isTrue);
        expect(snapshot.pullRequests, isEmpty);
      },
    );

    test('pages in 16-row slices up to 100 scanned rows and marks truncated when scan limit stops early', () async {
      final requestedLimits = <int>[];
      var pageIndex = 0;
      final adapter = ThreadAttachmentProtocolAdapter(
        request: (method, [params = const {}]) async {
          final limit = params['limit'] as int;
          requestedLimits.add(limit);
          pageIndex += 1;
          return {
            'data': [
              for (var i = 0; i < limit; i++)
                if (pageIndex == 1 && i == 0)
                  {
                    'id': 'pr-1',
                    'attachmentType': 'pull_request',
                    'identityKey': '["github.com","openai","codex",10]',
                    'payload': {
                      'url': 'https://github.com/openai/codex/pull/10',
                    },
                    'createdAt': 10,
                  }
                else
                  {
                    'id': 'wt-$pageIndex-$i',
                    'attachmentType': 'worktree',
                    'identityKey': '/tmp/wt-$pageIndex-$i',
                    'payload': {'root': '/tmp/wt-$pageIndex-$i'},
                    'createdAt': pageIndex * 100 + i,
                  },
            ],
            'nextCursor': 'cursor-$pageIndex',
          };
        },
      );

      final snapshot = await adapter.readLinkedPullRequests('thread-paged');

      expect(requestedLimits, [16, 16, 16, 16, 16, 16, 4]);
      expect(snapshot.scannedAttachmentCount, 100);
      expect(snapshot.truncated, isTrue);
      expect(snapshot.pullRequests, hasLength(1));
      expect(snapshot.pullRequests.single.number, 10);
    });

    test(
      'guards against duplicate pagination cursors and oversized pages',
      () async {
        final duplicateCursorAdapter = ThreadAttachmentProtocolAdapter(
          request: (method, [params = const {}]) async => {
            'data': [
              {
                'id': 'wt-1',
                'attachmentType': 'worktree',
                'identityKey': '/tmp/wt-1',
                'payload': const <String, Object?>{},
                'createdAt': 1,
              },
            ],
            'nextCursor': 'same-cursor',
          },
        );

        await expectLater(
          duplicateCursorAdapter.readLinkedPullRequests('thread-dup'),
          throwsA(isA<ProtocolViolation>()),
        );

        final oversizedAdapter = ThreadAttachmentProtocolAdapter(
          request: (method, [params = const {}]) async => {
            'data': [
              for (var i = 0; i < 17; i++)
                {
                  'id': 'wt-$i',
                  'attachmentType': 'worktree',
                  'identityKey': '/tmp/wt-$i',
                  'payload': const <String, Object?>{},
                  'createdAt': i,
                },
            ],
            'nextCursor': null,
          },
        );

        await expectLater(
          oversizedAdapter.readLinkedPullRequests('thread-oversized'),
          throwsA(isA<ProtocolViolation>()),
        );
      },
    );

    test('parses thread/attachment/updated notifications', () async {
      final notifications = StreamController<CodexNotification>.broadcast();
      final adapter = ThreadAttachmentProtocolAdapter(
        request: (method, [params = const {}]) async => const {'data': []},
        notifications: notifications.stream,
      );

      final events = <ThreadAttachmentEvent>[];
      final sub = adapter.events.listen(events.add);

      notifications.add(
        const CodexNotification(
          method: 'thread/attachment/updated',
          params: {
            'threadId': 'thread-1',
            'attachmentId': 'att-1',
            'attachmentType': 'pull_request',
            'identityKey': '["github.com","openai","codex",55]',
            'operation': 'created',
          },
        ),
      );
      notifications.add(
        const CodexNotification(
          method: 'thread/attachment/updated',
          params: {
            'threadId': '',
            'attachmentId': 'att-bad',
            'attachmentType': 'pull_request',
            'identityKey': '["github.com","openai","codex",55]',
            'operation': 'deleted',
          },
        ),
      );
      await Future<void>.delayed(Duration.zero);

      expect(events, hasLength(1));
      final event = events.single as ThreadAttachmentUpdatedEvent;
      expect(event.threadId, 'thread-1');
      expect(event.attachmentId, 'att-1');
      expect(event.attachmentType, 'pull_request');
      expect(event.operation, ThreadAttachmentUpdateOperation.created);

      await sub.cancel();
      await notifications.close();
    });

    test('ProcessTransport latches supportsThreadAttachments=false on JSON-RPC -32601, rethrows first error, and throws UnsupportedError thereafter', () async {
      final fakeChild = _FakeAttachmentChildProcess(
        onRequest: (id, method, params) {
          if (method == 'thread/attachment/list') {
            return {
              'id': id,
              'error': {'code': -32601, 'message': 'Method not found'},
            };
          }
          return {'id': id, 'result': const <String, Object?>{}};
        },
      );
      final transport = await ProcessTransport.start(
        executablePath: 'fake-codex',
        launcher: (_, _) async => fakeChild,
      );

      expect(transport.supportsThreadAttachments, isTrue);

      await expectLater(
        transport.readLinkedPullRequests('thread-1'),
        throwsA(isA<JsonRpcException>().having((e) => e.code, 'code', -32601)),
      );
      expect(transport.supportsThreadAttachments, isFalse);
      expect(fakeChild.receivedMethods, ['thread/attachment/list']);

      // Subsequent reads throw UnsupportedError without issuing another RPC.
      await expectLater(
        transport.readLinkedPullRequests('thread-2'),
        throwsA(isA<UnsupportedError>()),
      );
      expect(fakeChild.receivedMethods, ['thread/attachment/list']);

      await transport.close();
    });

    test('linkPullRequest preflight-scans the thread, creates a canonical pull_request attachment when absent, and enforces 256-byte identityKey and secret-safe errors', () async {
      final recordedCalls = <({String method, JsonObject params})>[];
      final adapter = ThreadAttachmentProtocolAdapter(
        request: (method, [params = const {}]) async {
          recordedCalls.add((method: method, params: params));
          if (method == 'thread/attachment/list') {
            return {'data': const <Object?>[], 'nextCursor': null};
          }
          if (method == 'thread/attachment/add') {
            return {
              'outcome': 'created',
              'attachment': {
                'id': 'att-created-1',
                'attachmentType': 'pull_request',
                'identityKey': params['identityKey'],
                'payload': params['payload'],
                'createdAt': 1700000100,
              },
            };
          }
          throw StateError('Unexpected method: $method');
        },
      );

      final result = await adapter.linkPullRequest(
        'thread-link-1',
        url: 'https://www.github.com/OpenAI/Codex/pull/888',
        headBranch: '  feat/link-888  ',
      );

      expect(result.outcome, ThreadPullRequestLinkOutcome.created);
      expect(result.pullRequest.attachmentId, 'att-created-1');
      expect(
        result.pullRequest.canonicalIdentityKey,
        '["github.com","openai","codex",888]',
      );
      expect(
        result.pullRequest.canonicalUrl,
        'https://github.com/OpenAI/Codex/pull/888',
      );
      expect(result.pullRequest.headBranch, 'feat/link-888');
      expect(recordedCalls, hasLength(2));
      expect(recordedCalls[0].method, 'thread/attachment/list');
      expect(recordedCalls[0].params, {
        'threadId': 'thread-link-1',
        'limit': 16,
      });
      expect(recordedCalls[1].method, 'thread/attachment/add');
      expect(recordedCalls[1].params, {
        'threadId': 'thread-link-1',
        'attachmentType': 'pull_request',
        'identityKey': '["github.com","openai","codex",888]',
        'payload': {
          'url': 'https://github.com/OpenAI/Codex/pull/888',
          'headBranch': 'feat/link-888',
        },
      });

      // Secret-bearing userinfo/query URLs fail locally without echoing the secret
      // in the thrown ArgumentError string.
      Object? caughtSecretError;
      try {
        await adapter.linkPullRequest(
          'thread-link-1',
          url: 'https://user:super_secret_token_999@github.com/openai/codex/pull/1?token=leak_me_123',
        );
      } on Object catch (error) {
        caughtSecretError = error;
      }
      expect(caughtSecretError, isA<ArgumentError>());
      expect(
        caughtSecretError.toString(),
        isNot(contains('super_secret_token_999')),
      );
      expect(caughtSecretError.toString(), isNot(contains('leak_me_123')));
      expect(recordedCalls, hasLength(2));

      // Canonical identity exceeding 256 UTF-8 bytes fails locally before any RPC.
      final longSeg = 'a' * 60;
      final over256GitLabUrl =
          'https://gitlab.com/$longSeg/$longSeg/$longSeg/$longSeg/$longSeg/-/merge_requests/12345';
      final parsedLong =
          ThreadAttachmentProtocolAdapter.tryParseCanonicalPullRequestUrl(
            over256GitLabUrl,
          );
      expect(parsedLong, isNotNull);
      expect(
        utf8.encode(parsedLong!.canonicalIdentityKey).length,
        greaterThan(256),
      );

      await expectLater(
        adapter.linkPullRequest('thread-link-1', url: over256GitLabUrl),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.toString(),
            'toString',
            allOf(
              contains('256 UTF-8 bytes'),
              isNot(contains(over256GitLabUrl)),
            ),
          ),
        ),
      );
      expect(recordedCalls, hasLength(2));
    });

    test('linkPullRequest detects an already-linked legacy URL row during preflight without adding a duplicate canonical row, and returns scanIncomplete when preflight truncates', () async {
      final recordedMethods = <String>[];
      final legacyAdapter = ThreadAttachmentProtocolAdapter(
        request: (method, [params = const {}]) async {
          recordedMethods.add(method);
          return {
            'data': [
              {
                'id': 'att-legacy-412',
                'attachmentType': 'pull_request',
                'identityKey': 'https://github.com/openai/codex/pull/412',
                'payload': {
                  'url': 'https://github.com/OpenAI/Codex/pull/412',
                  'headBranch': 'legacy-branch',
                },
                'createdAt': 1700000002,
              },
            ],
            'nextCursor': null,
          };
        },
      );

      final legacyResult = await legacyAdapter.linkPullRequest(
        'thread-legacy-dup',
        url: 'https://github.com/OpenAI/Codex/pull/412',
        headBranch: 'new-branch-ignored',
      );

      expect(legacyResult.outcome, ThreadPullRequestLinkOutcome.existing);
      expect(legacyResult.pullRequest.attachmentId, 'att-legacy-412');
      expect(legacyResult.pullRequest.headBranch, 'legacy-branch');
      // Never issued thread/attachment/add because legacy row already links this PR.
      expect(recordedMethods, ['thread/attachment/list']);

      // When preflight hits the 100-row scan cap without confirming absence,
      // returns scanIncomplete without calling thread/attachment/add.
      final truncatedMethods = <String>[];
      var page = 0;
      final truncatedAdapter = ThreadAttachmentProtocolAdapter(
        request: (method, [params = const {}]) async {
          truncatedMethods.add(method);
          page += 1;
          final limit = params['limit'] as int;
          return {
            'data': [
              for (var i = 0; i < limit; i++)
                {
                  'id': 'wt-$page-$i',
                  'attachmentType': 'worktree',
                  'identityKey': '/tmp/wt-$page-$i',
                  'payload': const <String, Object?>{},
                  'createdAt': page * 100 + i,
                },
            ],
            'nextCursor': 'cursor-$page',
          };
        },
      );

      final incompleteResult = await truncatedAdapter.linkPullRequest(
        'thread-truncated',
        url: 'https://github.com/OpenAI/Codex/pull/900',
      );
      expect(
        incompleteResult.outcome,
        ThreadPullRequestLinkOutcome.scanIncomplete,
      );
      expect(incompleteResult.pullRequest.displayLabel, 'OpenAI/Codex#900');
      expect(
        truncatedMethods.every((m) => m == 'thread/attachment/list'),
        isTrue,
      );
    });

    test('ProcessTransport latches supportsThreadAttachmentWrites=false on add -32601 while preserving readLinkedPullRequests capability', () async {
      final fakeChild = _FakeAttachmentChildProcess(
        onRequest: (id, method, params) {
          if (method == 'thread/attachment/list') {
            return {
              'id': id,
              'result': {'data': const <Object?>[], 'nextCursor': null},
            };
          }
          if (method == 'thread/attachment/add') {
            return {
              'id': id,
              'error': {'code': -32601, 'message': 'Method not found'},
            };
          }
          return {'id': id, 'result': const <String, Object?>{}};
        },
      );
      final transport = await ProcessTransport.start(
        executablePath: 'fake-codex',
        launcher: (_, _) async => fakeChild,
      );

      expect(transport.supportsThreadAttachments, isTrue);
      expect(transport.supportsThreadAttachmentWrites, isTrue);

      await expectLater(
        transport.linkPullRequest(
          'thread-1',
          url: 'https://github.com/openai/codex/pull/12',
        ),
        throwsA(isA<JsonRpcException>().having((e) => e.code, 'code', -32601)),
      );

      // Write capability is latched false, but read capability remains true!
      expect(transport.supportsThreadAttachmentWrites, isFalse);
      expect(transport.supportsThreadAttachments, isTrue);

      // Subsequent linkPullRequest fails locally with UnsupportedError.
      await expectLater(
        transport.linkPullRequest(
          'thread-1',
          url: 'https://github.com/openai/codex/pull/13',
        ),
        throwsA(isA<UnsupportedError>()),
      );

      // Read path still works against the transport.
      final snapshot = await transport.readLinkedPullRequests('thread-1');
      expect(snapshot.pullRequests, isEmpty);

      await transport.close();
    });
  });
}

final class _FakeAttachmentChildProcess implements ChildProcess {
  _FakeAttachmentChildProcess({required this.onRequest});

  final Map<String, Object?> Function(
    Object id,
    String method,
    Map<String, Object?> params,
  )
  onRequest;
  final StreamController<List<int>> _stdout = StreamController<List<int>>();
  final StreamController<List<int>> _stderr = StreamController<List<int>>();
  final Completer<int> _exitCode = Completer<int>();
  final List<String> receivedMethods = <String>[];

  @override
  int get pid => 4242;

  @override
  Stream<List<int>> get stdout => _stdout.stream;

  @override
  Stream<List<int>> get stderr => _stderr.stream;

  @override
  Future<int> get exitCode => _exitCode.future;

  @override
  Future<void> write(String value) async {
    for (final line in value.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }
      final decoded = jsonDecode(trimmed) as Map<String, Object?>;
      final method = decoded['method'] as String?;
      final id = decoded['id'];
      if (method != null && id != null) {
        receivedMethods.add(method);
        final params =
            (decoded['params'] as Map<String, Object?>?) ??
            const <String, Object?>{};
        final response = onRequest(id, method, params);
        _stdout.add(utf8.encode('${jsonEncode(response)}\n'));
      }
    }
  }

  @override
  Future<void> closeInput() async {
    if (!_exitCode.isCompleted) {
      _exitCode.complete(0);
    }
    await _stdout.close();
    await _stderr.close();
  }

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) {
    if (!_exitCode.isCompleted) {
      _exitCode.complete(0);
    }
    return true;
  }
}
