use super::{CURRENT_PROTOCOL_VERSION, EventJournal, JournalEvent, MIN_PROTOCOL_VERSION};
use serde::{Deserialize, Serialize};
use serde_json::Value;
use std::collections::BTreeSet;
use std::fmt;

#[derive(Clone, Debug, Deserialize, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ClientMessage {
    ClientHello {
        #[serde(rename = "supportedProtocolVersions")]
        supported_protocol_versions: Vec<u32>,
        #[serde(rename = "lastSessionId")]
        last_session_id: Option<String>,
        #[serde(rename = "lastSequence")]
        last_sequence: Option<u64>,
    },
    Ack {
        sequence: u64,
    },
    Rpc {
        id: Value,
        method: String,
        #[serde(default)]
        params: Value,
        #[serde(rename = "idempotencyKey")]
        idempotency_key: Option<String>,
    },
}

#[derive(Clone, Debug, Serialize, PartialEq)]
#[serde(tag = "type", rename_all = "snake_case")]
pub enum ServerMessage {
    ServerHello {
        #[serde(rename = "minProtocolVersion")]
        min_protocol_version: u32,
        #[serde(rename = "maxProtocolVersion")]
        max_protocol_version: u32,
        #[serde(rename = "supportedProtocolVersions")]
        supported_protocol_versions: Vec<u32>,
        #[serde(rename = "sessionId")]
        session_id: String,
        sequence: u64,
        capabilities: BTreeSet<String>,
    },
    HelloAck {
        #[serde(rename = "protocolVersion")]
        protocol_version: u32,
        #[serde(rename = "sessionId")]
        session_id: String,
        sequence: u64,
        #[serde(rename = "replayAvailable")]
        replay_available: bool,
        #[serde(rename = "resyncRequired")]
        resync_required: bool,
        capabilities: BTreeSet<String>,
    },
    RpcResult {
        id: Value,
        result: Value,
    },
    RpcError {
        id: Value,
        error: Value,
    },
    ProtocolError {
        error: String,
    },
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ReplayDisposition {
    None,
    Replay(Vec<JournalEvent>),
    ResyncRequired,
}

#[derive(Clone, Debug, PartialEq)]
pub enum ConnectionAction {
    Negotiated {
        acknowledgement: ServerMessage,
        replay: ReplayDisposition,
    },
    Acknowledged(AckOutcome),
    Rpc {
        id: Value,
        method: String,
        params: Value,
        idempotency_key: Option<String>,
    },
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum ConnectionState {
    AwaitingClientHello,
    Negotiated,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum ProtocolError {
    PreHandshakeMessage,
    AlreadyNegotiated,
    NoCommonVersion,
    IncompleteResumeCursor,
    InvalidAck(AckError),
}

impl fmt::Display for ProtocolError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::PreHandshakeMessage => {
                write!(formatter, "client_hello is required before other messages")
            }
            Self::AlreadyNegotiated => write!(formatter, "connection is already negotiated"),
            Self::NoCommonVersion => write!(formatter, "no common Remote protocol version"),
            Self::IncompleteResumeCursor => {
                write!(
                    formatter,
                    "resume session and sequence must be supplied together"
                )
            }
            Self::InvalidAck(error) => write!(formatter, "invalid event acknowledgement: {error}"),
        }
    }
}

impl std::error::Error for ProtocolError {}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum AckError {
    Future { acknowledged: u64, sent: u64 },
    Regressed { acknowledged: u64, previous: u64 },
}

impl fmt::Display for AckError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::Future { acknowledged, sent } => write!(
                formatter,
                "sequence {acknowledged} is newer than the last sent sequence {sent}"
            ),
            Self::Regressed {
                acknowledged,
                previous,
            } => write!(
                formatter,
                "sequence {acknowledged} is older than the previous acknowledgement {previous}"
            ),
        }
    }
}

#[derive(Clone, Copy, Debug, Eq, PartialEq)]
pub enum AckOutcome {
    Advanced,
    Duplicate,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct AckTracker {
    highest_sent: u64,
    highest_acked: Option<u64>,
}

impl AckTracker {
    pub fn new(highest_sent: u64, highest_acked: Option<u64>) -> Result<Self, AckError> {
        if let Some(acknowledged) = highest_acked
            && acknowledged > highest_sent
        {
            return Err(AckError::Future {
                acknowledged,
                sent: highest_sent,
            });
        }
        Ok(Self {
            highest_sent,
            highest_acked,
        })
    }

    pub fn record_sent(&mut self, sequence: u64) -> Result<(), AckError> {
        if sequence < self.highest_sent {
            return Err(AckError::Regressed {
                acknowledged: sequence,
                previous: self.highest_sent,
            });
        }
        self.highest_sent = sequence;
        Ok(())
    }

    pub fn acknowledge(&mut self, sequence: u64) -> Result<AckOutcome, AckError> {
        if sequence > self.highest_sent {
            return Err(AckError::Future {
                acknowledged: sequence,
                sent: self.highest_sent,
            });
        }
        match self.highest_acked {
            Some(previous) if sequence < previous => Err(AckError::Regressed {
                acknowledged: sequence,
                previous,
            }),
            Some(previous) if sequence == previous => Ok(AckOutcome::Duplicate),
            _ => {
                self.highest_acked = Some(sequence);
                Ok(AckOutcome::Advanced)
            }
        }
    }

    pub fn highest_sent(&self) -> u64 {
        self.highest_sent
    }

    pub fn highest_acked(&self) -> Option<u64> {
        self.highest_acked
    }
}

#[derive(Debug)]
pub struct ProtocolConnection {
    state: ConnectionState,
    session_id: String,
    supported_versions: BTreeSet<u32>,
    capabilities: BTreeSet<String>,
    acknowledgements: Option<AckTracker>,
}

impl ProtocolConnection {
    pub fn new(
        session_id: impl Into<String>,
        supported_versions: impl IntoIterator<Item = u32>,
        capabilities: impl IntoIterator<Item = String>,
    ) -> Result<Self, ProtocolError> {
        let supported_versions: BTreeSet<_> = supported_versions.into_iter().collect();
        if supported_versions.is_empty() {
            return Err(ProtocolError::NoCommonVersion);
        }
        Ok(Self {
            state: ConnectionState::AwaitingClientHello,
            session_id: session_id.into(),
            supported_versions,
            capabilities: capabilities.into_iter().collect(),
            acknowledgements: None,
        })
    }

    pub fn current(
        session_id: impl Into<String>,
        capabilities: impl IntoIterator<Item = String>,
    ) -> Self {
        Self::new(
            session_id,
            MIN_PROTOCOL_VERSION..=CURRENT_PROTOCOL_VERSION,
            capabilities,
        )
        .expect("the built-in protocol version set is non-empty")
    }

    pub fn state(&self) -> ConnectionState {
        self.state
    }

    pub fn server_hello(&self, journal: &EventJournal) -> ServerMessage {
        ServerMessage::ServerHello {
            min_protocol_version: *self
                .supported_versions
                .first()
                .expect("connection has a supported protocol version"),
            max_protocol_version: *self
                .supported_versions
                .last()
                .expect("connection has a supported protocol version"),
            supported_protocol_versions: self.supported_versions.iter().copied().collect(),
            session_id: self.session_id.clone(),
            sequence: journal.current_sequence(),
            capabilities: self.capabilities.clone(),
        }
    }

    pub fn receive(
        &mut self,
        message: ClientMessage,
        journal: &EventJournal,
    ) -> Result<ConnectionAction, ProtocolError> {
        match (self.state, message) {
            (
                ConnectionState::AwaitingClientHello,
                ClientMessage::ClientHello {
                    supported_protocol_versions,
                    last_session_id,
                    last_sequence,
                },
            ) => self.negotiate(
                supported_protocol_versions,
                last_session_id,
                last_sequence,
                journal,
            ),
            (ConnectionState::AwaitingClientHello, _) => Err(ProtocolError::PreHandshakeMessage),
            (ConnectionState::Negotiated, ClientMessage::ClientHello { .. }) => {
                Err(ProtocolError::AlreadyNegotiated)
            }
            (ConnectionState::Negotiated, ClientMessage::Ack { sequence }) => {
                let result = self
                    .acknowledgements
                    .as_mut()
                    .expect("negotiated connection has an ACK tracker")
                    .acknowledge(sequence)
                    .map_err(ProtocolError::InvalidAck)?;
                Ok(ConnectionAction::Acknowledged(result))
            }
            (
                ConnectionState::Negotiated,
                ClientMessage::Rpc {
                    id,
                    method,
                    params,
                    idempotency_key,
                },
            ) => Ok(ConnectionAction::Rpc {
                id,
                method,
                params,
                idempotency_key,
            }),
        }
    }

    pub fn record_event_sent(&mut self, sequence: u64) -> Result<(), ProtocolError> {
        if self.state != ConnectionState::Negotiated {
            return Err(ProtocolError::PreHandshakeMessage);
        }
        self.acknowledgements
            .as_mut()
            .expect("negotiated connection has an ACK tracker")
            .record_sent(sequence)
            .map_err(ProtocolError::InvalidAck)
    }

    pub fn acknowledgements(&self) -> Option<&AckTracker> {
        self.acknowledgements.as_ref()
    }

    fn negotiate(
        &mut self,
        client_versions: Vec<u32>,
        last_session_id: Option<String>,
        last_sequence: Option<u64>,
        journal: &EventJournal,
    ) -> Result<ConnectionAction, ProtocolError> {
        if last_session_id.is_some() != last_sequence.is_some() {
            return Err(ProtocolError::IncompleteResumeCursor);
        }
        let selected = client_versions
            .into_iter()
            .filter(|version| self.supported_versions.contains(version))
            .max()
            .ok_or(ProtocolError::NoCommonVersion)?;

        let (replay, initial_acknowledgement) = match (last_session_id, last_sequence) {
            (None, None) => (ReplayDisposition::None, None),
            (Some(session), Some(_)) if session != self.session_id => {
                (ReplayDisposition::ResyncRequired, None)
            }
            (Some(_), Some(sequence)) => match journal.replay_after(sequence) {
                Some(events) if events.is_empty() => (ReplayDisposition::None, Some(sequence)),
                Some(events) => (ReplayDisposition::Replay(events), Some(sequence)),
                None => (ReplayDisposition::ResyncRequired, None),
            },
            _ => unreachable!("resume cursor completeness was checked"),
        };
        let resync_required = replay == ReplayDisposition::ResyncRequired;
        self.acknowledgements = Some(
            AckTracker::new(journal.current_sequence(), initial_acknowledgement)
                .map_err(ProtocolError::InvalidAck)?,
        );
        self.state = ConnectionState::Negotiated;
        Ok(ConnectionAction::Negotiated {
            acknowledgement: ServerMessage::HelloAck {
                protocol_version: selected,
                session_id: self.session_id.clone(),
                sequence: journal.current_sequence(),
                replay_available: true,
                resync_required,
                capabilities: self.capabilities.clone(),
            },
            replay,
        })
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::remote::EventJournal;
    use serde_json::json;

    fn hello(session: Option<&str>, sequence: Option<u64>) -> ClientMessage {
        ClientMessage::ClientHello {
            supported_protocol_versions: vec![99, 1],
            last_session_id: session.map(str::to_owned),
            last_sequence: sequence,
        }
    }

    #[test]
    fn refuses_rpc_until_negotiated_and_selects_highest_common_version() {
        let journal = EventJournal::new(4, 4096).unwrap();
        let mut connection = ProtocolConnection::new("session", [1, 2], []).unwrap();
        let rpc = ClientMessage::Rpc {
            id: json!(1),
            method: "thread/list".into(),
            params: json!({}),
            idempotency_key: None,
        };
        assert_eq!(
            connection.receive(rpc.clone(), &journal).unwrap_err(),
            ProtocolError::PreHandshakeMessage
        );
        let action = connection
            .receive(
                ClientMessage::ClientHello {
                    supported_protocol_versions: vec![1, 2],
                    last_session_id: None,
                    last_sequence: None,
                },
                &journal,
            )
            .unwrap();
        assert!(matches!(
            action,
            ConnectionAction::Negotiated {
                acknowledgement: ServerMessage::HelloAck {
                    protocol_version: 2,
                    resync_required: false,
                    ..
                },
                replay: ReplayDisposition::None,
            }
        ));
        assert!(matches!(
            connection.receive(rpc, &journal).unwrap(),
            ConnectionAction::Rpc { method, .. } if method == "thread/list"
        ));
    }

    #[test]
    fn server_hello_uses_the_versioned_wire_shape() {
        let journal = EventJournal::new(4, 4096).unwrap();
        let connection = ProtocolConnection::current("session-1", ["ack".into()]);
        let encoded = serde_json::to_value(connection.server_hello(&journal)).unwrap();
        assert_eq!(encoded["type"], "server_hello");
        assert_eq!(encoded["minProtocolVersion"], 1);
        assert_eq!(encoded["maxProtocolVersion"], 1);
        assert_eq!(encoded["supportedProtocolVersions"], json!([1]));
        assert_eq!(encoded["sessionId"], "session-1");
        assert_eq!(encoded["sequence"], 0);
        assert_eq!(encoded["capabilities"], json!(["ack"]));
    }

    #[test]
    fn distinguishes_same_session_replay_from_gap_and_process_change() {
        let mut journal = EventJournal::new(2, 4096).unwrap();
        for index in 0..3 {
            journal
                .publish("item/delta", json!({"index": index}))
                .unwrap();
        }

        let mut replayable = ProtocolConnection::current("current", []);
        let action = replayable
            .receive(hello(Some("current"), Some(1)), &journal)
            .unwrap();
        assert!(matches!(
            action,
            ConnectionAction::Negotiated {
                replay: ReplayDisposition::Replay(ref events),
                ..
            } if events.iter().map(JournalEvent::sequence).collect::<Vec<_>>() == [2, 3]
        ));

        for (session, sequence) in [("current", 0), ("old", 3), ("current", 99)] {
            let mut connection = ProtocolConnection::current("current", []);
            let action = connection
                .receive(hello(Some(session), Some(sequence)), &journal)
                .unwrap();
            assert!(matches!(
                action,
                ConnectionAction::Negotiated {
                    acknowledgement: ServerMessage::HelloAck {
                        resync_required: true,
                        ..
                    },
                    replay: ReplayDisposition::ResyncRequired,
                }
            ));
        }
    }

    #[test]
    fn rejects_incomplete_cursor_and_incompatible_version() {
        let journal = EventJournal::new(2, 1024).unwrap();
        let mut incomplete = ProtocolConnection::current("session", []);
        assert_eq!(
            incomplete
                .receive(hello(Some("session"), None), &journal)
                .unwrap_err(),
            ProtocolError::IncompleteResumeCursor
        );
        let mut incompatible = ProtocolConnection::current("session", []);
        assert_eq!(
            incompatible
                .receive(
                    ClientMessage::ClientHello {
                        supported_protocol_versions: vec![7],
                        last_session_id: None,
                        last_sequence: None,
                    },
                    &journal,
                )
                .unwrap_err(),
            ProtocolError::NoCommonVersion
        );
    }

    #[test]
    fn acknowledgements_are_monotonic_and_never_accept_the_future() {
        let mut tracker = AckTracker::new(8, Some(5)).unwrap();
        assert_eq!(tracker.acknowledge(5).unwrap(), AckOutcome::Duplicate);
        assert_eq!(tracker.acknowledge(7).unwrap(), AckOutcome::Advanced);
        assert_eq!(
            tracker.acknowledge(6).unwrap_err(),
            AckError::Regressed {
                acknowledged: 6,
                previous: 7,
            }
        );
        assert_eq!(
            tracker.acknowledge(9).unwrap_err(),
            AckError::Future {
                acknowledged: 9,
                sent: 8,
            }
        );
        tracker.record_sent(9).unwrap();
        assert_eq!(tracker.acknowledge(9).unwrap(), AckOutcome::Advanced);
    }
}
