use fs2::FileExt;
use serde_json::Value;
use std::fs::{self, File, OpenOptions};
use std::io::{self, Read, Seek, SeekFrom, Write};
use std::path::{Path, PathBuf};
use std::sync::atomic::{AtomicU64, Ordering};
use std::time::{Duration, SystemTime, UNIX_EPOCH};
use uuid::Uuid;

const SESSION_PREFIX: &str = "session-";
const METADATA_SUFFIX: &str = ".json";
const DATA_SUFFIX: &str = ".data";
const PART_SUFFIX: &str = ".part";

#[derive(Clone, Debug, Eq, PartialEq)]
pub(crate) struct OutputDescriptor {
    pub(crate) output_ref: Option<String>,
    pub(crate) bytes: u64,
    pub(crate) stored_bytes: u64,
    pub(crate) truncated: bool,
    pub(crate) available: bool,
}

impl OutputDescriptor {
    pub(crate) fn to_wire_value(&self) -> Value {
        serde_json::json!({
            "ref": self.output_ref,
            "bytes": self.bytes,
            "storedBytes": self.stored_bytes,
            "truncated": self.truncated,
            "available": self.available,
        })
    }
}

#[derive(Debug)]
pub(crate) struct OutputStat {
    pub(crate) output_ref: String,
    pub(crate) bytes: u64,
    pub(crate) stored_bytes: u64,
    pub(crate) truncated: bool,
}

#[derive(Debug)]
pub(crate) struct OutputChunk {
    pub(crate) output_ref: String,
    pub(crate) offset: u64,
    pub(crate) bytes: Vec<u8>,
    pub(crate) total_bytes: u64,
    pub(crate) stored_bytes: u64,
    pub(crate) truncated: bool,
    pub(crate) eof: bool,
}

#[derive(Debug)]
pub(crate) struct SpoolStore {
    session: PathBuf,
    _session_lock: File,
    max_output_bytes: u64,
    max_session_bytes: u64,
    max_forward_message_bytes: u64,
    max_read_bytes: usize,
    stored_bytes: AtomicU64,
}

impl SpoolStore {
    pub(crate) fn open(
        root: PathBuf,
        max_output_bytes: u64,
        max_session_bytes: u64,
        max_forward_message_bytes: u64,
        max_read_bytes: usize,
        stale_age: Duration,
    ) -> io::Result<Self> {
        if max_output_bytes == 0
            || max_session_bytes == 0
            || max_forward_message_bytes == 0
            || max_read_bytes == 0
        {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "spool limits must be positive",
            ));
        }
        create_private_dir(&root)?;
        cleanup_inactive_sessions(&root, stale_age, max_session_bytes)?;

        let timestamp = SystemTime::now()
            .duration_since(UNIX_EPOCH)
            .unwrap_or_default()
            .as_secs();
        let session = root.join(format!(
            "{SESSION_PREFIX}{timestamp}-{}",
            Uuid::new_v4().simple()
        ));
        create_private_dir(&session)?;
        let session_lock = open_private_file(&session.join(".lock"), true)?;
        session_lock.lock_exclusive()?;

        Ok(Self {
            session,
            _session_lock: session_lock,
            max_output_bytes,
            max_session_bytes,
            max_forward_message_bytes,
            max_read_bytes,
            stored_bytes: AtomicU64::new(0),
        })
    }

    pub(crate) fn max_output_bytes(&self) -> u64 {
        self.max_output_bytes
    }

    pub(crate) fn max_session_bytes(&self) -> u64 {
        self.max_session_bytes
    }

    pub(crate) fn max_read_bytes(&self) -> usize {
        self.max_read_bytes
    }

    pub(crate) fn start_output(&self) -> OutputSpool<'_> {
        let output_ref = Uuid::new_v4().simple().to_string();
        let part_path = self
            .session
            .join(format!("{output_ref}{DATA_SUFFIX}{PART_SUFFIX}"));
        let file = open_private_file(&part_path, true).ok();
        OutputSpool {
            store: self,
            output_ref,
            part_path,
            file,
            bytes: 0,
            stored_bytes: 0,
            truncated: false,
            failed: false,
            finalized: false,
        }
    }

    pub(crate) fn start_candidate(&self) -> io::Result<CandidateFile> {
        let id = Uuid::new_v4().simple().to_string();
        let path = self.session.join(format!("message-{id}{PART_SUFFIX}"));
        let file = open_private_file(&path, true)?;
        Ok(CandidateFile {
            path,
            file,
            bytes: 0,
            max_bytes: self.max_forward_message_bytes,
            finished: false,
        })
    }

    pub(crate) fn stat(&self, output_ref: &str) -> io::Result<OutputStat> {
        validate_ref(output_ref)?;
        let metadata = read_metadata(&self.metadata_path(output_ref))?;
        let stored_size = fs::metadata(self.data_path(output_ref))?.len();
        if stored_size != metadata.stored_bytes {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "output metadata does not match stored data",
            ));
        }
        Ok(OutputStat {
            output_ref: output_ref.to_owned(),
            bytes: metadata.bytes,
            stored_bytes: metadata.stored_bytes,
            truncated: metadata.truncated,
        })
    }

    pub(crate) fn read_range(
        &self,
        output_ref: &str,
        offset: u64,
        length: usize,
    ) -> io::Result<OutputChunk> {
        if length == 0 || length > self.max_read_bytes {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                format!("length must be between 1 and {} bytes", self.max_read_bytes),
            ));
        }
        let stat = self.stat(output_ref)?;
        if offset > stat.stored_bytes {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "offset exceeds stored output",
            ));
        }
        let available = stat.stored_bytes.saturating_sub(offset);
        let count = available.min(length as u64) as usize;
        let mut bytes = vec![0_u8; count];
        let mut file = File::open(self.data_path(output_ref))?;
        file.seek(SeekFrom::Start(offset))?;
        file.read_exact(&mut bytes)?;
        Ok(OutputChunk {
            output_ref: output_ref.to_owned(),
            offset,
            bytes,
            total_bytes: stat.bytes,
            stored_bytes: stat.stored_bytes,
            truncated: stat.truncated,
            eof: offset + count as u64 >= stat.stored_bytes,
        })
    }

    pub(crate) fn tail(&self, output_ref: &str, length: usize) -> io::Result<OutputChunk> {
        let stat = self.stat(output_ref)?;
        let offset = stat
            .stored_bytes
            .saturating_sub(length.min(self.max_read_bytes) as u64);
        self.read_range(output_ref, offset, length.min(self.max_read_bytes).max(1))
    }

    pub(crate) fn cleanup(self) -> io::Result<()> {
        let session = self.session.clone();
        drop(self);
        match fs::remove_dir_all(session) {
            Ok(()) => Ok(()),
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
            Err(error) => Err(error),
        }
    }

    #[cfg(test)]
    pub(crate) fn session_path(&self) -> &Path {
        &self.session
    }

    #[cfg(test)]
    pub(crate) fn stored_bytes(&self) -> u64 {
        self.stored_bytes.load(Ordering::Relaxed)
    }

    fn data_path(&self, output_ref: &str) -> PathBuf {
        self.session.join(format!("{output_ref}{DATA_SUFFIX}"))
    }

    fn metadata_path(&self, output_ref: &str) -> PathBuf {
        self.session.join(format!("{output_ref}{METADATA_SUFFIX}"))
    }
}

pub(crate) struct OutputSpool<'a> {
    store: &'a SpoolStore,
    output_ref: String,
    part_path: PathBuf,
    file: Option<File>,
    bytes: u64,
    stored_bytes: u64,
    truncated: bool,
    failed: bool,
    finalized: bool,
}

impl OutputSpool<'_> {
    pub(crate) fn write_decoded(&mut self, bytes: &[u8]) -> io::Result<()> {
        self.bytes = self
            .bytes
            .checked_add(bytes.len() as u64)
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "output size overflow"))?;
        if self.failed {
            self.truncated = true;
            return Ok(());
        }

        let output_remaining = self.max_output_remaining();
        let session_used = self.store.stored_bytes.load(Ordering::Relaxed);
        let session_remaining = self.store.max_session_bytes.saturating_sub(session_used);
        let allowed = (bytes.len() as u64)
            .min(output_remaining)
            .min(session_remaining) as usize;

        if allowed > 0 {
            let result = self
                .file
                .as_mut()
                .ok_or_else(|| io::Error::other("output spool is unavailable"))
                .and_then(|file| file.write_all(&bytes[..allowed]));
            if result.is_err() {
                self.fail_storage();
                return Ok(());
            }
            self.stored_bytes += allowed as u64;
            self.store
                .stored_bytes
                .fetch_add(allowed as u64, Ordering::Relaxed);
        }
        if allowed < bytes.len() {
            self.truncated = true;
        }
        Ok(())
    }

    pub(crate) fn finish(mut self) -> io::Result<OutputDescriptor> {
        if self.failed || self.file.is_none() {
            self.fail_storage();
            self.finalized = true;
            return Ok(self.unavailable_descriptor());
        }

        if self.publish().is_err() {
            self.fail_storage();
            self.finalized = true;
            return Ok(self.unavailable_descriptor());
        }

        self.finalized = true;
        Ok(OutputDescriptor {
            output_ref: Some(self.output_ref.clone()),
            bytes: self.bytes,
            stored_bytes: self.stored_bytes,
            truncated: self.truncated,
            available: true,
        })
    }

    fn max_output_remaining(&self) -> u64 {
        self.store
            .max_output_bytes
            .saturating_sub(self.stored_bytes)
    }

    fn publish(&mut self) -> io::Result<()> {
        let mut file = self.file.take().expect("checked before publish");
        file.flush()?;
        drop(file);
        let data_path = self.store.data_path(&self.output_ref);
        fs::rename(&self.part_path, &data_path)?;

        let metadata_path = self.store.metadata_path(&self.output_ref);
        let metadata_part = metadata_path.with_extension("json.part");
        let mut metadata = open_private_file(&metadata_part, true)?;
        serde_json::to_writer(
            &mut metadata,
            &serde_json::json!({
                "bytes": self.bytes,
                "storedBytes": self.stored_bytes,
                "truncated": self.truncated,
            }),
        )?;
        metadata.flush()?;
        drop(metadata);
        fs::rename(metadata_part, metadata_path)
    }

    fn fail_storage(&mut self) {
        self.failed = true;
        self.truncated = true;
        self.file.take();
        self.cleanup_unpublished_files();
        self.release_unpublished_bytes();
    }

    fn cleanup_unpublished_files(&self) {
        let metadata_path = self.store.metadata_path(&self.output_ref);
        for path in [
            self.part_path.clone(),
            self.store.data_path(&self.output_ref),
            metadata_path.with_extension("json.part"),
            metadata_path,
        ] {
            let _ = fs::remove_file(path);
        }
    }

    fn release_unpublished_bytes(&mut self) {
        if self.stored_bytes > 0 {
            self.store
                .stored_bytes
                .fetch_sub(self.stored_bytes, Ordering::Relaxed);
            self.stored_bytes = 0;
        }
    }

    fn unavailable_descriptor(&self) -> OutputDescriptor {
        OutputDescriptor {
            output_ref: None,
            bytes: self.bytes,
            stored_bytes: 0,
            truncated: true,
            available: false,
        }
    }
}

impl Drop for OutputSpool<'_> {
    fn drop(&mut self) {
        if !self.finalized {
            self.fail_storage();
        }
    }
}

pub(crate) struct CandidateFile {
    path: PathBuf,
    file: File,
    bytes: u64,
    max_bytes: u64,
    finished: bool,
}

pub(crate) struct CandidateCapture {
    pub(crate) payload: Option<Vec<u8>>,
    pub(crate) total_bytes: u64,
}

impl CandidateFile {
    pub(crate) fn publish_to(mut self, output: &mut impl Write) -> io::Result<()> {
        self.file.flush()?;
        self.file.seek(SeekFrom::Start(0))?;
        io::copy(&mut self.file, output)?;
        output.write_all(b"\n")?;
        output.flush()?;
        self.finished = true;
        fs::remove_file(&self.path)?;
        Ok(())
    }

    pub(crate) fn capture_bounded(mut self, max_bytes: usize) -> io::Result<CandidateCapture> {
        self.file.flush()?;
        let payload = if self.bytes <= max_bytes as u64 {
            self.file.seek(SeekFrom::Start(0))?;
            let mut payload = Vec::with_capacity(self.bytes as usize);
            self.file.read_to_end(&mut payload)?;
            Some(payload)
        } else {
            None
        };
        self.finished = true;
        fs::remove_file(&self.path)?;
        Ok(CandidateCapture {
            payload,
            total_bytes: self.bytes,
        })
    }
}

impl Write for CandidateFile {
    fn write(&mut self, buffer: &[u8]) -> io::Result<usize> {
        let next = self
            .bytes
            .checked_add(buffer.len() as u64)
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "message size overflow"))?;
        if next > self.max_bytes {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                format!(
                    "sanitized app-server message exceeds {} bytes",
                    self.max_bytes
                ),
            ));
        }
        let written = self.file.write(buffer)?;
        self.bytes += written as u64;
        Ok(written)
    }

    fn flush(&mut self) -> io::Result<()> {
        self.file.flush()
    }
}

impl Drop for CandidateFile {
    fn drop(&mut self) {
        if !self.finished {
            let _ = fs::remove_file(&self.path);
        }
    }
}

#[derive(Debug)]
struct StoredMetadata {
    bytes: u64,
    stored_bytes: u64,
    truncated: bool,
}

fn read_metadata(path: &Path) -> io::Result<StoredMetadata> {
    let value: Value = serde_json::from_reader(File::open(path)?)?;
    let field = |name| {
        value
            .get(name)
            .and_then(Value::as_u64)
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "invalid output metadata"))
    };
    Ok(StoredMetadata {
        bytes: field("bytes")?,
        stored_bytes: field("storedBytes")?,
        truncated: value
            .get("truncated")
            .and_then(Value::as_bool)
            .ok_or_else(|| io::Error::new(io::ErrorKind::InvalidData, "invalid output metadata"))?,
    })
}

fn validate_ref(output_ref: &str) -> io::Result<()> {
    if output_ref.len() == 32 && output_ref.bytes().all(|byte| byte.is_ascii_hexdigit()) {
        Ok(())
    } else {
        Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "invalid output reference",
        ))
    }
}

fn cleanup_inactive_sessions(root: &Path, stale_age: Duration, cap: u64) -> io::Result<()> {
    let now = SystemTime::now();
    let mut inactive = Vec::new();
    let mut total = 0_u64;
    for entry in fs::read_dir(root)? {
        let entry = match entry {
            Ok(entry) => entry,
            Err(_) => continue,
        };
        let path = entry.path();
        if !entry.file_type().is_ok_and(|kind| kind.is_dir())
            || !entry
                .file_name()
                .to_string_lossy()
                .starts_with(SESSION_PREFIX)
        {
            continue;
        }
        let lock_path = path.join(".lock");
        let lock = match open_private_file(&lock_path, false) {
            Ok(lock) => lock,
            Err(_) => continue,
        };
        if lock.try_lock_exclusive().is_err() {
            continue;
        }
        let modified = entry
            .metadata()
            .and_then(|metadata| metadata.modified())
            .unwrap_or(UNIX_EPOCH);
        let bytes = directory_size(&path).unwrap_or(0);
        if now.duration_since(modified).unwrap_or_default() >= stale_age {
            drop(lock);
            let _ = fs::remove_dir_all(&path);
            continue;
        }
        total = total.saturating_add(bytes);
        inactive.push((modified, bytes, path, lock));
    }
    inactive.sort_by_key(|entry| entry.0);
    for (_, bytes, path, lock) in inactive {
        if total <= cap {
            break;
        }
        drop(lock);
        if fs::remove_dir_all(path).is_ok() {
            total = total.saturating_sub(bytes);
        }
    }
    Ok(())
}

fn directory_size(path: &Path) -> io::Result<u64> {
    let mut total = 0_u64;
    for entry in fs::read_dir(path)? {
        let entry = entry?;
        let metadata = entry.metadata()?;
        if metadata.is_file() {
            total = total.saturating_add(metadata.len());
        } else if metadata.is_dir() {
            total = total.saturating_add(directory_size(&entry.path())?);
        }
    }
    Ok(total)
}

fn create_private_dir(path: &Path) -> io::Result<()> {
    fs::create_dir_all(path)?;
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(path, fs::Permissions::from_mode(0o700))?;
    }
    Ok(())
}

fn open_private_file(path: &Path, truncate: bool) -> io::Result<File> {
    let mut options = OpenOptions::new();
    options
        .read(true)
        .write(true)
        .create(true)
        .truncate(truncate);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(path)
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    fn store(root: &Path, max_output: u64, max_total: u64) -> SpoolStore {
        SpoolStore::open(
            root.to_owned(),
            max_output,
            max_total,
            1024 * 1024,
            64,
            Duration::from_secs(60),
        )
        .unwrap()
    }

    #[test]
    fn stores_reads_and_tails_only_by_opaque_reference() {
        let temp = TempDir::new().unwrap();
        let store = store(temp.path(), 1024, 2048);
        let mut output = store.start_output();
        output.write_decoded(b"alpha-beta-gamma").unwrap();
        let descriptor = output.finish().unwrap();
        let output_ref = descriptor.output_ref.unwrap();

        let range = store.read_range(&output_ref, 6, 4).unwrap();
        assert_eq!(range.bytes, b"beta");
        assert!(!range.eof);
        let tail = store.tail(&output_ref, 5).unwrap();
        assert_eq!(tail.bytes, b"gamma");
        assert!(tail.eof);

        assert!(store.read_range("../secret", 0, 10).is_err());
        assert!(store.read_range(&output_ref, 0, 65).is_err());
    }

    #[test]
    fn enforces_output_and_session_caps_without_failing_ingestion() {
        let temp = TempDir::new().unwrap();
        let store = store(temp.path(), 5, 7);
        let mut first = store.start_output();
        first.write_decoded(b"0123456789").unwrap();
        let first = first.finish().unwrap();
        assert_eq!(first.bytes, 10);
        assert_eq!(first.stored_bytes, 5);
        assert!(first.truncated);

        let mut second = store.start_output();
        second.write_decoded(b"abcdef").unwrap();
        let second = second.finish().unwrap();
        assert_eq!(second.bytes, 6);
        assert_eq!(second.stored_bytes, 2);
        assert!(second.truncated);
    }

    #[test]
    fn reports_an_unavailable_descriptor_when_the_spool_cannot_open() {
        let temp = TempDir::new().unwrap();
        let store = store(temp.path(), 1024, 2048);
        fs::remove_dir_all(store.session_path()).unwrap();

        let mut output = store.start_output();
        output.write_decoded(b"still-counted").unwrap();
        let descriptor = output.finish().unwrap();
        assert_eq!(descriptor.bytes, 13);
        assert_eq!(descriptor.stored_bytes, 0);
        assert!(descriptor.truncated);
        assert!(!descriptor.available);
        assert!(descriptor.output_ref.is_none());
    }

    #[test]
    fn abandoned_output_releases_its_session_budget_and_partial_file() {
        let temp = TempDir::new().unwrap();
        let store = store(temp.path(), 7, 7);
        let part_path = {
            let mut abandoned = store.start_output();
            let path = abandoned.part_path.clone();
            abandoned.write_decoded(b"12345").unwrap();
            assert_eq!(store.stored_bytes(), 5);
            path
        };
        assert_eq!(store.stored_bytes(), 0);
        assert!(!part_path.exists());

        let mut replacement = store.start_output();
        replacement.write_decoded(b"123456").unwrap();
        let descriptor = replacement.finish().unwrap();
        assert_eq!(descriptor.stored_bytes, 6);
        assert!(!descriptor.truncated);
    }

    #[test]
    fn finalization_failure_removes_published_data_and_releases_budget() {
        let temp = TempDir::new().unwrap();
        let store = store(temp.path(), 1024, 2048);
        let mut output = store.start_output();
        let output_ref = output.output_ref.clone();
        output.write_decoded(b"temporary").unwrap();
        let metadata_part = store.metadata_path(&output_ref).with_extension("json.part");
        fs::create_dir(&metadata_part).unwrap();

        let descriptor = output.finish().unwrap();
        assert!(!descriptor.available);
        assert!(descriptor.output_ref.is_none());
        assert_eq!(descriptor.stored_bytes, 0);
        assert_eq!(store.stored_bytes(), 0);
        assert!(!store.data_path(&output_ref).exists());
        assert!(
            !store
                .session_path()
                .join(format!("{output_ref}{DATA_SUFFIX}{PART_SUFFIX}"))
                .exists()
        );
        fs::remove_dir(metadata_part).unwrap();
    }

    #[cfg(target_os = "linux")]
    #[test]
    fn disk_full_write_becomes_unavailable_without_leaking_budget() {
        let temp = TempDir::new().unwrap();
        let store = store(temp.path(), 1024, 2048);
        let mut output = store.start_output();
        let part_path = output.part_path.clone();
        output.file = Some(OpenOptions::new().write(true).open("/dev/full").unwrap());

        output.write_decoded(b"cannot be persisted").unwrap();
        let descriptor = output.finish().unwrap();
        assert_eq!(descriptor.bytes, 19);
        assert_eq!(descriptor.stored_bytes, 0);
        assert!(descriptor.truncated);
        assert!(!descriptor.available);
        assert!(descriptor.output_ref.is_none());
        assert_eq!(store.stored_bytes(), 0);
        assert!(!part_path.exists());
    }

    #[test]
    fn rejects_a_cache_root_that_is_not_a_directory() {
        let temp = TempDir::new().unwrap();
        let root = temp.path().join("cache-root");
        fs::write(&root, b"not a directory").unwrap();

        let error = SpoolStore::open(root, 1024, 2048, 1024 * 1024, 64, Duration::from_secs(60))
            .expect_err("a file cannot be used as the cache root");
        assert!(matches!(
            error.kind(),
            io::ErrorKind::AlreadyExists | io::ErrorKind::NotADirectory
        ));
    }

    #[test]
    fn removes_only_inactive_stale_sessions() {
        let temp = TempDir::new().unwrap();
        let stale_path = {
            let stale = store(temp.path(), 1024, 2048);
            stale.session_path().to_owned()
        };
        assert!(stale_path.exists());

        let active = SpoolStore::open(
            temp.path().to_owned(),
            1024,
            2048,
            1024 * 1024,
            64,
            Duration::ZERO,
        )
        .unwrap();
        assert!(!stale_path.exists());
        assert!(active.session_path().exists());
    }

    #[cfg(unix)]
    #[test]
    fn creates_owner_only_session_and_output_files() {
        use std::os::unix::fs::PermissionsExt;

        let temp = TempDir::new().unwrap();
        let store = store(temp.path(), 1024, 2048);
        assert_eq!(
            fs::metadata(store.session_path())
                .unwrap()
                .permissions()
                .mode()
                & 0o777,
            0o700
        );
        let mut output = store.start_output();
        output.write_decoded(b"secret").unwrap();
        let descriptor = output.finish().unwrap();
        let data = store.data_path(descriptor.output_ref.as_deref().unwrap());
        assert_eq!(
            fs::metadata(data).unwrap().permissions().mode() & 0o777,
            0o600
        );
    }
}
