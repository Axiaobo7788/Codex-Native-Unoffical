#!/usr/bin/env bash
set -euo pipefail

repository_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cargo_executable="${CARGO_EXECUTABLE:-cargo}"
expected_version="cargo-about 0.9.3"
output_file="${repository_root}/licenses/NATIVE_HOST_THIRD_PARTY_LICENSES.txt"
temporary_file="$(mktemp)"

cleanup() {
  if [[ -f "${temporary_file}" ]]; then
    unlink "${temporary_file}"
  fi
}
trap cleanup EXIT

actual_version="$(${cargo_executable} about --version 2>/dev/null || true)"
if [[ "${actual_version}" != "${expected_version}" ]]; then
  echo "error: ${expected_version} is required; found '${actual_version:-missing}'" >&2
  echo "install it with: cargo install --locked --version 0.9.3 --features cli cargo-about" >&2
  exit 2
fi

"${cargo_executable}" about generate \
  --locked \
  --workspace \
  --fail \
  --manifest-path "${repository_root}/Cargo.toml" \
  --config "${repository_root}/licenses/about.toml" \
  --output-file "${temporary_file}" \
  "${repository_root}/licenses/native-host-licenses.hbs"

# Upstream license files legitimately use mixed platform line endings and some
# carry trailing horizontal whitespace. Normalize only those representation
# details so the reviewed generated artifact is deterministic and passes the
# repository whitespace gate without changing license prose.
perl -0777 -pi -e 's/\r\n?/\n/g; s/[ \t]+(?=\n)//g; s/\n*\z/\n/' \
  "${temporary_file}"

case "${1:---check}" in
  --write)
    install -m 644 "${temporary_file}" "${output_file}"
    ;;
  --check)
    if [[ ! -f "${output_file}" ]]; then
      echo "error: generated native Host license bundle is missing" >&2
      echo "run: ./tool/generate_native_licenses.sh --write" >&2
      exit 1
    fi
    if ! cmp -s "${temporary_file}" "${output_file}"; then
      echo "error: generated native Host license bundle is stale" >&2
      diff -u "${output_file}" "${temporary_file}" || true
      echo "run: ./tool/generate_native_licenses.sh --write" >&2
      exit 1
    fi
    ;;
  *)
    echo "usage: $0 [--check|--write]" >&2
    exit 2
    ;;
esac
