use crate::spool::{OutputChunk, OutputStat, SpoolStore};
use base64::Engine;
use serde_json::Value;
use std::io;

const HOST_PREFIX: &str = "host/";

#[derive(Debug)]
pub(crate) enum ClientMessage {
    Forward(Vec<u8>),
    Respond(Option<Vec<u8>>),
}

pub(crate) fn route_client_message(line: Vec<u8>, store: &SpoolStore) -> ClientMessage {
    let value: Value = match serde_json::from_slice(&line) {
        Ok(value) => value,
        Err(_) => return ClientMessage::Forward(line),
    };
    let Some(method) = value.get("method").and_then(Value::as_str) else {
        return ClientMessage::Forward(line);
    };
    if !method.starts_with(HOST_PREFIX) {
        return ClientMessage::Forward(line);
    }

    let id = value.get("id").cloned();
    let params = value.get("params").unwrap_or(&Value::Null);
    let result: io::Result<Value> = (|| match method {
        "host/status" => Ok(serde_json::json!({
            "version": env!("CARGO_PKG_VERSION"),
            "maxOutputBytes": store.max_output_bytes(),
            "maxSessionBytes": store.max_session_bytes(),
            "maxReadBytes": store.max_read_bytes(),
        })),
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
        _ => (-32603, "Host output operation failed"),
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
    use std::time::Duration;
    use tempfile::TempDir;

    fn fixture() -> (TempDir, SpoolStore, String) {
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
        (temp, store, output_ref)
    }

    fn response(message: ClientMessage) -> Value {
        match message {
            ClientMessage::Respond(Some(bytes)) => serde_json::from_slice(&bytes).unwrap(),
            other => panic!("expected response, got {other:?}"),
        }
    }

    #[test]
    fn forwards_non_host_messages_byte_for_byte() {
        let (_temp, store, _) = fixture();
        let input = br#"{"id":7,"method":"thread/list","params":{}}"#.to_vec();
        match route_client_message(input.clone(), &store) {
            ClientMessage::Forward(actual) => assert_eq!(actual, input),
            other => panic!("expected forward, got {other:?}"),
        }
    }

    #[test]
    fn reads_bounded_ranges_without_exposing_paths() {
        let (_temp, store, output_ref) = fixture();
        let request = serde_json::to_vec(&serde_json::json!({
            "id": 9,
            "method": "host/output/readRange",
            "params": {"ref": output_ref, "offset": 6, "length": 4},
        }))
        .unwrap();
        let value = response(route_client_message(request, &store));
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
        let (_temp, store, output_ref) = fixture();
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
            let value = response(route_client_message(request, &store));
            assert_eq!(value["error"]["code"], -32602);
        }
    }

    #[test]
    fn host_notifications_are_consumed_without_a_response() {
        let (_temp, store, _) = fixture();
        let request = br#"{"method":"host/status"}"#.to_vec();
        assert!(matches!(
            route_client_message(request, &store),
            ClientMessage::Respond(None)
        ));
    }
}
