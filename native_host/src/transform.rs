use crate::events::{
    AppServerRemoteNotification, AppServerRemoteObservation, AppServerRemoteResponse,
};
use crate::file_diff_metrics::FileDiffMetrics;
use crate::json_string::JsonStringDecoder;
use crate::spool::{CandidateFile, OutputSpool, SpoolStore};
use json_skimmer::{Event, Mode, Parser, StringKind};
use std::io::{self, Read, Write};
use std::num::NonZeroUsize;

const INPUT_BUFFER_BYTES: usize = 16 * 1024;
const MAX_JSON_DEPTH: usize = 256;
const TARGET_KEY: &[u8] = b"aggregatedOutput";
const ID_KEY: &[u8] = b"id";
const METHOD_KEY: &[u8] = b"method";
const MAX_KEY_BYTES: usize = 256;
const MAX_REMOTE_ID_BYTES: usize = 128;
const MAX_REMOTE_METHOD_BYTES: usize = 128;
const MAX_REMOTE_RESPONSE_BYTES: usize = 1024 * 1024 - 4096;
const MAX_REMOTE_NOTIFICATION_BYTES: usize = 256 * 1024;

pub(crate) fn transform_stream(
    mut input: impl Read,
    mut output: impl Write,
    store: &SpoolStore,
    remote_id_prefix: Option<String>,
    mut on_remote_observation: impl FnMut(AppServerRemoteObservation) -> io::Result<()>,
) -> io::Result<()> {
    let mut transformer = Transformer::new(store, remote_id_prefix);
    let mut buffer = [0_u8; INPUT_BUFFER_BYTES];
    loop {
        let count = match input.read(&mut buffer) {
            Ok(0) => break,
            Ok(count) => count,
            Err(error) if error.kind() == io::ErrorKind::Interrupted => continue,
            Err(error) => return Err(error),
        };
        transformer.push(&buffer[..count], &mut output, &mut on_remote_observation)?;
    }
    transformer.finish(&mut output, &mut on_remote_observation)
}

struct Transformer<'a> {
    parser: Parser,
    processor: Processor<'a>,
}

impl<'a> Transformer<'a> {
    fn new(store: &'a SpoolStore, remote_id_prefix: Option<String>) -> Self {
        Self {
            parser: Parser::with_max_depth(
                Mode::Scan,
                NonZeroUsize::new(MAX_JSON_DEPTH).expect("positive JSON depth"),
            ),
            processor: Processor::new(store, remote_id_prefix),
        }
    }

    fn push(
        &mut self,
        input: &[u8],
        output: &mut impl Write,
        on_remote_observation: &mut dyn FnMut(AppServerRemoteObservation) -> io::Result<()>,
    ) -> io::Result<()> {
        let base = self.parser.offset();
        if self.processor.cursor != base {
            return Err(invalid_data("JSON transformer offset mismatch"));
        }
        let processor = &mut self.processor;
        self.parser.push(input, |event| {
            if processor.error.is_none()
                && let Err(error) =
                    processor.handle(event, input, base, output, on_remote_observation)
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

    fn finish(
        &mut self,
        output: &mut impl Write,
        on_remote_observation: &mut dyn FnMut(AppServerRemoteObservation) -> io::Result<()>,
    ) -> io::Result<()> {
        let parser_offset = self.parser.offset();
        let processor = &mut self.processor;
        self.parser.finish(|event| {
            if processor.error.is_none()
                && let Err(error) =
                    processor.handle(event, &[], parser_offset, output, on_remote_observation)
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

#[derive(Clone, Copy, PartialEq, Eq)]
enum PathStep {
    Opaque,
    Element,
    Params,
    Result,
    Data,
    InitialTurnsPage,
    Thread,
    Turn,
    Turns,
    Items,
    Item,
    Output,
    Changes,
    Diff,
}

impl PathStep {
    fn from_key(key: &[u8]) -> Self {
        match key {
            b"params" => Self::Params,
            b"result" => Self::Result,
            b"data" => Self::Data,
            b"initialTurnsPage" => Self::InitialTurnsPage,
            b"thread" => Self::Thread,
            b"turn" => Self::Turn,
            b"turns" => Self::Turns,
            b"items" => Self::Items,
            b"item" => Self::Item,
            TARGET_KEY => Self::Output,
            b"changes" => Self::Changes,
            b"diff" => Self::Diff,
            _ => Self::Opaque,
        }
    }
}

struct Container {
    step: PathStep,
    is_array: bool,
}

// A direct ThreadItem field at these stock v2 paths is command output.
// The schema reserves it to commandExecution, regardless of key order.
// An identically named field in an opaque result or argument stays untouched.
const THREAD_ITEM_PATHS: &[&[PathStep]] = {
    use PathStep::*;
    &[
        &[Params, Item],
        &[Params, Turn, Items, Element],
        &[Params, Thread, Turns, Element, Items, Element],
        &[Result, Data, Element, Item],
        &[Result, Data, Element, Items, Element],
        &[Result, Data, Element, Turns, Element, Items, Element],
        &[
            Result, Data, Element, Thread, Turns, Element, Items, Element,
        ],
        &[Result, Turn, Items, Element],
        &[Result, Thread, Turns, Element, Items, Element],
        &[Result, InitialTurnsPage, Data, Element, Items, Element],
    ]
};

struct Processor<'a> {
    store: &'a SpoolStore,
    candidate: Option<CandidateFile>,
    cursor: u64,
    containers: Vec<Container>,
    key: Option<KeyCollector>,
    pending_path_key: PathStep,
    pending_id_depth: Option<usize>,
    pending_method_depth: Option<usize>,
    active_output: Option<ActiveOutput<'a>>,
    active_id: Option<BoundedStringCollector>,
    active_method: Option<BoundedStringCollector>,
    remote_response_id: Option<String>,
    notification_method: Option<String>,
    top_level_has_id: bool,
    remote_id_prefix: Option<String>,
    completed_candidate: bool,
    separator_has_line_break: bool,
    created_outputs: Vec<crate::spool::OutputDescriptor>,
    error: Option<io::Error>,
}

impl<'a> Processor<'a> {
    fn new(store: &'a SpoolStore, remote_id_prefix: Option<String>) -> Self {
        Self {
            store,
            candidate: None,
            cursor: 0,
            containers: Vec::new(),
            key: None,
            pending_path_key: PathStep::Opaque,
            pending_id_depth: None,
            pending_method_depth: None,
            active_output: None,
            active_id: None,
            active_method: None,
            remote_response_id: None,
            notification_method: None,
            top_level_has_id: false,
            remote_id_prefix,
            completed_candidate: false,
            separator_has_line_break: false,
            created_outputs: Vec::new(),
            error: None,
        }
    }

    fn handle(
        &mut self,
        event: Event<'_>,
        input: &[u8],
        base: u64,
        output: &mut impl Write,
        on_remote_observation: &mut dyn FnMut(AppServerRemoteObservation) -> io::Result<()>,
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
                if !self.created_outputs.is_empty() {
                    return Err(invalid_data("unfinished output candidate lifecycle"));
                }
                self.candidate = Some(self.store.start_candidate()?);
                self.containers.clear();
                self.key = None;
                self.pending_path_key = PathStep::Opaque;
                self.pending_id_depth = None;
                self.pending_method_depth = None;
                self.active_output = None;
                self.active_id = None;
                self.active_method = None;
                self.remote_response_id = None;
                self.notification_method = None;
                self.top_level_has_id = false;
                self.separator_has_line_break = false;
            }
            start @ (Event::ObjectStart { .. } | Event::ArrayStart { .. }) => {
                let step = if self.containers.last().is_some_and(|parent| parent.is_array) {
                    PathStep::Element
                } else {
                    self.pending_path_key
                };
                self.clear_pending_for_non_string_value();
                self.containers.push(Container {
                    step,
                    is_array: matches!(start, Event::ArrayStart { .. }),
                });
            }
            Event::ObjectEnd { .. } | Event::ArrayEnd { .. } => {
                self.containers
                    .pop()
                    .ok_or_else(|| invalid_data("JSON depth underflow"))?;
            }
            Event::StringStart { kind, offset } => {
                self.copy_until(offset, input, base)?;
                match kind {
                    StringKind::Key => {
                        self.key = Some(KeyCollector::default());
                    }
                    StringKind::Value => {
                        let depth = self.containers.len();
                        if self.pending_id_depth.take() == Some(depth) {
                            self.active_id = Some(BoundedStringCollector::new(MAX_REMOTE_ID_BYTES));
                        }
                        if self.pending_method_depth.take() == Some(depth) {
                            self.active_method =
                                Some(BoundedStringCollector::new(MAX_REMOTE_METHOD_BYTES));
                        }
                        let key = std::mem::replace(&mut self.pending_path_key, PathStep::Opaque);
                        let file_diff = key == PathStep::Diff && self.is_file_change_path();
                        if (key == PathStep::Output && self.is_thread_item_path()) || file_diff {
                            self.candidate_mut()?.write_all(if file_diff {
                                b"\"\""
                            } else {
                                b"null"
                            })?;
                            self.cursor = offset + 1;
                            self.active_output = Some(ActiveOutput {
                                decoder: JsonStringDecoder::default(),
                                spool: self.store.start_output(),
                                file_diff_metrics: file_diff.then(FileDiffMetrics::default),
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
                    if let Some(id) = self.active_id.as_mut() {
                        id.feed(bytes)?;
                    }
                    if let Some(method) = self.active_method.as_mut() {
                        method.feed(bytes)?;
                    }
                    self.copy_until(offset, input, base)?;
                    let active = self.active_output.as_mut().expect("checked above");
                    active.decoder.feed(bytes, |decoded| {
                        if let Some(metrics) = active.file_diff_metrics.as_mut() {
                            metrics.feed(decoded);
                        }
                        active.spool.write_decoded(decoded)
                    })?;
                    self.cursor = offset + bytes.len() as u64;
                }
                StringKind::Value => {
                    if let Some(id) = self.active_id.as_mut() {
                        id.feed(bytes)?;
                    }
                    if let Some(method) = self.active_method.as_mut() {
                        method.feed(bytes)?;
                    }
                }
            },
            Event::StringEnd { kind, offset } => match kind {
                StringKind::Key => {
                    let key = self
                        .key
                        .take()
                        .ok_or_else(|| invalid_data("missing JSON key state"))?;
                    if let Some(key) = key.finish() {
                        self.pending_path_key = PathStep::from_key(&key);
                        let depth = self.containers.len();
                        if depth == 1 && key == ID_KEY {
                            self.top_level_has_id = true;
                            self.pending_id_depth = Some(depth);
                        } else {
                            self.pending_id_depth = None;
                        }
                        self.pending_method_depth =
                            (depth == 1 && key == METHOD_KEY).then_some(depth);
                    }
                }
                StringKind::Value if self.active_output.is_some() => {
                    self.finish_active_id();
                    self.finish_active_method();
                    self.copy_until(offset, input, base)?;
                    self.cursor = offset + 1;
                    let active = self.active_output.take().expect("checked above");
                    active.decoder.finish()?;
                    let descriptor = active.spool.finish()?;
                    if descriptor.newly_stored {
                        self.created_outputs.push(descriptor.clone());
                    }
                    let mut wire = descriptor.to_wire_value();
                    if let Some(metrics) = active.file_diff_metrics {
                        wire["lineStats"] = metrics.finish();
                        self.candidate_mut()?
                            .write_all(b",\"_codexNativeFileDiff\":")?;
                    } else {
                        self.candidate_mut()?
                            .write_all(b",\"_codexNativeOutput\":")?;
                    }
                    serde_json::to_writer(self.candidate_mut()?, &wire)?;
                }
                StringKind::Value => {
                    self.finish_active_id();
                    self.finish_active_method();
                }
            },
            Event::NumberStart { .. } | Event::Boolean { .. } | Event::Null { .. } => {
                self.clear_pending_for_non_string_value();
            }
            Event::CandidateEnd { span, .. } => {
                self.copy_until(span.end, input, base)?;
                if !self.containers.is_empty()
                    || self.key.is_some()
                    || self.pending_path_key != PathStep::Opaque
                    || self.pending_id_depth.is_some()
                    || self.pending_method_depth.is_some()
                    || self.active_output.is_some()
                    || self.active_id.is_some()
                    || self.active_method.is_some()
                {
                    return Err(invalid_data("incomplete JSON transformer state"));
                }
                let candidate = self
                    .candidate
                    .take()
                    .ok_or_else(|| invalid_data("missing JSON candidate"))?;
                if let Some(host_id) = self.remote_response_id.take() {
                    let captured = candidate.capture_bounded(MAX_REMOTE_RESPONSE_BYTES)?;
                    on_remote_observation(AppServerRemoteObservation::Response(
                        AppServerRemoteResponse {
                            host_id,
                            payload: captured.payload,
                            total_bytes: captured.total_bytes,
                        },
                    ))?;
                    self.created_outputs.clear();
                } else if let Some(method) = self
                    .notification_method
                    .take()
                    .filter(|method| !self.top_level_has_id && is_remote_notification(method))
                {
                    let captured =
                        candidate.publish_to_with_capture(output, MAX_REMOTE_NOTIFICATION_BYTES)?;
                    // Local stdout has received the complete descriptor-bearing candidate.
                    // It now owns every newly created output even if Remote publication fails.
                    self.created_outputs.clear();
                    on_remote_observation(AppServerRemoteObservation::Notification(
                        AppServerRemoteNotification {
                            method,
                            payload: captured.payload,
                            total_bytes: captured.total_bytes,
                        },
                    ))?;
                } else {
                    candidate.publish_to(output)?;
                    self.created_outputs.clear();
                }
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

    fn is_thread_item_path(&self) -> bool {
        THREAD_ITEM_PATHS.iter().any(|path| {
            self.containers
                .iter()
                .skip(1)
                .map(|container| container.step)
                .eq(path.iter().copied())
        })
    }

    // Only FileUpdateChange.diff at schema-reserved ThreadItem/changes paths,
    // plus the stable patchUpdated params.changes path, is a file diff. Nested
    // MCP results/arguments and approval fileChanges maps stay opaque.
    fn is_file_change_path(&self) -> bool {
        let depth = self.containers.len();
        if depth < 4
            || self.containers[depth - 2].step != PathStep::Changes
            || self.containers[depth - 1].step != PathStep::Element
        {
            return false;
        }
        let prefix = &self.containers[1..depth - 2];
        if prefix.len() == 1 && prefix[0].step == PathStep::Params {
            return true;
        }
        THREAD_ITEM_PATHS.iter().any(|path| {
            prefix
                .iter()
                .map(|container| container.step)
                .eq(path.iter().copied())
        })
    }

    fn clear_pending_for_non_string_value(&mut self) {
        self.pending_path_key = PathStep::Opaque;
        let depth = self.containers.len();
        if self.pending_id_depth == Some(depth) {
            self.pending_id_depth = None;
        }
        if self.pending_method_depth == Some(depth) {
            self.pending_method_depth = None;
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
        self.pending_path_key = PathStep::Opaque;
        self.pending_id_depth = None;
        self.pending_method_depth = None;
        self.active_id.take();
        self.active_method.take();
        self.remote_response_id.take();
        self.notification_method.take();
        for descriptor in self.created_outputs.drain(..) {
            self.store.discard_new_output(&descriptor);
        }
    }

    fn finish_active_id(&mut self) {
        let Some(id) = self
            .active_id
            .take()
            .and_then(BoundedStringCollector::finish)
        else {
            return;
        };
        if self
            .remote_id_prefix
            .as_ref()
            .is_some_and(|prefix| id.starts_with(prefix))
        {
            self.remote_response_id = Some(id);
        }
    }

    fn finish_active_method(&mut self) {
        let Some(method) = self.active_method.take() else {
            return;
        };
        if self.remote_id_prefix.is_some() {
            self.notification_method = method.finish();
        }
    }
}

fn is_remote_notification(method: &str) -> bool {
    matches!(
        method,
        "turn/started"
            | "turn/completed"
            | "item/started"
            | "item/completed"
            | "thread/status/changed"
            | "thread/name/updated"
            | "thread/archived"
            | "thread/unarchived"
            | "thread/reverted"
            | "error"
    )
}

struct ActiveOutput<'a> {
    decoder: JsonStringDecoder,
    spool: OutputSpool<'a>,
    file_diff_metrics: Option<FileDiffMetrics>,
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

    fn finish(self) -> Option<Vec<u8>> {
        (self.decoder.finish().is_ok() && !self.overflow).then_some(self.decoded)
    }
}

struct BoundedStringCollector {
    decoder: JsonStringDecoder,
    decoded: Vec<u8>,
    max_bytes: usize,
    overflow: bool,
}

impl BoundedStringCollector {
    fn new(max_bytes: usize) -> Self {
        Self {
            decoder: JsonStringDecoder::default(),
            decoded: Vec::new(),
            max_bytes,
            overflow: false,
        }
    }

    fn feed(&mut self, bytes: &[u8]) -> io::Result<()> {
        let decoded = &mut self.decoded;
        let overflow = &mut self.overflow;
        let max_bytes = self.max_bytes;
        self.decoder.feed(bytes, |fragment| {
            if decoded.len() + fragment.len() <= max_bytes {
                decoded.extend_from_slice(fragment);
            } else {
                *overflow = true;
            }
            Ok(())
        })
    }

    fn finish(self) -> Option<String> {
        if self.decoder.finish().is_err() || self.overflow {
            return None;
        }
        String::from_utf8(self.decoded).ok()
    }
}

fn invalid_data(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

#[cfg(test)]
mod tests {
    use super::*;
    use serde_json::Value;
    use std::fs;
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
                2 * 1024 * 1024,
                1024,
                Duration::from_secs(60),
            )
            .unwrap();
            Self { _temp: temp, store }
        }

        fn transform(&self, input: &[u8], chunk_size: usize) -> io::Result<Vec<u8>> {
            let mut transformer =
                Transformer::new(&self.store, Some("codex-remote:session:".to_owned()));
            let mut output = Vec::new();
            let mut ignore_remote = |_| Ok(());
            for chunk in input.chunks(chunk_size) {
                transformer.push(chunk, &mut output, &mut ignore_remote)?;
            }
            transformer.finish(&mut output, &mut ignore_remote)?;
            Ok(output)
        }

        fn transform_with_remote(
            &self,
            input: &[u8],
            chunk_size: usize,
        ) -> io::Result<(Vec<u8>, Vec<AppServerRemoteObservation>)> {
            let mut transformer =
                Transformer::new(&self.store, Some("codex-remote:session:".to_owned()));
            let mut output = Vec::new();
            let mut remote = Vec::new();
            {
                let mut collect_remote = |response| {
                    remote.push(response);
                    Ok(())
                };
                for chunk in input.chunks(chunk_size) {
                    transformer.push(chunk, &mut output, &mut collect_remote)?;
                }
                transformer.finish(&mut output, &mut collect_remote)?;
            }
            Ok((output, remote))
        }
    }

    fn transformed_item(output: &[u8]) -> Value {
        let line = std::str::from_utf8(output).unwrap().trim();
        serde_json::from_str::<Value>(line).unwrap()["result"]["data"][0]["item"].clone()
    }

    #[test]
    fn spools_file_diffs_at_typed_item_paths_without_changing_kind_or_path() {
        use serde_json::json;
        let fixture = Fixture::new(1024, 4096);
        let content = "- bullet\r\n+literal\r\n\r\n";
        let item = || {
            json!({"type":"fileChange", "id":"i", "status":"completed", "changes":[{
                "diff":content, "kind":{"type":"add"}, "path":"/project/notes.md"
            }]})
        };
        for (value, path) in [
            (json!({"params":{"item":item()}}), "/params/item"),
            (
                json!({"params":{"turn":{"items":[item()]}}}),
                "/params/turn/items/0",
            ),
            (
                json!({"params":{"thread":{"turns":[{"items":[item()]}]}}}),
                "/params/thread/turns/0/items/0",
            ),
            (
                json!({"result":{"data":[{"item":item()}]}}),
                "/result/data/0/item",
            ),
            (
                json!({"result":{"data":[{"items":[item()]}]}}),
                "/result/data/0/items/0",
            ),
            (
                json!({"result":{"data":[{"turns":[{"items":[item()]}]}]}}),
                "/result/data/0/turns/0/items/0",
            ),
            (
                json!({"result":{"data":[{"thread":{"turns":[{"items":[item()]}]}}]}}),
                "/result/data/0/thread/turns/0/items/0",
            ),
            (
                json!({"result":{"turn":{"items":[item()]}}}),
                "/result/turn/items/0",
            ),
            (
                json!({"result":{"thread":{"turns":[{"items":[item()]}]}}}),
                "/result/thread/turns/0/items/0",
            ),
            (
                json!({"result":{"initialTurnsPage":{"data":[{"items":[item()]}]}}}),
                "/result/initialTurnsPage/data/0/items/0",
            ),
        ] {
            let input = serde_json::to_vec(&value).unwrap();
            for size in [1, 17, input.len()] {
                let output = fixture.transform(&input, size).unwrap();
                let parsed: Value = serde_json::from_slice(&output).unwrap();
                let change = parsed.pointer(&format!("{path}/changes/0")).unwrap();
                assert_eq!(change["diff"], "");
                assert_eq!(change["kind"]["type"], "add");
                assert_eq!(change["path"], "/project/notes.md");
                let descriptor = &change["_codexNativeFileDiff"];
                assert_eq!(
                    descriptor["lineStats"],
                    json!({"contentLines":3,"additions":1,"deletions":1})
                );
                let stored = fixture
                    .store
                    .read_range(descriptor["ref"].as_str().unwrap(), 0, 1024)
                    .unwrap();
                assert_eq!(stored.bytes, content.as_bytes());
            }
        }
        // All paths/fragments point to the same content-addressed object.
        assert_eq!(fixture.store.stored_output_count(), 1);
    }

    #[test]
    fn patch_updated_escaped_hunks_work_with_method_and_kind_after_diff() {
        let fixture = Fixture::new(1024, 4096);
        let input = br#"{"params":{"changes":[{"diff":"--- a/f\n+++ b/f\n@@ -1 +1 @@\n\u002d\u002dold\n\u002b\u002bnew\n","kind":{"type":"update","move_path":null},"path":"f"}],"threadId":"t","turnId":"u","itemId":"i"},"method":"item/fileChange/patchUpdated"}
"#;
        for size in 1..=input.len() {
            let output = fixture.transform(input, size).unwrap();
            let parsed: Value = serde_json::from_slice(&output).unwrap();
            let change = &parsed["params"]["changes"][0];
            assert_eq!(change["diff"], "");
            assert_eq!(
                change["_codexNativeFileDiff"]["lineStats"],
                serde_json::json!({"contentLines":5,"additions":1,"deletions":1})
            );
        }
    }

    #[test]
    fn file_spooling_preserves_aggregate_approval_and_opaque_tool_payloads() {
        let fixture = Fixture::new(1024, 4096);
        let input = br#"{"method":"turn/diff/updated","params":{"diff":"aggregate remains unchanged"}}
{"method":"applyPatchApproval","params":{"fileChanges":{"f":{"type":"update","unified_diff":"approval body"}}}}
{"method":"item/completed","params":{"item":{"type":"mcpToolCall","arguments":{"changes":[{"diff":"argument"}]},"result":{"structuredContent":{"changes":[{"diff":"result"}]}}}}}
"#;
        for size in [1, 19, input.len()] {
            assert_eq!(fixture.transform(input, size).unwrap(), input);
        }
        assert_eq!(fixture.store.stored_output_count(), 0);
    }

    #[test]
    fn large_file_body_is_spooled_before_forward_limit_and_remote_capture() {
        let fixture = Fixture::new(64, 1024);
        let lines = 3 * 1024 * 1024;
        let input = serde_json::to_vec(&serde_json::json!({
            "id":"codex-remote:session:1",
            "result":{"data":[{"item":{"type":"fileChange","changes":[{
                "diff":"-a\n".repeat(lines),"kind":{"type":"add"},"path":"large.md"
            }]}}]}
        }))
        .unwrap();
        assert!(input.len() > 8 * 1024 * 1024);
        let (output, remote) = fixture.transform_with_remote(&input, 16 * 1024).unwrap();
        assert!(output.is_empty());
        let AppServerRemoteObservation::Response(response) = &remote[0] else {
            panic!("response expected")
        };
        let payload = response.payload.as_ref().unwrap();
        assert!(payload.len() < 1024);
        let parsed: Value = serde_json::from_slice(payload).unwrap();
        let change = &parsed["result"]["data"][0]["item"]["changes"][0];
        assert_eq!(change["diff"], "");
        let descriptor = &change["_codexNativeFileDiff"];
        assert_eq!(descriptor["bytes"], (lines * 3) as u64);
        assert_eq!(descriptor["storedBytes"], 64);
        assert_eq!(descriptor["truncated"], true);
        assert_eq!(descriptor["lineStats"]["contentLines"], lines as u64);
        assert_eq!(fixture.store.stored_bytes(), 64);
    }

    #[test]
    fn malformed_file_candidate_rolls_back_its_new_output() {
        let fixture = Fixture::new(1024, 4096);
        let input = br#"{"result":{"data":[{"item":{"type":"fileChange","changes":[{"diff":"temporary","kind":{"type":"add"},"invalid":]}}]}}
"#;
        assert!(fixture.transform(input, 1).is_err());
        assert_eq!(fixture.store.stored_output_count(), 0);
        assert_eq!(fixture.store.stored_bytes(), 0);
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
    fn preserves_opaque_mcp_result_and_argument_objects() {
        let fixture = Fixture::new(1024, 4096);
        let input = br#"{"id":1,"result":{"structuredContent":{"nested":{"aggregatedOutput":"mcp value","type":"commandExecution"}}}}
{"method":"item/completed","params":{"item":{"id":"m","type":"mcpToolCall","arguments":{"aggregatedOutput":"arg"},"result":{"structuredContent":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"fake command"}}]}}}}}
"#;
        for chunk_size in [1, 7, input.len()] {
            assert_eq!(
                fixture.transform(input, chunk_size).unwrap(),
                input,
                "chunk={chunk_size}",
            );
        }
        assert_eq!(fixture.store.stored_bytes(), 0);
        assert_eq!(fixture.store.stored_output_count(), 0);
    }

    #[test]
    fn spools_direct_command_output_at_each_supported_path_in_any_key_order() {
        use serde_json::json;

        let fixture = Fixture::new(1024, 4096);
        let command = || json!({"aggregatedOutput": "output", "type": "commandExecution"});
        let cases = [
            (
                json!({"method":"item/completed","params":{"item":command()}}),
                "/params/item",
            ),
            (
                json!({"method":"turn/completed","params":{"turn":{"items":[command()]}}}),
                "/params/turn/items/0",
            ),
            (
                json!({"method":"thread/started","params":{"thread":{"turns":[{"items":[command()]}]}}}),
                "/params/thread/turns/0/items/0",
            ),
            (
                json!({"id":1,"result":{"data":[{"item":command()}]}}),
                "/result/data/0/item",
            ),
            (
                json!({"id":1,"result":{"data":[{"items":[command()]}]}}),
                "/result/data/0/items/0",
            ),
            (
                json!({"id":1,"result":{"data":[{"turns":[{"items":[command()]}]}]}}),
                "/result/data/0/turns/0/items/0",
            ),
            (
                json!({"id":1,"result":{"data":[{"thread":{"turns":[{"items":[command()]}]}}]}}),
                "/result/data/0/thread/turns/0/items/0",
            ),
            (
                json!({"id":1,"result":{"turn":{"items":[command()]}}}),
                "/result/turn/items/0",
            ),
            (
                json!({"id":1,"result":{"thread":{"turns":[{"items":[command()]}]}}}),
                "/result/thread/turns/0/items/0",
            ),
            (
                json!({"id":1,"result":{"initialTurnsPage":{"data":[{"items":[command()]}]}}}),
                "/result/initialTurnsPage/data/0/items/0",
            ),
        ];
        for (message, path) in cases {
            let input = message.to_string();
            assert!(input.find("aggregatedOutput").unwrap() < input.find("type").unwrap());
            let output = fixture.transform(input.as_bytes(), 3).unwrap();
            let value: Value = serde_json::from_slice(&output).unwrap();
            let item = value.pointer(path).unwrap();
            assert!(item["aggregatedOutput"].is_null(), "{path}");
            assert_eq!(item["type"], "commandExecution");
            assert_eq!(item["_codexNativeOutput"]["bytes"], 6, "{path}");
        }
        assert_eq!(fixture.store.stored_output_count(), 1);
    }

    #[test]
    fn handles_multiple_messages_nested_keys_and_non_string_values() {
        let fixture = Fixture::new(1024, 4096);
        let input =
            br#"{"id":1,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":null}},{"item":{"type":"mcpToolCall","arguments":{"aggregatedOutput":"one"}}}]}}
{"method":"item/completed","params":{"item":{"type":"commandExecution","aggregatedOutput":"two"}}}
"#;
        let output = fixture.transform(input, 7).unwrap();
        let lines = std::str::from_utf8(&output)
            .unwrap()
            .lines()
            .collect::<Vec<_>>();
        assert_eq!(lines.len(), 2);
        let first: Value = serde_json::from_str(lines[0]).unwrap();
        let second: Value = serde_json::from_str(lines[1]).unwrap();
        let command = &first["result"]["data"][0]["item"];
        assert!(command["aggregatedOutput"].is_null());
        assert!(command.get("_codexNativeOutput").is_none());
        let arguments = &first["result"]["data"][1]["item"]["arguments"];
        assert_eq!(arguments["aggregatedOutput"], "one");
        assert!(arguments.get("_codexNativeOutput").is_none());
        assert_eq!(second["params"]["item"]["_codexNativeOutput"]["bytes"], 3);
    }

    #[test]
    fn reuses_one_spool_for_repeated_complete_output_messages() {
        let fixture = Fixture::new(1024, 4096);
        let input = br#"{"id":1,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"repeat"}}]}}
{"id":2,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"repeat"}}]}}
"#;
        let output = fixture.transform(input, 3).unwrap();
        let messages = std::str::from_utf8(&output)
            .unwrap()
            .lines()
            .map(|line| serde_json::from_str::<Value>(line).unwrap())
            .collect::<Vec<_>>();

        assert_eq!(messages.len(), 2);
        assert_eq!(
            messages[0]["result"]["data"][0]["item"]["_codexNativeOutput"]["ref"],
            messages[1]["result"]["data"][0]["item"]["_codexNativeOutput"]["ref"]
        );
        assert_eq!(fixture.store.stored_bytes(), 6);
        assert_eq!(fixture.store.stored_output_count(), 1);
    }

    #[test]
    fn rolls_back_a_finished_output_when_the_json_candidate_is_invalid() {
        let fixture = Fixture::new(1024, 4096);
        let input = br#"{"id":1,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"temporary","invalid":]}}]}}
"#;

        assert!(fixture.transform(input, 2).is_err());
        assert_eq!(fixture.store.stored_bytes(), 0);
        assert_eq!(fixture.store.stored_output_count(), 0);
        assert_eq!(
            fs::read_dir(fixture.store.session_path())
                .unwrap()
                .filter_map(Result::ok)
                .filter(|entry| {
                    matches!(
                        entry.path().extension().and_then(|value| value.to_str()),
                        Some("data" | "json" | "part")
                    )
                })
                .count(),
            0
        );
    }

    #[test]
    fn invalid_duplicate_candidate_does_not_remove_a_prior_valid_output() {
        let fixture = Fixture::new(1024, 4096);
        let valid = fixture
            .transform(
                br#"{"id":1,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"durable"}}]}}
"#,
                2,
            )
            .unwrap();
        let output_ref = transformed_item(&valid)["_codexNativeOutput"]["ref"]
            .as_str()
            .unwrap()
            .to_owned();

        assert!(
            fixture
                .transform(
                    br#"{"id":2,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"durable","invalid":]}}]}}
"#,
                    2,
                )
                .is_err()
        );
        assert_eq!(fixture.store.stored_bytes(), 7);
        assert_eq!(fixture.store.stored_output_count(), 1);
        assert_eq!(
            fixture.store.read_range(&output_ref, 0, 7).unwrap().bytes,
            b"durable"
        );
    }

    #[test]
    fn rolls_back_an_undelivered_remote_response_when_the_observer_fails() {
        let fixture = Fixture::new(1024, 4096);
        let input = br#"{"id":"codex-remote:session:1","result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"temporary"}}]}}
"#;
        let mut transformer =
            Transformer::new(&fixture.store, Some("codex-remote:session:".to_owned()));
        let mut output = Vec::new();
        let mut fail_remote = |_| Err(io::Error::other("remote observer failed"));

        assert!(
            transformer
                .push(input, &mut output, &mut fail_remote)
                .is_err()
        );
        assert!(output.is_empty());
        assert_eq!(fixture.store.stored_bytes(), 0);
        assert_eq!(fixture.store.stored_output_count(), 0);
    }

    #[test]
    fn keeps_output_after_local_notification_delivery_if_remote_observation_fails() {
        let fixture = Fixture::new(1024, 4096);
        let input =
            br#"{"method":"item/completed","params":{"item":{"type":"commandExecution","aggregatedOutput":"durable"}}}
"#;
        let mut transformer =
            Transformer::new(&fixture.store, Some("codex-remote:session:".to_owned()));
        let mut output = Vec::new();
        let mut fail_remote = |_| Err(io::Error::other("remote observer failed"));

        assert!(
            transformer
                .push(input, &mut output, &mut fail_remote)
                .is_err()
        );
        let forwarded: Value = serde_json::from_slice(&output).unwrap();
        let descriptor = &forwarded["params"]["item"]["_codexNativeOutput"];
        let output_ref = descriptor["ref"].as_str().unwrap();
        assert_eq!(fixture.store.stored_bytes(), 7);
        assert_eq!(fixture.store.stored_output_count(), 1);
        assert_eq!(
            fixture.store.read_range(output_ref, 0, 7).unwrap().bytes,
            b"durable"
        );
    }

    #[test]
    fn suppresses_only_top_level_reserved_responses_after_sanitizing_them() {
        let fixture = Fixture::new(1024, 4096);
        let input = br#"{"id":1,"result":{"value":"desktop"}}
{"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"secret output"}}]},"id":"codex-remote:session:1"}
{"method":"event","params":{"id":"codex-remote:not-a-top-level-response"}}
{"id":"codex-remote:other-session:1","result":{"value":"not ours"}}
"#;
        let (output, remote) = fixture.transform_with_remote(input, 5).unwrap();
        let forwarded = std::str::from_utf8(&output)
            .unwrap()
            .lines()
            .collect::<Vec<_>>();
        assert_eq!(forwarded.len(), 3);
        assert_eq!(
            serde_json::from_str::<Value>(forwarded[0]).unwrap()["id"],
            1
        );
        assert_eq!(
            serde_json::from_str::<Value>(forwarded[1]).unwrap()["method"],
            "event"
        );
        assert_eq!(
            serde_json::from_str::<Value>(forwarded[2]).unwrap()["id"],
            "codex-remote:other-session:1"
        );
        assert_eq!(remote.len(), 1);
        let AppServerRemoteObservation::Response(response) = &remote[0] else {
            panic!("expected a Remote response observation");
        };
        assert_eq!(response.host_id, "codex-remote:session:1");
        let captured: Value = serde_json::from_slice(response.payload.as_ref().unwrap()).unwrap();
        let item = &captured["result"]["data"][0]["item"];
        assert!(item["aggregatedOutput"].is_null());
        assert_eq!(item["_codexNativeOutput"]["bytes"], 13);
        assert!(
            !String::from_utf8_lossy(response.payload.as_ref().unwrap()).contains("secret output")
        );
    }

    #[test]
    fn reports_an_oversized_remote_response_without_forwarding_or_materializing_it() {
        let fixture = Fixture::new(1024, 4096);
        let input = serde_json::to_vec(&serde_json::json!({
            "id": "codex-remote:session:2",
            "result": {"data": [{"item": {
                "type": "mcpToolCall",
                "arguments": {"aggregatedOutput": "x".repeat(MAX_REMOTE_RESPONSE_BYTES)},
            }}]},
        }))
        .unwrap();
        let (output, remote) = fixture.transform_with_remote(&input, 8192).unwrap();
        assert!(output.is_empty());
        assert_eq!(remote.len(), 1);
        let AppServerRemoteObservation::Response(response) = &remote[0] else {
            panic!("expected a Remote response observation");
        };
        assert!(response.payload.is_none());
        assert!(response.total_bytes > MAX_REMOTE_RESPONSE_BYTES as u64);
    }

    #[test]
    fn captures_only_allowlisted_notifications_after_sanitizing_desktop_output() {
        let fixture = Fixture::new(1024, 4096);
        let input =
            br#"{"method":"item/completed","params":{"item":{"type":"commandExecution","aggregatedOutput":"secret output"}}}
{"method":"item/completed","id":7,"params":{"request":"not an event"}}
{"method":"item/agentMessage/delta","params":{"delta":"token"}}
"#;
        let (output, remote) = fixture.transform_with_remote(input, 3).unwrap();
        assert_eq!(std::str::from_utf8(&output).unwrap().lines().count(), 3);
        assert_eq!(remote.len(), 1);
        let AppServerRemoteObservation::Notification(notification) = &remote[0] else {
            panic!("expected a Remote notification observation");
        };
        assert_eq!(notification.method, "item/completed");
        let captured: Value =
            serde_json::from_slice(notification.payload.as_ref().unwrap()).unwrap();
        assert!(captured["params"]["item"]["aggregatedOutput"].is_null());
        assert_eq!(
            captured["params"]["item"]["_codexNativeOutput"]["bytes"],
            13
        );
        assert!(
            !String::from_utf8_lossy(notification.payload.as_ref().unwrap())
                .contains("secret output")
        );
    }

    #[test]
    fn reports_an_oversized_notification_without_materializing_it_for_remote() {
        let fixture = Fixture::new(1024, 4096);
        let input = serde_json::to_vec(&serde_json::json!({
            "method": "turn/completed",
            "params": {"padding": "x".repeat(MAX_REMOTE_NOTIFICATION_BYTES)},
        }))
        .unwrap();
        let (output, remote) = fixture.transform_with_remote(&input, 8192).unwrap();
        assert_eq!(output.len(), input.len() + 1);
        assert_eq!(&output[..input.len()], input);
        assert_eq!(output.last(), Some(&b'\n'));
        assert_eq!(remote.len(), 1);
        let AppServerRemoteObservation::Notification(notification) = &remote[0] else {
            panic!("expected a Remote notification observation");
        };
        assert_eq!(notification.method, "turn/completed");
        assert!(notification.payload.is_none());
        assert!(notification.total_bytes > MAX_REMOTE_NOTIFICATION_BYTES as u64);
    }

    #[test]
    fn recognizes_an_escaped_target_key() {
        let fixture = Fixture::new(1024, 4096);
        let output = fixture
            .transform(
                br#"{"id":1,"res\u0075lt":{"data":[{"item":{"type":"commandExecution","aggregated\u004futput":"data"}}]}}
"#,
                1,
            )
            .unwrap();
        let value = transformed_item(&output);
        assert!(value["aggregatedOutput"].is_null());
        assert_eq!(value["_codexNativeOutput"]["bytes"], 4);
    }

    #[test]
    fn truncates_spool_but_never_reinjects_large_content() {
        let fixture = Fixture::new(4, 4);
        let output = fixture
            .transform(
                br#"{"id":1,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"0123456789"}}]}}
"#,
                3,
            )
            .unwrap();
        assert!(!std::str::from_utf8(&output).unwrap().contains("0123456789"));
        let value = transformed_item(&output);
        assert_eq!(value["_codexNativeOutput"]["bytes"], 10);
        assert_eq!(value["_codexNativeOutput"]["storedBytes"], 4);
        assert_eq!(value["_codexNativeOutput"]["truncated"], true);
    }

    #[test]
    fn rejects_malformed_truncated_junk_and_missing_newline() {
        let fixture = Fixture::new(1024, 4096);
        for invalid in [
            br#"{"id":1,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"unterminated"#.as_slice(),
            b"not-json\n",
            b"{}{}\n",
            br#"{"id":1,"result":{"data":[{"item":{"type":"commandExecution","aggregatedOutput":"\ud83d"}}]}}
"#,
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
