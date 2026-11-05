use codex_native_host::remote::ServerMessage;
use serde_json::Value;
use std::io;
use tokio::sync::oneshot;

pub(crate) const HOST_EVENT_CAPACITY: usize = 64;

pub(crate) enum HostEvent {
    ClientLine(Vec<u8>),
    ClientEof,
    InputFailed(io::Error),
    RemoteRpc(RemoteRpcCall),
    RemoteDisconnected(String),
    AppServerRemoteResponse(AppServerRemoteResponse),
    OutputFinished(io::Result<()>),
}

pub(crate) struct RemoteRpcCall {
    pub(crate) connection_id: String,
    pub(crate) client_id: Value,
    pub(crate) method: String,
    pub(crate) params: Value,
    pub(crate) reply: oneshot::Sender<ServerMessage>,
}

#[derive(Debug)]
pub(crate) struct AppServerRemoteResponse {
    pub(crate) host_id: String,
    pub(crate) payload: Option<Vec<u8>>,
    pub(crate) total_bytes: u64,
}

#[derive(Debug)]
pub(crate) struct AppServerRemoteNotification {
    pub(crate) method: String,
    pub(crate) payload: Option<Vec<u8>>,
    pub(crate) total_bytes: u64,
}

#[derive(Debug)]
pub(crate) enum AppServerRemoteObservation {
    Response(AppServerRemoteResponse),
    Notification(AppServerRemoteNotification),
}
