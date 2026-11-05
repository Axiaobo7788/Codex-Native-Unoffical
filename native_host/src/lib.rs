pub mod remote;
#[cfg(windows)]
// This shared source also backs the binary's spool boundary, so each crate sees
// one helper that is intentionally used only by the other crate.
#[allow(dead_code)]
mod windows_acl;
