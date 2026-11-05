mod auth;
mod correlation;
mod idempotency;
mod journal;
mod protocol;

pub use auth::{AuthError, Device, DeviceRegistry, DeviceScope, IssuedCredential, PairingTicket};
pub use correlation::{CorrelationError, CorrelationMap, PendingCorrelation};
pub use idempotency::{
    BeginOutcome, CompletionOutcome, IdempotencyError, IdempotencyLedger, OperationLease,
    RpcOutcome,
};
pub use journal::{EventJournal, JournalError, JournalEvent, PublishOutcome};
pub use protocol::{
    AckError, AckOutcome, AckTracker, ClientMessage, ConnectionAction, ConnectionState,
    ProtocolConnection, ProtocolError, ReplayDisposition, ServerMessage,
};

pub const MIN_PROTOCOL_VERSION: u32 = 1;
pub const CURRENT_PROTOCOL_VERSION: u32 = 1;
pub const DEFAULT_MAX_JOURNAL_EVENTS: usize = 512;
pub const DEFAULT_MAX_JOURNAL_BYTES: usize = 8 * 1024 * 1024;
