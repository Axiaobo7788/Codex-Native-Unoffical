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
