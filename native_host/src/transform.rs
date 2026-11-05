use crate::json_string::JsonStringDecoder;
use crate::spool::{CandidateFile, OutputSpool, SpoolStore};
use json_skimmer::{Event, Mode, Parser, StringKind};
use std::io::{self, Read, Write};
use std::num::NonZeroUsize;

const INPUT_BUFFER_BYTES: usize = 16 * 1024;
const MAX_JSON_DEPTH: usize = 256;
const TARGET_KEY: &[u8] = b"aggregatedOutput";
const MAX_KEY_BYTES: usize = 256;

pub(crate) fn transform_stream(
    mut input: impl Read,
    mut output: impl Write,
    store: &SpoolStore,
) -> io::Result<()> {
    let mut transformer = Transformer::new(store);
    let mut buffer = [0_u8; INPUT_BUFFER_BYTES];
    loop {
        let count = match input.read(&mut buffer) {
            Ok(0) => break,
            Ok(count) => count,
            Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
            Err(error) => return Err(error),
        };
        transformer.push(&buffer[..count], &mut output)?;
    }
    transformer.finish(&mut output)
}

struct Transformer<'a> {
    parser: Parser,
    processor: Processor<'a>,
}

impl<'a> Transformer<'a> {
    fn new(store: &'a SpoolStore) -> Self {
        Self {
            parser: Parser::with_max_depth(
                Mode::Scan,
                NonZeroUsize::new(MAX_JSON_DEPTH).expect("positive JSON depth"),
            ),
            processor: Processor::new(store),
        }
    }

    fn push(&mut self, input: &[u8], output: &mut impl Write) -> io::Result<()> {
        let base = self.parser.offset();
        if self.processor.cursor != base {
            return Err(invalid_data("JSON transformer offset mismatch"));
        }
        let processor = &mut self.processor;
        self.parser.push(input, |event| {
            if processor.error.is_none()
                && let Err(error) = processor.handle(event, input, base, output)
            {
                processor.error = Some(error);
            }
        });
        if let Some(error) = processor.error.take() {
            processor.discard_candidate();
            return Err(error);
        }
        processor.copy_until(base + input.len() as u64, input, base)?;
        Ok(())
    }

    fn finish(&mut self, output: &mut impl Write) -> io::Result<()> {
        let parser_offset = self.parser.offset();
        let processor = &mut self.processor;
        self.parser.finish(|event| {
            if processor.error.is_none()
                && let Err(error) = processor.handle(event, &[], parser_offset, output)
            {
                processor.error = Some(error);
            }
        });
        if let Some(error) = processor.error.take() {
            processor.discard_candidate();
            return Err(error);
        }
        if processor.candidate.is_some() || processor.active_output.is_some() {
            processor.discard_candidate();
            return Err(invalid_data("truncated app-server JSON message"));
        }
        Ok(())
    }
}

struct Processor<'a> {
    store: &'a SpoolStore,
    candidate: Option<CandidateFile>,
    cursor: u64,
    depth: usize,
    key: Option<KeyCollector>,
    pending_target_depth: Option<usize>,
    active_output: Option<ActiveOutput<'a>>,
    completed_candidate: bool,
    separator_has_line_break: bool,
    error: Option<io::Error>,
}

impl<'a> Processor<'a> {
    fn new(store: &'a SpoolStore) -> Self {
        Self {
            store,
            candidate: None,
            cursor: 0,
            depth: 0,
            key: None,
            pending_target_depth: None,
            active_output: None,
            completed_candidate: false,
            separator_has_line_break: false,
            error: None,
        }
    }

    fn handle(
        &mut self,
        event: Event<'_>,
        input: &[u8],
        base: u64,
        output: &mut impl Write,
    ) -> io::Result<()> {
        match event {
            Event::CandidateStart { offset, .. } => {
                self.copy_until(offset, input, base)?;
                if self.completed_candidate && !self.separator_has_line_break {
                    return Err(invalid_data(
                        "app-server JSON messages must be separated by a newline",
                    ));
                }
                if self.candidate.is_some() {
                    return Err(invalid_data("nested JSON candidate lifecycle"));
                }
                self.candidate = Some(self.store.start_candidate()?);
                self.depth = 0;
                self.key = None;
                self.pending_target_depth = None;
                self.active_output = None;
                self.separator_has_line_break = false;
            }
            Event::ObjectStart { .. } | Event::ArrayStart { .. } => {
                self.clear_pending_for_non_string_value();
                self.depth = self
                    .depth
                    .checked_add(1)
                    .ok_or_else(|| invalid_data("JSON depth overflow"))?;
            }
            Event::ObjectEnd { .. } | Event::ArrayEnd { .. } => {
                self.depth = self
                    .depth
                    .checked_sub(1)
                    .ok_or_else(|| invalid_data("JSON depth underflow"))?;
            }
            Event::StringStart { kind, offset } => {
                self.copy_until(offset, input, base)?;
                match kind {
                    StringKind::Key => {
                        self.key = Some(KeyCollector::default());
                    }
                    StringKind::Value => {
                        if self.pending_target_depth.take() == Some(self.depth) {
                            self.candidate_mut()?.write_all(b"null")?;
                            self.cursor = offset + 1;
                            self.active_output = Some(ActiveOutput {
                                decoder: JsonStringDecoder::default(),
                                spool: self.store.start_output(),
                            });
                        }
                    }
                }
            }
            Event::StringFragment {
                kind,
                bytes,
                offset,
            } => match kind {
                StringKind::Key => {
                    if let Some(key) = self.key.as_mut() {
                        key.feed(bytes)?;
                    }
                }
                StringKind::Value if self.active_output.is_some() => {
                    self.copy_until(offset, input, base)?;
                    let active = self.active_output.as_mut().expect("checked above");
                    active
                        .decoder
                        .feed(bytes, |decoded| active.spool.write_decoded(decoded))?;
                    self.cursor = offset + bytes.len() as u64;
                }
                StringKind::Value => {}
            },
            Event::StringEnd { kind, offset } => match kind {
                StringKind::Key => {
                    let key = self
                        .key
                        .take()
                        .ok_or_else(|| invalid_data("missing JSON key state"))?;
                    self.pending_target_depth = key.matches_target().then_some(self.depth);
                }
                StringKind::Value if self.active_output.is_some() => {
                    self.copy_until(offset, input, base)?;
                    self.cursor = offset + 1;
                    let active = self.active_output.take().expect("checked above");
                    active.decoder.finish()?;
                    let descriptor = active.spool.finish()?;
                    self.candidate_mut()?
                        .write_all(b",\"_codexNativeOutput\":")?;
                    serde_json::to_writer(self.candidate_mut()?, &descriptor.to_wire_value())?;
                }
                StringKind::Value => {}
            },
            Event::NumberStart { .. } | Event::Boolean { .. } | Event::Null { .. } => {
                self.clear_pending_for_non_string_value();
            }
            Event::CandidateEnd { span, .. } => {
                self.copy_until(span.end, input, base)?;
                if self.depth != 0
                    || self.key.is_some()
                    || self.pending_target_depth.is_some()
                    || self.active_output.is_some()
                {
                    return Err(invalid_data("incomplete JSON transformer state"));
                }
                let candidate = self
                    .candidate
                    .take()
                    .ok_or_else(|| invalid_data("missing JSON candidate"))?;
                candidate.publish_to(output)?;
                self.completed_candidate = true;
                self.separator_has_line_break = false;
            }
            Event::Invalid(error) => {
                return Err(io::Error::new(
                    io::ErrorKind::InvalidData,
                    format!(
                        "malformed app-server JSON at byte {}: {:?}",
                        error.offset, error.kind
                    ),
                ));
            }
            Event::NumberFragment { .. } | Event::NumberEnd { .. } => {}
        }
        Ok(())
    }

    fn copy_until(&mut self, target: u64, input: &[u8], base: u64) -> io::Result<()> {
        if target < self.cursor || self.cursor < base || target > base + input.len() as u64 {
            return Err(invalid_data("invalid JSON event offsets"));
        }
        let start = (self.cursor - base) as usize;
        let end = (target - base) as usize;
        let bytes = &input[start..end];
        if let Some(candidate) = self.candidate.as_mut() {
            candidate.write_all(bytes)?;
        } else {
            for byte in bytes {
                if !matches!(byte, b' ' | b'\t' | b'\r' | b'\n') {
                    return Err(invalid_data("non-JSON data on app-server stdout"));
                }
                if matches!(byte, b'\r' | b'\n') {
                    self.separator_has_line_break = true;
                }
            }
        }
        self.cursor = target;
        Ok(())
    }

    fn clear_pending_for_non_string_value(&mut self) {
        if self.pending_target_depth == Some(self.depth) {
            self.pending_target_depth = None;
        }
    }

    fn candidate_mut(&mut self) -> io::Result<&mut CandidateFile> {
        self.candidate
            .as_mut()
            .ok_or_else(|| invalid_data("missing JSON candidate file"))
    }

    fn discard_candidate(&mut self) {
        self.candidate.take();
        self.active_output.take();
        self.key.take();
        self.pending_target_depth = None;
    }
}

struct ActiveOutput<'a> {
    decoder: JsonStringDecoder,
    spool: OutputSpool<'a>,
}

#[derive(Default)]
struct KeyCollector {
    decoder: JsonStringDecoder,
    decoded: Vec<u8>,
    overflow: bool,
}

impl KeyCollector {
    fn feed(&mut self, bytes: &[u8]) -> io::Result<()> {
        let decoded = &mut self.decoded;
        let overflow = &mut self.overflow;
        self.decoder.feed(bytes, |fragment| {
            if decoded.len() + fragment.len() <= MAX_KEY_BYTES {
                decoded.extend_from_slice(fragment);
            } else {
                *overflow = true;
            }
            Ok(())
        })
    }

    fn matches_target(self) -> bool {
        self.decoder.finish().is_ok() && !self.overflow && self.decoded == TARGET_KEY
    }
}

fn invalid_data(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;
    use std::time::Duration;
    use tempfile::TempDir;

    struct Fixture {
        _temp: TempDir,
        store: SpoolStore,
    }

    impl Fixture {
        fn new(max_output: u64, max_total: u64) -> Self {
            let temp = TempDir::new().unwrap();
            let store = SpoolStore::open(
                temp.path().to_owned(),
                max_output,
                max_total,
                1024 * 1024,
                1024,
                Duration::from_secs(60),
            )
            .unwrap();
            Self { _temp: temp, store }
        }

        fn transform(&self, input: &[u8], chunk_size: usize) -> io::Result<Vec<u8>> {
            let mut transformer = Transformer::new(&self.store);
            let mut output = Vec::new();
            for chunk in input.chunks(chunk_size) {
                transformer.push(chunk, &mut output)?;
            }
            transformer.finish(&mut output)?;
            Ok(output)
        }
    }

    fn transformed_item(output: &[u8]) -> Value {
        let line = std::str::from_utf8(output).unwrap().trim();
        serde_json::from_str::<Value>(line).unwrap()["result"]["data"][0]["item"].clone()
    }

    #[test]
    fn extracts_output_correctly_across_every_chunk_size() {
        let fixture = Fixture::new(1024 * 1024, 2 * 1024 * 1024);
        let input = r#"{"id":1,"result":{"data":[{"turnId":"t","item":{"id":"i","type":"commandExecution","aggregatedOutput":"quote:\" slash:\\ line:\n unicode:\u4f60\u597d rocket:\ud83d\ude80 raw:π","status":"completed"}}],"nextCursor":null}}
"#
        .as_bytes();
        let expected = "quote:\" slash:\\ line:\n unicode:你好 rocket:🚀 raw:π".as_bytes();

        for chunk_size in 1..=input.len() {
            let output = fixture.transform(input, chunk_size).unwrap();
            let item = transformed_item(&output);
            assert!(item["aggregatedOutput"].is_null(), "chunk={chunk_size}");
            let descriptor = &item["_codexNativeOutput"];
            assert_eq!(descriptor["bytes"].as_u64(), Some(expected.len() as u64));
            let output_ref = descriptor["ref"].as_str().unwrap();
            let stored = fixture
                .store
                .read_range(output_ref, 0, expected.len())
                .unwrap();
            assert_eq!(stored.bytes, expected, "chunk={chunk_size}");
        }
    }

    #[test]
    fn handles_multiple_messages_nested_keys_and_non_string_values() {
        let fixture = Fixture::new(1024, 4096);
        let input =
            br#"{"id":1,"result":{"aggregatedOutput":null,"nested":{"aggregatedOutput":"one"}}}
{"method":"event","params":{"aggregatedOutput":"two"}}
"#;
        let output = fixture.transform(input, 7).unwrap();
        let lines = std::str::from_utf8(&output)
            .unwrap()
            .lines()
            .collect::<Vec<_>>();
        assert_eq!(lines.len(), 2);
        let first: Value = serde_json::from_str(lines[0]).unwrap();
        let second: Value = serde_json::from_str(lines[1]).unwrap();
        assert!(first["result"]["aggregatedOutput"].is_null());
        assert!(first["result"]["nested"]["aggregatedOutput"].is_null());
        assert_eq!(first["result"]["nested"]["_codexNativeOutput"]["bytes"], 3);
        assert_eq!(second["params"]["_codexNativeOutput"]["bytes"], 3);
    }

    #[test]
    fn recognizes_an_escaped_target_key() {
        let fixture = Fixture::new(1024, 4096);
        let output = fixture
            .transform(
                br#"{"aggregated\u004futput":"data"}
"#,
                1,
            )
            .unwrap();
        let value: Value = serde_json::from_slice(&output).unwrap();
        assert!(value["aggregatedOutput"].is_null());
        assert_eq!(value["_codexNativeOutput"]["bytes"], 4);
    }

    #[test]
    fn truncates_spool_but_never_reinjects_large_content() {
        let fixture = Fixture::new(4, 4);
        let output = fixture
            .transform(
                br#"{"aggregatedOutput":"0123456789"}
"#,
                3,
            )
            .unwrap();
        assert!(!std::str::from_utf8(&output).unwrap().contains("0123456789"));
        let value: Value = serde_json::from_slice(&output).unwrap();
        assert_eq!(value["_codexNativeOutput"]["bytes"], 10);
        assert_eq!(value["_codexNativeOutput"]["storedBytes"], 4);
        assert_eq!(value["_codexNativeOutput"]["truncated"], true);
    }

    #[test]
    fn rejects_malformed_truncated_junk_and_missing_newline() {
        let fixture = Fixture::new(1024, 4096);
        for invalid in [
            br#"{"aggregatedOutput":"unterminated"#.as_slice(),
            b"not-json\n",
            b"{}{}\n",
            b"{\"aggregatedOutput\":\"\\ud83d\"}\n",
        ] {
            assert!(fixture.transform(invalid, 2).is_err());
            assert_eq!(fixture.store.stored_bytes(), 0);
        }
    }

    #[test]
    fn rejects_excessive_json_depth() {
        let fixture = Fixture::new(1024, 4096);
        let mut input = vec![b'['; MAX_JSON_DEPTH + 1];
        input.extend(std::iter::repeat_n(b']', MAX_JSON_DEPTH + 1));
        input.push(b'\n');
        assert!(fixture.transform(&input, 17).is_err());
    }
}
