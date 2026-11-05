#!/bin/bash
set -euo pipefail

repository_root="${SRCROOT}/.."
target_dir="${DERIVED_FILE_DIR}/codex_native_host_target"
profile="debug"
cargo_arguments=(build --locked)
if [[ "${CONFIGURATION}" != "Debug" ]]; then
  profile="release"
  cargo_arguments+=(--release)
fi

cargo_executable="$(command -v cargo || true)"
if [[ -z "${cargo_executable}" && -x "${HOME}/.cargo/bin/cargo" ]]; then
  cargo_executable="${HOME}/.cargo/bin/cargo"
fi
if [[ -z "${cargo_executable}" ]]; then
  echo "error: cargo is required to build codex-native-host" >&2
  exit 1
fi

"${cargo_executable}" "${cargo_arguments[@]}" \
  --manifest-path "${repository_root}/Cargo.toml" \
  --target-dir "${target_dir}"

destination_dir="${TARGET_BUILD_DIR}/${EXECUTABLE_FOLDER_PATH}"
destination="${destination_dir}/codex-native-host"
mkdir -p "${destination_dir}"
install -m 755 "${target_dir}/${profile}/codex-native-host" "${destination}"

license_source="${repository_root}/licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt"
resources_dir="${TARGET_BUILD_DIR}/${UNLOCALIZED_RESOURCES_FOLDER_PATH}"
mkdir -p "${resources_dir}"
install -m 644 "${license_source}" \
  "${resources_dir}/NATIVE_HOST_THIRD_PARTY_LICENSES.txt"

if [[ "${CODE_SIGNING_ALLOWED:-NO}" == "YES" ]]; then
  signing_identity="${EXPANDED_CODE_SIGN_IDENTITY:-}"
  if [[ -z "${signing_identity}" ]]; then
    signing_identity="-"
  fi
  signing_arguments=(--force --sign "${signing_identity}")
  if [[ "${CONFIGURATION}" != "Debug" ]]; then
    signing_arguments+=(--options runtime)
  fi
  signing_arguments+=(
    --identifier "${PRODUCT_BUNDLE_IDENTIFIER}.codex-native-host"
    "${destination}"
  )
  /usr/bin/codesign "${signing_arguments[@]}"
fi
