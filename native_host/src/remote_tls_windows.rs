//! Read-only validation for operator-supplied Remote TLS private keys.
//!
//! This deliberately does not rewrite the external file. The key is opened
//! without following a reparse point, its owner and DACL are inspected through
//! that handle, and `remote_tls` reads from the same handle only after this gate.

use std::fs::File;
use std::io;
use std::os::windows::io::AsRawHandle;
use std::ptr;
use windows_sys::Win32::Foundation::{CloseHandle, ERROR_SUCCESS, HANDLE, LocalFree};
use windows_sys::Win32::Security::Authorization::{GetSecurityInfo, SE_FILE_OBJECT};
use windows_sys::Win32::Security::{
    ACCESS_ALLOWED_ACE, ACL, DACL_SECURITY_INFORMATION, EqualSid, GetAce,
    GetSecurityDescriptorControl, GetTokenInformation, IsValidAcl, IsValidSid, IsWellKnownSid,
    OWNER_SECURITY_INFORMATION, PSECURITY_DESCRIPTOR, PSID, SE_DACL_PROTECTED, TOKEN_QUERY,
    TOKEN_USER, TokenUser, WinBuiltinAdministratorsSid, WinLocalSystemSid,
};
use windows_sys::Win32::System::SystemServices::{ACCESS_ALLOWED_ACE_TYPE, ACCESS_DENIED_ACE_TYPE};
use windows_sys::Win32::System::Threading::{GetCurrentProcess, OpenProcessToken};

const SID_HEADER_BYTES: usize = 8;
const SID_SUBAUTHORITY_BYTES: usize = 4;

pub(crate) fn validate_private_key_acl(file: &File) -> io::Result<()> {
    let current_user = CurrentUserSid::read()?;
    let mut owner: PSID = ptr::null_mut();
    let mut dacl: *mut ACL = ptr::null_mut();
    let mut descriptor: PSECURITY_DESCRIPTOR = ptr::null_mut();
    // SAFETY: the file handle is live, each output pointer is valid, and the
    // returned owner/DACL stay backed by descriptor until this function exits.
    let status = unsafe {
        GetSecurityInfo(
            file.as_raw_handle(),
            SE_FILE_OBJECT,
            OWNER_SECURITY_INFORMATION | DACL_SECURITY_INFORMATION,
            &mut owner,
            ptr::null_mut(),
            &mut dacl,
            ptr::null_mut(),
            &mut descriptor,
        )
    };
    if status != ERROR_SUCCESS {
        return Err(io::Error::from_raw_os_error(status as i32));
    }
    let descriptor = LocalSecurityDescriptor(descriptor);
    if descriptor.0.is_null() || owner.is_null() || unsafe { IsValidSid(owner) } == 0 {
        return Err(invalid_security("private key has no valid owner SID"));
    }
    let mut control = 0_u16;
    let mut revision = 0_u32;
    // SAFETY: descriptor owns the valid security descriptor returned above and
    // both scalar output pointers are valid.
    if unsafe { GetSecurityDescriptorControl(descriptor.0, &mut control, &mut revision) } == 0 {
        return Err(invalid_security(
            "private key security descriptor control is unreadable",
        ));
    }
    if control & SE_DACL_PROTECTED == 0 {
        return Err(permission_denied(
            "private key must use a protected DACL that cannot inherit new access",
        ));
    }
    if !is_trusted(owner, current_user.sid()) {
        return Err(permission_denied(
            "private key owner is not the current process user, LocalSystem, or Administrators",
        ));
    }
    if dacl.is_null() {
        return Err(permission_denied("private key has a null DACL"));
    }
    // SAFETY: dacl is backed by the live descriptor and is non-null.
    if unsafe { IsValidAcl(dacl) } == 0 {
        return Err(invalid_security("private key has an invalid DACL"));
    }

    // SAFETY: IsValidAcl established that AceCount entries fit inside the ACL.
    let ace_count = unsafe { (*dacl).AceCount as u32 };
    for index in 0..ace_count {
        let mut ace = ptr::null_mut();
        // SAFETY: dacl remains live and index is below its validated AceCount.
        if unsafe { GetAce(dacl, index, &mut ace) } == 0 || ace.is_null() {
            return Err(invalid_security(
                "private key DACL contains an unreadable ACE",
            ));
        }
        // SAFETY: every validated ACE begins with ACE_HEADER, whose first byte
        // is the ACE type and whose size is checked before any SID access.
        let ace_type = unsafe { *ace.cast::<u8>() } as u32;
        match ace_type {
            ACCESS_ALLOWED_ACE_TYPE => {
                if !allow_ace_is_trusted(ace.cast(), current_user.sid())? {
                    return Err(permission_denied(
                        "private key DACL grants an untrusted principal",
                    ));
                }
            }
            ACCESS_DENIED_ACE_TYPE => {}
            _ => {
                return Err(permission_denied(
                    "private key DACL contains an unsupported ACE type",
                ));
            }
        }
    }
    Ok(())
}

fn allow_ace_is_trusted(ace: *const ACCESS_ALLOWED_ACE, current_user: PSID) -> io::Result<bool> {
    // SAFETY: the caller obtained this standard allow ACE from a valid ACL.
    let ace_size = unsafe { (*ace).Header.AceSize as usize };
    let sid_offset = core::mem::offset_of!(ACCESS_ALLOWED_ACE, SidStart);
    if ace_size < sid_offset + SID_HEADER_BYTES {
        return Err(invalid_security(
            "private key DACL contains a truncated allow ACE",
        ));
    }
    // SAFETY: the preceding size check makes the two-byte SID header readable.
    let sid_bytes = unsafe { ace.cast::<u8>().add(sid_offset) };
    let subauthority_count = unsafe { *sid_bytes.add(1) as usize };
    let sid_size = SID_HEADER_BYTES
        .checked_add(subauthority_count.saturating_mul(SID_SUBAUTHORITY_BYTES))
        .ok_or_else(|| invalid_security("private key DACL contains an impossible SID"))?;
    if sid_size > ace_size - sid_offset {
        return Err(invalid_security(
            "private key DACL contains a truncated SID",
        ));
    }
    let sid = sid_bytes.cast_mut().cast();
    // SAFETY: the complete SID fits in the validated ACE allocation.
    if unsafe { IsValidSid(sid) } == 0 {
        return Err(invalid_security("private key DACL contains an invalid SID"));
    }
    Ok(is_trusted(sid, current_user))
}

fn is_trusted(candidate: PSID, current_user: PSID) -> bool {
    // SAFETY: both SIDs were validated and remain live for these comparisons.
    unsafe {
        EqualSid(candidate, current_user) != 0
            || IsWellKnownSid(candidate, WinLocalSystemSid) != 0
            || IsWellKnownSid(candidate, WinBuiltinAdministratorsSid) != 0
    }
}

struct CurrentUserSid {
    storage: Vec<usize>,
}

impl CurrentUserSid {
    fn read() -> io::Result<Self> {
        let mut token: HANDLE = ptr::null_mut();
        // SAFETY: the current-process pseudo-handle is valid and token is a
        // valid output pointer.
        if unsafe { OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token) } == 0 {
            return Err(io::Error::last_os_error());
        }
        let token = OwnedHandle(token);
        let mut required = 0_u32;
        // SAFETY: a zero-length probe reports the required aligned buffer size.
        unsafe {
            GetTokenInformation(token.0, TokenUser, ptr::null_mut(), 0, &mut required);
        }
        if required == 0 {
            return Err(io::Error::last_os_error());
        }
        let word = size_of::<usize>();
        let mut storage = vec![0_usize; (required as usize).div_ceil(word)];
        // SAFETY: storage is aligned and at least required bytes long.
        if unsafe {
            GetTokenInformation(
                token.0,
                TokenUser,
                storage.as_mut_ptr().cast(),
                required,
                &mut required,
            )
        } == 0
        {
            return Err(io::Error::last_os_error());
        }
        let result = Self { storage };
        // SAFETY: a successful TokenUser query initializes a valid TOKEN_USER.
        if unsafe { IsValidSid(result.sid()) } == 0 {
            return Err(invalid_security(
                "current process token contains an invalid user SID",
            ));
        }
        Ok(result)
    }

    fn sid(&self) -> PSID {
        // SAFETY: storage owns a successfully initialized TOKEN_USER payload.
        unsafe { (*(self.storage.as_ptr().cast::<TOKEN_USER>())).User.Sid }
    }
}

struct OwnedHandle(HANDLE);

impl Drop for OwnedHandle {
    fn drop(&mut self) {
        // SAFETY: OpenProcessToken returned this uniquely owned handle.
        unsafe {
            CloseHandle(self.0);
        }
    }
}

struct LocalSecurityDescriptor(PSECURITY_DESCRIPTOR);

impl Drop for LocalSecurityDescriptor {
    fn drop(&mut self) {
        if !self.0.is_null() {
            // SAFETY: GetSecurityInfo allocates the descriptor with LocalAlloc.
            unsafe {
                LocalFree(self.0);
            }
        }
    }
}

fn invalid_security(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

fn permission_denied(message: &'static str) -> io::Error {
    io::Error::new(io::ErrorKind::PermissionDenied, message)
}
