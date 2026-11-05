import 'dart:async';
import 'dart:io';

import 'package:codex_native_unofficial/src/app/runtime_controller.dart';
import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/features/conversation/conversation_controller.dart';
import 'package:codex_native_unofficial/src/features/diff/diff_controller.dart';
import 'package:codex_native_unofficial/src/features/settings/execution_settings_controller.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'completes a bounded real coding task through production controllers',
    _runSmoke,
    timeout: const Timeout(Duration(minutes: 5)),
  );
}

Future<void> _runSmoke() async {
  final workspace = await Directory.systemTemp.createTemp(
    'codex-native-coding-smoke-',
  );
  final target = File('${workspace.path}/notes.txt');
  await target.writeAsString('alpha\n', flush: true);

  final runtime = RuntimeController();
  final settings = ExecutionSettingsController(gateway: runtime)
    ..selectApprovalPolicy(ApprovalPolicyOverride.never)
    ..selectSandbox(SandboxModeOverride.workspaceWrite);
  final conversation = ConversationController(
    gateway: runtime,
    settings: settings,
  );
  final diff = DiffController(gateway: runtime);
  StreamSubscription<TurnEvent>? turnSubscription;
  StreamSubscription<ApprovalEvent>? approvalSubscription;
  String? smokeThreadId;
  String? activeTurnId;
  final terminal = Completer<TurnCompletedEvent>();
  var unexpectedApprovals = 0;

  try {
    await runtime.start();
    final thread = await runtime.startThread(
      settings.threadOptions(workspace.path),
    );
    smokeThreadId = thread.id;
    conversation.bindThread(thread);
    diff.bindThread(thread);

    approvalSubscription = runtime.approvalEvents.listen((event) {
      if (event case ApprovalRequestedEvent()) {
        unexpectedApprovals += 1;
        unawaited(
          runtime.decideApproval(
            requestId: event.request.requestId,
            decision: ApprovalDecision.reject,
          ),
        );
      }
    });
    turnSubscription = runtime.turnEvents.listen((event) {
      if (event.threadId != smokeThreadId) {
        return;
      }
      switch (event) {
        case TurnStartedEvent():
          activeTurnId = event.turnId;
        case TurnCompletedEvent():
          if (!terminal.isCompleted) {
            terminal.complete(event);
          }
        case TurnErrorEvent():
          if (!event.willRetry && !terminal.isCompleted) {
            terminal.completeError(StateError(event.message));
          }
        case AssistantTextDeltaEvent():
        case AssistantMessageEvent():
        case ActivityEvent():
        case TurnDiffUpdatedEvent():
      }
    });

    if (!await conversation.submit(
      'Edit notes.txt with apply_patch so it contains exactly two lines: '
      'alpha and beta. Do not modify any other file. Then reply with exactly '
      'CODING_TASK_DONE.',
    )) {
      throw StateError('Conversation controller rejected the smoke turn.');
    }

    final completed = await terminal.future.timeout(const Duration(minutes: 3));
    if (completed.status != TurnRuntimeStatus.completed) {
      throw StateError('Turn ended with status ${completed.status.name}.');
    }
    if (await target.readAsString() != 'alpha\nbeta\n') {
      throw StateError('Codex did not produce the expected file content.');
    }
    final entries = workspace.listSync(followLinks: false);
    if (entries.length != 1 || entries.single.path != target.path) {
      throw StateError('Codex changed files outside the requested target.');
    }
    final snapshot = diff.snapshot;
    if (snapshot == null ||
        !snapshot.files.any((file) => file.path.endsWith('notes.txt'))) {
      throw StateError('No typed notes.txt diff was projected.');
    }
    if (!conversation.entries.any(
      (entry) => entry.text.contains('CODING_TASK_DONE'),
    )) {
      throw StateError('Assistant completion marker was not projected.');
    }

    stdout.writeln('CODING_TASK_SMOKE=PASS');
    stdout.writeln('TURN_STATUS=${completed.status.name}');
    stdout.writeln('CHANGED_FILES=${snapshot.files.length}');
    stdout.writeln('ADDITIONS=${snapshot.additions}');
    stdout.writeln('UNEXPECTED_APPROVALS=$unexpectedApprovals');
  } catch (error, stackTrace) {
    stderr.writeln('CODING_TASK_SMOKE=FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    final threadId = smokeThreadId;
    final turnId = activeTurnId;
    if (threadId != null && turnId != null) {
      try {
        await runtime.interruptTurn(threadId: threadId, turnId: turnId);
      } catch (_) {
        // The turn may already be terminal.
      }
    }
    rethrow;
  } finally {
    await turnSubscription?.cancel();
    await approvalSubscription?.cancel();
    if (smokeThreadId case final threadId?) {
      try {
        await runtime.deleteThread(threadId);
        stdout.writeln('SMOKE_THREAD_CLEANED=true');
      } catch (error) {
        stderr.writeln('SMOKE_THREAD_CLEANUP=FAIL');
        stderr.writeln(error);
        rethrow;
      }
    }
    conversation.dispose();
    diff.dispose();
    settings.dispose();
    await runtime.shutdown();
    runtime.dispose();
    await workspace.delete(recursive: true);
    stdout.writeln('TEMP_WORKSPACE_CLEANED=true');
  }
}
