#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/install-local.sh [SSH_TARGET]

Installs the local xcv CLI and daemon, then writes ~/.config/xcv/config.

Examples:
  ./scripts/install-local.sh
  ./scripts/install-local.sh my-ec2
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
  ln -sfn "${source}" "${target}"
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
user_bin="${HOME}/bin"
user_local_bin="${HOME}/.local/bin"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/xcv"
config_path="${config_dir}/config"

SSH_TARGET="${1:-}"
XCV_PORT="18339"
XCV_TOKEN=""
REMOTE_CACHE_DIR="~/.cache/xcv"
REMOTE_XCV_PATH="~/.local/bin/xcv"
XCV_REAL_XCLIP=""

if [[ -f "${config_path}" ]]; then
  # shellcheck disable=SC1090
  . "${config_path}"
fi

if [[ -n "${1:-}" ]]; then
  SSH_TARGET="${1}"
fi

if [[ -z "${XCV_TOKEN}" ]]; then
  XCV_TOKEN="$(random_token)"
fi

mkdir -p "${user_bin}" "${user_local_bin}" "${config_dir}"
cp "${repo_root}/bin/xcv" "${user_bin}/xcv"
cp "${repo_root}/bin/xcvd" "${user_bin}/xcvd"
cp "${repo_root}/bin/receive-clipboard-image" "${user_bin}/receive-clipboard-image"
chmod 0755 "${user_bin}/xcv" "${user_bin}/xcvd" "${user_bin}/receive-clipboard-image"

ensure_link "${user_bin}/xcv" "${user_local_bin}/xcv"
ensure_link "${user_bin}/xcvd" "${user_local_bin}/xcvd"

cat >"${config_path}" <<EOF
SSH_TARGET=$(printf '%q' "${SSH_TARGET}")
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
  ${user_bin}/xcvd
  ${user_bin}/receive-clipboard-image

Linked:
  ${user_local_bin}/xcv
  ${user_local_bin}/xcvd

Wrote config:
  ${config_path}

Next:
  ${user_bin}/xcv doctor
  ${user_bin}/xcv setup
EOF

if [[ -n "${SSH_TARGET}" ]]; then
  printf '  ./scripts/setup-host.sh %s\n' "${SSH_TARGET}"
else
  echo "  ./scripts/setup-host.sh user@host"
fi
echo "  ./scripts/install-auto-ssh.sh"
