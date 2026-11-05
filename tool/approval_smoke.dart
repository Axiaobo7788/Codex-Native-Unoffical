import 'dart:async';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/approval_models.dart';
import 'package:codex_native_unofficial/src/domain/execution_settings.dart';
import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

Future<void> main() async {
  final executable = await const CodexExecutableLocator().locate();
  if (executable == null) {
    stderr.writeln('APPROVAL_SMOKE=CODEX_NOT_FOUND');
    exitCode = 2;
    return;
  }
  final host = await const HostExecutableLocator().locate();
  if (host == null) {
    stderr.writeln('APPROVAL_SMOKE=HOST_NOT_FOUND');
    exitCode = 2;
    return;
  }

  ProcessTransport? transport;
  StreamSubscription<ApprovalEvent>? approvalSubscription;
  StreamSubscription<TurnEvent>? turnSubscription;
  String? smokeThreadId;
  String? activeTurnId;
  final approvalRequested = Completer<ApprovalRequest>();
  final approvalResolved = Completer<void>();
  final turnCompleted = Completer<TurnCompletedEvent>();

  try {
    transport = await ProcessTransport.startHost(
      hostExecutablePath: host,
      codexExecutablePath: executable,
    );
    await transport.initialize(const InitializeRequest());
    final thread = await transport.startThread(
      ThreadStartOptions(
        cwd: Directory.current.path,
        approvalPolicy: ApprovalPolicyOverride.untrusted,
        sandbox: SandboxModeOverride.readOnly,
      ),
    );
    smokeThreadId = thread.id;

    approvalSubscription = transport.approvalEvents.listen((event) {
      switch (event) {
        case ApprovalRequestedEvent():
          if (event.request.threadId == smokeThreadId &&
              !approvalRequested.isCompleted) {
            approvalRequested.complete(event.request);
          }
        case ApprovalResolvedEvent():
          if (!approvalResolved.isCompleted) {
            approvalResolved.complete();
          }
      }
    }, onError: approvalRequested.completeError);
    turnSubscription = transport.turnEvents.listen((event) {
      if (event.threadId != smokeThreadId) {
        return;
      }
      switch (event) {
        case TurnStartedEvent():
          activeTurnId = event.turnId;
        case TurnCompletedEvent():
          if (!turnCompleted.isCompleted) {
            turnCompleted.complete(event);
          }
        case TurnErrorEvent():
          if (!event.willRetry && !turnCompleted.isCompleted) {
            turnCompleted.completeError(StateError(event.message));
          }
        case AssistantTextDeltaEvent():
        case AssistantMessageEvent():
        case ActivityEvent():
        case TurnDiffUpdatedEvent():
      }
    }, onError: turnCompleted.completeError);

    final turn = await transport.startTurn(
      TurnStartOptions(
        threadId: smokeThreadId,
        text:
            'Run exactly this shell command once: '
            'python -c "print(\'APPROVAL_SMOKE_OK\')". '
            'Do not use any other tool.',
      ),
    );
    activeTurnId = turn.id;

    final request = await approvalRequested.future.timeout(
      const Duration(minutes: 3),
    );
    if (request.kind != ApprovalKind.command) {
      throw StateError(
        'Expected a command approval, received ${request.kind.name}.',
      );
    }
    await transport.decideApproval(
      requestId: request.requestId,
      decision: ApprovalDecision.reject,
    );
    await approvalResolved.future.timeout(const Duration(seconds: 10));

    final completed = await turnCompleted.future.timeout(
      const Duration(minutes: 1),
    );
    if (completed.status == TurnRuntimeStatus.inProgress) {
      throw StateError('Turn remained in progress after approval rejection.');
    }

    stdout.writeln('APPROVAL_SMOKE=PASS');
    stdout.writeln('APPROVAL_KIND=${request.kind.name}');
    stdout.writeln('APPROVAL_DECISION=reject');
    stdout.writeln('TURN_STATUS=${completed.status.name}');
  } catch (error, stackTrace) {
    stderr.writeln('APPROVAL_SMOKE=FAIL');
    stderr.writeln(error);
    stderr.writeln(stackTrace);
    final turnId = activeTurnId;
    if (transport != null && smokeThreadId != null && turnId != null) {
      try {
        await transport.interruptTurn(threadId: smokeThreadId, turnId: turnId);
      } catch (_) {
        // The turn may already be terminal.
      }
    }
    final stderrTail = transport?.stderrTail.trim();
    if (stderrTail != null && stderrTail.isNotEmpty) {
      stderr.writeln(stderrTail);
    }
    exitCode = 1;
  } finally {
    await approvalSubscription?.cancel();
    await turnSubscription?.cancel();
    if (transport != null && smokeThreadId != null) {
      try {
        await transport.deleteThread(smokeThreadId);
        stdout.writeln('SMOKE_THREAD_CLEANED=true');
      } catch (error) {
        stderr.writeln('SMOKE_THREAD_CLEANUP=FAIL');
        stderr.writeln(error);
        exitCode = 1;
      }
    }
    await transport?.close();
  }
}
