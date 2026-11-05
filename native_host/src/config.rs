use crate::remote_tls::RemoteTlsFiles;
use std::env;
use std::io;
use std::net::SocketAddr;
use std::path::PathBuf;
use std::time::Duration;

const DEFAULT_MAX_OUTPUT_BYTES: u64 = 512 * 1024 * 1024;
const DEFAULT_MAX_SESSION_BYTES: u64 = 2 * 1024 * 1024 * 1024;
const DEFAULT_MAX_FORWARD_MESSAGE_BYTES: u64 = 8 * 1024 * 1024;
const DEFAULT_MAX_READ_BYTES: usize = 256 * 1024;
const DEFAULT_MAX_CLIENT_MESSAGE_BYTES: usize = 1024 * 1024;
const DEFAULT_STALE_AGE_SECS: u64 = 24 * 60 * 60;

#[derive(Debug)]
pub(crate) struct Config {
    pub(crate) codex_executable: PathBuf,
    pub(crate) cache_dir: PathBuf,
    pub(crate) remote_device_file: Option<PathBuf>,
    pub(crate) remote_listen: Option<SocketAddr>,
    pub(crate) remote_tls: Option<RemoteTlsFiles>,
    pub(crate) max_output_bytes: u64,
    pub(crate) max_session_bytes: u64,
    pub(crate) max_forward_message_bytes: u64,
    pub(crate) max_read_bytes: usize,
    pub(crate) max_client_message_bytes: usize,
    pub(crate) stale_age: Duration,
}

impl Config {
    pub(crate) fn parse() -> io::Result<Option<Self>> {
        let mut codex_executable = env::var_os("CODEX_NATIVE_CODEX")
            .map(PathBuf::from)
            .unwrap_or_else(|| PathBuf::from("codex"));
        let mut cache_dir = env::var_os("CODEX_NATIVE_CACHE_DIR")
            .map(PathBuf::from)
            .unwrap_or_else(default_cache_dir);
        let mut remote_device_file = env::var_os("CODEX_NATIVE_REMOTE_DEVICE_FILE")
            .map(PathBuf::from)
            .map(Some)
            .unwrap_or_else(default_remote_device_file);
        let mut remote_listen = optional_socket_addr("CODEX_NATIVE_REMOTE_LISTEN")?;
        let mut remote_tls_cert = optional_path("CODEX_NATIVE_REMOTE_TLS_CERT")?;
        let mut remote_tls_key = optional_path("CODEX_NATIVE_REMOTE_TLS_KEY")?;

        let mut arguments = env::args_os().skip(1);
        while let Some(argument) = arguments.next() {
            match argument.to_string_lossy().as_ref() {
                "--codex" => codex_executable = required_path(&mut arguments, "--codex")?,
                "--cache-dir" => cache_dir = required_path(&mut arguments, "--cache-dir")?,
                "--remote-device-file" => {
                    remote_device_file =
                        Some(required_path(&mut arguments, "--remote-device-file")?)
                }
                "--remote-listen" => {
                    remote_listen = Some(required_socket_addr(&mut arguments, "--remote-listen")?)
                }
                "--remote-tls-cert" => {
                    remote_tls_cert = Some(required_path(&mut arguments, "--remote-tls-cert")?)
                }
                "--remote-tls-key" => {
                    remote_tls_key = Some(required_path(&mut arguments, "--remote-tls-key")?)
                }
                "-h" | "--help" => {
                    println!(
                        "codex-native-host {}\n\nUsage: codex-native-host [--codex PATH] [--cache-dir PATH] [--remote-device-file PATH] [--remote-listen IP:PORT [--remote-tls-cert CERT.pem --remote-tls-key KEY.pem]]",
                        env!("CARGO_PKG_VERSION")
                    );
                    return Ok(None);
                }
                "-V" | "--version" => {
                    println!("codex-native-host {}", env!("CARGO_PKG_VERSION"));
                    return Ok(None);
                }
                unknown => {
                    return Err(io::Error::new(
                        io::ErrorKind::InvalidInput,
                        format!("unknown argument: {unknown}"),
                    ));
                }
            }
        }

        let remote_tls = validate_remote_transport(remote_listen, remote_tls_cert, remote_tls_key)?;

        Ok(Some(Self {
            codex_executable,
            cache_dir,
            remote_device_file,
            remote_listen,
            remote_tls,
            max_output_bytes: positive_u64(
                "CODEX_NATIVE_MAX_OUTPUT_BYTES",
                DEFAULT_MAX_OUTPUT_BYTES,
            )?,
            max_session_bytes: positive_u64(
                "CODEX_NATIVE_MAX_SESSION_BYTES",
                DEFAULT_MAX_SESSION_BYTES,
            )?,
            max_forward_message_bytes: positive_u64(
                "CODEX_NATIVE_MAX_FORWARD_MESSAGE_BYTES",
                DEFAULT_MAX_FORWARD_MESSAGE_BYTES,
            )?,
            max_read_bytes: positive_usize("CODEX_NATIVE_MAX_READ_BYTES", DEFAULT_MAX_READ_BYTES)?,
            max_client_message_bytes: positive_usize(
                "CODEX_NATIVE_MAX_CLIENT_MESSAGE_BYTES",
                DEFAULT_MAX_CLIENT_MESSAGE_BYTES,
            )?,
            stale_age: Duration::from_secs(positive_u64(
                "CODEX_NATIVE_STALE_AGE_SECS",
                DEFAULT_STALE_AGE_SECS,
            )?),
        }))
    }
}

fn required_path(
    arguments: &mut impl Iterator<Item = std::ffi::OsString>,
    flag: &str,
) -> io::Result<PathBuf> {
    arguments.next().map(PathBuf::from).ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{flag} requires a path"),
        )
    })
}

fn required_socket_addr(
    arguments: &mut impl Iterator<Item = std::ffi::OsString>,
    flag: &str,
) -> io::Result<SocketAddr> {
    let value = arguments.next().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{flag} requires a socket address"),
        )
    })?;
    parse_socket_addr(&value.to_string_lossy(), flag)
}

fn optional_socket_addr(name: &str) -> io::Result<Option<SocketAddr>> {
    match env::var(name) {
        Ok(value) => parse_socket_addr(&value, name).map(Some),
        Err(env::VarError::NotPresent) => Ok(None),
        Err(env::VarError::NotUnicode(_)) => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{name} must be a UTF-8 IP socket address"),
        )),
    }
}

fn parse_socket_addr(value: &str, source: &str) -> io::Result<SocketAddr> {
    value.parse::<SocketAddr>().map_err(|_| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{source} must be a literal IP socket address"),
        )
    })
}

fn optional_path(name: &str) -> io::Result<Option<PathBuf>> {
    match env::var_os(name) {
        Some(value) if value.is_empty() => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            format!("{name} must not be empty"),
        )),
        Some(value) => Ok(Some(PathBuf::from(value))),
        None => Ok(None),
    }
}

fn validate_remote_transport(
    address: Option<SocketAddr>,
    cert: Option<PathBuf>,
    key: Option<PathBuf>,
) -> io::Result<Option<RemoteTlsFiles>> {
    let tls = match (cert, key) {
        (Some(cert), Some(key)) => Some(RemoteTlsFiles { cert, key }),
        (None, None) => None,
        _ => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Remote TLS certificate and private key must be configured together",
            ));
        }
    };
    match (address, tls) {
        (None, Some(_)) => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "Remote TLS files require a Remote listener",
        )),
        (Some(address), None) if !address.ip().is_loopback() => Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "plaintext Remote listener is restricted to loopback",
        )),
        (_, tls) => Ok(tls),
    }
}

fn default_cache_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(std::env::temp_dir)
        .join("codex-native-unofficial")
        .join("host-output")
}

fn default_remote_device_file() -> Option<PathBuf> {
    dirs::config_dir().map(|directory| {
        directory
            .join("codex-native-unofficial")
            .join("remote")
            .join("devices.json")
    })
}

fn positive_u64(name: &str, default: u64) -> io::Result<u64> {
    match env::var(name) {
        Ok(value) => value
            .parse::<u64>()
            .ok()
            .filter(|value| *value > 0)
            .ok_or_else(|| invalid_environment(name)),
        Err(env::VarError::NotPresent) => Ok(default),
        Err(env::VarError::NotUnicode(_)) => Err(invalid_environment(name)),
    }
}

fn positive_usize(name: &str, default: usize) -> io::Result<usize> {
    let value = positive_u64(name, default as u64)?;
    usize::try_from(value).map_err(|_| invalid_environment(name))
}

fn invalid_environment(name: &str) -> io::Error {
    io::Error::new(
        io::ErrorKind::InvalidInput,
        format!("{name} must be a positive integer"),
    )
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn remote_address_requires_a_literal_ip() {
        assert_eq!(
            parse_socket_addr("127.0.0.1:0", "test").unwrap(),
            "127.0.0.1:0".parse().unwrap()
        );
        assert_eq!(
            parse_socket_addr("[::1]:4317", "test").unwrap(),
            "[::1]:4317".parse().unwrap()
        );
        assert_eq!(
            parse_socket_addr("0.0.0.0:4317", "test").unwrap(),
            "0.0.0.0:4317".parse().unwrap()
        );
        for invalid in ["localhost:4317", "missing-port"] {
            assert_eq!(
                parse_socket_addr(invalid, "test").unwrap_err().kind(),
                io::ErrorKind::InvalidInput
            );
        }
    }

    #[test]
    fn remote_transport_configuration_fails_closed() {
        let loopback = Some("127.0.0.1:0".parse().unwrap());
        let network = Some("0.0.0.0:4317".parse().unwrap());
        let cert = || Some(PathBuf::from("cert.pem"));
        let key = || Some(PathBuf::from("key.pem"));

        assert!(
            validate_remote_transport(None, None, None)
                .unwrap()
                .is_none()
        );
        assert!(
            validate_remote_transport(loopback, None, None)
                .unwrap()
                .is_none()
        );
        let tls = validate_remote_transport(network, cert(), key())
            .unwrap()
            .unwrap();
        assert_eq!(tls.cert, PathBuf::from("cert.pem"));
        assert_eq!(tls.key, PathBuf::from("key.pem"));

        for result in [
            validate_remote_transport(None, cert(), key()),
            validate_remote_transport(loopback, cert(), None),
            validate_remote_transport(loopback, None, key()),
            validate_remote_transport(network, None, None),
        ] {
            assert_eq!(result.unwrap_err().kind(), io::ErrorKind::InvalidInput);
        }
    }
}
