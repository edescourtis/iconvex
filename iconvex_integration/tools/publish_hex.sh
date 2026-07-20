#!/usr/bin/env bash
set -Eeuo pipefail

EXPECTED_HEX_USER="eric.descourtis"
EXPECTED_GITHUB_REPOSITORY="edescourtis/iconvex"
EXPECTED_GITHUB_URL="https://github.com/${EXPECTED_GITHUB_REPOSITORY}"
EXPECTED_VERSION="0.1.0"
EXPECTED_ELIXIR_VERSION="1.19.5"
EXPECTED_OTP_VERSION="28"
EXPECTED_HEX_VERSION="2.2.1"
EXPECTED_MANIFEST_SHA256="20952bda49efd909ec11b761d66d079e2a9563b41124c5b3099d36458f6a7636"
DEFAULT_ASDF_DATA_DIR="${ASDF_DATA_DIR:-${HOME}/.asdf}"
DEFAULT_ELIXIR_BIN="${DEFAULT_ASDF_DATA_DIR}/installs/elixir/1.19.5-otp-28/bin/elixir"
DEFAULT_MIX_BIN="${DEFAULT_ASDF_DATA_DIR}/installs/elixir/1.19.5-otp-28/bin/mix"
DEFAULT_ERLANG_BIN_DIR="${DEFAULT_ASDF_DATA_DIR}/installs/erlang/28.3/bin"
DRY_RUN_COMMAND="mix hex.publish package --dry-run --yes"
PUBLISH_COMMAND="mix hex.publish package --yes"

PACKAGES=(
  iconvex
  iconvex_specs_icu_archive_a
  iconvex_specs_icu_archive_b
  iconvex_specs_icu_archive_c
  iconvex_extras
  iconvex_telecom
  iconvex_specs
)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DEFAULT_WORKSPACE="$(cd "${SCRIPT_DIR}/../.." && pwd)"
DEFAULT_RELEASE_ROOT="${DEFAULT_WORKSPACE}/iconvex_release_0.1.0"
WORKSPACE="${ICONVEX_PUBLISH_WORKSPACE:-${DEFAULT_WORKSPACE}}"
RELEASE_ROOT="${ICONVEX_RELEASE_ROOT:-${DEFAULT_RELEASE_ROOT}}"
ELIXIR_BIN="${ICONVEX_PUBLISH_ELIXIR_BIN:-${DEFAULT_ELIXIR_BIN}}"
MIX_BIN="${ICONVEX_PUBLISH_MIX_BIN:-${DEFAULT_MIX_BIN}}"
ERLANG_BIN_DIR="${ICONVEX_PUBLISH_ERLANG_BIN_DIR:-${DEFAULT_ERLANG_BIN_DIR}}"
CURL_BIN="${ICONVEX_PUBLISH_CURL_BIN:-}"
JQ_BIN="${ICONVEX_PUBLISH_JQ_BIN:-}"
VERIFY_ATTEMPTS="${ICONVEX_HEX_VERIFY_ATTEMPTS:-12}"
VERIFY_DELAY_SECONDS="${ICONVEX_HEX_VERIFY_DELAY_SECONDS:-2}"
PUBLISH=false
PREFLIGHT_DIR=""

usage() {
  cat <<EOF
Usage: $(basename "$0") [--publish] [--release-root PATH] [--workspace PATH]

Default: verify all seven source packages and candidate tarballs, then run Hex
dry-runs. Nothing is published.

Live release:
  $(basename "$0") --publish

After every preflight passes, type this exact confirmation:
  publish Iconvex ${EXPECTED_VERSION} as ${EXPECTED_HEX_USER}

Non-interactive opt-in requires both --publish and:
  ICONVEX_HEX_PUBLISH_CONFIRM='publish Iconvex ${EXPECTED_VERSION} as ${EXPECTED_HEX_USER}'

Environment overrides:
  ICONVEX_RELEASE_ROOT              candidate root (default: ${DEFAULT_RELEASE_ROOT})
  ICONVEX_PUBLISH_WORKSPACE         parent of seven package source directories
  ICONVEX_PUBLISH_ELIXIR_BIN        pinned Elixir executable
  ICONVEX_PUBLISH_MIX_BIN           pinned Mix executable
  ICONVEX_PUBLISH_ERLANG_BIN_DIR    pinned Erlang bin directory
  ICONVEX_PUBLISH_CURL_BIN          curl executable used for Hex API reads
  ICONVEX_PUBLISH_JQ_BIN            jq executable used for Hex API validation
  ICONVEX_HEX_VERIFY_ATTEMPTS       post-publish API attempts (default: 12)
  ICONVEX_HEX_VERIFY_DELAY_SECONDS  delay between attempts (default: 2)

Expected Hex owner: ${EXPECTED_HEX_USER}
Expected GitHub repository: ${EXPECTED_GITHUB_URL}
Package version: ${EXPECTED_VERSION}
Package order: ${PACKAGES[*]}

The integration project is never published. API keys are never read or printed
by this script; Hex CLI uses its normal authentication configuration.
EOF
}

fail() {
  printf 'ERROR: %s\n' "$*" >&2
  exit 1
}

info() {
  printf '%s\n' "$*"
}

cleanup() {
  if [[ -n "${PREFLIGHT_DIR}" && -d "${PREFLIGHT_DIR}" ]]; then
    rm -rf "${PREFLIGHT_DIR}"
  fi
}

trap cleanup EXIT

while [[ $# -gt 0 ]]; do
  case "$1" in
    --publish)
      PUBLISH=true
      shift
      ;;
    --release-root)
      [[ $# -ge 2 ]] || fail "--release-root requires a path"
      RELEASE_ROOT="$2"
      shift 2
      ;;
    --workspace)
      [[ $# -ge 2 ]] || fail "--workspace requires a path"
      WORKSPACE="$2"
      shift 2
      ;;
    -h | --help)
      usage
      exit 0
      ;;
    *)
      fail "unknown argument: $1"
      ;;
  esac
done

[[ -x "${ELIXIR_BIN}" ]] || fail "Elixir executable is missing or not executable: ${ELIXIR_BIN}"
[[ -x "${MIX_BIN}" ]] || fail "Mix executable is missing or not executable: ${MIX_BIN}"
[[ -d "${ERLANG_BIN_DIR}" ]] || fail "Erlang bin directory is missing: ${ERLANG_BIN_DIR}"

ELIXIR_BIN_DIR="$(dirname "${ELIXIR_BIN}")"
export PATH="${ELIXIR_BIN_DIR}:${ERLANG_BIN_DIR}:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"
export ERL_FLAGS="+S 8:8"
export MIX_ENV="prod"
export HEX_API_URL="https://hex.pm/api"
export HEX_UNSAFE_HTTPS="0"
export HEX_UNSAFE_REGISTRY="0"
export HEX_NO_VERIFY_REPO_ORIGIN="0"

if [[ -z "${CURL_BIN}" ]]; then
  CURL_BIN="$(command -v curl || true)"
fi
if [[ -z "${JQ_BIN}" ]]; then
  JQ_BIN="$(command -v jq || true)"
fi

[[ -x "${CURL_BIN}" ]] || fail "curl is missing or not executable: ${CURL_BIN:-not found}"
[[ -x "${JQ_BIN}" ]] || fail "jq is missing or not executable: ${JQ_BIN:-not found}"
[[ "${VERIFY_ATTEMPTS}" =~ ^[1-9][0-9]*$ ]] ||
  fail "ICONVEX_HEX_VERIFY_ATTEMPTS must be a positive integer"
[[ "${VERIFY_DELAY_SECONDS}" =~ ^[0-9]+$ ]] ||
  fail "ICONVEX_HEX_VERIFY_DELAY_SECONDS must be a non-negative integer"

toolchain="$("${ELIXIR_BIN}" --version 2>&1)" || fail "could not execute pinned Elixir"
[[ "${toolchain}" == *"Elixir ${EXPECTED_ELIXIR_VERSION}"* ]] ||
  fail "Elixir version mismatch; expected ${EXPECTED_ELIXIR_VERSION}"
[[ "${toolchain}" == *"Erlang/OTP ${EXPECTED_OTP_VERSION}"* ]] ||
  fail "OTP version mismatch; expected ${EXPECTED_OTP_VERSION}"

[[ -d "${WORKSPACE}" ]] || fail "workspace does not exist: ${WORKSPACE}"
[[ -d "${RELEASE_ROOT}/tarballs" ]] || fail "candidate tarball directory is missing"
MANIFEST="${RELEASE_ROOT}/manifests/SHA256SUMS"
[[ -f "${MANIFEST}" ]] || fail "candidate SHA256SUMS is missing: ${MANIFEST}"

for package in "${PACKAGES[@]}"; do
  [[ -f "${WORKSPACE}/${package}/mix.exs" ]] || fail "package source is missing: ${package}"
done

is_expected_filename() {
  local candidate="$1"
  local package

  for package in "${PACKAGES[@]}"; do
    if [[ "${candidate}" == "${package}-${EXPECTED_VERSION}.tar" ]]; then
      return 0
    fi
  done

  return 1
}

sha256_file() {
  local path="$1"

  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "${path}" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "${path}" | awk '{print $1}'
  else
    fail "neither sha256sum nor shasum is available"
  fi
}

run_source_mix() {
  local package="$1"
  shift

  (
    cd "${WORKSPACE}/${package}"
    unset ICONVEX_PATH ICONVEX_ARCHIVE_PATH
    "${MIX_BIN}" "$@"
  )
}

hex_cli_output="$(run_source_mix iconvex hex --version 2>&1)" ||
  fail "could not read pinned Hex archive version"
hex_version="$(printf '%s\n' "${hex_cli_output}" | sed -n 's/^Hex v\([0-9][0-9.]*\)$/\1/p' | head -n 1)"
[[ "${hex_version}" == "${EXPECTED_HEX_VERSION}" ]] ||
  fail "Hex version mismatch; expected ${EXPECTED_HEX_VERSION}, got ${hex_version:-unknown}"
info "Hex archive verified: ${EXPECTED_HEX_VERSION}"

PREFLIGHT_DIR="$(mktemp -d "${TMPDIR:-/tmp}/iconvex-hex-preflight.XXXXXX")"
FROZEN_WORKSPACE="${PREFLIGHT_DIR}/source"
mkdir -p "${FROZEN_WORKSPACE}"

for package in "${PACKAGES[@]}"; do
  frozen_package_root="${FROZEN_WORKSPACE}/${package}"
  info "freezing package source: ${package}"
  run_source_mix "${package}" hex.build --unpack --output "${frozen_package_root}"
  [[ -f "${frozen_package_root}/mix.exs" ]] ||
    fail "frozen package source is missing mix.exs: ${package}"

  if find "${frozen_package_root}" -type l -print -quit | grep -q .; then
    fail "frozen package source contains a symbolic link: ${package}"
  fi
done

manifest_checksum="$(sha256_file "${MANIFEST}")"
[[ "${manifest_checksum}" == "${EXPECTED_MANIFEST_SHA256}" ]] ||
  fail "candidate SHA256SUMS digest mismatch: expected ${EXPECTED_MANIFEST_SHA256}"
info "candidate SHA256SUMS verified: ${manifest_checksum}"

manifest_entries=0
while read -r checksum filename extra; do
  [[ -n "${checksum:-}" ]] || continue
  [[ -z "${extra:-}" ]] || fail "malformed candidate SHA256SUMS entry"
  [[ "${checksum}" =~ ^[0-9a-f]{64}$ ]] || fail "malformed candidate SHA-256: ${checksum}"
  is_expected_filename "${filename}" || fail "unexpected candidate manifest file: ${filename}"

  candidate="${RELEASE_ROOT}/tarballs/${filename}"
  [[ -f "${candidate}" ]] || fail "candidate tarball is missing: ${filename}"
  actual_checksum="$(sha256_file "${candidate}")"
  [[ "${actual_checksum}" == "${checksum}" ]] || fail "candidate SHA-256 mismatch: ${filename}"
  manifest_entries=$((manifest_entries + 1))
done < "${MANIFEST}"

[[ "${manifest_entries}" -eq "${#PACKAGES[@]}" ]] ||
  fail "candidate SHA256SUMS must contain exactly ${#PACKAGES[@]} entries"

candidate_tar_count="$(find "${RELEASE_ROOT}/tarballs" -maxdepth 1 -type f -name '*.tar' | wc -l | tr -d ' ')"
[[ "${candidate_tar_count}" -eq "${#PACKAGES[@]}" ]] ||
  fail "candidate tarball directory must contain exactly ${#PACKAGES[@]} tarballs"

for candidate in "${RELEASE_ROOT}"/tarballs/*.tar; do
  is_expected_filename "$(basename "${candidate}")" ||
    fail "unexpected candidate tarball: $(basename "${candidate}")"
done

manifest_hash_for() {
  local filename="$1"
  awk -v filename="${filename}" '$2 == filename {print $1}' "${MANIFEST}"
}

api_status_for() {
  local state_root="$1"
  local package="$2"
  local resource="$3"

  tr -d '\r\n' < "${state_root}/${package}.${resource}.status"
}

api_body_for() {
  local state_root="$1"
  local package="$2"
  local resource="$3"

  printf '%s/%s.%s.body\n' "${state_root}" "${package}" "${resource}"
}

fetch_api_resource() {
  local state_root="$1"
  local package="$2"
  local resource="$3"
  local url="$4"
  local body
  local status
  local curl_status

  body="$(api_body_for "${state_root}" "${package}" "${resource}")"
  : > "${body}"

  if status="$(
    "${CURL_BIN}" \
      --silent \
      --show-error \
      --tlsv1.2 \
      --header 'Accept: application/json' \
      --header 'Cache-Control: no-cache' \
      --connect-timeout 10 \
      --max-time 30 \
      --output "${body}" \
      --write-out '%{http_code}' \
      "${url}"
  )"; then
    :
  else
    curl_status=$?
    status="curl-exit-${curl_status}"
  fi

  printf '%s\n' "${status}" > "${state_root}/${package}.${resource}.status"
}

collect_remote_states() {
  local state_root="$1"
  local package

  mkdir -p "${state_root}"

  # Collection and validation are deliberately separate. Even a bad state for
  # an early package cannot prevent the other six read-only preflight queries.
  for package in "${PACKAGES[@]}"; do
    fetch_api_resource \
      "${state_root}" \
      "${package}" \
      package \
      "${HEX_API_URL}/packages/${package}"
    fetch_api_resource \
      "${state_root}" \
      "${package}" \
      release \
      "${HEX_API_URL}/packages/${package}/releases/${EXPECTED_VERSION}"
  done
}

REMOTE_VALIDATION_ERROR=""
REMOTE_RELEASE_PRESENT=false

validate_remote_state() {
  local state_root="$1"
  local package="$2"
  local expected_tar_sha256="$3"
  local require_release="$4"
  local package_status
  local release_status
  local package_body
  local release_body
  local publisher
  local release_checksum
  local release_version

  REMOTE_VALIDATION_ERROR=""
  REMOTE_RELEASE_PRESENT=false
  package_status="$(api_status_for "${state_root}" "${package}" package)"
  release_status="$(api_status_for "${state_root}" "${package}" release)"
  package_body="$(api_body_for "${state_root}" "${package}" package)"
  release_body="$(api_body_for "${state_root}" "${package}" release)"

  case "${package_status}" in
    200)
      if ! "${JQ_BIN}" -e --arg package "${package}" \
        ".name == \$package and (.owners | type == \"array\")" \
        "${package_body}" >/dev/null 2>&1; then
        REMOTE_VALIDATION_ERROR="invalid Hex API package response: ${package}"
        return 1
      fi

      if ! "${JQ_BIN}" -e --arg user "${EXPECTED_HEX_USER}" \
        "any(.owners[]?; .username == \$user)" \
        "${package_body}" >/dev/null 2>&1; then
        REMOTE_VALIDATION_ERROR="remote package ownership collision: ${package}; expected owner ${EXPECTED_HEX_USER}"
        return 1
      fi
      ;;
    404)
      ;;
    *)
      REMOTE_VALIDATION_ERROR="Hex API package query failed for ${package}: HTTP ${package_status}"
      return 1
      ;;
  esac

  case "${release_status}" in
    200)
      if [[ "${package_status}" != "200" ]]; then
        REMOTE_VALIDATION_ERROR="Hex API returned release without package: ${package} ${EXPECTED_VERSION}"
        return 1
      fi

      if ! release_version="$("${JQ_BIN}" -er '.version | select(type == "string")' "${release_body}")"; then
        REMOTE_VALIDATION_ERROR="invalid Hex API release response: ${package} ${EXPECTED_VERSION}"
        return 1
      fi
      if ! publisher="$("${JQ_BIN}" -er '.publisher.username | select(type == "string")' "${release_body}")"; then
        REMOTE_VALIDATION_ERROR="remote release publisher mismatch: ${package} ${EXPECTED_VERSION}; expected ${EXPECTED_HEX_USER}, got missing"
        return 1
      fi
      if ! release_checksum="$("${JQ_BIN}" -er '.checksum | select(type == "string")' "${release_body}")"; then
        REMOTE_VALIDATION_ERROR="remote release checksum mismatch: ${package} ${EXPECTED_VERSION}; checksum missing"
        return 1
      fi

      if [[ "${release_version}" != "${EXPECTED_VERSION}" ]]; then
        REMOTE_VALIDATION_ERROR="remote release version mismatch: ${package}; expected ${EXPECTED_VERSION}, got ${release_version}"
        return 1
      fi
      if [[ "${publisher}" != "${EXPECTED_HEX_USER}" ]]; then
        REMOTE_VALIDATION_ERROR="remote release publisher mismatch: ${package} ${EXPECTED_VERSION}; expected ${EXPECTED_HEX_USER}, got ${publisher}"
        return 1
      fi
      # Hex API release `checksum` is the SHA-256 of the complete outer package
      # tar. It is intentionally distinct from that tar's embedded CHECKSUM.
      if [[ "${release_checksum}" != "${expected_tar_sha256}" ]]; then
        REMOTE_VALIDATION_ERROR="remote release checksum mismatch: ${package} ${EXPECTED_VERSION}; expected ${expected_tar_sha256}, got ${release_checksum}"
        return 1
      fi

      REMOTE_RELEASE_PRESENT=true
      ;;
    404)
      if [[ "${require_release}" == true ]]; then
        REMOTE_VALIDATION_ERROR="remote release is not yet visible: ${package} ${EXPECTED_VERSION}"
        return 1
      fi
      ;;
    *)
      REMOTE_VALIDATION_ERROR="Hex API release query failed for ${package} ${EXPECTED_VERSION}: HTTP ${release_status}"
      return 1
      ;;
  esac
}

verify_published_release() {
  local package="$1"
  local expected_tar_sha256="$2"
  local attempt=1
  local state_root

  while [[ "${attempt}" -le "${VERIFY_ATTEMPTS}" ]]; do
    state_root="${PREFLIGHT_DIR}/hex-api-postpublish/${package}/${attempt}"
    mkdir -p "${state_root}"
    fetch_api_resource \
      "${state_root}" \
      "${package}" \
      package \
      "${HEX_API_URL}/packages/${package}"
    fetch_api_resource \
      "${state_root}" \
      "${package}" \
      release \
      "${HEX_API_URL}/packages/${package}/releases/${EXPECTED_VERSION}"

    if validate_remote_state "${state_root}" "${package}" "${expected_tar_sha256}" true; then
      info "post-publish Hex API verified: ${package} ${EXPECTED_VERSION} ${expected_tar_sha256} publisher=${EXPECTED_HEX_USER}"
      return 0
    fi

    if [[ "${attempt}" -lt "${VERIFY_ATTEMPTS}" ]]; then
      sleep "${VERIFY_DELAY_SECONDS}"
    fi
    attempt=$((attempt + 1))
  done

  fail "post-publish verification failed for ${package}: ${REMOTE_VALIDATION_ERROR}"
}

run_frozen_mix() {
  local package="$1"
  shift

  (
    cd "${FROZEN_WORKSPACE}/${package}"
    unset ICONVEX_PATH ICONVEX_ARCHIVE_PATH
    export MIX_BUILD_PATH="${PREFLIGHT_DIR}/mix-build/${package}"
    "${MIX_BIN}" "$@"
  )
}

PROJECT_PROBE='config = Mix.Project.config(); package = Keyword.get(config, :package, []); links = Keyword.get(package, :links, %{}); IO.puts("ICONVEX_APP=#{config[:app]}"); IO.puts("ICONVEX_VERSION=#{config[:version]}"); IO.puts("ICONVEX_SOURCE_URL=#{config[:source_url] || ""}"); links |> Map.values() |> Enum.filter(&(is_binary(&1) and String.contains?(String.downcase(&1), "github.com"))) |> Enum.each(&IO.puts("ICONVEX_GITHUB_URL=#{&1}"))'

for package in "${PACKAGES[@]}"; do
  probe_output="$(run_frozen_mix "${package}" run --no-deps-check --no-compile --no-start -e "${PROJECT_PROBE}")" ||
    fail "could not read Mix metadata: ${package}"
  app="$(printf '%s\n' "${probe_output}" | sed -n 's/^ICONVEX_APP=//p')"
  version="$(printf '%s\n' "${probe_output}" | sed -n 's/^ICONVEX_VERSION=//p')"
  source_url="$(printf '%s\n' "${probe_output}" | sed -n 's/^ICONVEX_SOURCE_URL=//p')"

  [[ "${app}" == "${package}" ]] || fail "Mix app mismatch for ${package}: ${app}"
  [[ "${version}" == "${EXPECTED_VERSION}" ]] ||
    fail "Mix version mismatch for ${package}: expected ${EXPECTED_VERSION}, got ${version}"
  [[ "${source_url}" == "${EXPECTED_GITHUB_URL}" ]] ||
    fail "Mix source_url mismatch for ${package}: expected ${EXPECTED_GITHUB_URL}"

  github_urls="$(printf '%s\n' "${probe_output}" | sed -n 's/^ICONVEX_GITHUB_URL=//p')"
  printf '%s\n' "${github_urls}" | grep -Fxq "${EXPECTED_GITHUB_URL}" ||
    fail "GitHub package link missing or mismatched for ${package}: expected ${EXPECTED_GITHUB_URL}"
  info "metadata ${package}: exact source_url and GitHub package link verified"
done

whoami_output="$(run_frozen_mix iconvex hex.user whoami 2>&1)" ||
  fail "Hex authentication check failed"
if ! printf '%s\n' "${whoami_output}" |
  grep -Eq "^(Username:[[:space:]]*)?eric[.]descourtis[[:space:]]*$"; then
  fail "authenticated Hex user mismatch; expected ${EXPECTED_HEX_USER}"
fi
info "Hex owner verified: ${EXPECTED_HEX_USER}"

VERIFIED_ARTIFACT_DIR="${PREFLIGHT_DIR}/verified-artifacts"
mkdir -p "${VERIFIED_ARTIFACT_DIR}"

for package in "${PACKAGES[@]}"; do
  filename="${package}-${EXPECTED_VERSION}.tar"
  built_tar="${VERIFIED_ARTIFACT_DIR}/${filename}"
  expected_checksum="$(manifest_hash_for "${filename}")"

  [[ "$(printf '%s\n' "${expected_checksum}" | wc -l | tr -d ' ')" == "1" ]] ||
    fail "candidate manifest entry is missing or duplicated: ${filename}"
  run_frozen_mix "${package}" hex.build --output "${built_tar}"
  built_checksum="$(sha256_file "${built_tar}")"
  [[ "${built_checksum}" == "${expected_checksum}" ]] ||
    fail "source build differs from final candidate: ${filename}"
  info "source artifact verified: ${filename} ${built_checksum}"
done

for package in "${PACKAGES[@]}"; do
  info "preflight ${package}: ${DRY_RUN_COMMAND}"
  run_frozen_mix "${package}" hex.publish package --dry-run --yes
done

REMOTE_PREFLIGHT_DIR="${PREFLIGHT_DIR}/hex-api-preflight"
REMOTE_SKIP_FILE="${PREFLIGHT_DIR}/already-published-packages"
: > "${REMOTE_SKIP_FILE}"
info "querying all seven package and release states: ${HEX_API_URL}"
collect_remote_states "${REMOTE_PREFLIGHT_DIR}"

for package in "${PACKAGES[@]}"; do
  filename="${package}-${EXPECTED_VERSION}.tar"
  candidate_tar_sha256="$(manifest_hash_for "${filename}")"

  if ! validate_remote_state \
    "${REMOTE_PREFLIGHT_DIR}" \
    "${package}" \
    "${candidate_tar_sha256}" \
    false; then
    fail "${REMOTE_VALIDATION_ERROR}"
  fi

  if [[ "${REMOTE_RELEASE_PRESENT}" == true ]]; then
    printf '%s\n' "${package}" >> "${REMOTE_SKIP_FILE}"
    info "remote release verified as resumable: ${package} ${EXPECTED_VERSION} ${candidate_tar_sha256}"
  else
    info "remote package version available: ${package} ${EXPECTED_VERSION}"
  fi
done

if [[ "${PUBLISH}" != true ]]; then
  info "DRY RUN COMPLETE: no package published"
  exit 0
fi

required_confirmation="publish Iconvex ${EXPECTED_VERSION} as ${EXPECTED_HEX_USER}"
confirmation="${ICONVEX_HEX_PUBLISH_CONFIRM:-}"

if [[ -z "${confirmation}" && -t 0 ]]; then
  printf 'Type exact confirmation to publish all seven packages:\n  %s\n> ' "${required_confirmation}" >&2
  IFS= read -r confirmation
fi

[[ "${confirmation}" == "${required_confirmation}" ]] ||
  fail "live publish confirmation required; no package published"
unset ICONVEX_HEX_PUBLISH_CONFIRM confirmation

info "LIVE PUBLISH: owner=${EXPECTED_HEX_USER} version=${EXPECTED_VERSION} packages=${#PACKAGES[@]}"
LIVE_REVERIFY_DIR="${PREFLIGHT_DIR}/live-reverify"
mkdir -p "${LIVE_REVERIFY_DIR}"
published_count=0
skipped_count=0

for package in "${PACKAGES[@]}"; do
  filename="${package}-${EXPECTED_VERSION}.tar"
  candidate_tar_sha256="$(manifest_hash_for "${filename}")"

  if grep -Fxq "${package}" "${REMOTE_SKIP_FILE}"; then
    info "already published and verified; skipping: ${package} ${EXPECTED_VERSION}"
    skipped_count=$((skipped_count + 1))
    continue
  fi

  reverified_tar="${LIVE_REVERIFY_DIR}/${filename}"

  run_frozen_mix "${package}" hex.build --output "${reverified_tar}"
  reverified_checksum="$(sha256_file "${reverified_tar}")"
  [[ "${reverified_checksum}" == "${candidate_tar_sha256}" ]] ||
    fail "frozen source changed before live publish: ${filename}"

  info "publishing ${package}: ${PUBLISH_COMMAND}"
  run_frozen_mix "${package}" hex.publish package --yes
  published_count=$((published_count + 1))
  verify_published_release "${package}" "${candidate_tar_sha256}"
done

info "PUBLISH COMPLETE: ${#PACKAGES[@]} packages considered; published=${published_count} skipped=${skipped_count}"
