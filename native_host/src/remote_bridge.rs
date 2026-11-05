use crate::events::{AppServerRemoteResponse, RemoteRpcCall};
use codex_native_host::remote::{CorrelationMap, HOST_ID_PREFIX, ServerMessage};
use serde_json::{Map, Value, json};
use std::collections::BTreeMap;
use std::io;
use tokio::sync::oneshot;

const MAX_PENDING_REQUESTS: usize = 64;
const MAX_CORRELATION_BYTES: usize = 64 * 1024;
const MAX_CURSOR_BYTES: usize = 4096;
const MAX_THREAD_ID_BYTES: usize = 128;
const MAX_PAGE_SIZE: u64 = 100;

pub(crate) struct RemoteCoordinator {
    correlations: CorrelationMap,
    pending: BTreeMap<String, oneshot::Sender<ServerMessage>>,
}

impl RemoteCoordinator {
    pub(crate) fn new(session_id: &str) -> io::Result<Self> {
        Ok(Self {
            correlations: CorrelationMap::new(
                session_id,
                MAX_PENDING_REQUESTS,
                MAX_CORRELATION_BYTES,
            )
            .map_err(|error| io::Error::other(error.to_string()))?,
            pending: BTreeMap::new(),
        })
    }

    pub(crate) fn prepare(&mut self, call: RemoteRpcCall) -> Option<(String, Vec<u8>)> {
        let params = match validate_read_only_request(&call.method, &call.params) {
            Ok(params) => params,
            Err(message) => {
                let _ = call
                    .reply
                    .send(remote_error(call.client_id, -32602, message));
                return None;
            }
        };
        let host_id = match self
            .correlations
            .reserve(call.connection_id, call.client_id.clone())
        {
            Ok(host_id) => host_id,
            Err(error) => {
                let _ = call.reply.send(remote_error(
                    call.client_id,
                    -32001,
                    &format!("Remote request was rejected: {error}"),
                ));
                return None;
            }
        };
        let line = serde_json::to_vec(&json!({
            "id": host_id,
            "method": call.method,
            "params": params,
        }))
        .expect("validated Remote request is serializable");
        self.pending.insert(host_id.clone(), call.reply);
        Some((host_id, line))
    }

    pub(crate) fn dispatch_failed(&mut self, host_id: &str) {
        let Some(correlation) = self.correlations.resolve(host_id) else {
            return;
        };
        if let Some(reply) = self.pending.remove(host_id) {
            let _ = reply.send(remote_error(
                correlation.client_id,
                -32603,
                "The Host could not dispatch the Remote request",
            ));
        }
    }

    pub(crate) fn receive(&mut self, response: AppServerRemoteResponse) -> io::Result<()> {
        let Some(correlation) = self.correlations.resolve(&response.host_id) else {
            return Ok(());
        };
        let Some(reply) = self.pending.remove(&response.host_id) else {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "Remote correlation had no pending reply",
            ));
        };
        let message = match response.payload {
            None => remote_error(
                correlation.client_id,
                -32002,
                &format!(
                    "Sanitized app-server response is {} bytes and exceeds the Remote message limit",
                    response.total_bytes
                ),
            ),
            Some(payload) => {
                let value: Value = serde_json::from_slice(&payload).map_err(|_| {
                    io::Error::new(
                        io::ErrorKind::InvalidData,
                        "sanitized Remote response is not valid JSON",
                    )
                })?;
                if value.get("id").and_then(Value::as_str) != Some(response.host_id.as_str()) {
                    return Err(io::Error::new(
                        io::ErrorKind::InvalidData,
                        "sanitized Remote response ID does not match its correlation",
                    ));
                }
                match (value.get("result"), value.get("error")) {
                    (Some(result), None) => ServerMessage::RpcResult {
                        id: correlation.client_id,
                        result: result.clone(),
                    },
                    (None, Some(error)) => ServerMessage::RpcError {
                        id: correlation.client_id,
                        error: error.clone(),
                    },
                    _ => {
                        return Err(io::Error::new(
                            io::ErrorKind::InvalidData,
                            "app-server Remote response must contain exactly one result or error",
                        ));
                    }
                }
            }
        };
        let _ = reply.send(message);
        Ok(())
    }

    pub(crate) fn disconnect(&mut self, connection_id: &str) {
        for host_id in self.correlations.remove_connection(connection_id) {
            self.pending.remove(&host_id);
        }
    }

    #[cfg(test)]
    fn pending(&self) -> usize {
        self.correlations.pending()
    }
}

pub(crate) fn validate_read_only_request(
    method: &str,
    params: &Value,
) -> Result<Value, &'static str> {
    let object = params
        .as_object()
        .ok_or("Remote read-only RPC params must be an object")?;
    match method {
        "model/list" => validate_model_list(object),
        "thread/list" => validate_thread_list(object),
        "thread/read" => validate_thread_read(object),
        _ => Err("Method is not available on the Remote read-only surface"),
    }
}

pub(crate) fn is_reserved_host_id(value: &Value) -> bool {
    value
        .as_str()
        .is_some_and(|identifier| identifier.starts_with(HOST_ID_PREFIX))
}

fn validate_model_list(params: &Map<String, Value>) -> Result<Value, &'static str> {
    require_known_keys(params, &["cursor", "limit", "includeHidden"])?;
    validate_cursor(params.get("cursor"))?;
    let limit = bounded_limit(params.get("limit"))?;
    if let Some(value) = params.get("includeHidden")
        && !value.is_boolean()
    {
        return Err("model/list includeHidden must be a boolean");
    }
    let mut normalized = params.clone();
    normalized.insert("limit".into(), Value::from(limit));
    Ok(Value::Object(normalized))
}

fn validate_thread_list(params: &Map<String, Value>) -> Result<Value, &'static str> {
    require_known_keys(
        params,
        &["cursor", "limit", "sortKey", "sortDirection", "archived"],
    )?;
    validate_cursor(params.get("cursor"))?;
    let limit = bounded_limit(params.get("limit"))?;
    if let Some(value) = params.get("sortKey")
        && !matches!(
            value.as_str(),
            Some("created_at" | "updated_at" | "recency_at")
        )
    {
        return Err("thread/list sortKey is not allowed");
    }
    if let Some(value) = params.get("sortDirection")
        && !matches!(value.as_str(), Some("asc" | "desc"))
    {
        return Err("thread/list sortDirection is invalid");
    }
    if let Some(value) = params.get("archived")
        && value.as_bool() != Some(false)
    {
        return Err("the initial Remote surface lists non-archived threads only");
    }
    let mut normalized = params.clone();
    normalized.insert("limit".into(), Value::from(limit));
    normalized.insert("archived".into(), Value::Bool(false));
    Ok(Value::Object(normalized))
}

fn validate_thread_read(params: &Map<String, Value>) -> Result<Value, &'static str> {
    require_known_keys(params, &["threadId", "includeTurns"])?;
    let thread_id = params
        .get("threadId")
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty() && value.len() <= MAX_THREAD_ID_BYTES)
        .ok_or("thread/read threadId is invalid")?;
    if let Some(value) = params.get("includeTurns")
        && value.as_bool() != Some(false)
    {
        return Err("thread/read includeTurns must be the boolean false");
    }
    Ok(json!({"threadId": thread_id, "includeTurns": false}))
}

fn require_known_keys(params: &Map<String, Value>, allowed: &[&str]) -> Result<(), &'static str> {
    if params.keys().all(|key| allowed.contains(&key.as_str())) {
        Ok(())
    } else {
        Err("Remote read-only RPC contains unsupported parameters")
    }
}

fn validate_cursor(value: Option<&Value>) -> Result<(), &'static str> {
    match value {
        None | Some(Value::Null) => Ok(()),
        Some(Value::String(cursor)) if cursor.len() <= MAX_CURSOR_BYTES => Ok(()),
        _ => Err("pagination cursor is invalid or too large"),
    }
}

fn bounded_limit(value: Option<&Value>) -> Result<u64, &'static str> {
    match value {
        None | Some(Value::Null) => Ok(MAX_PAGE_SIZE),
        Some(value)
            if value
                .as_u64()
                .is_some_and(|limit| (1..=MAX_PAGE_SIZE).contains(&limit)) =>
        {
            Ok(value.as_u64().expect("checked above"))
        }
        _ => Err("page limit must be between 1 and 100"),
    }
}

pub(crate) fn remote_error(id: Value, code: i64, message: &str) -> ServerMessage {
    ServerMessage::RpcError {
        id,
        error: json!({"code": code, "message": message}),
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::events::AppServerRemoteResponse;
    use tokio::sync::oneshot;

    fn call(
        id: Value,
        method: &str,
        params: Value,
    ) -> (RemoteRpcCall, oneshot::Receiver<ServerMessage>) {
        let (reply, receiver) = oneshot::channel();
        (
            RemoteRpcCall {
                connection_id: "phone-a".into(),
                client_id: id,
                method: method.into(),
                params,
                reply,
            },
            receiver,
        )
    }

    #[test]
    fn read_only_allowlist_normalizes_and_rejects_hydration_or_unknown_fields() {
        assert_eq!(
            validate_read_only_request(
                "thread/read",
                &json!({"threadId": "thread-1", "includeTurns": false}),
            )
            .unwrap(),
            json!({"threadId": "thread-1", "includeTurns": false})
        );
        assert_eq!(
            validate_read_only_request("model/list", &json!({})).unwrap()["limit"],
            MAX_PAGE_SIZE
        );
        for (method, params) in [
            (
                "thread/read",
                json!({"threadId": "thread-1", "includeTurns": true}),
            ),
            ("thread/list", json!({"limit": 101})),
            ("thread/list", json!({"limit": 10, "cwd": "/secret"})),
            ("thread/start", json!({})),
        ] {
            assert!(validate_read_only_request(method, &params).is_err());
        }
    }

    #[test]
    fn coordinator_remaps_results_errors_oversize_and_disconnects() {
        let mut coordinator = RemoteCoordinator::new("session").unwrap();
        let (first, first_reply) = call(json!(1), "model/list", json!({"limit": 10}));
        let (first_host_id, line) = coordinator.prepare(first).unwrap();
        assert!(first_host_id.starts_with(HOST_ID_PREFIX));
        assert_eq!(
            serde_json::from_slice::<Value>(&line).unwrap()["id"],
            first_host_id
        );
        coordinator
            .receive(AppServerRemoteResponse {
                host_id: first_host_id.clone(),
                payload: Some(
                    serde_json::to_vec(&json!({"id": first_host_id, "result": {"data": []}}))
                        .unwrap(),
                ),
                total_bytes: 48,
            })
            .unwrap();
        assert!(matches!(
            first_reply.blocking_recv().unwrap(),
            ServerMessage::RpcResult { id, .. } if id == json!(1)
        ));

        let (second, second_reply) = call(json!(2), "thread/list", json!({"limit": 10}));
        let (second_host_id, _) = coordinator.prepare(second).unwrap();
        coordinator
            .receive(AppServerRemoteResponse {
                host_id: second_host_id,
                payload: None,
                total_bytes: 1_048_577,
            })
            .unwrap();
        assert!(matches!(
            second_reply.blocking_recv().unwrap(),
            ServerMessage::RpcError { id, .. } if id == json!(2)
        ));

        let (third, third_reply) = call(json!(3), "thread/read", json!({"threadId": "t"}));
        coordinator.prepare(third).unwrap();
        coordinator.disconnect("phone-a");
        assert!(third_reply.blocking_recv().is_err());
        assert_eq!(coordinator.pending(), 0);
    }
}
