use std::fs::{File, OpenOptions};
use std::io::{self, Read};
use std::path::{Path, PathBuf};

const MAX_TLS_CERT_BYTES: u64 = 1024 * 1024;
const MAX_TLS_KEY_BYTES: u64 = 256 * 1024;

#[derive(Clone, Debug)]
pub(crate) struct RemoteTlsFiles {
    pub(crate) cert: PathBuf,
    pub(crate) key: PathBuf,
}

#[derive(Clone)]
pub(crate) struct RemoteTlsReloader {
    files: RemoteTlsFiles,
    config: axum_server::tls_rustls::RustlsConfig,
}

impl RemoteTlsReloader {
    pub(crate) fn load(files: RemoteTlsFiles) -> io::Result<Self> {
        let (cert, key) = load_tls_material(&files)?;
        let config = tls_runtime()?
            .block_on(async { axum_server::tls_rustls::RustlsConfig::from_pem(cert, key).await })
            .map_err(|error| {
                io::Error::new(
                    io::ErrorKind::InvalidInput,
                    format!("failed to load Remote TLS certificate/key: {error}"),
                )
            })?;
        Ok(Self { files, config })
    }

    pub(crate) fn config(&self) -> axum_server::tls_rustls::RustlsConfig {
        self.config.clone()
    }

    pub(crate) fn reload(&self) -> io::Result<()> {
        let (cert, key) = load_tls_material(&self.files)?;
        tls_runtime()?
            .block_on(async { self.config.reload_from_pem(cert, key).await })
            .map_err(|error| {
                io::Error::new(
                    io::ErrorKind::InvalidInput,
                    format!("failed to reload Remote TLS certificate/key: {error}"),
                )
            })
    }
}

fn tls_runtime() -> io::Result<tokio::runtime::Runtime> {
    tokio::runtime::Builder::new_current_thread()
        .enable_all()
        .build()
}

fn load_tls_material(files: &RemoteTlsFiles) -> io::Result<(Vec<u8>, Vec<u8>)> {
    // Validate and read the private input first. An invalid ACL must fail before
    // the Host consumes any key bytes.
    let key = read_private_key(&files.key)?;
    let cert = read_regular_bounded(&files.cert, MAX_TLS_CERT_BYTES, "Remote TLS certificate")?;
    Ok((cert, key))
}

fn read_private_key(path: &Path) -> io::Result<Vec<u8>> {
    let file = open_regular_no_follow(path, "Remote TLS private key")?;
    validate_private_key_file(&file)?;
    read_bounded(file, MAX_TLS_KEY_BYTES, "Remote TLS private key")
}

fn read_regular_bounded(path: &Path, max_bytes: u64, what: &str) -> io::Result<Vec<u8>> {
    let file = open_regular_no_follow(path, what)?;
    read_bounded(file, max_bytes, what)
}

fn open_regular_no_follow(path: &Path, what: &str) -> io::Result<File> {
    let mut options = OpenOptions::new();
    options.read(true);

    #[cfg(unix)]
    {
        use std::os::unix::fs::OpenOptionsExt;
        options.custom_flags(libc::O_CLOEXEC | libc::O_NOFOLLOW);
    }

    #[cfg(windows)]
    {
        use std::os::windows::fs::OpenOptionsExt;
        use windows_sys::Win32::Storage::FileSystem::{
            FILE_FLAG_OPEN_REPARSE_POINT, FILE_GENERIC_READ, FILE_SHARE_DELETE, FILE_SHARE_READ,
            FILE_SHARE_WRITE, READ_CONTROL,
        };
        options
            .access_mode(FILE_GENERIC_READ | READ_CONTROL)
            .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
            .custom_flags(FILE_FLAG_OPEN_REPARSE_POINT);
    }

    let file = options.open(path).map_err(|error| {
        #[cfg(unix)]
        if error.raw_os_error() == Some(libc::ELOOP) {
            return io::Error::new(
                io::ErrorKind::PermissionDenied,
                format!("{what} must not be a symbolic link"),
            );
        }
        io::Error::new(error.kind(), format!("failed to open {what}: {error}"))
    })?;
    let metadata = file.metadata().map_err(|error| {
        io::Error::new(error.kind(), format!("failed to inspect {what}: {error}"))
    })?;

    #[cfg(windows)]
    {
        use std::os::windows::fs::MetadataExt;
        use windows_sys::Win32::Storage::FileSystem::FILE_ATTRIBUTE_REPARSE_POINT;
        if metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                format!("{what} must not be a reparse object"),
            ));
        }
    }

    if !metadata.is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{what} must be a regular file"),
        ));
    }
    Ok(file)
}

fn validate_private_key_file(file: &File) -> io::Result<()> {
    #[cfg(unix)]
    {
        use std::os::unix::fs::MetadataExt;

        let metadata = file.metadata().map_err(|error| {
            io::Error::new(
                error.kind(),
                format!("failed to inspect Remote TLS private key: {error}"),
            )
        })?;
        // SAFETY: geteuid has no preconditions and returns the effective user
        // whose access the process is exercising for this already-open file.
        let effective_user = unsafe { libc::geteuid() };
        if metadata.uid() != effective_user {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "Remote TLS private key must be owned by the Host process user",
            ));
        }
        if metadata.mode() & 0o077 != 0 {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "Remote TLS private key must not be accessible by group or other users",
            ));
        }

        #[cfg(target_os = "macos")]
        validate_no_macos_extended_acl(file)?;
    }

    #[cfg(windows)]
    crate::remote_tls_windows::validate_private_key_acl(file).map_err(|error| {
        io::Error::new(
            error.kind(),
            format!("Remote TLS private key permission check failed: {error}"),
        )
    })?;

    Ok(())
}

#[cfg(target_os = "macos")]
fn validate_no_macos_extended_acl(file: &File) -> io::Result<()> {
    use std::ffi::c_void;
    use std::os::fd::AsRawFd;

    type Acl = *mut c_void;
    const ACL_TYPE_EXTENDED: libc::c_int = 0x0000_0100;

    unsafe extern "C" {
        fn acl_get_fd_np(fd: libc::c_int, acl_type: libc::c_int) -> Acl;
        fn acl_free(object: *mut c_void) -> libc::c_int;
    }

    struct OwnedAcl(Acl);

    impl Drop for OwnedAcl {
        fn drop(&mut self) {
            // SAFETY: acl_get_fd_np returned this non-null ACL allocation and
            // this guard is its only owner. acl_free accepts that allocation.
            unsafe {
                acl_free(self.0);
            }
        }
    }

    // SAFETY: __error returns this thread's errno slot on macOS. Clearing it
    // makes a surprising null-without-errno result fail closed instead of
    // inheriting an unrelated earlier error.
    unsafe {
        *libc::__error() = 0;
    }
    // SAFETY: the File keeps this valid descriptor open for the duration of
    // the call and ACL_TYPE_EXTENDED is the public macOS ACL type.
    let acl = unsafe { acl_get_fd_np(file.as_raw_fd(), ACL_TYPE_EXTENDED) };
    if acl.is_null() {
        let error = io::Error::last_os_error();
        if error.raw_os_error() == Some(libc::ENOENT) {
            return Ok(());
        }
        return Err(io::Error::new(
            error.kind(),
            format!("failed to inspect Remote TLS private key extended ACL: {error}"),
        ));
    }

    let _acl = OwnedAcl(acl);
    Err(io::Error::new(
        io::ErrorKind::PermissionDenied,
        "Remote TLS private key must not have a macOS extended ACL",
    ))
}

fn read_bounded(mut file: File, max_bytes: u64, what: &str) -> io::Result<Vec<u8>> {
    let metadata_len = file
        .metadata()
        .map(|metadata| metadata.len())
        .map_err(|error| {
            io::Error::new(error.kind(), format!("failed to inspect {what}: {error}"))
        })?;
    if metadata_len > max_bytes {
        return Err(file_too_large(what, max_bytes));
    }

    let mut bytes = Vec::with_capacity(metadata_len as usize);
    file.by_ref()
        .take(max_bytes + 1)
        .read_to_end(&mut bytes)
        .map_err(|error| io::Error::new(error.kind(), format!("failed to read {what}: {error}")))?;
    if bytes.len() as u64 > max_bytes {
        return Err(file_too_large(what, max_bytes));
    }
    Ok(bytes)
}

fn file_too_large(what: &str, max_bytes: u64) -> io::Error {
    io::Error::new(
        io::ErrorKind::InvalidData,
        format!("{what} exceeds the {max_bytes}-byte limit"),
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use std::fs;

    #[test]
    fn oversized_certificate_is_rejected_before_tls_parsing() {
        let temp = tempfile::tempdir().unwrap();
        let cert = temp.path().join("large-cert.pem");
        fs::write(&cert, vec![b'x'; MAX_TLS_CERT_BYTES as usize + 1]).unwrap();

        let error =
            read_regular_bounded(&cert, MAX_TLS_CERT_BYTES, "Remote TLS certificate").unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
        assert!(error.to_string().contains("1048576-byte limit"));
    }

    #[test]
    fn oversized_private_key_is_rejected_without_echoing_content() {
        let temp = tempfile::tempdir().unwrap();
        let key = temp.path().join("large-key.pem");
        let marker = b"PRIVATE-MARKER-MUST-NOT-LEAK";
        let mut bytes = vec![b'x'; MAX_TLS_KEY_BYTES as usize + 1];
        bytes[..marker.len()].copy_from_slice(marker);
        fs::write(&key, bytes).unwrap();
        make_private_for_test(&key);

        let error = read_private_key(&key).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::InvalidData);
        assert!(
            !error
                .to_string()
                .contains(std::str::from_utf8(marker).unwrap())
        );
    }

    #[cfg(unix)]
    #[test]
    fn private_key_symbolic_link_is_rejected_without_following_it() {
        use std::os::unix::fs::{PermissionsExt, symlink};

        let temp = tempfile::tempdir().unwrap();
        let target = temp.path().join("target.pem");
        let link = temp.path().join("key.pem");
        fs::write(&target, b"private").unwrap();
        fs::set_permissions(&target, fs::Permissions::from_mode(0o600)).unwrap();
        symlink(&target, &link).unwrap();

        let error = read_private_key(&link).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
    }

    #[cfg(target_os = "macos")]
    #[test]
    fn private_key_with_extended_acl_is_rejected() {
        use std::os::unix::fs::PermissionsExt;
        use std::process::Command;

        let temp = tempfile::tempdir().unwrap();
        let key = temp.path().join("key.pem");
        fs::write(&key, b"private").unwrap();
        fs::set_permissions(&key, fs::Permissions::from_mode(0o600)).unwrap();

        let output = Command::new("/bin/chmod")
            .arg("+a")
            .arg("everyone allow read")
            .arg(&key)
            .output()
            .unwrap();
        assert!(
            output.status.success(),
            "failed to prepare macOS ACL fixture: {}",
            String::from_utf8_lossy(&output.stderr)
        );
        assert_eq!(
            fs::metadata(&key).unwrap().permissions().mode() & 0o777,
            0o600,
            "the ACL fixture must remain owner-only by POSIX mode"
        );

        let error = read_private_key(&key).unwrap_err();

        assert_eq!(error.kind(), io::ErrorKind::PermissionDenied);
        assert!(
            error
                .to_string()
                .contains("must not have a macOS extended ACL")
        );
    }

    fn make_private_for_test(path: &Path) {
        #[cfg(unix)]
        {
            use std::os::unix::fs::PermissionsExt;
            fs::set_permissions(path, fs::Permissions::from_mode(0o600)).unwrap();
        }
        #[cfg(windows)]
        crate::windows_acl::protect_file(path).unwrap();
    }
}
