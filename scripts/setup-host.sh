#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/setup-host.sh SSH_TARGET

Bootstraps xcv from the local repo onto a remote SSH host:
  1. installs the local xcv CLI + daemon
  2. copies the remote xcv helper
  3. writes matching remote config
  4. installs the remote xclip shim

Example:
  ./scripts/setup-host.sh my-ec2
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

ssh_target="${1:-}"
if [[ -z "${ssh_target}" ]]; then
  echo "SSH target is required." >&2
  usage >&2
  exit 1
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/xcv"
config_path="${config_dir}/config"

"${repo_root}/scripts/install-local.sh" "${ssh_target}"

# shellcheck disable=SC1090
. "${config_path}"

remote_real_xclip="$(
  ssh "${ssh_target}" '
    for candidate in /usr/bin/xclip /bin/xclip; do
      if [ -x "$candidate" ]; then
        printf "%s" "$candidate"
        break
      fi
    done
    exit 0
  '
)"

ssh "${ssh_target}" 'mkdir -p "$HOME/bin" "$HOME/.local/bin" "$HOME/.config/xcv" "$HOME/.cache/xcv" "$HOME/clipboard-uploads"'

ssh "${ssh_target}" 'umask 077 && cat > "$HOME/bin/xcv" && chmod 0755 "$HOME/bin/xcv"' <"${repo_root}/bin/xcv"
ssh "${ssh_target}" 'umask 077 && cat > "$HOME/bin/receive-clipboard-image" && chmod 0755 "$HOME/bin/receive-clipboard-image"' <"${repo_root}/bin/receive-clipboard-image"

ssh "${ssh_target}" 'bash -s' <<'EOF'
set -euo pipefail

ensure_link() {
  local source="$1"
  local target="$2"

  if [[ -e "${target}" && ! -L "${target}" ]]; then
    echo "Skipped existing file: ${target}" >&2
    return
  fi

  ln -sfn "${source}" "${target}"
}

ensure_link "$HOME/bin/xcv" "$HOME/.local/bin/xcv"
ensure_link "$HOME/bin/xcv" "$HOME/bin/xclip"
ensure_link "$HOME/bin/xcv" "$HOME/.local/bin/xclip"
EOF

remote_config="$(cat <<EOF
SSH_TARGET=''
XCV_PORT=$(printf '%q' "${XCV_PORT}")
XCV_TOKEN=$(printf '%q' "${XCV_TOKEN}")
REMOTE_CACHE_DIR=$(printf '%q' "${REMOTE_CACHE_DIR}")
REMOTE_XCV_PATH=$(printf '%q' "${REMOTE_XCV_PATH}")
XCV_REAL_XCLIP=$(printf '%q' "${remote_real_xclip}")
EOF
)"

printf '%s\n' "${remote_config}" | ssh "${ssh_target}" 'umask 077 && cat > "$HOME/.config/xcv/config" && chmod 0600 "$HOME/.config/xcv/config"'

cat <<EOF
Configured:
  local daemon config: ${config_path}
  remote helper: ${ssh_target}:~/bin/xcv
  remote xclip shim: ${ssh_target}:~/bin/xclip

Next:
  ${HOME}/bin/xcv daemon start
  ${HOME}/bin/xcv ssh ${ssh_target}      # Claude Code
  ${HOME}/bin/xcv watch start            # Codex hotkey flow
  ${HOME}/bin/xcv paste --copy           # Codex one-shot flow
EOF
