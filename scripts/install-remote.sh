#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/install-remote.sh [--port PORT] [--token TOKEN] [--remote-cache-dir PATH]

Installs the remote xcv helper and xclip shim from a repo checkout that already
exists on the SSH host.

Examples:
  ./scripts/install-remote.sh
  ./scripts/install-remote.sh --token 0123abcd --port 18339
EOF
}

random_token() {
  if command -v openssl >/dev/null 2>&1; then
    openssl rand -hex 24
    return
  fi

  od -An -N 24 -tx1 /dev/urandom | tr -d ' \n'
}

ensure_link() {
  local source="$1"
  local target="$2"

  mkdir -p "$(dirname "${target}")"

  if [[ -e "${target}" && ! -L "${target}" ]]; then
    echo "Skipped existing file: ${target}" >&2
    return
  fi

  ln -sfn "${source}" "${target}"
}

detect_real_xclip() {
  for candidate in /usr/bin/xclip /bin/xclip; do
    if [[ -x "${candidate}" ]]; then
      printf '%s\n' "${candidate}"
      return
    fi
  done
}

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
user_bin="${HOME}/bin"
user_local_bin="${HOME}/.local/bin"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/xcv"
config_path="${config_dir}/config"
upload_dir="${HOME}/clipboard-uploads"

XCV_PORT="18339"
XCV_TOKEN=""
REMOTE_CACHE_DIR="~/.cache/xcv"
REMOTE_XCV_PATH="~/.local/bin/xcv"
XCV_REAL_XCLIP=""

if [[ -f "${config_path}" ]]; then
  # shellcheck disable=SC1090
  . "${config_path}"
fi

while (($# > 0)); do
  case "$1" in
    --port)
      XCV_PORT="${2:?missing value for --port}"
      shift 2
      ;;
    --token)
      XCV_TOKEN="${2:?missing value for --token}"
      shift 2
      ;;
    --remote-cache-dir)
      REMOTE_CACHE_DIR="${2:?missing value for --remote-cache-dir}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage >&2
      exit 1
      ;;
  esac
done

if [[ -z "${XCV_TOKEN}" ]]; then
  XCV_TOKEN="$(random_token)"
fi

if [[ -z "${XCV_REAL_XCLIP}" ]]; then
  XCV_REAL_XCLIP="$(detect_real_xclip || true)"
fi

mkdir -p "${user_bin}" "${user_local_bin}" "${config_dir}" "${upload_dir}" "${HOME}/.cache/xcv"
cp "${repo_root}/bin/xcv" "${user_bin}/xcv"
cp "${repo_root}/bin/receive-clipboard-image" "${user_bin}/receive-clipboard-image"
chmod 0755 "${user_bin}/xcv" "${user_bin}/receive-clipboard-image"

ensure_link "${user_bin}/xcv" "${user_local_bin}/xcv"
ensure_link "${user_bin}/xcv" "${user_bin}/xclip"
ensure_link "${user_bin}/xcv" "${user_local_bin}/xclip"

cat >"${config_path}" <<EOF
SSH_TARGET=''
XCV_PORT=$(printf '%q' "${XCV_PORT}")
XCV_TOKEN=$(printf '%q' "${XCV_TOKEN}")
REMOTE_CACHE_DIR=$(printf '%q' "${REMOTE_CACHE_DIR}")
REMOTE_XCV_PATH=$(printf '%q' "${REMOTE_XCV_PATH}")
XCV_REAL_XCLIP=$(printf '%q' "${XCV_REAL_XCLIP}")
EOF
chmod 0600 "${config_path}"

cat <<EOF
Installed:
  ${user_bin}/xcv
  ${user_bin}/receive-clipboard-image

Linked:
  ${user_local_bin}/xcv
  ${user_bin}/xclip
  ${user_local_bin}/xclip

Created directories:
  ${upload_dir}
  ${HOME}/.cache/xcv

Wrote config:
  ${config_path}
EOF

printf '\nToken prefix: %s…\n' "${XCV_TOKEN:0:8}"
