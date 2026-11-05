use serde::{Deserialize, Serialize};
use serde_json::Value;
use sha2::{Digest, Sha256};
use std::collections::BTreeMap;
use std::fmt;

const MAX_DEVICE_ID_BYTES: usize = 128;
const MAX_METHOD_BYTES: usize = 256;
const MAX_IDEMPOTENCY_KEY_BYTES: usize = 256;
const ENTRY_OVERHEAD_BYTES: usize = 96;

#[derive(Clone, Debug, Deserialize, PartialEq, Serialize)]
pub struct RpcOutcome {
    pub success: bool,
    pub payload: Value,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct OperationLease {
    key: LedgerKey,
    fingerprint: [u8; 32],
}

#[derive(Clone, Debug, PartialEq)]
pub enum BeginOutcome {
    Started(OperationLease),
    Pending,
    Replayed(RpcOutcome),
    Unconfirmed,
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum CompletionOutcome {
    Stored,
    MarkedUnconfirmed,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum IdempotencyError {
    InvalidConfiguration,
    InvalidIdentity,
    ExpiryOverflow,
    Capacity,
    ParameterMismatch,
    LeaseExpired,
    AlreadyCompleted,
}

impl fmt::Display for IdempotencyError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidConfiguration => write!(formatter, "idempotency limits must be positive"),
            Self::InvalidIdentity => write!(formatter, "idempotency identity is empty or too long"),
            Self::ExpiryOverflow => write!(formatter, "idempotency expiry overflows"),
            Self::Capacity => write!(formatter, "idempotency ledger capacity reached"),
            Self::ParameterMismatch => {
                write!(
                    formatter,
                    "idempotency key was reused with different parameters"
                )
            }
            Self::LeaseExpired => write!(formatter, "idempotency operation is no longer pending"),
            Self::AlreadyCompleted => {
                write!(formatter, "idempotency operation is already complete")
            }
        }
    }
}

impl std::error::Error for IdempotencyError {}

#[derive(Clone, Debug, Eq, Ord, PartialEq, PartialOrd)]
struct LedgerKey {
    device_id: String,
    method: String,
    idempotency_key: String,
}

#[derive(Clone, Debug)]
struct LedgerEntry {
    fingerprint: [u8; 32],
    expires_at_ms: u64,
    state: EntryState,
    retained_bytes: usize,
}

#[derive(Clone, Debug)]
enum EntryState {
    Pending,
    Completed(RpcOutcome),
    Unconfirmed,
}

#[derive(Debug)]
pub struct IdempotencyLedger {
    ttl_ms: u64,
    max_entries: usize,
    max_bytes: usize,
    retained_bytes: usize,
    entries: BTreeMap<LedgerKey, LedgerEntry>,
}

impl IdempotencyLedger {
    pub fn new(
        ttl_ms: u64,
        max_entries: usize,
        max_bytes: usize,
    ) -> Result<Self, IdempotencyError> {
        if ttl_ms == 0 || max_entries == 0 || max_bytes == 0 {
            return Err(IdempotencyError::InvalidConfiguration);
        }
        Ok(Self {
            ttl_ms,
            max_entries,
            max_bytes,
            retained_bytes: 0,
            entries: BTreeMap::new(),
        })
    }

    pub fn begin(
        &mut self,
        device_id: &str,
        method: &str,
        idempotency_key: &str,
        params: &Value,
        now_ms: u64,
    ) -> Result<BeginOutcome, IdempotencyError> {
        self.cleanup(now_ms);
        let key = validated_key(device_id, method, idempotency_key)?;
        let fingerprint = fingerprint(params);
        if let Some(entry) = self.entries.get(&key) {
            if entry.fingerprint != fingerprint {
                return Err(IdempotencyError::ParameterMismatch);
            }
            return Ok(match &entry.state {
                EntryState::Pending => BeginOutcome::Pending,
                EntryState::Completed(outcome) => BeginOutcome::Replayed(outcome.clone()),
                EntryState::Unconfirmed => BeginOutcome::Unconfirmed,
            });
        }
        if self.entries.len() >= self.max_entries {
            return Err(IdempotencyError::Capacity);
        }
        let retained_bytes = base_entry_bytes(&key);
        if retained_bytes > self.max_bytes.saturating_sub(self.retained_bytes) {
            return Err(IdempotencyError::Capacity);
        }
        let expires_at_ms = now_ms
            .checked_add(self.ttl_ms)
            .ok_or(IdempotencyError::ExpiryOverflow)?;
        self.retained_bytes += retained_bytes;
        self.entries.insert(
            key.clone(),
            LedgerEntry {
                fingerprint,
                expires_at_ms,
                state: EntryState::Pending,
                retained_bytes,
            },
        );
        Ok(BeginOutcome::Started(OperationLease { key, fingerprint }))
    }

    pub fn complete(
        &mut self,
        lease: &OperationLease,
        outcome: RpcOutcome,
        now_ms: u64,
    ) -> Result<CompletionOutcome, IdempotencyError> {
        self.cleanup(now_ms);
        let entry = self
            .entries
            .get_mut(&lease.key)
            .filter(|entry| entry.fingerprint == lease.fingerprint)
            .ok_or(IdempotencyError::LeaseExpired)?;
        if !matches!(entry.state, EntryState::Pending) {
            return Err(IdempotencyError::AlreadyCompleted);
        }
        let outcome_bytes = serde_json::to_vec(&outcome)
            .expect("an idempotency outcome containing JSON values always serializes")
            .len();
        if outcome_bytes > self.max_bytes.saturating_sub(self.retained_bytes) {
            entry.state = EntryState::Unconfirmed;
            return Ok(CompletionOutcome::MarkedUnconfirmed);
        }
        entry.retained_bytes += outcome_bytes;
        self.retained_bytes += outcome_bytes;
        entry.state = EntryState::Completed(outcome);
        Ok(CompletionOutcome::Stored)
    }

    pub fn mark_unconfirmed(
        &mut self,
        lease: &OperationLease,
        now_ms: u64,
    ) -> Result<(), IdempotencyError> {
        self.cleanup(now_ms);
        let entry = self
            .entries
            .get_mut(&lease.key)
            .filter(|entry| entry.fingerprint == lease.fingerprint)
            .ok_or(IdempotencyError::LeaseExpired)?;
        if !matches!(entry.state, EntryState::Pending) {
            return Err(IdempotencyError::AlreadyCompleted);
        }
        entry.state = EntryState::Unconfirmed;
        Ok(())
    }

    pub fn cancel_before_dispatch(
        &mut self,
        lease: &OperationLease,
        now_ms: u64,
    ) -> Result<(), IdempotencyError> {
        self.cleanup(now_ms);
        let entry = self
            .entries
            .get(&lease.key)
            .filter(|entry| entry.fingerprint == lease.fingerprint)
            .ok_or(IdempotencyError::LeaseExpired)?;
        if !matches!(entry.state, EntryState::Pending) {
            return Err(IdempotencyError::AlreadyCompleted);
        }
        let removed = self
            .entries
            .remove(&lease.key)
            .expect("validated pending entry remains present");
        self.retained_bytes -= removed.retained_bytes;
        Ok(())
    }

    pub fn cleanup(&mut self, now_ms: u64) {
        let expired: Vec<_> = self
            .entries
            .iter()
            .filter(|(_, entry)| entry.expires_at_ms <= now_ms)
            .map(|(key, _)| key.clone())
            .collect();
        for key in expired {
            if let Some(entry) = self.entries.remove(&key) {
                self.retained_bytes -= entry.retained_bytes;
            }
        }
    }

    pub fn entries(&self) -> usize {
        self.entries.len()
    }

    pub fn retained_bytes(&self) -> usize {
        self.retained_bytes
    }
}

fn validated_key(
    device_id: &str,
    method: &str,
    idempotency_key: &str,
) -> Result<LedgerKey, IdempotencyError> {
    for (value, limit) in [
        (device_id, MAX_DEVICE_ID_BYTES),
        (method, MAX_METHOD_BYTES),
        (idempotency_key, MAX_IDEMPOTENCY_KEY_BYTES),
    ] {
        if value.is_empty() || value.len() > limit {
            return Err(IdempotencyError::InvalidIdentity);
        }
    }
    Ok(LedgerKey {
        device_id: device_id.into(),
        method: method.into(),
        idempotency_key: idempotency_key.into(),
    })
}

fn fingerprint(params: &Value) -> [u8; 32] {
    let encoded = serde_json::to_vec(params).expect("a serde_json::Value always serializes");
    Sha256::digest(encoded).into()
}

fn base_entry_bytes(key: &LedgerKey) -> usize {
    key.device_id.len() + key.method.len() + key.idempotency_key.len() + ENTRY_OVERHEAD_BYTES
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    fn ledger() -> IdempotencyLedger {
        IdempotencyLedger::new(100, 4, 4096).unwrap()
    }

    fn started(outcome: BeginOutcome) -> OperationLease {
        match outcome {
            BeginOutcome::Started(lease) => lease,
            other => panic!("expected a new operation, got {other:?}"),
        }
    }

    #[test]
    fn replays_same_parameters_and_rejects_key_reuse_with_different_parameters() {
        let mut ledger = ledger();
        let lease = started(
            ledger
                .begin("device", "turn/start", "write-1", &json!({"a": 1}), 0)
                .unwrap(),
        );
        assert_eq!(
            ledger
                .begin("device", "turn/start", "write-1", &json!({"a": 1}), 1)
                .unwrap(),
            BeginOutcome::Pending
        );
        assert_eq!(
            ledger
                .begin("device", "turn/start", "write-1", &json!({"a": 2}), 1)
                .unwrap_err(),
            IdempotencyError::ParameterMismatch
        );
        let result = RpcOutcome {
            success: true,
            payload: json!({"turn": "created"}),
        };
        assert_eq!(
            ledger.complete(&lease, result.clone(), 2).unwrap(),
            CompletionOutcome::Stored
        );
        assert_eq!(
            ledger
                .begin("device", "turn/start", "write-1", &json!({"a": 1}), 2)
                .unwrap(),
            BeginOutcome::Replayed(result)
        );
    }

    #[test]
    fn unconfirmed_and_pre_dispatch_paths_have_distinct_retry_semantics() {
        let mut ledger = ledger();
        let uncertain = started(
            ledger
                .begin("device", "turn/start", "uncertain", &json!({}), 0)
                .unwrap(),
        );
        ledger.mark_unconfirmed(&uncertain, 1).unwrap();
        assert_eq!(
            ledger
                .begin("device", "turn/start", "uncertain", &json!({}), 1)
                .unwrap(),
            BeginOutcome::Unconfirmed
        );

        let cancelled = started(
            ledger
                .begin("device", "turn/start", "cancelled", &json!({}), 0)
                .unwrap(),
        );
        ledger.cancel_before_dispatch(&cancelled, 1).unwrap();
        assert!(matches!(
            ledger
                .begin("device", "turn/start", "cancelled", &json!({}), 1)
                .unwrap(),
            BeginOutcome::Started(_)
        ));
    }

    #[test]
    fn expiration_and_count_capacity_release_exact_accounting() {
        let mut ledger = IdempotencyLedger::new(10, 1, 4096).unwrap();
        started(
            ledger
                .begin("device", "turn/start", "first", &Value::Null, 0)
                .unwrap(),
        );
        assert_eq!(
            ledger
                .begin("device", "turn/start", "second", &Value::Null, 9)
                .unwrap_err(),
            IdempotencyError::Capacity
        );
        assert!(matches!(
            ledger
                .begin("device", "turn/start", "second", &Value::Null, 10)
                .unwrap(),
            BeginOutcome::Started(_)
        ));
        assert_eq!(ledger.entries(), 1);
        assert!(ledger.retained_bytes() > 0);
    }

    #[test]
    fn oversized_outcome_becomes_unconfirmed_instead_of_reexecutable() {
        let base = base_entry_bytes(&validated_key("d", "m", "k").unwrap());
        let mut ledger = IdempotencyLedger::new(100, 2, base + 8).unwrap();
        let lease = started(ledger.begin("d", "m", "k", &Value::Null, 0).unwrap());
        assert_eq!(
            ledger
                .complete(
                    &lease,
                    RpcOutcome {
                        success: true,
                        payload: json!("far too large"),
                    },
                    1,
                )
                .unwrap(),
            CompletionOutcome::MarkedUnconfirmed
        );
        assert_eq!(
            ledger.begin("d", "m", "k", &Value::Null, 1).unwrap(),
            BeginOutcome::Unconfirmed
        );
    }

    #[test]
    fn validates_limits_identity_and_expiry_overflow() {
        assert_eq!(
            IdempotencyLedger::new(0, 1, 1).unwrap_err(),
            IdempotencyError::InvalidConfiguration
        );
        let mut ledger = ledger();
        assert_eq!(
            ledger.begin("", "m", "k", &Value::Null, 0).unwrap_err(),
            IdempotencyError::InvalidIdentity
        );
        assert_eq!(
            ledger
                .begin("d", "m", "overflow", &Value::Null, u64::MAX)
                .unwrap_err(),
            IdempotencyError::ExpiryOverflow
        );
        assert_eq!(ledger.entries(), 0);

        let mut expiring = IdempotencyLedger::new(1, 1, 1024).unwrap();
        let lease = started(
            expiring
                .begin("d", "m", "expires", &Value::Null, 0)
                .unwrap(),
        );
        assert_eq!(
            expiring
                .complete(
                    &lease,
                    RpcOutcome {
                        success: true,
                        payload: Value::Null,
                    },
                    1,
                )
                .unwrap_err(),
            IdempotencyError::LeaseExpired
        );
        assert_eq!(expiring.entries(), 0);
    }
}
