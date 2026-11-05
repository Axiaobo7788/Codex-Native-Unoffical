use base64::Engine;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::collections::{BTreeMap, BTreeSet};
use std::fmt;
use std::fs::{self, File, OpenOptions};
use std::io::{self, Write};
use std::path::{Path, PathBuf};
use subtle::ConstantTimeEq;

const FILE_VERSION: u32 = 1;
const PAIRING_RANDOM_BYTES: usize = 18;
const DEVICE_ID_BYTES: usize = 16;
const DEVICE_TOKEN_BYTES: usize = 32;
const MAX_DEVICE_NAME_CHARS: usize = 80;

#[derive(Clone, Copy, Debug, Deserialize, Eq, Ord, PartialEq, PartialOrd, Serialize)]
#[serde(rename_all = "snake_case")]
pub enum DeviceScope {
    Read,
    Write,
    ApprovalsRespond,
    DeviceRotate,
}

#[derive(Clone, Debug, Eq, PartialEq, Serialize)]
#[serde(rename_all = "camelCase")]
pub struct Device {
    pub id: String,
    pub name: String,
    pub scopes: BTreeSet<DeviceScope>,
    pub created_at_ms: u64,
    pub expires_at_ms: u64,
    pub last_seen_at_ms: Option<u64>,
    pub rotated_at_ms: Option<u64>,
    pub revoked_at_ms: Option<u64>,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct PairingTicket {
    pub code: String,
    pub expires_at_ms: u64,
}

#[derive(Clone, Debug, Eq, PartialEq)]
pub struct IssuedCredential {
    pub device: Device,
    pub token: String,
}

#[derive(Debug)]
pub enum AuthError {
    InvalidConfiguration(&'static str),
    InvalidStore(String),
    PairingUnavailable,
    PairingRejected,
    DeviceLimit,
    RotationDenied,
    Random(String),
    Io(io::Error),
}

impl fmt::Display for AuthError {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        match self {
            Self::InvalidConfiguration(message) => write!(formatter, "{message}"),
            Self::InvalidStore(message) => write!(formatter, "invalid device store: {message}"),
            Self::PairingUnavailable => write!(formatter, "no active pairing ticket"),
            Self::PairingRejected => write!(formatter, "pairing ticket is invalid or expired"),
            Self::DeviceLimit => write!(formatter, "paired-device limit reached"),
            Self::RotationDenied => write!(formatter, "device credential rotation is denied"),
            Self::Random(message) => {
                write!(formatter, "secure random generation failed: {message}")
            }
            Self::Io(error) => write!(formatter, "device store operation failed: {error}"),
        }
    }
}

impl std::error::Error for AuthError {
    fn source(&self) -> Option<&(dyn std::error::Error + 'static)> {
        match self {
            Self::Io(error) => Some(error),
            _ => None,
        }
    }
}

impl From<io::Error> for AuthError {
    fn from(error: io::Error) -> Self {
        Self::Io(error)
    }
}

#[derive(Clone, Debug)]
struct DeviceRecord {
    device: Device,
    token_digest: [u8; 32],
}

impl DeviceRecord {
    fn is_active(&self, now_ms: u64) -> bool {
        self.device.revoked_at_ms.is_none() && now_ms < self.device.expires_at_ms
    }
}

#[derive(Debug)]
pub struct DeviceRegistry {
    file_path: PathBuf,
    credential_ttl_ms: u64,
    max_devices: usize,
    devices: BTreeMap<String, DeviceRecord>,
    pairing: Option<PairingTicket>,
}

impl DeviceRegistry {
    pub fn open(
        file_path: PathBuf,
        credential_ttl_ms: u64,
        max_devices: usize,
    ) -> Result<Self, AuthError> {
        if credential_ttl_ms == 0 {
            return Err(AuthError::InvalidConfiguration(
                "device credential TTL must be positive",
            ));
        }
        if max_devices == 0 {
            return Err(AuthError::InvalidConfiguration(
                "paired-device limit must be positive",
            ));
        }
        let devices = load_store(&file_path)?;
        if devices.len() > max_devices {
            return Err(AuthError::InvalidStore(
                "stored device count exceeds the configured limit".into(),
            ));
        }
        Ok(Self {
            file_path,
            credential_ttl_ms,
            max_devices,
            devices,
            pairing: None,
        })
    }

    pub fn create_pairing_ticket(
        &mut self,
        now_ms: u64,
        ttl_ms: u64,
    ) -> Result<PairingTicket, AuthError> {
        if ttl_ms == 0 {
            return Err(AuthError::InvalidConfiguration(
                "pairing ticket TTL must be positive",
            ));
        }
        let ticket =
            PairingTicket {
                code: random_urlsafe(PAIRING_RANDOM_BYTES)?,
                expires_at_ms: now_ms.checked_add(ttl_ms).ok_or(
                    AuthError::InvalidConfiguration("pairing ticket expiry overflows"),
                )?,
            };
        self.pairing = Some(ticket.clone());
        Ok(ticket)
    }

    pub fn pair(
        &mut self,
        code: &str,
        requested_name: &str,
        scopes: BTreeSet<DeviceScope>,
        now_ms: u64,
    ) -> Result<IssuedCredential, AuthError> {
        let Some(ticket) = self.pairing.as_ref() else {
            return Err(AuthError::PairingUnavailable);
        };
        if now_ms >= ticket.expires_at_ms || !constant_time_str_eq(code, &ticket.code) {
            if now_ms >= ticket.expires_at_ms {
                self.pairing = None;
            }
            return Err(AuthError::PairingRejected);
        }

        // A correct ticket is consumed even if durable publication fails. Retrying a
        // partially failed security operation requires a newly displayed local ticket.
        self.pairing = None;
        if self.devices.len() >= self.max_devices {
            return Err(AuthError::DeviceLimit);
        }
        let token = unique_token(&self.devices)?;
        let id = unique_device_id(&self.devices)?;
        let expires_at_ms =
            now_ms
                .checked_add(self.credential_ttl_ms)
                .ok_or(AuthError::InvalidConfiguration(
                    "device credential expiry overflows",
                ))?;
        let device = Device {
            id: id.clone(),
            name: bounded_device_name(requested_name),
            scopes,
            created_at_ms: now_ms,
            expires_at_ms,
            last_seen_at_ms: None,
            rotated_at_ms: None,
            revoked_at_ms: None,
        };
        let record = DeviceRecord {
            device: device.clone(),
            token_digest: token_digest(&token),
        };
        let mut staged = self.devices.clone();
        staged.insert(id, record);
        save_store(&self.file_path, &staged)?;
        self.devices = staged;
        Ok(IssuedCredential { device, token })
    }

    pub fn authenticate(&mut self, token: &str, now_ms: u64) -> Result<Option<Device>, AuthError> {
        let Some(digest) = decoded_token_digest(token) else {
            return Ok(None);
        };
        let matched_id = self.devices.iter().fold(None, |matched, (id, record)| {
            if bool::from(digest.ct_eq(&record.token_digest)) {
                Some(id.clone())
            } else {
                matched
            }
        });
        let Some(id) = matched_id else {
            return Ok(None);
        };
        let Some(record) = self.devices.get(&id) else {
            return Ok(None);
        };
        if !record.is_active(now_ms) {
            return Ok(None);
        }
        let mut staged = self.devices.clone();
        let authenticated = staged
            .get_mut(&id)
            .expect("matched device exists in the staged registry");
        authenticated.device.last_seen_at_ms = Some(now_ms);
        let result = authenticated.device.clone();
        save_store(&self.file_path, &staged)?;
        self.devices = staged;
        Ok(Some(result))
    }

    pub fn rotate(&mut self, token: &str, now_ms: u64) -> Result<IssuedCredential, AuthError> {
        let Some(digest) = decoded_token_digest(token) else {
            return Err(AuthError::RotationDenied);
        };
        let matched_id = self.devices.iter().fold(None, |matched, (id, record)| {
            if record.is_active(now_ms)
                && record.device.scopes.contains(&DeviceScope::DeviceRotate)
                && bool::from(digest.ct_eq(&record.token_digest))
            {
                Some(id.clone())
            } else {
                matched
            }
        });
        let Some(id) = matched_id else {
            return Err(AuthError::RotationDenied);
        };
        let replacement = unique_token(&self.devices)?;
        let replacement_digest = token_digest(&replacement);
        let expires_at_ms =
            now_ms
                .checked_add(self.credential_ttl_ms)
                .ok_or(AuthError::InvalidConfiguration(
                    "device credential expiry overflows",
                ))?;
        let mut staged = self.devices.clone();
        let record = staged
            .get_mut(&id)
            .expect("matched device exists in the staged registry");
        record.token_digest = replacement_digest;
        record.device.rotated_at_ms = Some(now_ms);
        record.device.expires_at_ms = expires_at_ms;
        let device = record.device.clone();
        save_store(&self.file_path, &staged)?;
        self.devices = staged;
        Ok(IssuedCredential {
            device,
            token: replacement,
        })
    }

    pub fn revoke(&mut self, device_id: &str, now_ms: u64) -> Result<bool, AuthError> {
        let Some(existing) = self.devices.get(device_id) else {
            return Ok(false);
        };
        if existing.device.revoked_at_ms.is_some() {
            return Ok(false);
        }
        let mut staged = self.devices.clone();
        staged
            .get_mut(device_id)
            .expect("existing device exists in the staged registry")
            .device
            .revoked_at_ms = Some(now_ms);
        save_store(&self.file_path, &staged)?;
        self.devices = staged;
        Ok(true)
    }

    pub fn is_active(&self, device_id: &str, now_ms: u64) -> bool {
        self.devices
            .get(device_id)
            .is_some_and(|record| record.is_active(now_ms))
    }

    pub fn list(&self) -> Vec<Device> {
        self.devices
            .values()
            .map(|record| record.device.clone())
            .collect()
    }
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct StoredFile {
    version: u32,
    devices: Vec<StoredDevice>,
}

#[derive(Debug, Deserialize, Serialize)]
#[serde(rename_all = "camelCase")]
struct StoredDevice {
    id: String,
    name: String,
    token_hash: String,
    scopes: BTreeSet<DeviceScope>,
    created_at_ms: u64,
    expires_at_ms: u64,
    last_seen_at_ms: Option<u64>,
    rotated_at_ms: Option<u64>,
    revoked_at_ms: Option<u64>,
}

fn load_store(path: &Path) -> Result<BTreeMap<String, DeviceRecord>, AuthError> {
    validate_store_file(path)?;
    let bytes = match fs::read(path) {
        Ok(bytes) => bytes,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(BTreeMap::new()),
        Err(error) => return Err(error.into()),
    };
    let stored: StoredFile = serde_json::from_slice(&bytes)
        .map_err(|error| AuthError::InvalidStore(error.to_string()))?;
    if stored.version != FILE_VERSION {
        return Err(AuthError::InvalidStore(format!(
            "unsupported version {}",
            stored.version
        )));
    }
    let mut devices = BTreeMap::new();
    let mut token_digests = BTreeSet::new();
    for stored in stored.devices {
        let record = validate_stored_device(stored)?;
        if !token_digests.insert(record.token_digest) {
            return Err(AuthError::InvalidStore("duplicate token hash".into()));
        }
        if devices.insert(record.device.id.clone(), record).is_some() {
            return Err(AuthError::InvalidStore("duplicate device ID".into()));
        }
    }
    Ok(devices)
}

fn validate_store_file(path: &Path) -> Result<(), AuthError> {
    let metadata = match fs::symlink_metadata(path) {
        Ok(metadata) => metadata,
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(()),
        Err(error) => return Err(error.into()),
    };
    if metadata.file_type().is_symlink() || !metadata.is_file() {
        return Err(AuthError::InvalidStore(
            "device store must be a regular non-symlink file".into(),
        ));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::{MetadataExt, PermissionsExt};
        if metadata.uid() != unsafe { libc::geteuid() } {
            return Err(AuthError::InvalidStore(
                "device store is not owned by the current user".into(),
            ));
        }
        if metadata.permissions().mode() & 0o077 != 0 {
            return Err(AuthError::InvalidStore(
                "device store permissions allow group or other access".into(),
            ));
        }
    }
    Ok(())
}

fn validate_stored_device(stored: StoredDevice) -> Result<DeviceRecord, AuthError> {
    let id_bytes = URL_SAFE_NO_PAD
        .decode(stored.id.as_bytes())
        .map_err(|_| AuthError::InvalidStore("invalid device ID".into()))?;
    if id_bytes.len() != DEVICE_ID_BYTES {
        return Err(AuthError::InvalidStore("invalid device ID length".into()));
    }
    if stored.name.is_empty() || stored.name.chars().count() > MAX_DEVICE_NAME_CHARS {
        return Err(AuthError::InvalidStore("invalid device name".into()));
    }
    if stored.expires_at_ms <= stored.created_at_ms {
        return Err(AuthError::InvalidStore(
            "device expiry does not follow creation".into(),
        ));
    }
    let digest = URL_SAFE_NO_PAD
        .decode(stored.token_hash.as_bytes())
        .map_err(|_| AuthError::InvalidStore("invalid token hash".into()))?;
    let token_digest: [u8; 32] = digest
        .try_into()
        .map_err(|_| AuthError::InvalidStore("invalid token hash length".into()))?;
    Ok(DeviceRecord {
        device: Device {
            id: stored.id,
            name: stored.name,
            scopes: stored.scopes,
            created_at_ms: stored.created_at_ms,
            expires_at_ms: stored.expires_at_ms,
            last_seen_at_ms: stored.last_seen_at_ms,
            rotated_at_ms: stored.rotated_at_ms,
            revoked_at_ms: stored.revoked_at_ms,
        },
        token_digest,
    })
}

fn save_store(path: &Path, devices: &BTreeMap<String, DeviceRecord>) -> Result<(), AuthError> {
    let parent = path
        .parent()
        .filter(|parent| !parent.as_os_str().is_empty())
        .ok_or(AuthError::InvalidConfiguration(
            "device store must have a parent directory",
        ))?;
    create_private_dir(parent)?;
    let stored = StoredFile {
        version: FILE_VERSION,
        devices: devices
            .values()
            .map(|record| StoredDevice {
                id: record.device.id.clone(),
                name: record.device.name.clone(),
                token_hash: URL_SAFE_NO_PAD.encode(record.token_digest),
                scopes: record.device.scopes.clone(),
                created_at_ms: record.device.created_at_ms,
                expires_at_ms: record.device.expires_at_ms,
                last_seen_at_ms: record.device.last_seen_at_ms,
                rotated_at_ms: record.device.rotated_at_ms,
                revoked_at_ms: record.device.revoked_at_ms,
            })
            .collect(),
    };
    let body = serde_json::to_vec_pretty(&stored)
        .map_err(|error| AuthError::InvalidStore(error.to_string()))?;
    let temporary = parent.join(format!(
        ".{}.tmp-{}",
        path.file_name()
            .and_then(|name| name.to_str())
            .unwrap_or("devices"),
        random_urlsafe(12)?
    ));
    let result = (|| -> io::Result<()> {
        let mut file = create_private_file(&temporary)?;
        file.write_all(&body)?;
        file.write_all(b"\n")?;
        file.sync_all()?;
        fs::rename(&temporary, path)?;
        sync_parent(parent)?;
        Ok(())
    })();
    if result.is_err() {
        let _ = fs::remove_file(&temporary);
    }
    result.map_err(AuthError::Io)
}

fn random_urlsafe(bytes: usize) -> Result<String, AuthError> {
    let mut value = vec![0_u8; bytes];
    getrandom::fill(&mut value).map_err(|error| AuthError::Random(error.to_string()))?;
    Ok(URL_SAFE_NO_PAD.encode(value))
}

fn unique_token(devices: &BTreeMap<String, DeviceRecord>) -> Result<String, AuthError> {
    for _ in 0..8 {
        let token = random_urlsafe(DEVICE_TOKEN_BYTES)?;
        let digest = token_digest(&token);
        if devices.values().all(|record| record.token_digest != digest) {
            return Ok(token);
        }
    }
    Err(AuthError::Random(
        "could not generate a unique device token".into(),
    ))
}

fn unique_device_id(devices: &BTreeMap<String, DeviceRecord>) -> Result<String, AuthError> {
    for _ in 0..8 {
        let id = random_urlsafe(DEVICE_ID_BYTES)?;
        if !devices.contains_key(&id) {
            return Ok(id);
        }
    }
    Err(AuthError::Random(
        "could not generate a unique device ID".into(),
    ))
}

fn token_digest(token: &str) -> [u8; 32] {
    Sha256::digest(token.as_bytes()).into()
}

fn decoded_token_digest(token: &str) -> Option<[u8; 32]> {
    let decoded = URL_SAFE_NO_PAD.decode(token.as_bytes()).ok()?;
    if decoded.len() != DEVICE_TOKEN_BYTES {
        return None;
    }
    Some(token_digest(token))
}

fn constant_time_str_eq(left: &str, right: &str) -> bool {
    left.len() == right.len() && bool::from(left.as_bytes().ct_eq(right.as_bytes()))
}

fn bounded_device_name(value: &str) -> String {
    let name: String = value.trim().chars().take(MAX_DEVICE_NAME_CHARS).collect();
    if name.is_empty() {
        "Android device".into()
    } else {
        name
    }
}

fn create_private_file(path: &Path) -> io::Result<File> {
    let mut options = OpenOptions::new();
    options.write(true).create_new(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.mode(0o600);
    }
    options.open(path)
}

fn create_private_dir(path: &Path) -> io::Result<()> {
    if path.exists() {
        if !path.is_dir() {
            return Err(io::Error::new(
                io::ErrorKind::NotADirectory,
                "device store parent is not a directory",
            ));
        }
        return Ok(());
    }
    let mut builder = fs::DirBuilder::new();
    builder.recursive(true);
    #[cfg(unix)]
    {
        use std::os::unix::fs::DirBuilderExt;
        builder.mode(0o700);
    }
    builder.create(path)
}

fn sync_parent(parent: &Path) -> io::Result<()> {
    #[cfg(unix)]
    {
        File::open(parent)?.sync_all()
    }
    #[cfg(not(unix))]
    {
        let _ = parent;
        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use tempfile::TempDir;

    const CREDENTIAL_TTL_MS: u64 = 10_000;

    fn registry(temp: &TempDir) -> DeviceRegistry {
        DeviceRegistry::open(
            temp.path().join("remote/devices.json"),
            CREDENTIAL_TTL_MS,
            4,
        )
        .unwrap()
    }

    fn scopes() -> BTreeSet<DeviceScope> {
        [
            DeviceScope::Read,
            DeviceScope::Write,
            DeviceScope::DeviceRotate,
        ]
        .into_iter()
        .collect()
    }

    fn pair(registry: &mut DeviceRegistry, now_ms: u64) -> IssuedCredential {
        let ticket = registry.create_pairing_ticket(now_ms, 500).unwrap();
        registry
            .pair(&ticket.code, " Test phone ", scopes(), now_ms + 1)
            .unwrap()
    }

    #[test]
    fn ticket_is_short_lived_single_use_and_only_correct_code_consumes_it() {
        let temp = TempDir::new().unwrap();
        let mut registry = registry(&temp);
        let ticket = registry.create_pairing_ticket(100, 10).unwrap();
        assert!(matches!(
            registry.pair("wrong", "phone", scopes(), 101),
            Err(AuthError::PairingRejected)
        ));
        let issued = registry.pair(&ticket.code, "phone", scopes(), 102).unwrap();
        assert_eq!(issued.token.len(), 43);
        assert!(matches!(
            registry.pair(&ticket.code, "phone", scopes(), 103),
            Err(AuthError::PairingUnavailable)
        ));

        let expired = registry.create_pairing_ticket(200, 10).unwrap();
        assert!(matches!(
            registry.pair(&expired.code, "phone", scopes(), 210),
            Err(AuthError::PairingRejected)
        ));
        assert!(matches!(
            registry.pair(&expired.code, "phone", scopes(), 209),
            Err(AuthError::PairingUnavailable)
        ));
    }

    #[test]
    fn persists_only_the_hash_and_authenticates_after_reopen() {
        let temp = TempDir::new().unwrap();
        let path = temp.path().join("remote/devices.json");
        let mut registry = registry(&temp);
        let ticket = registry.create_pairing_ticket(100, 500).unwrap();
        let issued = registry
            .pair(&ticket.code, " Test phone ", scopes(), 101)
            .unwrap();
        let stored = fs::read_to_string(&path).unwrap();
        assert!(!stored.contains(&issued.token));
        assert!(!stored.contains(&ticket.code));
        assert_eq!(issued.device.name, "Test phone");
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            assert_eq!(
                fs::metadata(&path).unwrap().permissions().mode() & 0o777,
                0o600
            );
        }

        let mut reopened = DeviceRegistry::open(path, CREDENTIAL_TTL_MS, 4).unwrap();
        let authenticated = reopened.authenticate(&issued.token, 102).unwrap().unwrap();
        assert_eq!(authenticated.id, issued.device.id);
        assert_eq!(authenticated.last_seen_at_ms, Some(102));
        assert!(reopened.authenticate("not-a-token", 103).unwrap().is_none());
    }

    #[test]
    fn expiry_revocation_and_rotation_fail_closed() {
        let temp = TempDir::new().unwrap();
        let mut registry = registry(&temp);
        let issued = pair(&mut registry, 100);
        let rotated = registry.rotate(&issued.token, 200).unwrap();
        assert!(registry.authenticate(&issued.token, 201).unwrap().is_none());
        assert!(
            registry
                .authenticate(&rotated.token, 201)
                .unwrap()
                .is_some()
        );
        assert!(registry.revoke(&rotated.device.id, 202).unwrap());
        assert!(!registry.revoke(&rotated.device.id, 203).unwrap());
        assert!(
            registry
                .authenticate(&rotated.token, 204)
                .unwrap()
                .is_none()
        );

        let another = pair(&mut registry, 300);
        assert!(
            registry
                .authenticate(&another.token, 300 + CREDENTIAL_TTL_MS + 1)
                .unwrap()
                .is_none()
        );
    }

    #[test]
    fn corrupt_store_and_device_limit_are_rejected() {
        let temp = TempDir::new().unwrap();
        let path = temp.path().join("bad.json");
        fs::write(&path, b"{not json").unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&path, fs::Permissions::from_mode(0o600)).unwrap();
        }
        assert!(matches!(
            DeviceRegistry::open(path, 1, 1),
            Err(AuthError::InvalidStore(_))
        ));

        let path = temp.path().join("limited/devices.json");
        let mut limited = DeviceRegistry::open(path, CREDENTIAL_TTL_MS, 1).unwrap();
        pair(&mut limited, 100);
        let ticket = limited.create_pairing_ticket(200, 100).unwrap();
        assert!(matches!(
            limited.pair(&ticket.code, "second", scopes(), 201),
            Err(AuthError::DeviceLimit)
        ));
        assert!(matches!(
            limited.pair(&ticket.code, "second", scopes(), 202),
            Err(AuthError::PairingUnavailable)
        ));
    }

    #[test]
    fn rejects_duplicate_token_hashes_in_persisted_state() {
        let temp = TempDir::new().unwrap();
        let path = temp.path().join("devices.json");
        let token_hash = URL_SAFE_NO_PAD.encode([7_u8; 32]);
        let stored = StoredFile {
            version: FILE_VERSION,
            devices: ["first", "second"]
                .into_iter()
                .map(|name| StoredDevice {
                    id: random_urlsafe(DEVICE_ID_BYTES).unwrap(),
                    name: name.into(),
                    token_hash: token_hash.clone(),
                    scopes: scopes(),
                    created_at_ms: 1,
                    expires_at_ms: 2,
                    last_seen_at_ms: None,
                    rotated_at_ms: None,
                    revoked_at_ms: None,
                })
                .collect(),
        };
        fs::write(&path, serde_json::to_vec(&stored).unwrap()).unwrap();
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(&path, fs::Permissions::from_mode(0o600)).unwrap();
        }
        assert!(matches!(
            DeviceRegistry::open(path, CREDENTIAL_TTL_MS, 4),
            Err(AuthError::InvalidStore(message)) if message == "duplicate token hash"
        ));
    }

    #[cfg(unix)]
    #[test]
    fn rejects_symlinked_and_overexposed_store_files() {
        use std::os::unix::fs::{PermissionsExt, symlink};

        let temp = TempDir::new().unwrap();
        let target = temp.path().join("target.json");
        fs::write(&target, b"{\"version\":1,\"devices\":[]}").unwrap();
        fs::set_permissions(&target, fs::Permissions::from_mode(0o600)).unwrap();
        let link = temp.path().join("link.json");
        symlink(&target, &link).unwrap();
        assert!(matches!(
            DeviceRegistry::open(link, CREDENTIAL_TTL_MS, 2),
            Err(AuthError::InvalidStore(_))
        ));

        fs::set_permissions(&target, fs::Permissions::from_mode(0o644)).unwrap();
        assert!(matches!(
            DeviceRegistry::open(target, CREDENTIAL_TTL_MS, 2),
            Err(AuthError::InvalidStore(_))
        ));
    }

    #[test]
    fn publication_failure_consumes_ticket_and_leaves_no_temp_credential() {
        let temp = TempDir::new().unwrap();
        let path = temp.path().join("devices.json");
        let mut registry = DeviceRegistry::open(path.clone(), CREDENTIAL_TTL_MS, 2).unwrap();
        fs::create_dir(&path).unwrap();
        let ticket = registry.create_pairing_ticket(100, 100).unwrap();
        assert!(matches!(
            registry.pair(&ticket.code, "phone", scopes(), 101),
            Err(AuthError::Io(_))
        ));
        assert!(matches!(
            registry.pair(&ticket.code, "phone", scopes(), 102),
            Err(AuthError::PairingUnavailable)
        ));
        assert!(registry.list().is_empty());
        let leftovers: Vec<_> = fs::read_dir(temp.path())
            .unwrap()
            .filter_map(Result::ok)
            .filter(|entry| entry.file_name().to_string_lossy().contains(".tmp-"))
            .collect();
        assert!(leftovers.is_empty());
    }
}
