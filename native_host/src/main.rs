mod config;
mod events;
mod json_string;
mod remote_bridge;
mod remote_pairing_invitation;
mod remote_server;
mod remote_tls;
mod rpc;
mod spool;
mod transform;

use config::Config;
use events::{AppServerRemoteObservation, HOST_EVENT_CAPACITY, HostEvent};
use remote_bridge::RemoteCoordinator;
use remote_server::RemoteServer;
use rpc::{ClientMessage, RemoteAdmin, route_client_message};
use spool::SpoolStore;
use std::io::{self, BufWriter, Read, Write};
use std::process::{Child, ChildStdin, Command, ExitStatus, Stdio};
use std::sync::{Arc, Mutex, MutexGuard, mpsc};
use std::thread;
use std::time::{Duration, Instant};

const CHILD_GRACE_PERIOD: Duration = Duration::from_secs(3);
const CHILD_TERM_PERIOD: Duration = Duration::from_secs(3);

fn main() {
    if let Err(error) = run() {
        eprintln!("codex-native-host: {error}");
        std::process::exit(1);
    }
}

fn run() -> io::Result<()> {
    let Some(config) = Config::parse()? else {
        return Ok(());
    };
    let cache_dir = config.cache_dir.clone();
    let remote_advertise_endpoint = config.remote_advertise_endpoint.clone();
    let remote_pairing_trust = config.remote_pairing_trust.clone();
    let remote_admin = Arc::new(Mutex::new(RemoteAdmin::new(
        config.remote_device_file.clone(),
    )));
    let (events_tx, events_rx) = mpsc::sync_channel(HOST_EVENT_CAPACITY);
    let remote_server = match config.remote_listen {
        Some(address) => {
            let server = RemoteServer::start(
                address,
                config.remote_tls.clone(),
                Arc::clone(&remote_admin),
                events_tx.clone(),
            )?;
            remote_admin
                .lock()
                .map_err(|_| io::Error::other("Remote administration lock poisoned"))?
                .set_listener(
                    server.address(),
                    server.is_tls(),
                    server.tls_reloader(),
                    remote_advertise_endpoint,
                    remote_pairing_trust,
                );
            Some(server)
        }
        None => None,
    };
    let store = Arc::new(
        SpoolStore::open(
            config.cache_dir,
            config.max_output_bytes,
            config.max_session_bytes,
            config.max_forward_message_bytes,
            config.max_read_bytes,
            config.stale_age,
        )
        .map_err(|error| {
            io::Error::new(
                error.kind(),
                format!(
                    "failed to initialize Host output cache at `{}`: {error}",
                    cache_dir.display()
                ),
            )
        })?,
    );

    let mut command = Command::new(&config.codex_executable);
    command
        .args(["app-server", "--listen", "stdio://"])
        .stdin(Stdio::piped())
        .stdout(Stdio::piped())
        .stderr(Stdio::inherit());
    configure_child_lifecycle(&mut command);
    let mut child = command.spawn().map_err(|error| {
        io::Error::new(
            error.kind(),
            format!(
                "failed to start `{}`: {error}",
                config.codex_executable.display()
            ),
        )
    })?;
    let mut child_stdin = child
        .stdin
        .take()
        .ok_or_else(|| io::Error::other("app-server stdin is unavailable"))?;
    let child_stdout = child
        .stdout
        .take()
        .ok_or_else(|| io::Error::other("app-server stdout is unavailable"))?;

    let input_tx = events_tx.clone();
    let _input_thread = thread::Builder::new()
        .name("host-client-input".into())
        .spawn(move || {
            let result = read_client_input(
                io::stdin(),
                config.max_client_message_bytes,
                input_tx.clone(),
            );
            let event = match result {
                Ok(()) => HostEvent::ClientEof,
                Err(error) => HostEvent::InputFailed(error),
            };
            let _ = input_tx.send(event);
        })?;

    let stdout_lock = Arc::new(Mutex::new(()));
    let output_store = Arc::clone(&store);
    let output_lock = Arc::clone(&stdout_lock);
    let output_tx = events_tx.clone();
    let remote_id_prefix = remote_server.as_ref().map(RemoteServer::correlation_prefix);
    let remote_event_publisher = remote_server.as_ref().map(RemoteServer::publisher);
    let output_thread = thread::Builder::new()
        .name("host-app-server-output".into())
        .spawn(move || {
            let result = transform::transform_stream(
                child_stdout,
                LockedStdout::new(&output_lock),
                &output_store,
                remote_id_prefix,
                |observation| match observation {
                    AppServerRemoteObservation::Response(response) => output_tx
                        .send(HostEvent::AppServerRemoteResponse(response))
                        .map_err(|_| io::Error::other("Host event loop is unavailable")),
                    AppServerRemoteObservation::Notification(notification) => {
                        remote_event_publisher
                            .as_ref()
                            .ok_or_else(|| {
                                io::Error::other("Remote event publisher is unavailable")
                            })?
                            .publish(notification)
                    }
                },
            );
            let _ = output_tx.send(HostEvent::OutputFinished(result));
        })?;
    drop(events_tx);

    let mut primary_error = None;
    let mut shutdown_requested = false;
    let mut remote_coordinator = remote_server
        .as_ref()
        .map(|server| RemoteCoordinator::new(server.session_id()))
        .transpose()?;
    for event in events_rx {
        match event {
            HostEvent::ClientLine(line) => {
                match route_client_message(line, &store, &remote_admin) {
                    ClientMessage::Forward(line) => {
                        if let Err(error) = write_line(&mut child_stdin, &line) {
                            primary_error = Some(error);
                            break;
                        }
                    }
                    ClientMessage::Respond(Some(line)) => {
                        if let Err(error) = write_stdout_line(&stdout_lock, &line) {
                            primary_error = Some(error);
                            break;
                        }
                    }
                    ClientMessage::Respond(None) => {}
                }
            }
            HostEvent::ClientEof => {
                shutdown_requested = true;
                break;
            }
            HostEvent::InputFailed(error) => {
                primary_error = Some(error);
                break;
            }
            HostEvent::RemoteRpc(call) => {
                let Some(coordinator) = remote_coordinator.as_mut() else {
                    let _ = call.reply.send(remote_bridge::remote_error(
                        call.client_id,
                        -32603,
                        "Remote listener is unavailable",
                    ));
                    continue;
                };
                if let Some((host_id, line)) = coordinator.prepare(call)
                    && let Err(error) = write_line(&mut child_stdin, &line)
                {
                    coordinator.dispatch_failed(&host_id);
                    primary_error = Some(error);
                    break;
                }
            }
            HostEvent::RemoteDisconnected(connection_id) => {
                if let Some(coordinator) = remote_coordinator.as_mut() {
                    coordinator.disconnect(&connection_id);
                }
            }
            HostEvent::AppServerRemoteResponse(response) => {
                let Some(coordinator) = remote_coordinator.as_mut() else {
                    primary_error = Some(io::Error::new(
                        io::ErrorKind::InvalidData,
                        "app-server returned a reserved Remote response without a listener",
                    ));
                    break;
                };
                if let Err(error) = coordinator.receive(response) {
                    primary_error = Some(error);
                    break;
                }
            }
            HostEvent::OutputFinished(result) => {
                if let Err(error) = result {
                    primary_error = Some(error);
                }
                break;
            }
        }
    }

    drop(child_stdin);
    if let Some(remote_server) = remote_server {
        if let Err(error) = remote_server.stop()
            && primary_error.is_none()
        {
            primary_error = Some(error);
        }
    }
    let status = match stop_child(&mut child) {
        Ok(status) => Some(status),
        Err(error) => {
            if primary_error.is_none() {
                primary_error = Some(error);
            }
            None
        }
    };
    if !shutdown_requested
        && status.as_ref().is_some_and(|status| !status.success())
        && primary_error.is_none()
    {
        primary_error = Some(io::Error::other(format!(
            "app-server exited with {}",
            status.expect("checked above")
        )));
    }

    let _ = output_thread.join();
    drop(stdout_lock);
    let store = Arc::try_unwrap(store)
        .map_err(|_| io::Error::other("host output store is still in use"))?;
    if let Err(error) = store.cleanup()
        && primary_error.is_none()
    {
        primary_error = Some(error);
    }

    match primary_error {
        Some(error) => Err(error),
        None => Ok(()),
    }
}

fn read_client_input(
    input: impl Read,
    max_message_bytes: usize,
    events: mpsc::SyncSender<HostEvent>,
) -> io::Result<()> {
    let mut reader = BoundedLines::new(input, max_message_bytes);
    while let Some(line) = reader.next_line()? {
        if events.send(HostEvent::ClientLine(line)).is_err() {
            break;
        }
    }
    Ok(())
}

fn write_line(output: &mut ChildStdin, line: &[u8]) -> io::Result<()> {
    output.write_all(line)?;
    output.write_all(b"\n")?;
    output.flush()
}

fn write_stdout_line(lock: &Mutex<()>, line: &[u8]) -> io::Result<()> {
    let _guard = lock
        .lock()
        .map_err(|_| io::Error::other("stdout lock poisoned"))?;
    let mut output = io::stdout().lock();
    output.write_all(line)?;
    output.write_all(b"\n")?;
    output.flush()
}

struct LockedStdout<'a> {
    lock: &'a Mutex<()>,
    guard: Option<MutexGuard<'a, ()>>,
    output: BufWriter<io::Stdout>,
}

impl<'a> LockedStdout<'a> {
    fn new(lock: &'a Mutex<()>) -> Self {
        Self {
            lock,
            guard: None,
            output: BufWriter::new(io::stdout()),
        }
    }

    fn acquire(&mut self) -> io::Result<()> {
        if self.guard.is_none() {
            self.guard = Some(
                self.lock
                    .lock()
                    .map_err(|_| io::Error::other("stdout lock poisoned"))?,
            );
        }
        Ok(())
    }
}

impl Write for LockedStdout<'_> {
    fn write(&mut self, buffer: &[u8]) -> io::Result<usize> {
        self.acquire()?;
        self.output.write(buffer)
    }

    fn flush(&mut self) -> io::Result<()> {
        self.output.flush()?;
        self.guard.take();
        Ok(())
    }
}

struct BoundedLines<R> {
    reader: R,
    pending: Vec<u8>,
    max_message_bytes: usize,
    eof: bool,
}

impl<R: Read> BoundedLines<R> {
    fn new(reader: R, max_message_bytes: usize) -> Self {
        Self {
            reader,
            pending: Vec::new(),
            max_message_bytes,
            eof: false,
        }
    }

    fn next_line(&mut self) -> io::Result<Option<Vec<u8>>> {
        loop {
            if let Some(newline) = self.pending.iter().position(|byte| *byte == b'\n') {
                if newline > self.max_message_bytes {
                    return Err(message_too_large(self.max_message_bytes));
                }
                let mut remainder = self.pending.split_off(newline + 1);
                std::mem::swap(&mut remainder, &mut self.pending);
                remainder.pop();
                if remainder.last() == Some(&b'\r') {
                    remainder.pop();
                }
                return Ok(Some(remainder));
            }
            if self.pending.len() > self.max_message_bytes {
                return Err(message_too_large(self.max_message_bytes));
            }
            if self.eof {
                if self.pending.is_empty() {
                    return Ok(None);
                }
                if self.pending.len() > self.max_message_bytes {
                    return Err(message_too_large(self.max_message_bytes));
                }
                return Ok(Some(std::mem::take(&mut self.pending)));
            }

            let mut buffer = [0_u8; 8192];
            match self.reader.read(&mut buffer) {
                Ok(0) => self.eof = true,
                Ok(count) => self.pending.extend_from_slice(&buffer[..count]),
                Err(error) if error.kind() == io::ErrorKind::Interrupted => {}
                Err(error) => return Err(error),
            }
        }
    }
}

fn message_too_large(max: usize) -> io::Error {
    io::Error::new(
        io::ErrorKind::InvalidData,
        format!("client JSON message exceeds {max} bytes"),
    )
}

fn stop_child(child: &mut Child) -> io::Result<ExitStatus> {
    if let Some(status) = wait_until(child, CHILD_GRACE_PERIOD)? {
        return Ok(status);
    }
    terminate_child(child)?;
    if let Some(status) = wait_until(child, CHILD_TERM_PERIOD)? {
        return Ok(status);
    }
    child.kill()?;
    child.wait()
}

fn wait_until(child: &mut Child, timeout: Duration) -> io::Result<Option<ExitStatus>> {
    let deadline = Instant::now() + timeout;
    loop {
        if let Some(status) = child.try_wait()? {
            return Ok(Some(status));
        }
        if Instant::now() >= deadline {
            return Ok(None);
        }
        thread::sleep(Duration::from_millis(25));
    }
}

#[cfg(unix)]
fn terminate_child(child: &mut Child) -> io::Result<()> {
    let result = unsafe { libc::kill(child.id() as libc::pid_t, libc::SIGTERM) };
    if result == 0 {
        Ok(())
    } else {
        let error = io::Error::last_os_error();
        if error.raw_os_error() == Some(libc::ESRCH) {
            Ok(())
        } else {
            Err(error)
        }
    }
}

#[cfg(not(unix))]
fn terminate_child(child: &mut Child) -> io::Result<()> {
    child.kill()
}

#[cfg(any(target_os = "linux", target_os = "android"))]
fn configure_child_lifecycle(command: &mut Command) {
    use std::os::unix::process::CommandExt;
    unsafe {
        command.pre_exec(|| {
            if libc::prctl(libc::PR_SET_PDEATHSIG, libc::SIGTERM) == -1 {
                return Err(io::Error::last_os_error());
            }
            Ok(())
        });
    }
}

#[cfg(not(any(target_os = "linux", target_os = "android")))]
fn configure_child_lifecycle(_command: &mut Command) {}

#[cfg(test)]
mod tests {
    use super::*;
    use std::io::Cursor;

    #[test]
    fn bounded_lines_handles_chunking_crlf_and_final_unterminated_line() {
        let input = Cursor::new(b"one\r\ntwo\nthree".to_vec());
        let mut lines = BoundedLines::new(input, 16);
        assert_eq!(lines.next_line().unwrap(), Some(b"one".to_vec()));
        assert_eq!(lines.next_line().unwrap(), Some(b"two".to_vec()));
        assert_eq!(lines.next_line().unwrap(), Some(b"three".to_vec()));
        assert_eq!(lines.next_line().unwrap(), None);
    }

    #[test]
    fn bounded_lines_rejects_terminated_and_unterminated_oversize_messages() {
        for input in [b"12345\n".as_slice(), b"12345"] {
            let mut lines = BoundedLines::new(Cursor::new(input), 4);
            assert_eq!(
                lines.next_line().unwrap_err().kind(),
                io::ErrorKind::InvalidData
            );
        }
    }
}
