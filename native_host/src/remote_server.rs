use crate::rpc::RemoteAdmin;
use axum::extract::ws::{CloseFrame, Message, WebSocket, WebSocketUpgrade, close_code};
use axum::extract::{DefaultBodyLimit, State};
use axum::http::{HeaderMap, HeaderValue, StatusCode, header};
use axum::response::{IntoResponse, Response};
use axum::routing::{any, get, post};
use axum::{Json, Router, middleware};
use codex_native_host::remote::{
    AuthError, ClientMessage, ConnectionAction, Device, DeviceScope, EventJournal,
    ProtocolConnection, ReplayDisposition, ServerMessage,
};
use serde::{Deserialize, Serialize};
use std::collections::VecDeque;
use std::io;
use std::net::SocketAddr;
use std::sync::{Arc, Mutex};
use std::thread;
use std::time::{Duration, Instant};
use tokio::sync::{Semaphore, watch};
use uuid::Uuid;

const WS_PROTOCOL: &str = "codex-native-v1";
const HTTP_BODY_BYTES: usize = 8 * 1024;
const WS_READ_BUFFER_BYTES: usize = 16 * 1024;
const WS_WRITE_BUFFER_BYTES: usize = 0;
const WS_MAX_WRITE_BUFFER_BYTES: usize = 2 * 1024 * 1024;
const WS_MAX_FRAME_BYTES: usize = 256 * 1024;
const WS_MAX_MESSAGE_BYTES: usize = 1024 * 1024;
const MAX_CONNECTIONS: usize = 8;
const HANDSHAKE_TIMEOUT: Duration = Duration::from_secs(5);
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
    shutdown: Option<watch::Sender<bool>>,
    thread: Option<thread::JoinHandle<io::Result<()>>>,
}

impl RemoteServer {
    pub(crate) fn start(address: SocketAddr, admin: Arc<Mutex<RemoteAdmin>>) -> io::Result<Self> {
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
        let state = ServerState {
            admin,
            session_id: Arc::from(Uuid::new_v4().to_string()),
            journal: Arc::new(Mutex::new(
                EventJournal::new(512, 8 * 1024 * 1024).map_err(|error| {
                    io::Error::other(format!("failed to create Remote journal: {error}"))
                })?,
            )),
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
            shutdown: Some(shutdown_tx),
            thread: Some(thread),
        })
    }

    pub(crate) fn address(&self) -> SocketAddr {
        self.address
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
struct ServerState {
    admin: Arc<Mutex<RemoteAdmin>>,
    session_id: Arc<str>,
    journal: Arc<Mutex<EventJournal>>,
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

async fn socket_loop(mut socket: WebSocket, state: ServerState, device: Device) {
    let mut shutdown = state.shutdown.clone();
    let mut protocol = ProtocolConnection::current(
        state.session_id.to_string(),
        ["ack".into(), "readOnlyFoundation".into()],
    );
    let hello = match state.journal.lock() {
        Ok(journal) => protocol.server_hello(&journal),
        Err(_) => return,
    };
    if send_message(&mut socket, &hello).await.is_err() {
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
    if send_message(&mut socket, &acknowledgement).await.is_err() {
        return;
    }
    if let ReplayDisposition::Replay(events) = replay {
        for event in events {
            let Ok(text) = String::from_utf8(event.encoded().to_vec()) else {
                return;
            };
            if socket.send(Message::Text(text.into())).await.is_err() {
                return;
            }
        }
    }

    let mut heartbeat = tokio::time::interval(HEARTBEAT_INTERVAL);
    let mut revocation = tokio::time::interval(REVOCATION_INTERVAL);
    heartbeat.tick().await;
    revocation.tick().await;
    let mut last_pong = Instant::now();
    loop {
        tokio::select! {
            message = socket.recv() => match message {
                Some(Ok(Message::Text(text))) => {
                    if !handle_client_message(&mut socket, &mut protocol, &state, &device, &text).await {
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
            _ = heartbeat.tick() => {
                if last_pong.elapsed() >= HEARTBEAT_TIMEOUT {
                    close_with(&mut socket, close_code::POLICY, "heartbeat timed out").await;
                    return;
                }
                if socket.send(Message::Ping(b"codex-native".as_slice().into())).await.is_err() {
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
            _ = wait_for_shutdown(&mut shutdown) => {
                close_with(&mut socket, close_code::AWAY, "Host stopping").await;
                return;
            }
        }
    }
}

async fn handle_client_message(
    socket: &mut WebSocket,
    protocol: &mut ProtocolConnection,
    state: &ServerState,
    device: &Device,
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
            let response = if method == "host/remote/status"
                && params.as_object().is_some_and(serde_json::Map::is_empty)
                && idempotency_key.is_none()
                && device.scopes.contains(&DeviceScope::Read)
            {
                ServerMessage::RpcResult {
                    id,
                    result: serde_json::json!({
                        "sessionId": state.session_id.as_ref(),
                        "device": device,
                        "mode": "loopbackReadOnlyFoundation",
                    }),
                }
            } else {
                ServerMessage::RpcError {
                    id,
                    error: "RPC is unavailable in the loopback read-only foundation".into(),
                }
            };
            send_message(socket, &response).await.is_ok()
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

async fn send_message(socket: &mut WebSocket, message: &ServerMessage) -> Result<(), axum::Error> {
    let text = serde_json::to_string(message).expect("Remote server message is serializable");
    socket.send(Message::Text(text.into())).await
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

async fn close_with(socket: &mut WebSocket, code: u16, reason: &'static str) {
    let _ = socket
        .send(Message::Close(Some(CloseFrame {
            code,
            reason: reason.into(),
        })))
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
    use serde_json::{Value, json};
    use std::fs;
    use std::io::{Read, Write};
    use std::net::TcpStream;
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
        let error = RemoteServer::start("0.0.0.0:0".parse().unwrap(), admin)
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
    fn loopback_pairing_handshake_status_and_live_revocation_work_over_tcp() {
        let temp = TempDir::new().unwrap();
        let device_file = temp.path().join("devices.json");
        let admin = Arc::new(Mutex::new(RemoteAdmin::new(Some(device_file.clone()))));
        let ticket = admin.lock().unwrap().create_pairing_ticket().unwrap();
        let server =
            RemoteServer::start("127.0.0.1:0".parse().unwrap(), Arc::clone(&admin)).unwrap();
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
        assert_eq!(status["result"]["mode"], "loopbackReadOnlyFoundation");

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
        let server = RemoteServer::start("127.0.0.1:0".parse().unwrap(), admin).unwrap();
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
