import 'dart:async';

import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/protocol/jsonl_decoder.dart';
import 'package:codex_native_unofficial/src/protocol/server_request_protocol.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late StreamController<CodexServerRequest> requests;
  late StreamController<CodexNotification> notifications;
  late ServerRequestProtocolAdapter adapter;
  late List<(Object, JsonObject)> replies;
  late List<(Object, int, String)> errors;

  setUp(() {
    requests = StreamController.broadcast(sync: true);
    notifications = StreamController.broadcast(sync: true);
    replies = [];
    errors = [];
    adapter = ServerRequestProtocolAdapter(
      serverRequests: requests.stream,
      notifications: notifications.stream,
      respond: (id, result) async => replies.add((id, result)),
      respondError: (id, code, message) async =>
          errors.add((id, code, message)),
    );
  });

  tearDown(() async {
    await adapter.dispose();
    await requests.close();
    await notifications.close();
  });

  Future<ApprovalRequest> command(JsonObject params, {Object id = 1}) async {
    final next = adapter.approvalEvents.first;
    requests.add(
      CodexServerRequest(
        id: id,
        method: 'item/commandExecution/requestApproval',
        params: {'threadId': 'thread', 'itemId': 'item', ...params},
      ),
    );
    return (await next as ApprovalRequestedEvent).request;
  }

  test(
    'preserves advertised order and session vs cancel wire semantics',
    () async {
      final request = await command({
        'availableDecisions': ['acceptForSession', 'cancel', 'accept'],
      });
      expect(request.availableDecisions, [
        ApprovalDecision.approveForSession,
        ApprovalDecision.cancelTurn,
        ApprovalDecision.approveOnce,
      ]);
      await adapter.decideApproval(
        requestId: 1,
        decision: ApprovalDecision.approveForSession,
      );
      expect(replies.single.$2, {'decision': 'acceptForSession'});

      await command({
        'availableDecisions': ['cancel'],
      }, id: 2);
      await adapter.decideApproval(
        requestId: 2,
        decision: ApprovalDecision.cancelTurn,
      );
      expect(replies.last.$2, {'decision': 'cancel'});
    },
  );

  test(
    'only exact offered policy payload is accepted, including whitespace',
    () async {
      final request = await command({
        'availableDecisions': [
          {
            'acceptWithExecpolicyAmendment': {
              'execpolicy_amendment': ['printf', ' a b '],
            },
          },
          'accept',
        ],
      });
      final decision = request.availableDecisions.first;
      await expectLater(
        adapter.decideApproval(
          requestId: 1,
          decision: ApprovalDecision.withExecpolicyAmendment([
            'printf',
            ' a b ',
          ]),
        ),
        throwsUnsupportedError,
      );
      expect(replies, isEmpty);
      expect(
        () => decision.execpolicyAmendment.add('sh'),
        throwsUnsupportedError,
      );
      await adapter.decideApproval(requestId: 1, decision: decision);
      expect(replies.single.$2, {
        'decision': {
          'acceptWithExecpolicyAmendment': {
            'execpolicy_amendment': ['printf', ' a b '],
          },
        },
      });
    },
  );

  test('network allow/deny retain each exact host and action', () async {
    final request = await command({
      'availableDecisions': [
        {
          'applyNetworkPolicyAmendment': {
            'network_policy_amendment': {
              'host': 'one.example.invalid',
              'action': 'allow',
            },
          },
        },
        {
          'applyNetworkPolicyAmendment': {
            'network_policy_amendment': {
              'host': 'two.example.invalid',
              'action': 'deny',
            },
          },
        },
        'decline',
      ],
    });
    expect(request.availableDecisions[0].networkHost, 'one.example.invalid');
    final decision = request.availableDecisions[1];
    expect(decision.networkHost, 'two.example.invalid');
    expect(decision.networkAction, ApprovalNetworkAction.deny);
    await adapter.decideApproval(requestId: 1, decision: decision);
    expect(replies.single.$2, {
      'decision': {
        'applyNetworkPolicyAmendment': {
          'network_policy_amendment': {
            'host': 'two.example.invalid',
            'action': 'deny',
          },
        },
      },
    });
  });

  test(
    'explicit restrictions cannot become one-time or session grants',
    () async {
      final request = await command({
        'availableDecisions': ['cancel'],
      });
      expect(request.approveSupported, isFalse);
      for (final decision in [
        ApprovalDecision.approveOnce,
        ApprovalDecision.approveForSession,
      ]) {
        await expectLater(
          adapter.decideApproval(requestId: 1, decision: decision),
          throwsUnsupportedError,
        );
      }
      expect(replies, isEmpty);
      // Decline is stable and the official deny action remains independent of
      // reusable grants. It must never silently become turn cancellation.
      await adapter.decideApproval(
        requestId: 1,
        decision: ApprovalDecision.reject,
      );
      expect(replies.single.$2, {'decision': 'decline'});
      expect(errors, isEmpty);
    },
  );

  test(
    'old command context does not invent generic session approval',
    () async {
      final request = await command({});
      expect(request.supports(ApprovalDecision.approveOnce), isTrue);
      expect(request.supports(ApprovalDecision.approveForSession), isFalse);
      expect(request.supports(ApprovalDecision.cancelTurn), isTrue);
      await expectLater(
        adapter.decideApproval(
          requestId: 1,
          decision: ApprovalDecision.approveForSession,
        ),
        throwsUnsupportedError,
      );
      await adapter.decideApproval(
        requestId: 1,
        decision: ApprovalDecision.reject,
      );
      expect(replies.single.$2, {'decision': 'decline'});
    },
  );

  test(
    'old command fallback uses exact proposed rule and no invented prefix',
    () async {
      final request = await command({
        'proposedExecpolicyAmendment': ['printf', 'fixed'],
      });
      final choice = request.availableDecisions.singleWhere(
        (choice) =>
            choice.kind == ApprovalDecisionKind.approveWithExecpolicyAmendment,
      );
      await adapter.decideApproval(requestId: 1, decision: choice);
      expect(replies.single.$2, {
        'decision': {
          'acceptWithExecpolicyAmendment': {
            'execpolicy_amendment': ['printf', 'fixed'],
          },
        },
      });
    },
  );

  test('legacy network context admits only the proposed allow rule', () async {
    final request = await command({
      'networkApprovalContext': {
        'host': 'api.example.invalid',
        'protocol': 'https',
      },
      'proposedNetworkPolicyAmendments': [
        {'host': 'api.example.invalid', 'action': 'deny'},
        {'host': 'api.example.invalid', 'action': 'allow'},
      ],
    });
    expect(request.supports(ApprovalDecision.approveForSession), isTrue);
    final rule = request.availableDecisions.singleWhere(
      (choice) =>
          choice.kind == ApprovalDecisionKind.applyNetworkPolicyAmendment,
    );
    expect(rule.networkAction, ApprovalNetworkAction.allow);
    expect(rule.networkHost, 'api.example.invalid');
    await adapter.decideApproval(requestId: 1, decision: rule);
    expect(replies.single.$2, {
      'decision': {
        'applyNetworkPolicyAmendment': {
          'network_policy_amendment': {
            'host': 'api.example.invalid',
            'action': 'allow',
          },
        },
      },
    });
  });

  test(
    'additional permissions never infer a reusable grant from a prefix',
    () async {
      final request = await command({
        'additionalPermissions': {
          'network': {'enabled': true},
        },
        'proposedExecpolicyAmendment': ['printf'],
      });
      expect(request.availableDecisions, [
        ApprovalDecision.approveOnce,
        ApprovalDecision.reject,
        ApprovalDecision.cancelTurn,
      ]);
    },
  );

  test('human checkpoint never receives reusable consent', () async {
    final request = await command({
      'kind': 'humanCommand',
      'proposedExecpolicyAmendment': ['printf'],
      'availableDecisions': [
        'acceptForSession',
        {
          'acceptWithExecpolicyAmendment': {
            'execpolicy_amendment': ['printf'],
          },
        },
        'accept',
        'decline',
        'cancel',
      ],
    });
    expect(request.availableDecisions, [
      ApprovalDecision.approveOnce,
      ApprovalDecision.reject,
      ApprovalDecision.cancelTurn,
    ]);
    await expectLater(
      adapter.decideApproval(
        requestId: 1,
        decision: ApprovalDecision.approveForSession,
      ),
      throwsUnsupportedError,
    );
  });

  test('file session approval has its own stable wire path', () async {
    final next = adapter.approvalEvents.first;
    requests.add(
      const CodexServerRequest(
        id: 'patch',
        method: 'item/fileChange/requestApproval',
        params: {'threadId': 'thread'},
      ),
    );
    final request = (await next as ApprovalRequestedEvent).request;
    expect(request.supports(ApprovalDecision.approveForSession), isTrue);
    await adapter.decideApproval(
      requestId: 'patch',
      decision: ApprovalDecision.approveForSession,
    );
    expect(replies.single.$2, {'decision': 'acceptForSession'});
  });

  test(
    'a retired policy choice cannot authorize a reused protocol ID',
    () async {
      const params = <String, Object?>{
        'availableDecisions': [
          {
            'acceptWithExecpolicyAmendment': {
              'execpolicy_amendment': ['printf'],
            },
          },
          'decline',
        ],
      };
      final old = await command(params);
      notifications.add(
        const CodexNotification(
          method: 'serverRequest/resolved',
          params: {'requestId': 1, 'threadId': 'thread'},
        ),
      );
      await pumpEventQueue();
      final current = await command(params);
      await expectLater(
        adapter.decideApproval(
          requestId: 1,
          decision: old.availableDecisions.first,
        ),
        throwsUnsupportedError,
      );
      expect(replies, isEmpty);
      await adapter.decideApproval(
        requestId: 1,
        decision: current.availableDecisions.first,
      );
      expect(replies, hasLength(1));
    },
  );

  test('legacy and unsupported approvals do not inherit new grants', () async {
    for (final method in [
      'execCommandApproval',
      'applyPatchApproval',
      'item/permissions/requestApproval',
    ]) {
      final next = adapter.approvalEvents.first;
      requests.add(
        CodexServerRequest(id: method, method: method, params: const {}),
      );
      final request = (await next as ApprovalRequestedEvent).request;
      expect(request.supports(ApprovalDecision.approveForSession), isFalse);
      await expectLater(
        adapter.decideApproval(
          requestId: method,
          decision: ApprovalDecision.approveForSession,
        ),
        throwsUnsupportedError,
      );
      await adapter.decideApproval(
        requestId: method,
        decision: ApprovalDecision.reject,
      );
    }
    expect(errors.single.$1, 'item/permissions/requestApproval');
    expect(replies, hasLength(2));
  });

  test(
    'unknown-only and empty advertised sets resolve without a stuck card',
    () async {
      for (final decisions in [
        <Object?>[],
        ['futureGrant'],
      ]) {
        requests.add(
          CodexServerRequest(
            id: errors.length + 20,
            method: 'item/commandExecution/requestApproval',
            params: {'availableDecisions': decisions},
          ),
        );
        await pumpEventQueue();
      }
      expect(errors, hasLength(2));
      expect(errors.every((error) => error.$2 == -32000), isTrue);
    },
  );

  test('malformed and oversized proposals fail deterministically', () async {
    final invalid = <Object?>[
      List.filled(17, 'accept'),
      [
        {
          'acceptWithExecpolicyAmendment': {'execpolicy_amendment': <String>[]},
        },
      ],
      [
        {
          'acceptWithExecpolicyAmendment': {
            'execpolicy_amendment': ['x' * 1025],
          },
        },
      ],
      [
        {
          'applyNetworkPolicyAmendment': {
            'network_policy_amendment': {
              'host': 'example.invalid',
              'action': 'unknown',
            },
          },
        },
      ],
    ];
    for (var i = 0; i < invalid.length; i++) {
      requests.add(
        CodexServerRequest(
          id: 50 + i,
          method: 'item/commandExecution/requestApproval',
          params: {'availableDecisions': invalid[i]},
        ),
      );
      await pumpEventQueue();
    }
    expect(errors, hasLength(invalid.length));
    expect(errors.every((error) => error.$2 == -32602), isTrue);
    expect(replies, isEmpty);
  });

  test('duplicate structured choices collapse locally without reusing identity across requests', () async {
    const params = <String, Object?>{
      'availableDecisions': [
        {
          'acceptWithExecpolicyAmendment': {
            'execpolicy_amendment': ['printf'],
          },
        },
        {
          'acceptWithExecpolicyAmendment': {
            'execpolicy_amendment': ['printf'],
          },
        },
        {
          'applyNetworkPolicyAmendment': {
            'network_policy_amendment': {
              'host': 'example.invalid',
              'action': 'allow',
            },
          },
        },
        {
          'applyNetworkPolicyAmendment': {
            'network_policy_amendment': {
              'host': 'example.invalid',
              'action': 'allow',
            },
          },
        },
        'decline',
      ],
    };
    final first = await command(params);
    expect(first.availableDecisions, hasLength(3));
    await adapter.decideApproval(
      requestId: 1,
      decision: ApprovalDecision.reject,
    );
    final second = await command(params, id: 2);
    expect(second.availableDecisions, hasLength(3));
    await expectLater(
      adapter.decideApproval(
        requestId: 2,
        decision: first.availableDecisions.first,
      ),
      throwsUnsupportedError,
    );
    await adapter.decideApproval(
      requestId: 2,
      decision: second.availableDecisions.first,
    );
    expect(replies.last.$2, {
      'decision': {
        'acceptWithExecpolicyAmendment': {
          'execpolicy_amendment': ['printf'],
        },
      },
    });
  });

  test('legacy multiline rule is suppressed without changing an explicitly offered rule', () async {
    final legacy = await command({
      'proposedExecpolicyAmendment': ['printf', 'line1\n2: spoofed\r'],
    });
    expect(
      legacy.availableDecisions.any(
        (choice) =>
            choice.kind == ApprovalDecisionKind.approveWithExecpolicyAmendment,
      ),
      isFalse,
    );
    await adapter.decideApproval(
      requestId: 1,
      decision: ApprovalDecision.reject,
    );
    final explicit = await command({
      'availableDecisions': [
        {
          'acceptWithExecpolicyAmendment': {
            'execpolicy_amendment': ['printf', 'line1\n2: spoofed\r'],
          },
        },
        'decline',
      ],
    }, id: 2);
    final rule = explicit.availableDecisions.first;
    await adapter.decideApproval(requestId: 2, decision: rule);
    expect(replies.last.$2, {
      'decision': {
        'acceptWithExecpolicyAmendment': {
          'execpolicy_amendment': ['printf', 'line1\n2: spoofed\r'],
        },
      },
    });
  });
}
