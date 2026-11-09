import 'dart:async';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

Future<void> main() async {
  final executable = await const CodexExecutableLocator().locate();
  if (executable == null) {
    stderr.writeln('TURN_SMOKE=CODEX_NOT_FOUND');
    exitCode = 2;
    return;
  }
  final host = await const HostExecutableLocator().locate();
  if (host == null) {
    stderr.writeln('TURN_SMOKE=HOST_NOT_FOUND');
    exitCode = 2;
    return;
  }

  ProcessTransport? transport;
  StreamSubscription<TurnEvent>? eventSubscription;
  StreamSubscription<CodexServerRequest>? requestSubscription;
  String? smokeThreadId;
  String? activeTurnId;
  Completer<TurnCompletedEvent>? pendingCompletion;
  Completer<String>? pendingStarted;
  var assistantText = '';

  try {
    transport = await ProcessTransport.startHost(
      hostExecutablePath: host,
      codexExecutablePath: executable,
    );
    await transport.initialize(const InitializeRequest());
    final startedThread = await transport.startThread(
      ThreadStartOptions(cwd: Directory.current.path),
    );
    smokeThreadId = startedThread.id;

    eventSubscription = transport.turnEvents.listen(
      (event) {
        if (event.threadId != smokeThreadId) {
          return;
        }
        switch (event) {
          case TurnStartedEvent():
            activeTurnId = event.turnId;
            final started = pendingStarted;
            if (started != null && !started.isCompleted) {
              started.complete(event.turnId);
            }
          case AssistantTextDeltaEvent():
            assistantText += event.delta;
          case AssistantMessageEvent():
            if (event.completed && event.text.isNotEmpty) {
              assistantText = event.text;
            }
          case TurnCompletedEvent():
            final completion = pendingCompletion;
            if (completion != null && !completion.isCompleted) {
              completion.complete(event);
            }
          case TurnErrorEvent():
            final completion = pendingCompletion;
            if (!event.willRetry &&
                completion != null &&
                !completion.isCompleted) {
              completion.completeError(StateError(event.message));
            }
          case ActivityEvent():
          // The smoke prompt forbids tools; any approval request is handled below.
          case TurnDiffUpdatedEvent():
          // The smoke prompt forbids file changes.
          case UserMessageEvent():
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        final completion = pendingCompletion;
        if (completion != null && !completion.isCompleted) {
          completion.completeError(error, stackTrace);
        }
      },
    );

    requestSubscription = transport.serverRequests.listen((request) {
      final completion = pendingCompletion;
      if (completion != null && !completion.isCompleted) {
        completion.completeError(
          StateError('Unexpected server request: ${request.method}'),
        );
      }
    });

    pendingCompletion = Completer<TurnCompletedEvent>();
    final turn = await transport.startTurn(
      TurnStartOptions(
        threadId: smokeThreadId,
        text: 'Reply with exactly TURN_SMOKE_OK and do not call any tools.',
      ),
    );
    activeTurnId ??= turn.id;

    final completed = await pendingCompletion.future.timeout(
      const Duration(minutes: 3),
    );
    if (completed.status != TurnRuntimeStatus.completed) {
      throw StateError('Turn ended with status ${completed.status.name}.');
    }
    if (!assistantText.contains('TURN_SMOKE_OK')) {
      throw StateError('Assistant response did not contain the smoke marker.');
    }

    pendingCompletion = Completer<TurnCompletedEvent>();
    pendingStarted = Completer<String>();
    final interruptTarget = await transport.startTurn(
      TurnStartOptions(
        threadId: smokeThreadId,
        text: 'Begin writing a very long plain-text essay. Do not call tools.',
      ),
    );
    activeTurnId = interruptTarget.id;
    final startedTurnId = await pendingStarted.future.timeout(
      const Duration(seconds: 10),
    );
    if (startedTurnId != interruptTarget.id) {
      throw StateError('turn/started identity did not match turn/start.');
    }
    await transport.interruptTurn(
      threadId: smokeThreadId,
      turnId: interruptTarget.id,
    );
    final interrupted = await pendingCompletion.future.timeout(
      const Duration(seconds: 30),
    );
    if (interrupted.status != TurnRuntimeStatus.interrupted) {
      throw StateError(
        'Interrupted turn ended with status ${interrupted.status.name}.',
      );
    }

    stdout.writeln('TURN_SMOKE=PASS');
    stdout.writeln('TURN_STATUS=${completed.status.name}');
    stdout.writeln('INTERRUPT_STATUS=${interrupted.status.name}');
    stdout.writeln('ASSISTANT_CHARACTERS=${assistantText.length}');
  } catch (error) {
    stderr.writeln('TURN_SMOKE=FAIL');
    stderr.writeln(error);
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
    await eventSubscription?.cancel();
    await requestSubscription?.cancel();
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
