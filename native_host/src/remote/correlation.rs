use serde_json::Value;
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;

const MAX_NAMESPACE_BYTES: usize = 128;
const MAX_CONNECTION_ID_BYTES: usize = 128;
const MAX_CLIENT_ID_BYTES: usize = 256;
const ENTRY_OVERHEAD_BYTES: usize = 96;
pub const HOST_ID_PREFIX: &str = "codex-remote:";

#[derive(Clone, Debug, PartialEq)]
pub struct PendingCorrelation {
    pub connection_id: String,
    pub client_id: Value,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum CorrelationError {
    InvalidLimit,
    InvalidNamespace,
    InvalidConnectionId,
    InvalidClientId,
    PendingLimit,
    ByteLimit,
    DuplicateClientId,
    CounterExhausted,
}

impl fmt::Display for CorrelationError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidLimit => write!(formatter, "pending request limits must be positive"),
            Self::InvalidNamespace => write!(formatter, "correlation namespace is invalid"),
            Self::InvalidConnectionId => write!(formatter, "connection ID is invalid"),
            Self::InvalidClientId => write!(formatter, "JSON-RPC client ID is invalid"),
            Self::PendingLimit => write!(formatter, "remote pending request limit reached"),
            Self::ByteLimit => write!(formatter, "remote pending request byte limit reached"),
            Self::DuplicateClientId => {
                write!(
                    formatter,
                    "client request ID is already pending on this connection"
                )
            }
            Self::CounterExhausted => write!(formatter, "Host request ID counter is exhausted"),
        }
    }
}

impl std::error::Error for CorrelationError {}

#[derive(Debug)]
struct StoredCorrelation {
    pending: PendingCorrelation,
    retained_bytes: usize,
}

#[derive(Debug)]
pub struct CorrelationMap {
    session_namespace: String,
    max_pending: usize,
    max_bytes: usize,
    retained_bytes: usize,
    next_id: u64,
    by_host_id: BTreeMap<String, StoredCorrelation>,
    client_keys: BTreeSet<(String, String)>,
}

impl CorrelationMap {
    pub fn new(
        session_namespace: impl Into<String>,
        max_pending: usize,
        max_bytes: usize,
    ) -> Result<Self, CorrelationError> {
        if max_pending == 0 || max_bytes == 0 {
            return Err(CorrelationError::InvalidLimit);
        }
        let session_namespace = session_namespace.into();
        if session_namespace.is_empty() || session_namespace.len() > MAX_NAMESPACE_BYTES {
            return Err(CorrelationError::InvalidNamespace);
        }
        Ok(Self {
            session_namespace,
            max_pending,
            max_bytes,
            retained_bytes: 0,
            next_id: 0,
            by_host_id: BTreeMap::new(),
            client_keys: BTreeSet::new(),
        })
    }

    pub fn reserve(
        &mut self,
        connection_id: impl Into<String>,
        client_id: Value,
    ) -> Result<String, CorrelationError> {
        if self.by_host_id.len() >= self.max_pending {
            return Err(CorrelationError::PendingLimit);
        }
        let connection_id = connection_id.into();
        if connection_id.is_empty() || connection_id.len() > MAX_CONNECTION_ID_BYTES {
            return Err(CorrelationError::InvalidConnectionId);
        }
        if !matches!(client_id, Value::String(_) | Value::Number(_)) {
            return Err(CorrelationError::InvalidClientId);
        }
        let serialized_id = serde_json::to_string(&client_id)
            .expect("a serde_json::Value always serializes successfully");
        if serialized_id.len() > MAX_CLIENT_ID_BYTES {
            return Err(CorrelationError::InvalidClientId);
        }
        let client_key = (connection_id.clone(), serialized_id.clone());
        if self.client_keys.contains(&client_key) {
            return Err(CorrelationError::DuplicateClientId);
        }
        let sequence = self
            .next_id
            .checked_add(1)
            .ok_or(CorrelationError::CounterExhausted)?;
        let host_id = format!("{HOST_ID_PREFIX}{}:{sequence}", self.session_namespace);
        let retained_bytes = host_id
            .len()
            .saturating_add(connection_id.len().saturating_mul(2))
            .saturating_add(serialized_id.len().saturating_mul(2))
            .saturating_add(ENTRY_OVERHEAD_BYTES);
        if retained_bytes > self.max_bytes.saturating_sub(self.retained_bytes) {
            return Err(CorrelationError::ByteLimit);
        }

        self.next_id = sequence;
        self.client_keys.insert(client_key);
        self.retained_bytes += retained_bytes;
        self.by_host_id.insert(
            host_id.clone(),
            StoredCorrelation {
                pending: PendingCorrelation {
                    connection_id,
                    client_id,
                },
                retained_bytes,
            },
        );
        Ok(host_id)
    }

    pub fn resolve(&mut self, host_id: &str) -> Option<PendingCorrelation> {
        let stored = self.by_host_id.remove(host_id)?;
        self.retained_bytes -= stored.retained_bytes;
        let pending = stored.pending;
        let serialized_id = serde_json::to_string(&pending.client_id)
            .expect("a serde_json::Value always serializes successfully");
        self.client_keys
            .remove(&(pending.connection_id.clone(), serialized_id));
        Some(pending)
    }

    pub fn remove_connection(&mut self, connection_id: &str) -> Vec<String> {
        let host_ids: Vec<_> = self
            .by_host_id
            .iter()
            .filter(|(_, stored)| stored.pending.connection_id == connection_id)
            .map(|(host_id, _)| host_id.clone())
            .collect();
        for host_id in &host_ids {
            let _ = self.resolve(host_id);
        }
        host_ids
    }

    pub fn pending(&self) -> usize {
        self.by_host_id.len()
    }

    pub fn retained_bytes(&self) -> usize {
        self.retained_bytes
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn isolates_equal_client_ids_across_connections() {
        let mut correlations = CorrelationMap::new("session", 4, 4096).unwrap();
        let first = correlations.reserve("phone-a", json!(1)).unwrap();
        let second = correlations.reserve("phone-b", json!(1)).unwrap();
        assert_ne!(first, second);
        assert_eq!(
            correlations.reserve("phone-a", json!(1)).unwrap_err(),
            CorrelationError::DuplicateClientId
        );
        assert_eq!(
            correlations.resolve(&first),
            Some(PendingCorrelation {
                connection_id: "phone-a".into(),
                client_id: json!(1),
            })
        );
        assert!(correlations.reserve("phone-a", json!(1)).is_ok());
    }

    #[test]
    fn bounds_pending_requests_and_cleans_one_connection() {
        let mut correlations = CorrelationMap::new("session", 2, 4096).unwrap();
        let first = correlations.reserve("phone-a", json!("a")).unwrap();
        correlations.reserve("phone-b", json!("b")).unwrap();
        assert_eq!(
            correlations.reserve("phone-c", json!("c")).unwrap_err(),
            CorrelationError::PendingLimit
        );
        assert_eq!(correlations.remove_connection("phone-a"), vec![first]);
        assert_eq!(correlations.pending(), 1);
        assert!(correlations.retained_bytes() > 0);
    }

    #[test]
    fn rejects_zero_pending_limit_and_counter_wrap() {
        assert_eq!(
            CorrelationMap::new("session", 0, 1).unwrap_err(),
            CorrelationError::InvalidLimit
        );
        let mut correlations = CorrelationMap::new("session", 1, 4096).unwrap();
        correlations.next_id = u64::MAX;
        assert_eq!(
            correlations.reserve("phone", json!(1)).unwrap_err(),
            CorrelationError::CounterExhausted
        );
        assert_eq!(correlations.pending(), 0);
    }

    #[test]
    fn enforces_identifier_shapes_and_total_byte_budget() {
        assert_eq!(
            CorrelationMap::new("", 1, 1).unwrap_err(),
            CorrelationError::InvalidNamespace
        );
        let mut correlations = CorrelationMap::new("session", 4, 180).unwrap();
        assert_eq!(
            correlations.reserve("", json!(1)).unwrap_err(),
            CorrelationError::InvalidConnectionId
        );
        assert_eq!(
            correlations
                .reserve("phone", json!({"object": 1}))
                .unwrap_err(),
            CorrelationError::InvalidClientId
        );
        assert_eq!(
            correlations
                .reserve("phone", json!("x".repeat(256)))
                .unwrap_err(),
            CorrelationError::InvalidClientId
        );
        correlations.reserve("phone", json!(1)).unwrap();
        assert_eq!(
            correlations.reserve("phone", json!(2)).unwrap_err(),
            CorrelationError::ByteLimit
        );
        assert_eq!(correlations.pending(), 1);
    }
}
