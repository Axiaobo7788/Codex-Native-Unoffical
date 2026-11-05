use std::io;
use std::path::{Path, PathBuf};

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
        validate_private_key_file(&files.key)?;
        let config = tls_runtime()?
            .block_on(async {
                axum_server::tls_rustls::RustlsConfig::from_pem_file(&files.cert, &files.key).await
            })
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
        validate_private_key_file(&self.files.key)?;
        tls_runtime()?
            .block_on(async {
                self.config
                    .reload_from_pem_file(&self.files.cert, &self.files.key)
                    .await
            })
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

fn validate_private_key_file(path: &Path) -> io::Result<()> {
    let metadata = std::fs::metadata(path).map_err(|error| {
        io::Error::new(
            error.kind(),
            format!("failed to inspect Remote TLS private key: {error}"),
        )
    })?;
    if !metadata.is_file() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Remote TLS private key must be a regular file",
        ));
    }
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        if metadata.permissions().mode() & 0o077 != 0 {
            return Err(io::Error::new(
                io::ErrorKind::PermissionDenied,
                "Remote TLS private key must not be accessible by group or other users",
            ));
        }
    }
    Ok(())
}
