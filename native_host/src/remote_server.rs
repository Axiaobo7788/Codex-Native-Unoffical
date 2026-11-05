use crate::events::{AppServerRemoteNotification, HostEvent, RemoteRpcCall};
use crate::remote_bridge::{remote_error, validate_read_only_request};
use crate::rpc::RemoteAdmin;
use axum::extract::ws::{CloseFrame, Message, WebSocket, WebSocketUpgrade, close_code};
use axum::extract::{DefaultBodyLimit, State};
use axum::http::{HeaderMap, HeaderValue, StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{any, get, post};
use axum::{Json, Router, middleware};
use codex_native_host::remote::{
    AuthError, ClientMessage, ConnectionAction, DEFAULT_MAX_JOURNAL_BYTES,
    DEFAULT_MAX_JOURNAL_EVENTS, Device, DeviceScope, EventJournal, HOST_ID_PREFIX, JournalEvent,
    ProtocolConnection, ReplayDisposition, ServerMessage,
};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::io;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex, mpsc::SyncSender};
use std::thread;
use std::time::{Duration, Instant};
use tokio::sync::{OwnedSemaphorePermit, Semaphore, broadcast, mpsc, watch};
use uuid::Uuid;

const WS_PROTOCOL: &str = "codex-native-v1";
const HTTP_BODY_BYTES: usize = 8 * 1024;
const WS_READ_BUFFER_BYTES: usize = 16 * 1024;
const WS_WRITE_BUFFER_BYTES: usize = 0;
const WS_MAX_WRITE_BUFFER_BYTES: usize = 2 * 1024 * 1024;
const WS_MAX_FRAME_BYTES: usize = 256 * 1024;
const WS_MAX_MESSAGE_BYTES: usize = 1024 * 1024;
const MAX_CONNECTIONS: usize = 8;
const OUTBOUND_QUEUE_MESSAGES: usize = 16;
const OUTBOUND_QUEUE_BYTES: usize = 2 * 1024 * 1024;
const EVENT_BROADCAST_MESSAGES: usize = 64;
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(5);
#[cfg(not(test))]
const REMOTE_RPC_TIMEOUT: Duration = Duration::from_secs(30);
#[cfg(test)]
const REMOTE_RPC_TIMEOUT: Duration = Duration::from_millis(100);
const SOCKET_WRITE_TIMEOUT: Duration = Duration::from_secs(5);
const HEARTBEAT_INTERVAL: Duration = Duration::from_secs(20);
const HEARTBEAT_TIMEOUT: Duration = Duration::from_secs(45);
const SHUTDOWN_DRAIN_TIMEOUT: Duration = Duration::from_secs(1);
#[cfg(not(test))]
const REVOCATION_INTERVAL: Duration = Duration::from_secs(5);
#[cfg(test)]
const REVOCATION_INTERVAL: Duration = Duration::from_millis(50);
const PAIR_ATTEMPTS_PER_MINUTE: usize = 10;

pub(crate) struct RemoteServer {
    address: SocketAddr,
    session_id: Arc<str>,
    publisher: RemoteEventPublisher,
    shutdown: Option<watch::Sender<bool>>,
    thread: Option<thread::JoinHandle<io::Result<()>>>,
}

impl RemoteServer {
    pub(crate) fn start(
        address: SocketAddr,
        admin: Arc<Mutex<RemoteAdmin>>,
        events: SyncSender<HostEvent>,
    ) -> io::Result<Self> {
        if !address.ip().is_loopback() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "plaintext Remote listener is restricted to loopback",
            ));
        }
        let listener = std::net::TcpListener::bind(address)?;
        listener.set_nonblocking(true)?;
        let address = listener.local_addr()?;
        let (shutdown_tx, shutdown_rx) = watch::channel(false);
        let session_id: Arc<str> = Arc::from(Uuid::new_v4().to_string());
        let journal = Arc::new(Mutex::new(
            EventJournal::new(DEFAULT_MAX_JOURNAL_EVENTS, DEFAULT_MAX_JOURNAL_BYTES).map_err(
                |error| io::Error::other(format!("failed to create Remote journal: {error}")),
            )?,
        ));
        let (event_sender, _) = broadcast::channel(EVENT_BROADCAST_MESSAGES);
        let publisher = RemoteEventPublisher {
            journal: Arc::clone(&journal),
            event_sender: event_sender.clone(),
        };
        let state = ServerState {
            admin,
            events,
            session_id: Arc::clone(&session_id),
            journal,
            event_sender,
            connections: Arc::new(Semaphore::new(MAX_CONNECTIONS)),
            pair_budget: Arc::new(Mutex::new(AttemptBudget::new(
                PAIR_ATTEMPTS_PER_MINUTE,
                Duration::from_secs(60),
            ))),
            shutdown: shutdown_rx.clone(),
        };
        let thread = thread::Builder::new()
            .name("host-remote-loopback".into())
            .spawn(move || run_server(listener, state, shutdown_rx))?;
        Ok(Self {
            address,
            session_id,
            publisher,
            shutdown: Some(shutdown_tx),
            thread: Some(thread),
        })
    }

    pub(crate) fn address(&self) -> SocketAddr {
        self.address
    }

    pub(crate) fn session_id(&self) -> &str {
        &self.session_id
    }

    pub(crate) fn correlation_prefix(&self) -> String {
        format!("{HOST_ID_PREFIX}{}:", self.session_id)
    }

    pub(crate) fn publisher(&self) -> RemoteEventPublisher {
        self.publisher.clone()
    }

    pub(crate) fn stop(mut self) -> io::Result<()> {
        self.stop_inner()
    }

    fn stop_inner(&mut self) -> io::Result<()> {
        if let Some(shutdown) = self.shutdown.take() {
            let _ = shutdown.send(true);
        }
        let Some(thread) = self.thread.take() else {
            return Ok(());
        };
        thread
            .join()
            .map_err(|_| io::Error::other("Remote listener thread panicked"))?
    }
}

impl Drop for RemoteServer {
    fn drop(&mut self) {
        let _ = self.stop_inner();
    }
}

#[derive(Clone)]
pub(crate) struct RemoteEventPublisher {
    journal: Arc<Mutex<EventJournal>>,
    event_sender: broadcast::Sender<JournalEvent>,
}

impl RemoteEventPublisher {
    pub(crate) fn publish(&self, notification: AppServerRemoteNotification) -> io::Result<()> {
        let (method, params) = match notification.payload {
            Some(payload) => {
                let message: serde_json::Value =
                    serde_json::from_slice(&payload).map_err(|error| {
                        io::Error::new(
                            io::ErrorKind::InvalidData,
                            format!("captured app-server notification is invalid JSON: {error}"),
                        )
                    })?;
                let object = message.as_object().ok_or_else(|| {
                    io::Error::new(
                        io::ErrorKind::InvalidData,
                        "captured app-server notification is not an object",
                    )
                })?;
                if object.contains_key("id")
                    || object.get("method").and_then(serde_json::Value::as_str)
                        != Some(notification.method.as_str())
                {
                    return Err(io::Error::new(
                        io::ErrorKind::InvalidData,
                        "captured app-server notification identity changed after sanitization",
                    ));
                }
                (
                    notification.method,
                    object
                        .get("params")
                        .cloned()
                        .unwrap_or(serde_json::Value::Null),
                )
            }
            None => (
                "host/resyncRequired".to_owned(),
                serde_json::json!({
                    "reason": "eventTooLarge",
                    "sourceMethod": notification.method,
                    "bytes": notification.total_bytes,
                }),
            ),
        };
        let mut journal = self
            .journal
            .lock()
            .map_err(|_| io::Error::other("Remote event journal lock poisoned"))?;
        let event = journal
            .publish(&method, params)
            .map_err(|error| io::Error::other(format!("failed to publish Remote event: {error}")))?
            .event;
        let _ = self.event_sender.send(event);
        Ok(())
    }
}

#[derive(Clone)]
struct ServerState {
    admin: Arc<Mutex<RemoteAdmin>>,
    events: SyncSender<HostEvent>,
    session_id: Arc<str>,
    journal: Arc<Mutex<EventJournal>>,
    event_sender: broadcast::Sender<JournalEvent>,
    connections: Arc<Semaphore>,
    pair_budget: Arc<Mutex<AttemptBudget>>,
    shutdown: watch::Receiver<bool>,
}

#[derive(Debug)]
struct AttemptBudget {
    max_attempts: usize,
    window: Duration,
    attempts: VecDeque<Instant>,
}

impl AttemptBudget {
    fn new(max_attempts: usize, window: Duration) -> Self {
        Self {
            max_attempts,
            window,
            attempts: VecDeque::new(),
        }
    }

    fn take(&mut self, now: Instant) -> bool {
        while self
            .attempts
            .front()
            .is_some_and(|attempt| now.duration_since(*attempt) >= self.window)
        {
            self.attempts.pop_front();
        }
        if self.attempts.len() >= self.max_attempts {
            return false;
        }
        self.attempts.push_back(now);
        true
    }
}

fn run_server(
    listener: std::net::TcpListener,
    state: ServerState,
    mut shutdown: watch::Receiver<bool>,
) -> io::Result<()> {
    let runtime = tokio::runtime::Builder::new_multi_thread()
        .worker_threads(2)
        .enable_all()
        .build()?;
    runtime.block_on(async move {
        let listener = tokio::net::TcpListener::from_std(listener)?;
        let connections = Arc::clone(&state.connections);
        let app = Router::new()
            .route("/healthz", get(health))
            .route("/v1/pair", post(pair))
            .route("/v1/ws", any(websocket))
            .layer(DefaultBodyLimit::max(HTTP_BODY_BYTES))
            .layer(middleware::map_response(security_headers))
            .with_state(state);
        let server_result = axum::serve(listener, app)
            .with_graceful_shutdown(async move {
                wait_for_shutdown(&mut shutdown).await;
            })
            .await;
        let all_connections_closed = tokio::time::timeout(
            SHUTDOWN_DRAIN_TIMEOUT,
            connections.acquire_many_owned(MAX_CONNECTIONS as u32),
        )
        .await;
        match (server_result, all_connections_closed) {
            (Err(error), _) => Err(io::Error::other(format!("Remote listener failed: {error}"))),
            (Ok(()), Ok(Ok(_all_connection_permits))) => Ok(()),
            (Ok(()), Ok(Err(_))) => Err(io::Error::other(
                "Remote connection limiter closed during shutdown",
            )),
            (Ok(()), Err(_)) => Err(io::Error::new(
                io::ErrorKind::TimedOut,
                "Remote connections did not close before the shutdown deadline",
            )),
        }
    })
}

async fn wait_for_shutdown(shutdown: &mut watch::Receiver<bool>) {
    loop {
        if *shutdown.borrow_and_update() {
            return;
        }
        if shutdown.changed().await.is_err() {
            return;
        }
    }
}

async fn security_headers(mut response: Response) -> Response {
    let headers = response.headers_mut();
    headers.insert(header::CACHE_CONTROL, HeaderValue::from_static("no-store"));
    headers.insert(
        header::X_CONTENT_TYPE_OPTIONS,
        HeaderValue::from_static("nosniff"),
    );
    headers.insert(
        header::CONTENT_SECURITY_POLICY,
        HeaderValue::from_static("default-src 'none'"),
    );
    response
}

async fn health() -> Response {
    (
        StatusCode::OK,
        Json(serde_json::json!({
            "ok": true,
            "protocolVersion": 1,
        })),
    )
        .into_response()
}

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase", deny_unknown_fields)]
struct PairRequest {
    code: String,
    device_name: String,
}

#[derive(Debug, Serialize)]
#[serde(rename_all = "camelCase")]
struct PairResponse {
    protocol_version: u32,
    device: Device,
    token: String,
}

async fn pair(State(state): State<ServerState>, Json(request): Json<PairRequest>) -> Response {
    let allowed = state
        .pair_budget
        .lock()
        .map(|mut budget| budget.take(Instant::now()))
        .unwrap_or(false);
    if !allowed {
        return json_error(StatusCode::TOO_MANY_REQUESTS, "Pairing rate exceeded");
    }
    let admin = Arc::clone(&state.admin);
    let result = tokio::task::spawn_blocking(move || {
        let mut admin = admin
            .lock()
            .map_err(|_| io::Error::other("Remote administration lock poisoned"))?;
        let now_ms = admin.now_ms()?;
        let registry = admin.registry()?;
        registry
            .pair(
                &request.code,
                &request.device_name,
                [DeviceScope::Read, DeviceScope::DeviceRotate]
                    .into_iter()
                    .collect(),
                now_ms,
            )
            .map_err(PairFailure::Auth)
    })
    .await;
    match result {
        Ok(Ok(issued)) => (
            StatusCode::OK,
            Json(PairResponse {
                protocol_version: 1,
                device: issued.device,
                token: issued.token,
            }),
        )
            .into_response(),
        Ok(Err(PairFailure::Auth(AuthError::PairingRejected | AuthError::PairingUnavailable))) => {
            json_error(
                StatusCode::UNAUTHORIZED,
                "Pairing ticket is invalid or expired",
            )
        }
        Ok(Err(PairFailure::Auth(AuthError::DeviceLimit))) => {
            json_error(StatusCode::CONFLICT, "Paired-device limit reached")
        }
        Ok(Err(PairFailure::Io)) => json_error(StatusCode::INTERNAL_SERVER_ERROR, "Pairing failed"),
        Ok(Err(PairFailure::Auth(_))) | Err(_) => {
            json_error(StatusCode::INTERNAL_SERVER_ERROR, "Pairing failed")
        }
    }
}

#[derive(Debug)]
enum PairFailure {
    Auth(AuthError),
    Io,
}

impl From<io::Error> for PairFailure {
    fn from(_error: io::Error) -> Self {
        Self::Io
    }
}

async fn websocket(
    State(state): State<ServerState>,
    headers: HeaderMap,
    websocket: WebSocketUpgrade,
) -> Response {
    let Some(token) = bearer_token(&headers) else {
        return json_error(StatusCode::UNAUTHORIZED, "Authentication required");
    };
    let admin = Arc::clone(&state.admin);
    let device = match tokio::task::spawn_blocking(move || {
        admin
            .lock()
            .map_err(|_| io::Error::other("Remote administration lock poisoned"))?
            .authenticate(&token)
    })
    .await
    {
        Ok(Ok(Some(device))) => device,
        Ok(Ok(None)) => return json_error(StatusCode::UNAUTHORIZED, "Authentication failed"),
        Ok(Err(_)) | Err(_) => {
            return json_error(StatusCode::INTERNAL_SERVER_ERROR, "Authentication failed");
        }
    };
    let permit = match Arc::clone(&state.connections).try_acquire_owned() {
        Ok(permit) => permit,
        Err(_) => return json_error(StatusCode::SERVICE_UNAVAILABLE, "Connection limit reached"),
    };
    let websocket = websocket.protocols([WS_PROTOCOL]);
    if websocket.selected_protocol().is_none() {
        return json_error(
            StatusCode::UPGRADE_REQUIRED,
            "codex-native-v1 subprotocol is required",
        );
    }
    websocket
        .read_buffer_size(WS_READ_BUFFER_BYTES)
        .write_buffer_size(WS_WRITE_BUFFER_BYTES)
        .max_write_buffer_size(WS_MAX_WRITE_BUFFER_BYTES)
        .max_frame_size(WS_MAX_FRAME_BYTES)
        .max_message_size(WS_MAX_MESSAGE_BYTES)
        .on_upgrade(move |socket| async move {
            let _permit = permit;
            socket_loop(socket, state, device).await;
        })
}

struct QueuedOutbound {
    text: String,
    _bytes: OwnedSemaphorePermit,
}

#[derive(Clone)]
struct OutboundQueue {
    sender: mpsc::Sender<QueuedOutbound>,
    bytes: Arc<Semaphore>,
    fatal: mpsc::Sender<()>,
}

impl OutboundQueue {
    fn try_send(&self, message: ServerMessage) -> bool {
        let text = serde_json::to_string(&message).expect("Remote server message is serializable");
        self.try_send_text(text)
    }

    fn try_send_text(&self, text: String) -> bool {
        if text.len() > WS_MAX_MESSAGE_BYTES || text.len() > u32::MAX as usize {
            self.signal_fatal();
            return false;
        }
        let permit = match Arc::clone(&self.bytes).try_acquire_many_owned(text.len() as u32) {
            Ok(permit) => permit,
            Err(_) => {
                self.signal_fatal();
                return false;
            }
        };
        if self
            .sender
            .try_send(QueuedOutbound {
                text,
                _bytes: permit,
            })
            .is_err()
        {
            self.signal_fatal();
            return false;
        }
        true
    }

    fn signal_fatal(&self) {
        let _ = self.fatal.try_send(());
    }
}

async fn socket_loop(socket: WebSocket, state: ServerState, device: Device) {
    let connection_id = Uuid::new_v4().simple().to_string();
    socket_loop_inner(socket, &state, device, &connection_id).await;
    if *state.shutdown.borrow() {
        return;
    }
    let events = state.events.clone();
    let _ = tokio::task::spawn_blocking(move || {
        events.send(HostEvent::RemoteDisconnected(connection_id))
    })
    .await;
}

async fn socket_loop_inner(
    mut socket: WebSocket,
    state: &ServerState,
    device: Device,
    connection_id: &str,
) {
    let mut shutdown = state.shutdown.clone();
    let mut live_events = state.event_sender.subscribe();
    let mut protocol = ProtocolConnection::current(
        state.session_id.to_string(),
        ["ack".into(), "eventReplay".into(), "readOnlyCodex".into()],
    );
    let hello = match state.journal.lock() {
        Ok(journal) => protocol.server_hello(&journal),
        Err(_) => return,
    };
    if !send_message(&mut socket, &hello).await {
        return;
    }
    let first_result = tokio::select! {
        _ = wait_for_shutdown(&mut shutdown) => {
            close_with(&mut socket, close_code::AWAY, "Host stopping").await;
            return;
        }
        result = tokio::time::timeout(HANDSHAKE_TIMEOUT, socket.recv()) => result,
    };
    let first = match first_result {
        Ok(Some(Ok(Message::Text(text)))) => text,
        _ => {
            close_protocol(&mut socket, "client_hello required").await;
            return;
        }
    };
    let client = match serde_json::from_str::<ClientMessage>(&first) {
        Ok(client) => client,
        Err(_) => {
            close_protocol(&mut socket, "invalid client message").await;
            return;
        }
    };
    let action = match state.journal.lock() {
        Ok(journal) => protocol.receive(client, &journal),
        Err(_) => return,
    };
    let (acknowledgement, replay) = match action {
        Ok(ConnectionAction::Negotiated {
            acknowledgement,
            replay,
        }) => (acknowledgement, replay),
        Ok(_) => unreachable!("first negotiated action must be a handshake"),
        Err(error) => {
            close_protocol(&mut socket, &error.to_string()).await;
            return;
        }
    };
    if !send_message(&mut socket, &acknowledgement).await {
        return;
    }
    if let ReplayDisposition::Replay(events) = replay {
        for event in events {
            let Ok(text) = String::from_utf8(event.encoded().to_vec()) else {
                return;
            };
            if !send_text(&mut socket, text).await {
                return;
            }
        }
    }
    let mut last_event_sequence = protocol
        .acknowledgements()
        .expect("negotiated Remote connection has an ACK tracker")
        .highest_sent();

    let (outbound_tx, mut outbound_rx) = mpsc::channel(OUTBOUND_QUEUE_MESSAGES);
    let (fatal_tx, mut fatal_rx) = mpsc::channel(1);
    let outbound = OutboundQueue {
        sender: outbound_tx,
        bytes: Arc::new(Semaphore::new(OUTBOUND_QUEUE_BYTES)),
        fatal: fatal_tx,
    };
    let mut heartbeat = tokio::time::interval(HEARTBEAT_INTERVAL);
    let mut revocation = tokio::time::interval(REVOCATION_INTERVAL);
    heartbeat.tick().await;
    revocation.tick().await;
    let mut last_pong = Instant::now();
    loop {
        tokio::select! {
            biased;
            _ = wait_for_shutdown(&mut shutdown) => {
                close_with(&mut socket, close_code::AWAY, "Host stopping").await;
                return;
            }
            _ = fatal_rx.recv() => {
                close_with(&mut socket, close_code::POLICY, "outbound queue limit exceeded").await;
                return;
            }
            _ = heartbeat.tick() => {
                if last_pong.elapsed() >= HEARTBEAT_TIMEOUT {
                    close_with(&mut socket, close_code::POLICY, "heartbeat timed out").await;
                    return;
                }
                if !send_socket(&mut socket, Message::Ping(b"codex-native".as_slice().into())).await {
                    return;
                }
            }
            _ = revocation.tick() => {
                let admin = Arc::clone(&state.admin);
                let device_id = device.id.clone();
                let active = tokio::task::spawn_blocking(move || {
                    admin.lock().ok().and_then(|mut admin| admin.is_active(&device_id).ok()).unwrap_or(false)
                }).await.unwrap_or(false);
                if !active {
                    close_with(&mut socket, close_code::POLICY, "device credential revoked").await;
                    return;
                }
            }
            Some(queued) = outbound_rx.recv() => {
                if !send_text(&mut socket, queued.text).await {
                    return;
                }
            }
            event = live_events.recv() => match event {
                Ok(event) if event.sequence() <= last_event_sequence => {}
                Ok(event) => {
                    let Some(expected) = last_event_sequence.checked_add(1) else {
                        send_resync_required(&mut socket, state, "event sequence exhausted").await;
                        return;
                    };
                    if event.sequence() != expected
                        || protocol.record_event_sent(event.sequence()).is_err()
                    {
                        send_resync_required(&mut socket, state, "live event sequence gap").await;
                        return;
                    }
                    let Ok(text) = String::from_utf8(event.encoded().to_vec()) else {
                        send_resync_required(&mut socket, state, "live event encoding failure").await;
                        return;
                    };
                    last_event_sequence = event.sequence();
                    if !outbound.try_send_text(text) {
                        close_with(
                            &mut socket,
                            close_code::POLICY,
                            "outbound queue limit exceeded",
                        )
                        .await;
                        return;
                    }
                }
                Err(broadcast::error::RecvError::Lagged(_)) => {
                    send_resync_required(&mut socket, state, "live event receiver lagged").await;
                    return;
                }
                Err(broadcast::error::RecvError::Closed) => return,
            },
            message = socket.recv() => match message {
                Some(Ok(Message::Text(text))) => {
                    if !handle_client_message(
                        &mut socket,
                        &mut protocol,
                        state,
                        &device,
                        connection_id,
                        &outbound,
                        &text,
                    ).await {
                        return;
                    }
                }
                Some(Ok(Message::Pong(_))) => last_pong = Instant::now(),
                Some(Ok(Message::Ping(_))) => {}
                Some(Ok(Message::Close(_))) | None | Some(Err(_)) => return,
                Some(Ok(Message::Binary(_))) => {
                    close_with(&mut socket, close_code::UNSUPPORTED, "text messages only").await;
                    return;
                }
            },
        }
    }
}

async fn handle_client_message(
    socket: &mut WebSocket,
    protocol: &mut ProtocolConnection,
    state: &ServerState,
    device: &Device,
    connection_id: &str,
    outbound: &OutboundQueue,
    text: &str,
) -> bool {
    let client = match serde_json::from_str::<ClientMessage>(text) {
        Ok(client) => client,
        Err(_) => {
            close_protocol(socket, "invalid client message").await;
            return false;
        }
    };
    let action = match state.journal.lock() {
        Ok(journal) => protocol.receive(client, &journal),
        Err(_) => return false,
    };
    match action {
        Ok(ConnectionAction::Acknowledged(_)) => true,
        Ok(ConnectionAction::Rpc {
            id,
            method,
            params,
            idempotency_key,
        }) => {
            if !device.scopes.contains(&DeviceScope::Read) {
                return outbound.try_send(remote_error(
                    id,
                    -32003,
                    "Device does not have the read scope",
                ));
            }
            if idempotency_key.is_some() {
                return outbound.try_send(remote_error(
                    id,
                    -32602,
                    "Read-only Remote RPC does not accept an idempotency key",
                ));
            }
            if method == "host/remote/status"
                && params.as_object().is_some_and(serde_json::Map::is_empty)
            {
                return outbound.try_send(ServerMessage::RpcResult {
                    id,
                    result: serde_json::json!({
                        "sessionId": state.session_id.as_ref(),
                        "device": device,
                        "mode": "loopbackReadOnlyCodex",
                    }),
                });
            }
            if let Err(message) = validate_read_only_request(&method, &params) {
                return outbound.try_send(remote_error(id, -32602, message));
            }

            let fallback_id = id.clone();
            let (reply, receiver) = tokio::sync::oneshot::channel();
            let call = RemoteRpcCall {
                connection_id: connection_id.to_owned(),
                client_id: id,
                method,
                params,
                reply,
            };
            if state.events.try_send(HostEvent::RemoteRpc(call)).is_err() {
                return outbound.try_send(remote_error(
                    fallback_id,
                    -32001,
                    "Host request queue is full or unavailable",
                ));
            }
            let outbound = outbound.clone();
            tokio::spawn(async move {
                match tokio::time::timeout(REMOTE_RPC_TIMEOUT, receiver).await {
                    Ok(Ok(message)) => {
                        let _ = outbound.try_send(message);
                    }
                    Ok(Err(_)) => {
                        let _ = outbound.try_send(remote_error(
                            fallback_id,
                            -32603,
                            "Host stopped before the Remote request completed",
                        ));
                    }
                    Err(_) => outbound.signal_fatal(),
                }
            });
            true
        }
        Ok(ConnectionAction::Negotiated { .. }) => {
            close_protocol(socket, "connection is already negotiated").await;
            false
        }
        Err(error) => {
            close_protocol(socket, &error.to_string()).await;
            false
        }
    }
}

async fn send_message(socket: &mut WebSocket, message: &ServerMessage) -> bool {
    let text = serde_json::to_string(message).expect("Remote server message is serializable");
    send_text(socket, text).await
}

async fn send_text(socket: &mut WebSocket, text: String) -> bool {
    send_socket(socket, Message::Text(text.into())).await
}

async fn send_socket(socket: &mut WebSocket, message: Message) -> bool {
    matches!(
        tokio::time::timeout(SOCKET_WRITE_TIMEOUT, socket.send(message)).await,
        Ok(Ok(()))
    )
}

async fn close_protocol(socket: &mut WebSocket, reason: &str) {
    let _ = send_message(
        socket,
        &ServerMessage::ProtocolError {
            error: reason.into(),
        },
    )
    .await;
    close_with(socket, close_code::PROTOCOL, "protocol error").await;
}

async fn send_resync_required(socket: &mut WebSocket, state: &ServerState, reason: &'static str) {
    let sequence = state
        .journal
        .lock()
        .map(|journal| journal.current_sequence())
        .unwrap_or_default();
    let _ = send_message(
        socket,
        &ServerMessage::ResyncRequired {
            session_id: state.session_id.to_string(),
            sequence,
            reason: reason.to_owned(),
        },
    )
    .await;
    close_with(socket, close_code::POLICY, "Remote resync required").await;
}

async fn close_with(socket: &mut WebSocket, code: u16, reason: &'static str) {
    let _ = send_socket(
        socket,
        Message::Close(Some(CloseFrame {
            code,
            reason: reason.into(),
        })),
    )
    .await;
}

fn bearer_token(headers: &HeaderMap) -> Option<String> {
    let value = headers.get(header::AUTHORIZATION)?.to_str().ok()?;
    let token = value.strip_prefix("Bearer ")?;
    (token.len() == 43
        && token
            .bytes()
            .all(|byte| byte.is_ascii_alphanumeric() || matches!(byte, b'-' | b'_')))
    .then(|| token.to_owned())
}

fn json_error(status: StatusCode, message: &'static str) -> Response {
    (status, Json(serde_json::json!({"error": message}))).into_response()
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::events::HOST_EVENT_CAPACITY;
    use serde_json::{Value, json};
    use std::fs;
    use std::io::{Read, Write};
    use std::net::TcpStream;
    use std::sync::mpsc as std_mpsc;
    use tempfile::TempDir;
    use tungstenite::client::IntoClientRequest;
    use tungstenite::{Message as ClientWsMessage, client};

    #[test]
    fn attempt_budget_is_bounded_and_recovers_after_the_window() {
        let start = Instant::now();
        let mut budget = AttemptBudget::new(2, Duration::from_secs(10));
        assert!(budget.take(start));
        assert!(budget.take(start + Duration::from_secs(1)));
        assert!(!budget.take(start + Duration::from_secs(9)));
        assert!(budget.take(start + Duration::from_secs(10)));
    }

    #[test]
    fn rejects_non_loopback_plaintext_listener_before_binding() {
        let admin = Arc::new(Mutex::new(RemoteAdmin::new(None)));
        let (events, _receiver) = std_mpsc::sync_channel(HOST_EVENT_CAPACITY);
        let error = RemoteServer::start("0.0.0.0:0".parse().unwrap(), admin, events)
            .err()
            .unwrap();
        assert_eq!(error.kind(), io::ErrorKind::InvalidInput);
    }

    #[test]
    fn bearer_parser_is_exact() {
        let mut headers = HeaderMap::new();
        headers.insert(
            header::AUTHORIZATION,
            HeaderValue::from_str(&format!("Bearer {}", "a".repeat(43))).unwrap(),
        );
        assert_eq!(bearer_token(&headers), Some("a".repeat(43)));
        headers.insert(
            header::AUTHORIZATION,
            HeaderValue::from_static("Bearer too-short"),
        );
        assert!(bearer_token(&headers).is_none());
    }

    #[test]
    fn application_outbound_queue_is_bounded_by_count_bytes_and_message_size() {
        let (fatal_tx, mut fatal_rx) = mpsc::channel(1);
        let (count_tx, _count_rx) = mpsc::channel(1);
        let by_count = OutboundQueue {
            sender: count_tx,
            bytes: Arc::new(Semaphore::new(4096)),
            fatal: fatal_tx.clone(),
        };
        assert!(by_count.try_send(ServerMessage::RpcResult {
            id: json!(1),
            result: json!({"ok": true}),
        }));
        assert!(!by_count.try_send(ServerMessage::RpcResult {
            id: json!(2),
            result: json!({"ok": true}),
        }));
        assert!(fatal_rx.try_recv().is_ok());

        let sample = ServerMessage::RpcResult {
            id: json!(3),
            result: json!({"value": "x".repeat(128)}),
        };
        let sample_bytes = serde_json::to_string(&sample).unwrap().len();
        let (byte_tx, _byte_rx) = mpsc::channel(4);
        let by_bytes = OutboundQueue {
            sender: byte_tx,
            bytes: Arc::new(Semaphore::new(sample_bytes)),
            fatal: fatal_tx.clone(),
        };
        assert!(by_bytes.try_send(sample.clone()));
        assert!(!by_bytes.try_send(sample));
        assert!(fatal_rx.try_recv().is_ok());

        let (large_tx, _large_rx) = mpsc::channel(1);
        let by_message_size = OutboundQueue {
            sender: large_tx,
            bytes: Arc::new(Semaphore::new(OUTBOUND_QUEUE_BYTES)),
            fatal: fatal_tx,
        };
        assert!(!by_message_size.try_send(ServerMessage::RpcResult {
            id: json!(4),
            result: json!({"value": "x".repeat(WS_MAX_MESSAGE_BYTES)}),
        }));
        assert!(fatal_rx.try_recv().is_ok());
    }

    #[test]
    fn notifications_replay_once_and_an_evicted_cursor_requires_resync() {
        let temp = TempDir::new().unwrap();
        let admin = Arc::new(Mutex::new(RemoteAdmin::new(Some(
            temp.path().join("devices.json"),
        ))));
        let ticket = admin.lock().unwrap().create_pairing_ticket().unwrap();
        let issued = {
            let mut admin = admin.lock().unwrap();
            let now_ms = admin.now_ms().unwrap();
            admin
                .registry()
                .unwrap()
                .pair(
                    &ticket.code,
                    "Replay phone",
                    [DeviceScope::Read].into_iter().collect(),
                    now_ms,
                )
                .unwrap()
        };
        let (events, _receiver) = std_mpsc::sync_channel(HOST_EVENT_CAPACITY);
        let server = RemoteServer::start("127.0.0.1:0".parse().unwrap(), admin, events).unwrap();
        let publisher = server.publisher();

        let mut first = connect_and_negotiate(server.address(), &issued.token, None);
        let session_id = first.1["sessionId"].as_str().unwrap().to_owned();
        publisher
            .publish(test_notification(
                "thread/status/changed",
                json!({"threadId": "thread-1", "status": "active"}),
            ))
            .unwrap();
        let event = read_json(&mut first.0);
        assert_eq!(event["type"], "codex_event");
        assert_eq!(event["sequence"], 1);
        assert_eq!(event["method"], "thread/status/changed");
        first
            .0
            .send(ClientWsMessage::Text(
                json!({"type": "ack", "sequence": 1}).to_string().into(),
            ))
            .unwrap();
        drop(first);

        let mut replayed =
            connect_and_negotiate(server.address(), &issued.token, Some((&session_id, 0)));
        assert_eq!(replayed.1["resyncRequired"], false);
        assert_eq!(replayed.1["sequence"], 1);
        let replay = read_json(&mut replayed.0);
        assert_eq!(replay, event);
        replayed
            .0
            .get_mut()
            .set_read_timeout(Some(Duration::from_millis(100)))
            .unwrap();
        assert!(
            replayed.0.read().is_err(),
            "event was replayed more than once"
        );
        drop(replayed);

        let mut after_abrupt =
            connect_and_negotiate(server.address(), &issued.token, Some((&session_id, 0)));
        assert_eq!(after_abrupt.1["resyncRequired"], false);
        assert_eq!(read_json(&mut after_abrupt.0), event);
        drop(after_abrupt);

        for index in 0..512 {
            publisher
                .publish(test_notification(
                    "thread/status/changed",
                    json!({"threadId": "thread-1", "revision": index}),
                ))
                .unwrap();
        }
        let mut evicted =
            connect_and_negotiate(server.address(), &issued.token, Some((&session_id, 0)));
        assert_eq!(evicted.1["resyncRequired"], true);
        assert_eq!(evicted.1["sequence"], 513);
        evicted
            .0
            .get_mut()
            .set_read_timeout(Some(Duration::from_millis(100)))
            .unwrap();
        assert!(
            evicted.0.read().is_err(),
            "a replay-gap handshake must not emit partial history"
        );
        drop(evicted);
        server.stop().unwrap();
    }

    #[test]
    fn oversized_or_request_shaped_notifications_fail_closed() {
        let journal = Arc::new(Mutex::new(EventJournal::new(8, 4096).unwrap()));
        let (event_sender, _) = broadcast::channel(8);
        let publisher = RemoteEventPublisher {
            journal: Arc::clone(&journal),
            event_sender,
        };
        publisher
            .publish(AppServerRemoteNotification {
                method: "turn/completed".into(),
                payload: None,
                total_bytes: 300_000,
            })
            .unwrap();
        let marker = journal.lock().unwrap().replay_after(0).unwrap().remove(0);
        let marker: Value = serde_json::from_slice(marker.encoded()).unwrap();
        assert_eq!(marker["method"], "host/resyncRequired");
        assert_eq!(marker["params"]["reason"], "eventTooLarge");
        assert_eq!(marker["params"]["sourceMethod"], "turn/completed");
        assert_eq!(marker["params"]["bytes"], 300_000);

        let request = serde_json::to_vec(&json!({
            "id": 1,
            "method": "turn/completed",
            "params": {},
        }))
        .unwrap();
        let error = publisher
            .publish(AppServerRemoteNotification {
                method: "turn/completed".into(),
                payload: Some(request),
                total_bytes: 0,
            })
            .unwrap_err();
        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
        assert_eq!(journal.lock().unwrap().current_sequence(), 1);
    }

    #[test]
    fn a_slow_tcp_reader_is_disconnected_under_bounded_event_fanout() {
        let temp = TempDir::new().unwrap();
        let admin = Arc::new(Mutex::new(RemoteAdmin::new(Some(
            temp.path().join("devices.json"),
        ))));
        let ticket = admin.lock().unwrap().create_pairing_ticket().unwrap();
        let issued = {
            let mut admin = admin.lock().unwrap();
            let now_ms = admin.now_ms().unwrap();
            admin
                .registry()
                .unwrap()
                .pair(
                    &ticket.code,
                    "Slow phone",
                    [DeviceScope::Read].into_iter().collect(),
                    now_ms,
                )
                .unwrap()
        };
        let (events, _receiver) = std_mpsc::sync_channel(HOST_EVENT_CAPACITY);
        let server = RemoteServer::start("127.0.0.1:0".parse().unwrap(), admin, events).unwrap();
        let publisher = server.publisher();
        let (mut socket, _) = connect_and_negotiate(server.address(), &issued.token, None);

        for index in 0..96 {
            publisher
                .publish(test_notification(
                    "item/completed",
                    json!({
                        "index": index,
                        "padding": "x".repeat(192 * 1024),
                    }),
                ))
                .unwrap();
        }
        thread::sleep(SOCKET_WRITE_TIMEOUT + Duration::from_secs(1));

        socket
            .get_mut()
            .set_read_timeout(Some(Duration::from_secs(2)))
            .unwrap();
        let mut terminal = false;
        for _ in 0..128 {
            match socket.read() {
                Ok(ClientWsMessage::Text(text)) => {
                    let message: Value = serde_json::from_str(&text).unwrap();
                    if message["type"] == "resync_required" {
                        terminal = true;
                    }
                }
                Ok(ClientWsMessage::Ping(payload)) => {
                    let _ = socket.send(ClientWsMessage::Pong(payload));
                }
                Ok(ClientWsMessage::Close(_)) | Err(_) => {
                    terminal = true;
                    break;
                }
                Ok(_) => {}
            }
        }
        assert!(
            terminal,
            "slow reader remained connected after bounded fanout"
        );
        drop(socket);
        server.stop().unwrap();
    }

    #[test]
    fn loopback_pairing_handshake_status_and_live_revocation_work_over_tcp() {
        let temp = TempDir::new().unwrap();
        let device_file = temp.path().join("devices.json");
        let admin = Arc::new(Mutex::new(RemoteAdmin::new(Some(device_file.clone()))));
        let ticket = admin.lock().unwrap().create_pairing_ticket().unwrap();
        let (events, event_receiver) = std_mpsc::sync_channel(HOST_EVENT_CAPACITY);
        let server =
            RemoteServer::start("127.0.0.1:0".parse().unwrap(), Arc::clone(&admin), events)
                .unwrap();
        let address = server.address();

        let health = http_get(address, "/healthz");
        assert!(health.starts_with("HTTP/1.1 200 OK\r\n"), "{health}");
        assert!(health.contains("cache-control: no-store\r\n"));
        assert!(!health.contains("sessionId"));

        let pair_body = json!({"code": ticket.code, "deviceName": "Socket phone"}).to_string();
        let paired = http_post_json(address, "/v1/pair", &pair_body);
        assert!(paired.starts_with("HTTP/1.1 200 OK\r\n"), "{paired}");
        assert!(paired.contains("cache-control: no-store\r\n"));
        let paired_json: Value = serde_json::from_str(http_body(&paired)).unwrap();
        let token = paired_json["token"].as_str().unwrap().to_owned();
        let device_id = paired_json["device"]["id"].as_str().unwrap().to_owned();
        assert_eq!(token.len(), 43);
        assert!(!fs::read_to_string(&device_file).unwrap().contains(&token));

        let reused = http_post_json(address, "/v1/pair", &pair_body);
        assert!(reused.starts_with("HTTP/1.1 401 Unauthorized\r\n"));

        let unauthorized = websocket_request(address, None);
        let error = client(unauthorized, TcpStream::connect(address).unwrap()).unwrap_err();
        assert!(matches!(
            error,
            tungstenite::HandshakeError::Failure(tungstenite::Error::Http(ref response))
                if response.status() == tungstenite::http::StatusCode::UNAUTHORIZED
        ));

        let request = websocket_request(address, Some(&token));
        let stream = TcpStream::connect(address).unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(2)))
            .unwrap();
        let (mut socket, response) = client(request, stream).unwrap();
        assert_eq!(
            response.headers()[tungstenite::http::header::SEC_WEBSOCKET_PROTOCOL],
            WS_PROTOCOL
        );
        let server_hello = read_json(&mut socket);
        assert_eq!(server_hello["type"], "server_hello");
        let session_id = server_hello["sessionId"].as_str().unwrap().to_owned();
        socket
            .send(ClientWsMessage::Text(
                json!({
                    "type": "client_hello",
                    "supportedProtocolVersions": [1],
                })
                .to_string()
                .into(),
            ))
            .unwrap();
        let hello_ack = read_json(&mut socket);
        assert_eq!(hello_ack["type"], "hello_ack");
        assert_eq!(hello_ack["sessionId"], session_id);
        assert_eq!(hello_ack["resyncRequired"], false);

        socket
            .send(ClientWsMessage::Text(
                json!({
                    "type": "rpc",
                    "id": "status-1",
                    "method": "host/remote/status",
                    "params": {},
                })
                .to_string()
                .into(),
            ))
            .unwrap();
        let status = read_json(&mut socket);
        assert_eq!(status["type"], "rpc_result");
        assert_eq!(status["id"], "status-1");
        assert_eq!(status["result"]["device"]["id"], device_id);
        assert_eq!(status["result"]["mode"], "loopbackReadOnlyCodex");

        socket
            .send(ClientWsMessage::Text(
                json!({
                    "type": "rpc",
                    "id": "models-1",
                    "method": "model/list",
                    "params": {"limit": 10, "includeHidden": false},
                })
                .to_string()
                .into(),
            ))
            .unwrap();
        let call = match event_receiver.recv_timeout(Duration::from_secs(1)).unwrap() {
            HostEvent::RemoteRpc(call) => call,
            _ => panic!("expected a Remote RPC Host event"),
        };
        assert_eq!(call.method, "model/list");
        assert_eq!(call.params["limit"], 10);
        call.reply
            .send(ServerMessage::RpcResult {
                id: call.client_id,
                result: json!({"data": [], "nextCursor": null}),
            })
            .unwrap();
        let models = read_json(&mut socket);
        assert_eq!(models["type"], "rpc_result");
        assert_eq!(models["id"], "models-1");
        assert_eq!(models["result"]["data"], json!([]));

        let request = websocket_request(address, Some(&token));
        let (mut premature, _) = client(request, TcpStream::connect(address).unwrap()).unwrap();
        let _server_hello = read_json(&mut premature);
        premature
            .send(ClientWsMessage::Text(
                json!({
                    "type": "rpc",
                    "id": "too-early",
                    "method": "host/remote/status",
                    "params": {},
                })
                .to_string()
                .into(),
            ))
            .unwrap();
        let protocol_error = read_json(&mut premature);
        assert_eq!(protocol_error["type"], "protocol_error");
        assert!(matches!(
            premature.read().unwrap(),
            ClientWsMessage::Close(_)
        ));
        drop(premature);

        admin
            .lock()
            .unwrap()
            .registry()
            .unwrap()
            .revoke(&device_id, system_time_ms())
            .unwrap();
        let closed = loop {
            match socket.read() {
                Ok(ClientWsMessage::Close(frame)) => break frame,
                Ok(ClientWsMessage::Ping(payload)) => {
                    socket.send(ClientWsMessage::Pong(payload)).unwrap();
                }
                Ok(_) => {}
                Err(error) => panic!("expected revocation close frame: {error}"),
            }
        };
        assert!(matches!(
            closed,
            Some(frame) if frame.code == tungstenite::protocol::frame::coding::CloseCode::Policy
        ));
        drop(socket);

        let request = websocket_request(address, Some(&token));
        let error = client(request, TcpStream::connect(address).unwrap()).unwrap_err();
        assert!(matches!(
            error,
            tungstenite::HandshakeError::Failure(tungstenite::Error::Http(ref response))
                if response.status() == tungstenite::http::StatusCode::UNAUTHORIZED
        ));
        server.stop().unwrap();
    }

    #[test]
    fn stopping_server_closes_an_active_websocket_without_waiting_for_the_peer() {
        let temp = TempDir::new().unwrap();
        let admin = Arc::new(Mutex::new(RemoteAdmin::new(Some(
            temp.path().join("devices.json"),
        ))));
        let ticket = admin.lock().unwrap().create_pairing_ticket().unwrap();
        let issued = {
            let mut admin = admin.lock().unwrap();
            let now_ms = admin.now_ms().unwrap();
            admin
                .registry()
                .unwrap()
                .pair(
                    &ticket.code,
                    "Shutdown phone",
                    [DeviceScope::Read].into_iter().collect(),
                    now_ms,
                )
                .unwrap()
        };
        let (events, _receiver) = std_mpsc::sync_channel(HOST_EVENT_CAPACITY);
        let server = RemoteServer::start("127.0.0.1:0".parse().unwrap(), admin, events).unwrap();
        let request = websocket_request(server.address(), Some(&issued.token));
        let stream = TcpStream::connect(server.address()).unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(2)))
            .unwrap();
        let (mut socket, _) = client(request, stream).unwrap();
        let _server_hello = read_json(&mut socket);
        socket
            .send(ClientWsMessage::Text(
                json!({
                    "type": "client_hello",
                    "supportedProtocolVersions": [1],
                })
                .to_string()
                .into(),
            ))
            .unwrap();
        let _hello_ack = read_json(&mut socket);

        let started = Instant::now();
        server.stop().unwrap();
        assert!(started.elapsed() < Duration::from_secs(1));
        assert!(matches!(
            socket.read().unwrap(),
            ClientWsMessage::Close(Some(frame))
                if frame.code == tungstenite::protocol::frame::coding::CloseCode::Away
        ));
    }

    #[test]
    fn upstream_timeout_closes_the_connection_and_emits_disconnect_cleanup() {
        let temp = TempDir::new().unwrap();
        let admin = Arc::new(Mutex::new(RemoteAdmin::new(Some(
            temp.path().join("devices.json"),
        ))));
        let ticket = admin.lock().unwrap().create_pairing_ticket().unwrap();
        let issued = {
            let mut admin = admin.lock().unwrap();
            let now_ms = admin.now_ms().unwrap();
            admin
                .registry()
                .unwrap()
                .pair(
                    &ticket.code,
                    "Timeout phone",
                    [DeviceScope::Read].into_iter().collect(),
                    now_ms,
                )
                .unwrap()
        };
        let (events, receiver) = std_mpsc::sync_channel(HOST_EVENT_CAPACITY);
        let server = RemoteServer::start("127.0.0.1:0".parse().unwrap(), admin, events).unwrap();
        let request = websocket_request(server.address(), Some(&issued.token));
        let stream = TcpStream::connect(server.address()).unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(2)))
            .unwrap();
        let (mut socket, _) = client(request, stream).unwrap();
        let _server_hello = read_json(&mut socket);
        socket
            .send(ClientWsMessage::Text(
                json!({
                    "type": "client_hello",
                    "supportedProtocolVersions": [1],
                })
                .to_string()
                .into(),
            ))
            .unwrap();
        let _hello_ack = read_json(&mut socket);
        socket
            .send(ClientWsMessage::Text(
                json!({
                    "type": "rpc",
                    "id": "will-time-out",
                    "method": "model/list",
                    "params": {"limit": 1},
                })
                .to_string()
                .into(),
            ))
            .unwrap();
        let pending_call = match receiver.recv_timeout(Duration::from_secs(1)).unwrap() {
            HostEvent::RemoteRpc(call) => call,
            _ => panic!("expected a Remote RPC Host event"),
        };
        assert!(matches!(
            socket.read().unwrap(),
            ClientWsMessage::Close(Some(frame))
                if frame.code == tungstenite::protocol::frame::coding::CloseCode::Policy
        ));
        drop(pending_call);
        assert!(matches!(
            receiver.recv_timeout(Duration::from_secs(1)).unwrap(),
            HostEvent::RemoteDisconnected(_)
        ));
        server.stop().unwrap();
    }

    fn http_post_json(address: SocketAddr, path: &str, body: &str) -> String {
        let mut stream = TcpStream::connect(address).unwrap();
        write!(
            stream,
            "POST {path} HTTP/1.1\r\nHost: {address}\r\nContent-Type: application/json\r\nContent-Length: {}\r\nConnection: close\r\n\r\n{body}",
            body.len()
        )
        .unwrap();
        stream.flush().unwrap();
        let mut response = String::new();
        stream.read_to_string(&mut response).unwrap();
        response
    }

    fn http_get(address: SocketAddr, path: &str) -> String {
        let mut stream = TcpStream::connect(address).unwrap();
        write!(
            stream,
            "GET {path} HTTP/1.1\r\nHost: {address}\r\nConnection: close\r\n\r\n"
        )
        .unwrap();
        stream.flush().unwrap();
        let mut response = String::new();
        stream.read_to_string(&mut response).unwrap();
        response
    }

    fn http_body(response: &str) -> &str {
        response.split_once("\r\n\r\n").unwrap().1
    }

    fn websocket_request(
        address: SocketAddr,
        token: Option<&str>,
    ) -> tungstenite::http::Request<()> {
        let mut request = format!("ws://{address}/v1/ws")
            .into_client_request()
            .unwrap();
        request.headers_mut().insert(
            tungstenite::http::header::SEC_WEBSOCKET_PROTOCOL,
            tungstenite::http::HeaderValue::from_static(WS_PROTOCOL),
        );
        if let Some(token) = token {
            request.headers_mut().insert(
                tungstenite::http::header::AUTHORIZATION,
                tungstenite::http::HeaderValue::from_str(&format!("Bearer {token}")).unwrap(),
            );
        }
        request
    }

    fn connect_and_negotiate(
        address: SocketAddr,
        token: &str,
        resume: Option<(&str, u64)>,
    ) -> (tungstenite::WebSocket<TcpStream>, Value) {
        let request = websocket_request(address, Some(token));
        let stream = TcpStream::connect(address).unwrap();
        stream
            .set_read_timeout(Some(Duration::from_secs(2)))
            .unwrap();
        let (mut socket, _) = client(request, stream).unwrap();
        let server_hello = read_json(&mut socket);
        let mut hello = json!({
            "type": "client_hello",
            "supportedProtocolVersions": [1],
        });
        if let Some((session_id, sequence)) = resume {
            hello["lastSessionId"] = json!(session_id);
            hello["lastSequence"] = json!(sequence);
        }
        socket
            .send(ClientWsMessage::Text(hello.to_string().into()))
            .unwrap();
        let acknowledgement = read_json(&mut socket);
        assert_eq!(acknowledgement["type"], "hello_ack");
        assert_eq!(acknowledgement["sessionId"], server_hello["sessionId"]);
        (socket, acknowledgement)
    }

    fn test_notification(method: &str, params: Value) -> AppServerRemoteNotification {
        let payload = serde_json::to_vec(&json!({
            "method": method,
            "params": params,
        }))
        .unwrap();
        AppServerRemoteNotification {
            method: method.to_owned(),
            total_bytes: payload.len() as u64,
            payload: Some(payload),
        }
    }

    fn read_json(socket: &mut tungstenite::WebSocket<TcpStream>) -> Value {
        loop {
            match socket.read().unwrap() {
                ClientWsMessage::Text(text) => return serde_json::from_str(&text).unwrap(),
                ClientWsMessage::Ping(payload) => {
                    socket.send(ClientWsMessage::Pong(payload)).unwrap();
                }
                other => panic!("expected text message, got {other:?}"),
            }
        }
    }

    fn system_time_ms() -> u64 {
        std::time::SystemTime::now()
            .duration_since(std::time::UNIX_EPOCH)
            .unwrap()
            .as_millis() as u64
    }
}
