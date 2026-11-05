use base64::Engine;
use base64::engine::general_purpose::URL_SAFE_NO_PAD;
use codex_native_host::remote::PairingTicket;
use rustls::RootCertStore;
use rustls::pki_types::CertificateDer;
use serde::Serialize;
use sha2::{Digest, Sha256};
use std::fmt;
use std::io;
use std::path::Path;
use std::sync::Arc;

const INVITATION_PREFIX: &str = "codex-native-pairing-v1.";
const MAX_CERTIFICATE_FILE_BYTES: u64 = 16 * 1024;
const MAX_CERTIFICATE_DER_BYTES: usize = 8 * 1024;
const MAX_INVITATION_BYTES: usize = 24 * 1024;

#[derive(Clone)]
pub(crate) enum RemotePairingTrust {
    System,
    Certificate { der: Arc<[u8]>, sha256: Arc<str> },
}

impl RemotePairingTrust {
    pub(crate) fn from_certificate_file(path: &Path) -> io::Result<Self> {
        let metadata = std::fs::metadata(path).map_err(|error| {
            io::Error::new(
                error.kind(),
                format!("failed to inspect Remote pairing trust certificate: {error}"),
            )
        })?;
        if !metadata.is_file() || metadata.len() == 0 {
            return Err(invalid_certificate());
        }
        if metadata.len() > MAX_CERTIFICATE_FILE_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Remote pairing trust certificate file is too large",
            ));
        }
        let encoded = std::fs::read(path).map_err(|error| {
            io::Error::new(
                error.kind(),
                format!("failed to read Remote pairing trust certificate: {error}"),
            )
        })?;
        if encoded.len() as u64 > MAX_CERTIFICATE_FILE_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Remote pairing trust certificate file is too large",
            ));
        }
        let der = decode_certificate(&encoded)?;
        if der.is_empty() || der.len() > MAX_CERTIFICATE_DER_BYTES {
            return Err(invalid_certificate());
        }

        let mut roots = RootCertStore::empty();
        roots
            .add(CertificateDer::from(der.clone()))
            .map_err(|_| invalid_certificate())?;
        let sha256 = URL_SAFE_NO_PAD.encode(Sha256::digest(&der));
        Ok(Self::Certificate {
            der: Arc::from(der),
            sha256: Arc::from(sha256),
        })
    }

    pub(crate) fn kind(&self) -> &'static str {
        match self {
            Self::System => "system",
            Self::Certificate { .. } => "certificate",
        }
    }

    pub(crate) fn invitation(&self, endpoint: &str, ticket: &PairingTicket) -> io::Result<String> {
        let trust = match self {
            Self::System => PairingInvitationTrust::System { r#type: "system" },
            Self::Certificate { der, sha256 } => PairingInvitationTrust::Certificate {
                r#type: "certificate",
                sha256,
                der: URL_SAFE_NO_PAD.encode(der),
            },
        };
        let payload = serde_json::to_vec(&PairingInvitation {
            version: 1,
            endpoint,
            code: &ticket.code,
            expires_at_ms: ticket.expires_at_ms,
            trust,
        })
        .map_err(|_| io::Error::other("failed to encode Remote pairing invitation"))?;
        let invitation = format!("{INVITATION_PREFIX}{}", URL_SAFE_NO_PAD.encode(payload));
        if invitation.len() > MAX_INVITATION_BYTES {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "Remote pairing invitation exceeds its size limit",
            ));
        }
        Ok(invitation)
    }
}

impl fmt::Debug for RemotePairingTrust {
    fn fmt(&self, formatter: &mut fmt::Formatter<'_>) -> fmt::Result {
        formatter
            .debug_struct("RemotePairingTrust")
            .field("kind", &self.kind())
            .field("certificate", &"<redacted>")
            .finish()
    }
}

#[derive(Serialize)]
#[serde(rename_all = "camelCase")]
struct PairingInvitation<'a> {
    version: u8,
    endpoint: &'a str,
    code: &'a str,
    expires_at_ms: u64,
    trust: PairingInvitationTrust<'a>,
}

#[derive(Serialize)]
#[serde(untagged)]
enum PairingInvitationTrust<'a> {
    System {
        r#type: &'static str,
    },
    Certificate {
        r#type: &'static str,
        sha256: &'a str,
        der: String,
    },
}

fn decode_certificate(encoded: &[u8]) -> io::Result<Vec<u8>> {
    let trimmed = trim_ascii_whitespace(encoded);
    if trimmed.starts_with(b"-----BEGIN") {
        if !trimmed.starts_with(b"-----BEGIN CERTIFICATE-----")
            || !trimmed.ends_with(b"-----END CERTIFICATE-----")
        {
            return Err(invalid_certificate());
        }
        let blocks = pem::parse_many(trimmed).map_err(|_| invalid_certificate())?;
        if blocks.len() != 1 || blocks[0].tag() != "CERTIFICATE" {
            return Err(invalid_certificate());
        }
        Ok(blocks[0].contents().to_vec())
    } else {
        Ok(encoded.to_vec())
    }
}

fn trim_ascii_whitespace(mut value: &[u8]) -> &[u8] {
    while value.first().is_some_and(u8::is_ascii_whitespace) {
        value = &value[1..];
    }
    while value.last().is_some_and(u8::is_ascii_whitespace) {
        value = &value[..value.len() - 1];
    }
    value
}

fn invalid_certificate() -> io::Error {
    io::Error::new(
        io::ErrorKind::InvalidInput,
        "Remote pairing trust must contain exactly one valid DER or PEM certificate",
    )
}

#[cfg(test)]
mod tests {
    use super::*;
    use rcgen::{CertifiedKey, generate_simple_self_signed};
    use serde_json::Value;
    use tempfile::TempDir;

    #[test]
    fn invitation_binds_endpoint_ticket_expiry_and_certificate() {
        let temp = TempDir::new().unwrap();
        let CertifiedKey { cert, .. } =
            generate_simple_self_signed(vec!["host.example".to_owned()]).unwrap();
        let path = temp.path().join("root.pem");
        std::fs::write(&path, cert.pem()).unwrap();
        let trust = RemotePairingTrust::from_certificate_file(&path).unwrap();
        let ticket = PairingTicket {
            code: "AAAAAAAAAAAAAAAAAAAAAAAA".into(),
            expires_at_ms: 123_456,
        };

        let invitation = trust
            .invitation("wss://host.example/v1/ws", &ticket)
            .unwrap();
        assert!(invitation.starts_with(INVITATION_PREFIX));
        let payload = URL_SAFE_NO_PAD
            .decode(invitation.trim_start_matches(INVITATION_PREFIX))
            .unwrap();
        let decoded: Value = serde_json::from_slice(&payload).unwrap();
        assert_eq!(decoded["version"], 1);
        assert_eq!(decoded["endpoint"], "wss://host.example/v1/ws");
        assert_eq!(decoded["code"], ticket.code);
        assert_eq!(decoded["expiresAtMs"], ticket.expires_at_ms);
        assert_eq!(decoded["trust"]["type"], "certificate");
        assert_eq!(decoded["trust"]["sha256"].as_str().unwrap().len(), 43);
        assert_eq!(
            URL_SAFE_NO_PAD
                .decode(decoded["trust"]["der"].as_str().unwrap())
                .unwrap(),
            cert.der().as_ref()
        );
        assert!(!format!("{trust:?}").contains(decoded["trust"]["der"].as_str().unwrap()));
    }

    #[test]
    fn trust_file_requires_one_bounded_certificate() {
        let temp = TempDir::new().unwrap();
        let invalid = temp.path().join("invalid.pem");
        std::fs::write(&invalid, b"not a certificate").unwrap();
        assert_eq!(
            RemotePairingTrust::from_certificate_file(&invalid)
                .unwrap_err()
                .kind(),
            io::ErrorKind::InvalidInput
        );

        let multiple = temp.path().join("multiple.pem");
        let CertifiedKey { cert, .. } =
            generate_simple_self_signed(vec!["host.example".to_owned()]).unwrap();
        std::fs::write(&multiple, format!("{}{}", cert.pem(), cert.pem())).unwrap();
        assert_eq!(
            RemotePairingTrust::from_certificate_file(&multiple)
                .unwrap_err()
                .kind(),
            io::ErrorKind::InvalidInput
        );
    }

    #[test]
    fn der_bytes_are_not_trimmed_as_if_they_were_text() {
        let encoded = [0x30, 0x03, 0x02, 0x01, 0x0a];
        assert_eq!(decode_certificate(&encoded).unwrap(), encoded);
    }
}
