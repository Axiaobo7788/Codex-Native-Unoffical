use std::fs;
use std::process::Command;
use tempfile::TempDir;

#[test]
fn invalid_cache_root_fails_before_the_codex_child_is_started() {
    let temp = TempDir::new().unwrap();
    let cache_root = temp.path().join("cache-is-a-file");
    fs::write(&cache_root, b"not a directory").unwrap();

    let output = Command::new(env!("CARGO_BIN_EXE_codex-native-host"))
        .args([
            "--codex",
            "codex-child-must-not-start",
            "--cache-dir",
            cache_root.to_str().unwrap(),
        ])
        .output()
        .unwrap();

    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).unwrap();
    assert!(stderr.contains("failed to initialize Host output cache"));
    assert!(stderr.contains(cache_root.to_string_lossy().as_ref()));
    assert!(!stderr.contains("failed to start `codex-child-must-not-start`"));
}

#[test]
fn invalid_tls_material_fails_before_the_codex_child_is_started() {
    let temp = TempDir::new().unwrap();
    let cert = temp.path().join("invalid-cert.pem");
    let key = temp.path().join("invalid-key.pem");
    let private_marker = "PRIVATE-MARKER-MUST-NOT-LEAK";
    fs::write(&cert, b"not a certificate").unwrap();
    fs::write(&key, private_marker).unwrap();
    #[cfg(unix)]
    {
        use std::os::unix::fs::PermissionsExt;
        fs::set_permissions(&key, fs::Permissions::from_mode(0o600)).unwrap();
    }

    let output = Command::new(env!("CARGO_BIN_EXE_codex-native-host"))
        .args([
            "--codex",
            "codex-child-must-not-start",
            "--remote-listen",
            "127.0.0.1:0",
            "--remote-tls-cert",
            cert.to_str().unwrap(),
            "--remote-tls-key",
            key.to_str().unwrap(),
        ])
        .output()
        .unwrap();

    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).unwrap();
    // Unix gives this fixture owner-only permissions and reaches rustls. The
    // Windows fixture intentionally retains its inherited temporary-directory
    // ACL, so the new external-key gate may reject it earlier. Both are TLS
    // material failures and must happen before the Codex child starts.
    assert!(
        stderr.contains("failed to load Remote TLS certificate/key")
            || stderr.contains("Remote TLS private key permission check failed")
    );
    assert!(!stderr.contains(private_marker));
    assert!(!stderr.contains("failed to start `codex-child-must-not-start`"));
}

#[test]
fn invalid_pairing_trust_fails_before_the_codex_child_is_started() {
    let temp = TempDir::new().unwrap();
    let certificate = temp.path().join("invalid-pairing-trust.pem");
    let marker = "PAIRING-TRUST-MARKER-MUST-NOT-LEAK";
    fs::write(&certificate, marker).unwrap();

    let output = Command::new(env!("CARGO_BIN_EXE_codex-native-host"))
        .args([
            "--codex",
            "codex-child-must-not-start",
            "--remote-listen",
            "127.0.0.1:0",
            "--remote-advertise-endpoint",
            "wss://host.example/v1/ws",
            "--remote-pairing-trust-cert",
            certificate.to_str().unwrap(),
        ])
        .output()
        .unwrap();

    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).unwrap();
    assert!(stderr.contains("Remote pairing trust"));
    assert!(!stderr.contains(marker));
    assert!(!stderr.contains("failed to start `codex-child-must-not-start`"));
}

#[cfg(unix)]
#[test]
fn unwritable_cache_parent_is_reported_before_child_start() {
    use std::os::unix::fs::PermissionsExt;

    if unsafe { libc::geteuid() } == 0 {
        return;
    }

    let temp = TempDir::new().unwrap();
    let parent = temp.path().join("read-only-parent");
    let cache_root = parent.join("host-output");
    fs::create_dir(&parent).unwrap();
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o500)).unwrap();

    let output = Command::new(env!("CARGO_BIN_EXE_codex-native-host"))
        .args([
            "--codex",
            "codex-child-must-not-start",
            "--cache-dir",
            cache_root.to_str().unwrap(),
        ])
        .output()
        .unwrap();
    fs::set_permissions(&parent, fs::Permissions::from_mode(0o700)).unwrap();

    assert!(!output.status.success());
    let stderr = String::from_utf8(output.stderr).unwrap();
    assert!(stderr.contains("failed to initialize Host output cache"));
    assert!(stderr.contains(cache_root.to_string_lossy().as_ref()));
    assert!(!cache_root.exists());
    assert!(!stderr.contains("failed to start `codex-child-must-not-start`"));
}
