use serde::Serialize;
use serde_json::Value;
use std::collections::VecDeque;
use std::fmt;
use std::sync::Arc;

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct JournalEvent {
    sequence: u64,
    encoded: Arc<[u8]>,
}

impl JournalEvent {
    pub fn sequence(&self) -> u64 {
        self.sequence
    }

    pub fn encoded(&self) -> &[u8] {
        &self.encoded
    }
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PublishOutcome {
    pub event: JournalEvent,
    pub retained: bool,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub enum JournalError {
    InvalidLimit,
    SequenceExhausted,
    Serialization(String),
}

impl fmt::Display for JournalError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidLimit => write!(formatter, "journal limits must be positive"),
            Self::SequenceExhausted => write!(formatter, "remote event sequence is exhausted"),
            Self::Serialization(message) => {
                write!(formatter, "remote event serialization failed: {message}")
            }
        }
    }
}

impl std::error::Error for JournalError {}

#[derive(Debug)]
pub struct EventJournal {
    max_events: usize,
    max_bytes: usize,
    retained_bytes: usize,
    current_sequence: u64,
    events: VecDeque<JournalEvent>,
}

impl EventJournal {
    pub fn new(max_events: usize, max_bytes: usize) -> Result<Self, JournalError> {
        if max_events == 0 || max_bytes == 0 {
            return Err(JournalError::InvalidLimit);
        }
        Ok(Self {
            max_events,
            max_bytes,
            retained_bytes: 0,
            current_sequence: 0,
            events: VecDeque::new(),
        })
    }

    pub fn current_sequence(&self) -> u64 {
        self.current_sequence
    }

    pub fn retained_events(&self) -> usize {
        self.events.len()
    }

    pub fn retained_bytes(&self) -> usize {
        self.retained_bytes
    }

    pub fn oldest_sequence(&self) -> Option<u64> {
        self.events.front().map(JournalEvent::sequence)
    }

    pub fn publish(&mut self, method: &str, params: Value) -> Result<PublishOutcome, JournalError> {
        let sequence = self
            .current_sequence
            .checked_add(1)
            .ok_or(JournalError::SequenceExhausted)?;
        let encoded = serde_json::to_vec(&WireEvent {
            message_type: "codex_event",
            sequence,
            method,
            params,
        })
        .map_err(|error| JournalError::Serialization(error.to_string()))?;
        self.current_sequence = sequence;

        let event = JournalEvent {
            sequence,
            encoded: Arc::from(encoded),
        };
        if event.encoded.len() > self.max_bytes {
            self.events.clear();
            self.retained_bytes = 0;
            return Ok(PublishOutcome {
                event,
                retained: false,
            });
        }

        self.retained_bytes = self.retained_bytes.checked_add(event.encoded.len()).ok_or(
            JournalError::Serialization("retained byte accounting overflowed".into()),
        )?;
        self.events.push_back(event.clone());
        while self.events.len() > self.max_events || self.retained_bytes > self.max_bytes {
            let removed = self
                .events
                .pop_front()
                .expect("an over-budget journal contains an event");
            self.retained_bytes -= removed.encoded.len();
        }
        Ok(PublishOutcome {
            event,
            retained: true,
        })
    }

    pub fn replay_after(&self, sequence: u64) -> Option<Vec<JournalEvent>> {
        if sequence > self.current_sequence {
            return None;
        }
        if sequence == self.current_sequence {
            return Some(Vec::new());
        }
        let expected_first = sequence.checked_add(1)?;
        let first = self.events.front()?;
        let last = self.events.back()?;
        if first.sequence > expected_first || last.sequence != self.current_sequence {
            return None;
        }

        let replay: Vec<_> = self
            .events
            .iter()
            .filter(|event| event.sequence > sequence)
            .cloned()
            .collect();
        if replay.first().map(JournalEvent::sequence) != Some(expected_first) {
            return None;
        }
        if replay
            .windows(2)
            .any(|pair| pair[0].sequence.checked_add(1) != Some(pair[1].sequence))
        {
            return None;
        }
        Some(replay)
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct WireEvent<'a> {
    #[serde(rename = "type")]
    message_type: &'static str,
    sequence: u64,
    method: &'a str,
    params: Value,
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::json;

    #[test]
    fn enforces_count_and_byte_limits_independently() {
        let mut by_count = EventJournal::new(2, 4096).unwrap();
        for index in 0..3 {
            by_count
                .publish("item/delta", json!({"index": index}))
                .unwrap();
        }
        assert_eq!(by_count.retained_events(), 2);
        assert_eq!(by_count.oldest_sequence(), Some(2));
        assert!(by_count.replay_after(0).is_none());
        assert_eq!(by_count.replay_after(1).unwrap().len(), 2);

        let sample_size = EventJournal::new(4, 4096)
            .unwrap()
            .publish("item/delta", json!({"text": "x".repeat(32)}))
            .unwrap()
            .event
            .encoded()
            .len();
        let mut by_bytes = EventJournal::new(8, sample_size * 2).unwrap();
        for _ in 0..3 {
            by_bytes
                .publish("item/delta", json!({"text": "x".repeat(32)}))
                .unwrap();
        }
        assert_eq!(by_bytes.retained_events(), 2);
        assert!(by_bytes.retained_bytes() <= sample_size * 2);
        assert_eq!(by_bytes.oldest_sequence(), Some(2));
    }

    #[test]
    fn one_oversize_event_creates_an_explicit_replay_gap() {
        let mut journal = EventJournal::new(8, 160).unwrap();
        journal.publish("small", json!({"value": 1})).unwrap();
        let oversize = journal
            .publish("large", json!({"value": "x".repeat(512)}))
            .unwrap();
        assert!(!oversize.retained);
        assert_eq!(journal.retained_events(), 0);
        journal.publish("small", json!({"value": 2})).unwrap();
        assert!(journal.replay_after(1).is_none());
        assert_eq!(journal.replay_after(2).unwrap().len(), 1);
    }

    #[test]
    fn future_sequence_and_counter_exhaustion_fail_closed() {
        let mut journal = EventJournal::new(2, 1024).unwrap();
        journal.publish("one", Value::Null).unwrap();
        assert!(journal.replay_after(2).is_none());
        journal.current_sequence = u64::MAX;
        assert_eq!(
            journal.publish("never", Value::Null).unwrap_err(),
            JournalError::SequenceExhausted
        );
    }

    #[test]
    fn rejects_zero_limits() {
        assert_eq!(
            EventJournal::new(0, 1).unwrap_err(),
            JournalError::InvalidLimit
        );
        assert_eq!(
            EventJournal::new(1, 0).unwrap_err(),
            JournalError::InvalidLimit
        );
    }
}
