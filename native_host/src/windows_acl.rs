//! Current-user-only Windows ACLs for Host-owned local state.
//!
//! Directories receive an inheritable protected DACL at creation time and are
//! tightened again when they already exist. Files are either created with a
//! protected DACL or restricted before the Host reads or writes their content.

use std::fs::{self, File, OpenOptions};
use std::io;
use std::os::windows::ffi::OsStrExt;
use std::os::windows::fs::{MetadataExt, OpenOptionsExt};
use std::os::windows::io::{AsRawHandle, FromRawHandle};
use std::path::{Path, PathBuf};
use std::ptr;
use windows_sys::Win32::Foundation::{
    CloseHandle, ERROR_SUCCESS, GENERIC_READ, GENERIC_WRITE, HANDLE, INVALID_HANDLE_VALUE,
    LocalFree,
};
use windows_sys::Win32::Security::Authorization::{
    ConvertSidToStringSidW, ConvertStringSecurityDescriptorToSecurityDescriptorW, SDDL_REVISION_1,
    SE_FILE_OBJECT, SetSecurityInfo,
};
#[cfg(test)]
use windows_sys::Win32::Security::UNPROTECTED_DACL_SECURITY_INFORMATION;
use windows_sys::Win32::Security::{
    ACL, DACL_SECURITY_INFORMATION, GetSecurityDescriptorDacl, GetTokenInformation,
    PROTECTED_DACL_SECURITY_INFORMATION, PSECURITY_DESCRIPTOR, SECURITY_ATTRIBUTES, TOKEN_QUERY,
    TOKEN_USER, TokenUser,
};
use windows_sys::Win32::Storage::FileSystem::{
    BY_HANDLE_FILE_INFORMATION, CREATE_NEW, CreateDirectoryW, CreateFileW,
    FILE_ATTRIBUTE_DIRECTORY, FILE_ATTRIBUTE_NORMAL, FILE_ATTRIBUTE_REPARSE_POINT,
    FILE_FLAG_BACKUP_SEMANTICS, FILE_FLAG_OPEN_REPARSE_POINT, FILE_SHARE_DELETE, FILE_SHARE_READ,
    FILE_SHARE_WRITE, GetFileInformationByHandle, READ_CONTROL, WRITE_DAC,
};
use windows_sys::Win32::System::Threading::{GetCurrentProcess, OpenProcessToken};

pub(crate) fn create_private_dir(path: &Path) -> io::Result<()> {
    let parent = match path.parent() {
        Some(parent) if !parent.as_os_str().is_empty() => parent,
        Some(_) => Path::new("."),
        None => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "private directory cannot be a filesystem root",
            ));
        }
    };
    if path.as_os_str().is_empty() {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "private directory path is empty",
        ));
    }
    fs::create_dir_all(parent)?;

    let creation_path = canonical_child_path(path)?;
    let descriptor = SecurityDescriptor::current_user(true)?;
    let wide_path = wide_path(&creation_path)?;
    let attributes = descriptor.attributes();
    // SAFETY: the path is NUL-terminated and the descriptor remains alive for
    // the call. The descriptor is copied by the kernel for a new directory.
    if unsafe { CreateDirectoryW(wide_path.as_ptr(), &attributes) } == 0 {
        let error = io::Error::last_os_error();
        if error.kind() != io::ErrorKind::AlreadyExists {
            return Err(error);
        }
    }
    descriptor.apply_to_directory(&creation_path)
}

pub(crate) fn protect_file(path: &Path) -> io::Result<()> {
    SecurityDescriptor::current_user(false)?.apply_to_file(path)
}

#[cfg(test)]
pub(crate) fn apply_file_sddl_for_test(path: &Path, value: &str) -> io::Result<()> {
    SecurityDescriptor::from_sddl_for_test(value)?.apply_to_file(path)
}

#[cfg(test)]
pub(crate) fn apply_unprotected_current_user_acl_for_test(path: &Path) -> io::Result<()> {
    let descriptor = SecurityDescriptor::current_user(false)?;
    let handle = open_for_security(path, false)?;
    descriptor.apply_to_handle_with_protection(
        handle.as_raw_handle(),
        UNPROTECTED_DACL_SECURITY_INFORMATION,
    )
}

pub(crate) fn protect_tree(root: &Path) -> io::Result<()> {
    let directory = SecurityDescriptor::current_user(true)?;
    let file = SecurityDescriptor::current_user(false)?;
    let mut pending = vec![root.to_owned()];
    while let Some(path) = pending.pop() {
        directory.apply_to_directory(&path)?;
        for entry in fs::read_dir(&path)? {
            let entry = entry?;
            let child = entry.path();
            let metadata = fs::symlink_metadata(&child)?;
            if metadata.file_attributes() & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
                return Err(io::Error::new(
                    io::ErrorKind::PermissionDenied,
                    "private state tree contains a reparse object",
                ));
            }
            if metadata.is_dir() {
                pending.push(child);
            } else if metadata.is_file() {
                file.apply_to_file(&child)?;
            } else {
                return Err(io::Error::new(
                    io::ErrorKind::PermissionDenied,
                    "private state tree contains an unsupported object",
                ));
            }
        }
    }
    Ok(())
}

pub(crate) fn create_private_new_file(path: &Path) -> io::Result<File> {
    let creation_path = canonical_child_path(path)?;
    let descriptor = SecurityDescriptor::current_user(false)?;
    let wide_path = wide_path(&creation_path)?;
    let attributes = descriptor.attributes();
    // SAFETY: the path is NUL-terminated and the security descriptor outlives
    // creation. CREATE_NEW refuses an attacker-created destination. The share
    // flags preserve the atomic-rename behavior used by the device registry.
    let handle = unsafe {
        CreateFileW(
            wide_path.as_ptr(),
            GENERIC_READ | GENERIC_WRITE,
            FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE,
            &attributes,
            CREATE_NEW,
            FILE_ATTRIBUTE_NORMAL,
            ptr::null_mut(),
        )
    };
    if handle == INVALID_HANDLE_VALUE {
        return Err(io::Error::last_os_error());
    }
    // SAFETY: CreateFileW returned a unique owned handle and ownership moves to
    // File exactly once.
    Ok(unsafe { File::from_raw_handle(handle) })
}

struct SecurityDescriptor(PSECURITY_DESCRIPTOR);

impl SecurityDescriptor {
    fn current_user(inherit_to_children: bool) -> io::Result<Self> {
        let sid = current_user_sid_string()?;
        let inheritance = if inherit_to_children { "OICI" } else { "" };
        Self::from_sddl(&format!("D:P(A;{inheritance};FA;;;{sid})"))
    }

    #[cfg(test)]
    fn from_sddl_for_test(value: &str) -> io::Result<Self> {
        Self::from_sddl(value)
    }

    fn from_sddl(value: &str) -> io::Result<Self> {
        let wide: Vec<u16> = value.encode_utf16().chain(Some(0)).collect();
        let mut descriptor = ptr::null_mut();
        // SAFETY: the string is NUL-terminated and the output pointer is valid.
        // Windows allocates the returned descriptor with LocalAlloc.
        if unsafe {
            ConvertStringSecurityDescriptorToSecurityDescriptorW(
                wide.as_ptr(),
                SDDL_REVISION_1,
                &mut descriptor,
                ptr::null_mut(),
            )
        } == 0
        {
            return Err(io::Error::last_os_error());
        }
        Ok(Self(descriptor))
    }

    fn attributes(&self) -> SECURITY_ATTRIBUTES {
        SECURITY_ATTRIBUTES {
            nLength: size_of::<SECURITY_ATTRIBUTES>() as u32,
            lpSecurityDescriptor: self.0,
            bInheritHandle: 0,
        }
    }

    fn apply_to_directory(&self, path: &Path) -> io::Result<()> {
        let handle = open_for_security(path, true)?;
        self.apply_to_handle(handle.as_raw_handle())
    }

    fn apply_to_file(&self, path: &Path) -> io::Result<()> {
        let handle = open_for_security(path, false)?;
        self.apply_to_handle(handle.as_raw_handle())
    }

    fn apply_to_handle(&self, handle: HANDLE) -> io::Result<()> {
        self.apply_to_handle_with_protection(handle, PROTECTED_DACL_SECURITY_INFORMATION)
    }

    fn apply_to_handle_with_protection(&self, handle: HANDLE, protection: u32) -> io::Result<()> {
        let dacl = self.dacl()?;
        // SAFETY: the handle identifies the checked file/directory and the DACL
        // is borrowed from the live descriptor. Windows retains neither pointer.
        let status = unsafe {
            SetSecurityInfo(
                handle,
                SE_FILE_OBJECT,
                DACL_SECURITY_INFORMATION | protection,
                ptr::null_mut(),
                ptr::null_mut(),
                dacl,
                ptr::null(),
            )
        };
        if status == ERROR_SUCCESS {
            Ok(())
        } else {
            Err(io::Error::from_raw_os_error(status as i32))
        }
    }

    fn dacl(&self) -> io::Result<*const ACL> {
        let mut present = 0;
        let mut defaulted = 0;
        let mut dacl = ptr::null_mut();
        // SAFETY: self owns a valid descriptor and all output pointers are valid.
        if unsafe { GetSecurityDescriptorDacl(self.0, &mut present, &mut dacl, &mut defaulted) }
            == 0
        {
            return Err(io::Error::last_os_error());
        }
        if present == 0 || dacl.is_null() {
            return Err(io::Error::new(
                io::ErrorKind::InvalidData,
                "private security descriptor has no DACL",
            ));
        }
        Ok(dacl)
    }
}

impl Drop for SecurityDescriptor {
    fn drop(&mut self) {
        // SAFETY: the Win32 security API that produced this descriptor allocated
        // it with LocalAlloc.
        unsafe {
            LocalFree(self.0);
        }
    }
}

fn current_user_sid_string() -> io::Result<String> {
    let mut token: HANDLE = ptr::null_mut();
    // SAFETY: the current-process pseudo-handle is always valid and token is a
    // valid output pointer.
    if unsafe { OpenProcessToken(GetCurrentProcess(), TOKEN_QUERY, &mut token) } == 0 {
        return Err(io::Error::last_os_error());
    }
    let token = Handle(token);

    let mut required = 0_u32;
    // SAFETY: a zero-length probe with a null buffer returns the required size.
    unsafe {
        GetTokenInformation(token.0, TokenUser, ptr::null_mut(), 0, &mut required);
    }
    if required == 0 {
        return Err(io::Error::last_os_error());
    }
    let word = size_of::<usize>();
    let mut buffer = vec![0_usize; (required as usize).div_ceil(word)];
    // SAFETY: the aligned buffer is at least `required` bytes and remains live
    // while the embedded SID pointer is used.
    if unsafe {
        GetTokenInformation(
            token.0,
            TokenUser,
            buffer.as_mut_ptr().cast(),
            required,
            &mut required,
        )
    } == 0
    {
        return Err(io::Error::last_os_error());
    }
    // SAFETY: a successful TokenUser query initializes TOKEN_USER and its SID.
    let sid = unsafe { (*(buffer.as_ptr().cast::<TOKEN_USER>())).User.Sid };
    let mut text = ptr::null_mut();
    // SAFETY: sid remains backed by buffer and text is a valid output pointer.
    if unsafe { ConvertSidToStringSidW(sid, &mut text) } == 0 {
        return Err(io::Error::last_os_error());
    }
    let text = LocalWideString(text);
    // SAFETY: ConvertSidToStringSidW returns a NUL-terminated UTF-16 string.
    let length = unsafe { (0..).take_while(|&index| *text.0.add(index) != 0).count() };
    // SAFETY: length was measured within the NUL-terminated allocation.
    String::from_utf16(unsafe { std::slice::from_raw_parts(text.0, length) })
        .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "current user SID is not UTF-16"))
}

fn wide_path(path: &Path) -> io::Result<Vec<u16>> {
    let mut value: Vec<u16> = path.as_os_str().encode_wide().collect();
    if value.contains(&0) {
        return Err(io::Error::new(
            io::ErrorKind::InvalidInput,
            "private path contains a NUL character",
        ));
    }
    value.push(0);
    Ok(value)
}

fn canonical_child_path(path: &Path) -> io::Result<PathBuf> {
    let parent = match path.parent() {
        Some(parent) if !parent.as_os_str().is_empty() => parent,
        Some(_) => Path::new("."),
        None => {
            return Err(io::Error::new(
                io::ErrorKind::InvalidInput,
                "private state path cannot be a filesystem root",
            ));
        }
    };
    let name = path.file_name().ok_or_else(|| {
        io::Error::new(
            io::ErrorKind::InvalidInput,
            "private state path must name a child object",
        )
    })?;
    Ok(fs::canonicalize(parent)?.join(name))
}

fn open_for_security(path: &Path, expect_directory: bool) -> io::Result<File> {
    let flags = FILE_FLAG_OPEN_REPARSE_POINT
        | if expect_directory {
            FILE_FLAG_BACKUP_SEMANTICS
        } else {
            0
        };
    let file = OpenOptions::new()
        .access_mode(READ_CONTROL | WRITE_DAC)
        .share_mode(FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE)
        .custom_flags(flags)
        .open(path)?;
    // SAFETY: info is an integer-only output structure and handle is valid.
    let mut info: BY_HANDLE_FILE_INFORMATION = unsafe { std::mem::zeroed() };
    if unsafe { GetFileInformationByHandle(file.as_raw_handle(), &mut info) } == 0 {
        return Err(io::Error::last_os_error());
    }
    if info.dwFileAttributes & FILE_ATTRIBUTE_REPARSE_POINT != 0 {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "private state must not be a reparse object",
        ));
    }
    let is_directory = info.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY != 0;
    if expect_directory != is_directory {
        let kind = if expect_directory {
            io::ErrorKind::NotADirectory
        } else {
            io::ErrorKind::InvalidInput
        };
        return Err(io::Error::new(
            kind,
            "private state object has the wrong type",
        ));
    }
    if !expect_directory && info.nNumberOfLinks > 1 {
        return Err(io::Error::new(
            io::ErrorKind::Unsupported,
            "private state files must not have hard links",
        ));
    }
    Ok(file)
}

struct Handle(HANDLE);

impl Drop for Handle {
    fn drop(&mut self) {
        // SAFETY: OpenProcessToken returned this owned handle.
        unsafe {
            CloseHandle(self.0);
        }
    }
}

struct LocalWideString(*mut u16);

impl Drop for LocalWideString {
    fn drop(&mut self) {
        // SAFETY: the Win32 SDDL/SID conversion API allocated this buffer with
        // LocalAlloc.
        unsafe {
            LocalFree(self.0.cast());
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;
    use windows_sys::Win32::Security::Authorization::{
        ConvertSecurityDescriptorToStringSecurityDescriptorW, ConvertStringSidToSidW,
        GetNamedSecurityInfoW,
    };
    use windows_sys::Win32::Security::{
        ACCESS_ALLOWED_ACE, CONTAINER_INHERIT_ACE, EqualSid, GetAce, GetSecurityDescriptorControl,
        OBJECT_INHERIT_ACE, PSID, SE_DACL_PROTECTED,
    };
    use windows_sys::Win32::Storage::FileSystem::FILE_ALL_ACCESS;
    use windows_sys::Win32::System::SystemServices::ACCESS_ALLOWED_ACE_TYPE;

    #[test]
    fn creates_current_user_only_directory_and_file() {
        let temp = tempfile::tempdir().unwrap();
        SecurityDescriptor::from_sddl_for_test("D:P(A;OICI;FA;;;WD)")
            .unwrap()
            .apply_to_directory(temp.path())
            .unwrap();

        let directory = temp.path().join("private");
        create_private_dir(&directory).unwrap();
        assert_private(&directory, true);

        let file_path = directory.join("secret.json");
        drop(create_private_new_file(&file_path).unwrap());
        assert_private(&file_path, false);
    }

    #[test]
    fn tightens_existing_directory_and_file() {
        let temp = tempfile::tempdir().unwrap();
        let directory = temp.path().join("existing");
        fs::create_dir(&directory).unwrap();
        let file_path = directory.join("secret.json");
        fs::write(&file_path, b"secret").unwrap();
        let permissive = SecurityDescriptor::from_sddl_for_test("D:P(A;OICI;FA;;;WD)").unwrap();
        permissive.apply_to_directory(&directory).unwrap();
        SecurityDescriptor::from_sddl_for_test("D:P(A;;FA;;;WD)")
            .unwrap()
            .apply_to_file(&file_path)
            .unwrap();
        assert!(dacl_sddl(&file_path).unwrap().contains("WD"));

        create_private_dir(&directory).unwrap();
        protect_tree(&directory).unwrap();
        assert_private(&directory, true);
        assert_private(&file_path, false);
    }

    #[test]
    fn rejects_hard_linked_private_files() {
        let temp = tempfile::tempdir().unwrap();
        let file_path = temp.path().join("secret.json");
        let alias_path = temp.path().join("secret-alias.json");
        fs::write(&file_path, b"secret").unwrap();
        fs::hard_link(&file_path, &alias_path).unwrap();

        let error = protect_file(&file_path).expect_err("hard-linked state must fail closed");
        assert_eq!(error.kind(), io::ErrorKind::Unsupported);
    }

    fn assert_private(path: &Path, directory: bool) {
        let descriptor = named_security_descriptor(path).unwrap();
        let diagnostic = dacl_sddl(path).unwrap();
        let mut control = 0_u16;
        let mut revision = 0_u32;
        // SAFETY: descriptor is valid and both output pointers are initialized.
        assert_ne!(
            unsafe { GetSecurityDescriptorControl(descriptor.0, &mut control, &mut revision) },
            0,
            "cannot read DACL control: {diagnostic}"
        );
        assert_ne!(
            control & SE_DACL_PROTECTED,
            0,
            "unprotected DACL: {diagnostic}"
        );

        let dacl = descriptor.dacl().unwrap();
        // SAFETY: the DACL is borrowed from the live security descriptor.
        assert_eq!(
            unsafe { (*dacl).AceCount },
            1,
            "unexpected ACE count: {diagnostic}"
        );
        let mut raw_ace = ptr::null_mut();
        // SAFETY: the DACL has exactly one ACE and raw_ace is a valid output.
        assert_ne!(
            unsafe { GetAce(dacl, 0, &mut raw_ace) },
            0,
            "cannot read the private ACE: {diagnostic}"
        );
        // SAFETY: SDDL created a standard access-allowed ACE and GetAce returned
        // a pointer into the live descriptor.
        let ace = unsafe { &*raw_ace.cast::<ACCESS_ALLOWED_ACE>() };
        assert_eq!(
            u32::from(ace.Header.AceType),
            ACCESS_ALLOWED_ACE_TYPE,
            "private ACE is not access-allowed: {diagnostic}"
        );
        assert_eq!(
            ace.Mask, FILE_ALL_ACCESS,
            "private ACE is not full access: {diagnostic}"
        );

        let expected_sid = local_sid(&current_user_sid_string().unwrap()).unwrap();
        let actual_sid = ptr::addr_of!(ace.SidStart).cast_mut().cast();
        // SAFETY: actual_sid points at the variable-length SID embedded directly
        // after the fixed ACCESS_ALLOWED_ACE fields; both SIDs remain alive.
        assert_ne!(
            unsafe { EqualSid(actual_sid, expected_sid.0) },
            0,
            "private ACE does not target the current user: {diagnostic}"
        );

        let flags = u32::from(ace.Header.AceFlags);
        let inheritance = OBJECT_INHERIT_ACE | CONTAINER_INHERIT_ACE;
        if directory {
            assert_eq!(
                flags & inheritance,
                inheritance,
                "directory ACE misses inheritance: {diagnostic}"
            );
        } else {
            assert_eq!(
                flags & inheritance,
                0,
                "file ACE unexpectedly inherits to children: {diagnostic}"
            );
        }
    }

    fn named_security_descriptor(path: &Path) -> io::Result<SecurityDescriptor> {
        let wide_path = wide_path(path)?;
        let mut descriptor = ptr::null_mut();
        // SAFETY: the path is NUL-terminated and descriptor is an output pointer.
        let status = unsafe {
            GetNamedSecurityInfoW(
                wide_path.as_ptr(),
                SE_FILE_OBJECT,
                DACL_SECURITY_INFORMATION,
                ptr::null_mut(),
                ptr::null_mut(),
                ptr::null_mut(),
                ptr::null_mut(),
                &mut descriptor,
            )
        };
        if status != ERROR_SUCCESS {
            return Err(io::Error::from_raw_os_error(status as i32));
        }
        Ok(SecurityDescriptor(descriptor))
    }

    fn dacl_sddl(path: &Path) -> io::Result<String> {
        let descriptor = named_security_descriptor(path)?;
        let mut text = ptr::null_mut();
        // SAFETY: descriptor is valid and text is an output pointer.
        if unsafe {
            ConvertSecurityDescriptorToStringSecurityDescriptorW(
                descriptor.0,
                SDDL_REVISION_1,
                DACL_SECURITY_INFORMATION,
                &mut text,
                ptr::null_mut(),
            )
        } == 0
        {
            return Err(io::Error::last_os_error());
        }
        let text = LocalWideString(text);
        // SAFETY: the API returned a NUL-terminated UTF-16 string.
        let length = unsafe { (0..).take_while(|&index| *text.0.add(index) != 0).count() };
        // SAFETY: length is inside the allocation measured above.
        String::from_utf16(unsafe { std::slice::from_raw_parts(text.0, length) })
            .map_err(|_| io::Error::new(io::ErrorKind::InvalidData, "DACL SDDL is not UTF-16"))
    }

    fn local_sid(value: &str) -> io::Result<LocalSid> {
        let wide: Vec<u16> = value.encode_utf16().chain(Some(0)).collect();
        let mut sid = ptr::null_mut();
        // SAFETY: value is NUL-terminated and sid is a valid output pointer.
        if unsafe { ConvertStringSidToSidW(wide.as_ptr(), &mut sid) } == 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(LocalSid(sid))
    }

    struct LocalSid(PSID);

    impl Drop for LocalSid {
        fn drop(&mut self) {
            // SAFETY: ConvertStringSidToSidW allocated this SID with LocalAlloc.
            unsafe {
                LocalFree(self.0);
            }
        }
    }
}
