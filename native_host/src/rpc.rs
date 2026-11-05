use crate::remote_bridge::is_reserved_host_id;
use crate::spool::{OutputChunk, OutputStat, SpoolStore};
use base64::Engine;
use codex_native_host::remote::{AuthError, Device, DeviceRegistry, PairingTicket};
use serde_json::Value;
use std::io;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::sync::Mutex;
use std::time::{SystemTime, UNIX_EPOCH};

const HOST_PREFIX: &str = "host/";
const PAIRING_TTL_MS: u64 = 5 * 60 * 1000;
const DEVICE_CREDENTIAL_TTL_MS: u64 = 180 * 24 * 60 * 60 * 1000;
const MAX_PAIRED_DEVICES: usize = 32;

#[derive(Debug)]
pub(crate) enum ClientMessage {
    Forward(Vec<u8>),
    Respond(Option<Vec<u8>>),
}

pub(crate) struct RemoteAdmin {
    file_path: Option<PathBuf>,
    registry: Option<DeviceRegistry>,
    now_ms: fn() -> io::Result<u64>,
    listener_address: Option<SocketAddr>,
}

impl RemoteAdmin {
    pub(crate) fn new(file_path: Option<PathBuf>) -> Self {
        Self {
            file_path,
            registry: None,
            now_ms: system_now_ms,
            listener_address: None,
        }
    }

    #[cfg(test)]
    fn with_clock(file_path: PathBuf, now_ms: fn() -> io::Result<u64>) -> Self {
        Self {
            file_path: Some(file_path),
            registry: None,
            now_ms,
            listener_address: None,
        }
    }

    pub(crate) fn registry(&mut self) -> io::Result<&mut DeviceRegistry> {
        if self.registry.is_none() {
            let file_path = self.file_path.clone().ok_or_else(|| {
                io::Error::new(
                    io::ErrorKind::Unsupported,
                    "Remote credential storage is unavailable on this platform",
                )
            })?;
            self.registry = Some(
                DeviceRegistry::open(file_path, DEVICE_CREDENTIAL_TTL_MS, MAX_PAIRED_DEVICES)
                    .map_err(remote_auth_error)?,
            );
        }
        Ok(self.registry.as_mut().expect("registry was initialized"))
    }

    pub(crate) fn now_ms(&self) -> io::Result<u64> {
        (self.now_ms)()
    }

    pub(crate) fn create_pairing_ticket(&mut self) -> io::Result<PairingTicket> {
        let now_ms = self.now_ms()?;
        self.registry()?
            .create_pairing_ticket(now_ms, PAIRING_TTL_MS)
            .map_err(remote_auth_error)
    }

    pub(crate) fn authenticate(&mut self, token: &str) -> io::Result<Option<Device>> {
        let now_ms = self.now_ms()?;
        self.registry()?
            .authenticate(token, now_ms)
            .map_err(remote_auth_error)
    }

    pub(crate) fn is_active(&mut self, device_id: &str) -> io::Result<bool> {
        let now_ms = self.now_ms()?;
        Ok(self.registry()?.is_active(device_id, now_ms))
    }

    pub(crate) fn set_listener_address(&mut self, address: SocketAddr) {
        self.listener_address = Some(address);
    }

    fn listener_status(&self) -> Value {
        match self.listener_address {
            Some(address) => serde_json::json!({
                "enabled": true,
                "address": address.to_string(),
                "tls": false,
                "scope": "loopback",
            }),
            None => serde_json::json!({"enabled": false}),
        }
    }
}

pub(crate) fn route_client_message(
    line: Vec<u8>,
    store: &SpoolStore,
    remote_admin: &Mutex<RemoteAdmin>,
) -> ClientMessage {
    let value: Value = match serde_json::from_slice(&line) {
        Ok(value) => value,
        Err(_) => return ClientMessage::Forward(line),
    };
    let Some(method) = value.get("method").and_then(Value::as_str) else {
        return ClientMessage::Forward(line);
    };
    let id = value.get("id").cloned();
    if let Some(id) = id.as_ref().filter(|id| is_reserved_host_id(id)) {
        return ClientMessage::Respond(Some(
            serde_json::to_vec(&error_response(
                id.clone(),
                &invalid_params("request ID uses the reserved Host namespace"),
            ))
            .expect("host response is serializable"),
        ));
    }
    if !method.starts_with(HOST_PREFIX) {
        return ClientMessage::Forward(line);
    }

    let params = value.get("params").unwrap_or(&Value::Null);
    let result: io::Result<Value> = (|| match method {
        "host/status" => {
            let remote = remote_admin
                .lock()
                .map_err(|_| io::Error::other("Remote administration lock poisoned"))?
                .listener_status();
            Ok(serde_json::json!({
                "version": env!("CARGO_PKG_VERSION"),
                "maxOutputBytes": store.max_output_bytes(),
                "maxSessionBytes": store.max_session_bytes(),
                "maxReadBytes": store.max_read_bytes(),
                "remote": remote,
            }))
        }
        "host/output/stat" => {
            let output_ref = output_ref(params)?;
            Ok(stat_value(store.stat(output_ref)?))
        }
        "host/output/readRange" => {
            let output_ref = output_ref(params)?;
            let offset = required_u64(params, "offset")?;
            let length = required_length(params, store.max_read_bytes())?;
            Ok(chunk_value(store.read_range(output_ref, offset, length)?))
        }
        "host/output/tail" => {
            let output_ref = output_ref(params)?;
            let length = required_length(params, store.max_read_bytes())?;
            Ok(chunk_value(store.tail(output_ref, length)?))
        }
        "host/remote/pairing/create" => {
            require_no_params(params)?;
            let mut admin = remote_admin
                .lock()
                .map_err(|_| io::Error::other("Remote administration lock poisoned"))?;
            let ticket = admin.create_pairing_ticket()?;
            Ok(serde_json::json!({
                "code": ticket.code,
                "expiresAt": ticket.expires_at_ms,
            }))
        }
        "host/remote/devices/list" => {
            require_no_params(params)?;
            let mut admin = remote_admin
                .lock()
                .map_err(|_| io::Error::other("Remote administration lock poisoned"))?;
            Ok(serde_json::json!({"devices": admin.registry()?.list()}))
        }
        "host/remote/devices/revoke" => {
            let device_id = required_string(params, "deviceId")?;
            let mut admin = remote_admin
                .lock()
                .map_err(|_| io::Error::other("Remote administration lock poisoned"))?;
            let now_ms = admin.now_ms()?;
            let revoked = admin
                .registry()?
                .revoke(device_id, now_ms)
                .map_err(remote_auth_error)?;
            Ok(serde_json::json!({"revoked": revoked}))
        }
        _ => Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "unknown host method",
        )),
    })();

    let Some(id) = id else {
        return ClientMessage::Respond(None);
    };
    let response = match result {
        Ok(result) => serde_json::json!({"id": id, "result": result}),
        Err(error) => error_response(id, &error),
    };
    ClientMessage::Respond(Some(
        serde_json::to_vec(&response).expect("host response is serializable"),
    ))
}

fn output_ref(params: &Value) -> io::Result<&str> {
    params
        .get("ref")
        .and_then(Value::as_str)
        .ok_or_else(|| invalid_params("params.ref must be an output reference"))
}

fn required_string<'a>(params: &'a Value, name: &str) -> io::Result<&'a str> {
    params
        .get(name)
        .and_then(Value::as_str)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| invalid_params("required string parameter is missing"))
}

fn require_no_params(params: &Value) -> io::Result<()> {
    if params.is_null() || params.as_object().is_some_and(serde_json::Map::is_empty) {
        Ok(())
    } else {
        Err(invalid_params("method does not accept parameters"))
    }
}

fn system_now_ms() -> io::Result<u64> {
    let elapsed = SystemTime::now()
        .duration_since(UNIX_EPOCH)
        .map_err(|_| io::Error::other("system clock is before the Unix epoch"))?;
    u64::try_from(elapsed.as_millis())
        .map_err(|_| io::Error::other("system clock millisecond value is too large"))
}

fn remote_auth_error(error: AuthError) -> io::Error {
    io::Error::other(format!("Remote device operation failed: {error}"))
}

fn required_u64(params: &Value, name: &str) -> io::Result<u64> {
    params
        .get(name)
        .and_then(Value::as_u64)
        .ok_or_else(|| invalid_params("offset must be a non-negative integer"))
}

fn required_length(params: &Value, max: usize) -> io::Result<usize> {
    let value = required_u64(params, "length")?;
    let value = usize::try_from(value).map_err(|_| invalid_params("length is too large"))?;
    if value == 0 || value > max {
        return Err(invalid_params("length exceeds the bounded read limit"));
    }
    Ok(value)
}

fn stat_value(stat: OutputStat) -> Value {
    serde_json::json!({
        "ref": stat.output_ref,
        "bytes": stat.bytes,
        "storedBytes": stat.stored_bytes,
        "truncated": stat.truncated,
    })
}

fn chunk_value(chunk: OutputChunk) -> Value {
    serde_json::json!({
        "ref": chunk.output_ref,
        "offset": chunk.offset,
        "data": base64::engine::general_purpose::STANDARD.encode(chunk.bytes),
        "encoding": "base64",
        "bytes": chunk.total_bytes,
        "storedBytes": chunk.stored_bytes,
        "truncated": chunk.truncated,
        "eof": chunk.eof,
    })
}

fn error_response(id: Value, error: &io::Error) -> Value {
    let (code, message) = match error.kind() {
        io::ErrorKind::InvalidInput => (-32602, "Invalid host request"),
        io::ErrorKind::NotFound => (-32004, "Output is not available"),
        io::ErrorKind::Unsupported => (-32601, "Host method not found"),
        _ => (-32603, "Host operation failed"),
    };
    serde_json::json!({
        "id": id,
        "error": {"code": code, "message": message},
    })
}

fn invalid_params(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidInput, message)
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::spool::SpoolStore;
    use std::fs;
    use std::time::Duration;
    use tempfile::TempDir;

    fn fixed_now_ms() -> io::Result<u64> {
        Ok(1_000)
    }

    fn fixture() -> (TempDir, SpoolStore, String, Mutex<RemoteAdmin>) {
        let temp = TempDir::new().unwrap();
        let store = SpoolStore::open(
            temp.path().to_owned(),
            1024,
            2048,
            4096,
            64,
            Duration::from_secs(60),
        )
        .unwrap();
        let mut output = store.start_output();
        output.write_decoded(b"alpha-beta-gamma").unwrap();
        let output_ref = output.finish().unwrap().output_ref.unwrap();
        let remote_admin = Mutex::new(RemoteAdmin::with_clock(
            temp.path().join("remote/devices.json"),
            fixed_now_ms,
        ));
        (temp, store, output_ref, remote_admin)
    }

    fn response(message: ClientMessage) -> Value {
        match message {
            ClientMessage::Respond(Some(bytes)) => serde_json::from_slice(&bytes).unwrap(),
            other => panic!("expected response, got {other:?}"),
        }
    }

    #[test]
    fn forwards_non_host_messages_byte_for_byte() {
        let (_temp, store, _, remote_admin) = fixture();
        let input = br#"{"id":7,"method":"thread/list","params":{}}"#.to_vec();
        match route_client_message(input.clone(), &store, &remote_admin) {
            ClientMessage::Forward(actual) => assert_eq!(actual, input),
            other => panic!("expected forward, got {other:?}"),
        }
    }

    #[test]
    fn rejects_the_reserved_remote_correlation_namespace_from_local_input() {
        let (_temp, store, _, remote_admin) = fixture();
        let input = br#"{"id":"codex-remote:spoof:1","method":"thread/list","params":{}}"#.to_vec();
        let value = response(route_client_message(input, &store, &remote_admin));
        assert_eq!(value["error"]["code"], -32602);
    }

    #[test]
    fn reads_bounded_ranges_without_exposing_paths() {
        let (_temp, store, output_ref, remote_admin) = fixture();
        let request = serde_json::to_vec(&serde_json::json!({
            "id": 9,
            "method": "host/output/readRange",
            "params": {"ref": output_ref, "offset": 6, "length": 4},
        }))
        .unwrap();
        let value = response(route_client_message(request, &store, &remote_admin));
        let encoded = value["result"]["data"].as_str().unwrap();
        assert_eq!(
            base64::engine::general_purpose::STANDARD
                .decode(encoded)
                .unwrap(),
            b"beta"
        );
        assert!(value.to_string().contains("\"ref\""));
        assert!(
            !value
                .to_string()
                .contains(store.session_path().to_string_lossy().as_ref())
        );
    }

    #[test]
    fn rejects_traversal_and_oversized_reads_as_invalid_params() {
        let (_temp, store, output_ref, remote_admin) = fixture();
        for params in [
            serde_json::json!({"ref": "../secret", "offset": 0, "length": 1}),
            serde_json::json!({"ref": output_ref, "offset": 0, "length": 65}),
        ] {
            let request = serde_json::to_vec(&serde_json::json!({
                "id": 1,
                "method": "host/output/readRange",
                "params": params,
            }))
            .unwrap();
            let value = response(route_client_message(request, &store, &remote_admin));
            assert_eq!(value["error"]["code"], -32602);
        }
    }

    #[test]
    fn host_notifications_are_consumed_without_a_response() {
        let (_temp, store, _, remote_admin) = fixture();
        let request = br#"{"method":"host/status"}"#.to_vec();
        assert!(matches!(
            route_client_message(request, &store, &remote_admin),
            ClientMessage::Respond(None)
        ));
    }

    #[test]
    fn local_remote_admin_creates_lists_and_revokes_without_exposing_hashes() {
        use codex_native_host::remote::DeviceScope;
        use std::collections::BTreeSet;

        let (_temp, store, _, remote_admin) = fixture();
        let create = serde_json::to_vec(&serde_json::json!({
            "id": 1,
            "method": "host/remote/pairing/create",
            "params": {},
        }))
        .unwrap();
        let created = response(route_client_message(create, &store, &remote_admin));
        let code = created["result"]["code"].as_str().unwrap().to_owned();
        assert_eq!(code.len(), 24);
        assert_eq!(created["result"]["expiresAt"], 301_000);

        let issued = remote_admin
            .lock()
            .unwrap()
            .registry()
            .unwrap()
            .pair(
                &code,
                "Test phone",
                [DeviceScope::Read, DeviceScope::Write]
                    .into_iter()
                    .collect::<BTreeSet<_>>(),
                1_000,
            )
            .unwrap();
        let list = serde_json::to_vec(&serde_json::json!({
            "id": 2,
            "method": "host/remote/devices/list",
            "params": {},
        }))
        .unwrap();
        let listed = response(route_client_message(list, &store, &remote_admin));
        assert_eq!(listed["result"]["devices"][0]["id"], issued.device.id);
        assert_eq!(listed["result"]["devices"][0]["name"], "Test phone");
        assert!(!listed.to_string().contains(&issued.token));
        assert!(!listed.to_string().contains("tokenHash"));

        let revoke = serde_json::to_vec(&serde_json::json!({
            "id": 3,
            "method": "host/remote/devices/revoke",
            "params": {"deviceId": issued.device.id},
        }))
        .unwrap();
        let revoked = response(route_client_message(revoke, &store, &remote_admin));
        assert_eq!(revoked["result"]["revoked"], true);
    }

    #[test]
    fn corrupt_remote_store_is_lazy_and_does_not_block_local_host_status() {
        let (temp, store, _, _unused_admin) = fixture();
        let path = temp.path().join("corrupt/devices.json");
        fs::create_dir_all(path.parent().unwrap()).unwrap();
        fs::write(&path, b"not json").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&path, fs::Permissions::from_mode(0o600)).unwrap();
        }
        let remote_admin = Mutex::new(RemoteAdmin::with_clock(path, fixed_now_ms));

        let status = br#"{"id":1,"method":"host/status"}"#.to_vec();
        let status = response(route_client_message(status, &store, &remote_admin));
        assert_eq!(status["result"]["version"], env!("CARGO_PKG_VERSION"));

        let list = br#"{"id":2,"method":"host/remote/devices/list"}"#.to_vec();
        let failed = response(route_client_message(list, &store, &remote_admin));
        assert_eq!(failed["error"]["code"], -32603);
        assert_eq!(failed["error"]["message"], "Host operation failed");
        assert!(
            !failed
                .to_string()
                .contains(temp.path().to_string_lossy().as_ref())
        );
    }
}
