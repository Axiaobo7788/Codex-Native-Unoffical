use std::env;
use std::io;
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

        let mut arguments = env::args_os().skip(1);
        while let Some(argument) = arguments.next() {
            match argument.to_string_lossy().as_ref() {
                "--codex" => codex_executable = required_path(&mut arguments, "--codex")?,
                "--cache-dir" => cache_dir = required_path(&mut arguments, "--cache-dir")?,
                "-h" | "--help" => {
                    println!(
                        "codex-native-host {}\n\nUsage: codex-native-host [--codex PATH] [--cache-dir PATH]",
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

        Ok(Some(Self {
            codex_executable,
            cache_dir,
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

fn default_cache_dir() -> PathBuf {
    dirs::cache_dir()
        .unwrap_or_else(std::env::temp_dir)
        .join("codex-native-unofficial")
        .join("host-output")
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
