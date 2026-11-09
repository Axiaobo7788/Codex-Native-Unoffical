# Stock thread subscription and idle unload

- Date 2026-11-10
- Native baseline `075bdf2eafbdd60fb71a0ebd8dbcede30399a678`
- Stock CLI `0.167.0-alpha.3.2`, SHA-256 `c8242fc9e1bac7c6d661a228cecfaf50e6db74da219e4a9ca8912827e11607f0`
- Evidence `LOCAL_SCHEMA`, `PUBLIC_SOURCE`, `LIVE_CALLED`

## Public contract

The installed stable schema includes `thread/unsubscribe`,
`thread/loaded/list`, and `thread/closed`. Unsubscribe returns
`unsubscribed`, `notSubscribed`, or `notLoaded`. The upstream handler
removes a subscription for the calling connection. The upstream tests
cover idle delay, active-turn continuation, retained status, and cold
resume. The Git source is supporting evidence for the public contract.
The observations below come from the installed binary.
[Unsubscribe handler](https://github.com/openai/codex/blob/4f9e7171a1f3334ab22123aba61daa5af37f289e/codex-rs/app-server/src/request_processors/thread_processor.rs#L1160-L1190)
[Upstream runtime tests](https://github.com/openai/codex/blob/4f9e7171a1f3334ab22123aba61daa5af37f289e/codex-rs/app-server/tests/suite/v2/thread_unsubscribe.rs)

## Disposable probes

Each probe used a new `CODEX_HOME`, a new working directory, and an
environment without the user's Codex credentials. Idle fixtures were
materialized with `thread/name/set`. Turn fixtures used an offline
Responses API SSE endpoint bound to loopback. The endpoint controlled
when the model result and synthetic approval-producing tool call were
released. The approval reply always declined the command.

| Fixture | Observed result |
|---|---|
| Stdio, default idle settings | First unsubscribe returned `unsubscribed`. The same call returned `notSubscribed` on repetition. The thread remained in `thread/loaded/list` throughout the 1.9 s sample. Metadata read succeeded and resume restored the subscription. |
| Stdio, idle delay set to 2 s | The thread remained loaded immediately after unsubscribe. At 2.6 s the loaded list omitted it and `thread/closed` had arrived. A cold metadata read succeeded without loading the thread. Unsubscribe then returned `notLoaded`. Resume with `excludeTurns: true` loaded it again. |
| Two authenticated stock WebSocket connections, idle delay set to 1 s | B could read metadata but its unsubscribe returned `notSubscribed`. B resumed, A unsubscribed, and the thread remained loaded after 1.45 s. B then unsubscribed. After another 1.45 s the thread was absent from the loaded list and both A and B had received `thread/closed`. |
| Active model stream, unsubscribe during the turn | With a 1 s idle delay, the thread remained loaded and active after 1.3 s with the model response still held. After release, persisted turn history reported `completed` and the thread unloaded. The detached connection observed status and close events. Its `turn/completed` notice was absent. |
| Warm thread, unsubscribe immediately before starting a turn | The new `turn/start` request was accepted and persisted history later reported `completed`. The connection still received no `turn/started` or `turn/completed` notice for that turn. |
| Command approval routed before unsubscribe | The connection could decline the already-delivered request after detaching. The fixture issued its follow-up model request and the turn completed. |
| Unsubscribe before a new command approval | No request reached the detached connection in the approximately 5 s sample. Persisted turn history still showed `inProgress`. In a separate run, `thread/resume` on the same connection replayed the pending approval. Declining it completed the turn. The bundled Native Host reproduced the missing initial request, replay on resume, and terminal completion. |

The test-specific idle delay was written as
`thread_unload_delay_secs = 1` or `2` in the disposable
`config.toml`. The two-client test used the official app-server
`ws://127.0.0.1:0` listener with a newly generated capability token
stored in the fixture. This exercised the stock protocol on a single
server. Native Direct Host Remote uses a separate contract.

For the approval reproduction, start the fixture with the read-only
sandbox and on-request approval. Hold the first loopback SSE
response after `response.created`. To exercise the failure path,
call `thread/unsubscribe` before releasing the
`response.output_item.done` event for `exec_command` with
`sandbox_permissions: require_escalated`. Complete the SSE response,
check for `item/commandExecution/requestApproval`, and read the
turn status via `thread/turns/list`. Resume on the same connection
with `excludeTurns: true`, decline the replayed approval, and check
for the matching completed turn. The successful recovery and the
earlier window without a delivered request are separate observations.
[OpenAI fixture event builders](https://github.com/openai/codex/blob/4f9e7171a1f3334ab22123aba61daa5af37f289e/codex-rs/core/tests/common/responses.rs)

## Implications for Native

The client has two separate lifetimes. Flutter evicts inactive history
and live entries from its projection. Stock controls connection
subscription, in-flight work and unloading. Selecting a row uses
metadata-only `thread/read`. Existing execution preparation checks
the thread's loaded status. A loaded thread can be detached from the
current connection, so that status alone cannot establish delivery of
turn events or approvals. The global approval controller can display
requests from other threads only after the upstream connection receives
them.
[Selection and execution preparation](../../lib/src/features/threads/thread_list_controller.dart)
[Approval projection](../../lib/src/features/approvals/approval_controller.dart)

Automatic detach on deselection is blocked on an explicit subscription
policy. A future implementation would need:

- Connection-scoped state that resets on reconnect, with a bounded
  representation of pending work and approvals.
- A way to preserve active turns, reviews, Goals that can start work,
  and future approvals during detach admission. A client-side idle
  snapshot can go stale between read and unsubscribe.
- Subscription recovery before relying on turn or approval events.
  Cold reads, warm detached threads and recovered requests have
  distinct behavior. A status or `thread/closed` event alone cannot
  reconstruct an omitted terminal turn event.
- Direct stock and bundled Host checks for a concurrent turn,
  approval arriving during detach, reconnect, and recovery without
  duplicate or stale approval decisions.

These probes establish delayed stock unload under explicit fixture
settings. Stock process memory savings, default idle duration,
multi-client approval ownership, and reconnect recovery were outside
the measurements.
