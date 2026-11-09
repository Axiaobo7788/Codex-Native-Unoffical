import 'dart:async';
import 'dart:io';

import 'package:codex_native_unofficial/src/domain/thread_models.dart';
import 'package:codex_native_unofficial/src/domain/turn_models.dart';
import 'package:codex_native_unofficial/src/protocol/protocol_models.dart';
import 'package:codex_native_unofficial/src/transport/process/codex_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/host_executable_locator.dart';
import 'package:codex_native_unofficial/src/transport/process/process_transport.dart';

Future<void> main(List<String> args) async {
  final targetKind = _parseTargetArg(args);
  if (targetKind == null) {
    stderr.writeln(
      'Usage: dart run tool/review_smoke.dart '
      '[--target=uncommitted|base-branch|commit|custom]',
    );
    exitCode = 64;
    return;
  }
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
    await _runGit(fixtureDirectory.path, [
      'init',
      '--quiet',
      '--initial-branch=main',
    ]);
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
    await _runGit(fixtureDirectory.path, ['config', 'commit.gpgsign', 'false']);
    await _runGit(fixtureDirectory.path, ['config', 'tag.gpgsign', 'false']);
    await _runGit(fixtureDirectory.path, [
      'config',
      'core.hooksPath',
      '/dev/null',
    ]);
    final fixture = File('${fixtureDirectory.path}/calculator.dart');
    await fixture.writeAsString('int add(int a, int b) => a + b;\n');
    await _runGit(fixtureDirectory.path, ['add', 'calculator.dart']);
    await _runGit(fixtureDirectory.path, [
      'commit',
      '--quiet',
      '--no-gpg-sign',
      '--no-verify',
      '-m',
      'initial fixture',
    ]);
    await _runGit(fixtureDirectory.path, [
      'checkout',
      '--quiet',
      '-b',
      'feature/review-smoke',
    ]);
    await fixture.writeAsString(
      'int add(int a, int b) => a + b;\n'
      'int subtract(int a, int b) => a - b;\n',
    );
    await _runGit(fixtureDirectory.path, ['add', 'calculator.dart']);
    await _runGit(fixtureDirectory.path, [
      'commit',
      '--quiet',
      '--no-gpg-sign',
      '--no-verify',
      '-m',
      'add subtract helper',
    ]);
    final featureCommitSha = (await _runGit(fixtureDirectory.path, [
      'rev-parse',
      '--short',
      'HEAD',
    ])).trim();
    await fixture.writeAsString('int divide(int a, int b) => a ~/ b;\n');

    final target = switch (targetKind) {
      'uncommitted' => const UncommittedChangesReviewTarget(),
      'base-branch' => const BaseBranchReviewTarget('main'),
      'commit' => CommitReviewTarget(
        sha: featureCommitSha,
        title: 'add subtract helper',
      ),
      'custom' => const CustomReviewTarget(
        'Check calculator.dart for division by zero edge cases in 1 sentence.',
      ),
      _ => const UncommittedChangesReviewTarget(),
    };

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
          case UserMessageEvent() ||
              TurnStartedEvent() ||
              ActivityEvent() ||
              TurnDiffUpdatedEvent():
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
      ReviewStartOptions(threadId: smokeThreadId, target: target),
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
    stdout.writeln('REVIEW_TARGET=$targetKind');
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

String? _parseTargetArg(List<String> args) {
  var target = 'uncommitted';
  for (final arg in args) {
    if (arg.startsWith('--target=')) {
      target = arg.substring('--target='.length).trim();
    } else {
      return null;
    }
  }
  return switch (target) {
    'uncommitted' || 'base-branch' || 'commit' || 'custom' => target,
    _ => null,
  };
}

Future<String> _runGit(String workingDirectory, List<String> arguments) async {
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
  return result.stdout.toString();
}
