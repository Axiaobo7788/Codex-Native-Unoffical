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
    stderr.writeln('REVIEW_SMOKE=CODEX_NOT_FOUND');
    exitCode = 2;
    return;
  }
  final host = await const HostExecutableLocator().locate();
  if (host == null) {
    stderr.writeln('REVIEW_SMOKE=HOST_NOT_FOUND');
    exitCode = 2;
    return;
  }

  ProcessTransport? transport;
  StreamSubscription<TurnEvent>? eventSubscription;
  StreamSubscription<CodexServerRequest>? requestSubscription;
  Directory? fixtureDirectory;
  String? smokeThreadId;
  String? activeTurnId;
  final completion = Completer<TurnCompletedEvent>();
  var enteredReviewMode = false;
  var exitedReviewMode = false;
  var assistantCharacters = 0;

  try {
    fixtureDirectory = await Directory.systemTemp.createTemp(
      'codex-native-review-smoke-',
    );
    await _runGit(fixtureDirectory.path, ['init', '--quiet']);
    await _runGit(fixtureDirectory.path, [
      'config',
      'user.email',
      'review-smoke@example.invalid',
    ]);
    await _runGit(fixtureDirectory.path, [
      'config',
      'user.name',
      'Codex Native Review Smoke',
    ]);
    final fixture = File('${fixtureDirectory.path}/calculator.dart');
    await fixture.writeAsString('int add(int a, int b) => a + b;\n');
    await _runGit(fixtureDirectory.path, ['add', 'calculator.dart']);
    await _runGit(fixtureDirectory.path, [
      'commit',
      '--quiet',
      '-m',
      'initial fixture',
    ]);
    await fixture.writeAsString('int divide(int a, int b) => a ~/ b;\n');

    transport = await ProcessTransport.startHost(
      hostExecutablePath: host,
      codexExecutablePath: executable,
    );
    await transport.initialize(const InitializeRequest());
    final thread = await transport.startThread(
      ThreadStartOptions(cwd: fixtureDirectory.path),
    );
    smokeThreadId = thread.id;

    eventSubscription = transport.turnEvents.listen(
      (event) {
        if (event.threadId != smokeThreadId) {
          return;
        }
        activeTurnId ??= event.turnId;
        switch (event) {
          case ReviewModeEvent():
            if (event.phase == ReviewModePhase.entered) {
              enteredReviewMode = true;
            } else {
              exitedReviewMode = true;
            }
          case AssistantTextDeltaEvent():
            assistantCharacters += event.delta.length;
          case AssistantMessageEvent():
            if (event.completed) {
              assistantCharacters = event.text.length;
            }
          case TurnCompletedEvent():
            if (!completion.isCompleted) {
              completion.complete(event);
            }
          case TurnErrorEvent():
            if (!event.willRetry && !completion.isCompleted) {
              completion.completeError(StateError(event.message));
            }
          case TurnStartedEvent() || ActivityEvent() || TurnDiffUpdatedEvent():
        }
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!completion.isCompleted) {
          completion.completeError(error, stackTrace);
        }
      },
    );

    requestSubscription = transport.serverRequests.listen((request) {
      if (!completion.isCompleted) {
        completion.completeError(
          StateError('Unexpected server request: ${request.method}'),
        );
      }
    });

    final review = await transport.startReview(
      ReviewStartOptions(
        threadId: smokeThreadId,
        target: const UncommittedChangesReviewTarget(),
      ),
    );
    if (review.reviewThreadId != smokeThreadId) {
      throw StateError('review/start returned a different thread identity.');
    }
    activeTurnId ??= review.turn.id;

    final completed = await completion.future.timeout(
      const Duration(minutes: 4),
    );
    if (completed.turnId != review.turn.id) {
      throw StateError(
        'Review completion identity did not match review/start.',
      );
    }
    if (completed.status != TurnRuntimeStatus.completed) {
      throw StateError('Review ended with status ${completed.status.name}.');
    }
    if (!enteredReviewMode || !exitedReviewMode) {
      throw StateError(
        'Review lifecycle markers were incomplete: '
        'entered=$enteredReviewMode exited=$exitedReviewMode.',
      );
    }

    stdout.writeln('REVIEW_SMOKE=PASS');
    stdout.writeln('REVIEW_STATUS=${completed.status.name}');
    stdout.writeln('REVIEW_ENTERED=$enteredReviewMode');
    stdout.writeln('REVIEW_EXITED=$exitedReviewMode');
    stdout.writeln('ASSISTANT_CHARACTERS=$assistantCharacters');
  } catch (error) {
    stderr.writeln('REVIEW_SMOKE=FAIL');
    stderr.writeln(error);
    final turnId = activeTurnId;
    if (transport != null && smokeThreadId != null && turnId != null) {
      try {
        await transport.interruptTurn(threadId: smokeThreadId, turnId: turnId);
      } catch (_) {
        // The review may already be terminal.
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
    if (fixtureDirectory != null && await fixtureDirectory.exists()) {
      await fixtureDirectory.delete(recursive: true);
    }
  }
}

Future<void> _runGit(String workingDirectory, List<String> arguments) async {
  final result = await Process.run(
    'git',
    arguments,
    workingDirectory: workingDirectory,
  );
  if (result.exitCode != 0) {
    throw StateError(
      'git ${arguments.first} failed with exit ${result.exitCode}: '
      '${result.stderr.toString().trim()}',
    );
  }
}
