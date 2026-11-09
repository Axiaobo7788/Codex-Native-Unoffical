import 'dart:async';

import 'package:codex_native_unofficial/src/domain/thread_attachment_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/thread_attachment_protocol.dart';
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
  });
}
