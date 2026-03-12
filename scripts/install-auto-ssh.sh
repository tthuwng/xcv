#!/usr/bin/env bash

set -euo pipefail

usage() {
  cat <<'EOF'
Usage: ./scripts/install-auto-ssh.sh

Installs xcv locally, then adds an SSH config include that:
  - applies only to interactive SSH sessions
  - starts the local daemon on demand
  - forwards the xcv port automatically
  - bootstraps the remote xclip shim on first connect

After this, plain `ssh host` is enough for Claude Code image paste on hosts that
allow remote forwarding.
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd -P)"
ssh_dir="${HOME}/.ssh"
ssh_config="${ssh_dir}/config"
xcv_ssh_config="${ssh_dir}/xcv.conf"
config_dir="${XDG_CONFIG_HOME:-${HOME}/.config}/xcv"
config_path="${config_dir}/config"
local_xcv="${HOME}/bin/xcv"
control_path='~/.config/xcv/control/%C'

"${repo_root}/scripts/install-local.sh"

# shellcheck disable=SC1090
. "${config_path}"

mkdir -p "${ssh_dir}" "${config_dir}/control"
chmod 0700 "${ssh_dir}"

if [[ ! -f "${ssh_config}" ]]; then
  touch "${ssh_config}"
  chmod 0600 "${ssh_config}"
fi

if ! grep -Fqx 'Include ~/.ssh/xcv.conf' "${ssh_config}"; then
  printf '\nInclude ~/.ssh/xcv.conf\n' >>"${ssh_config}"
fi

cat >"${xcv_ssh_config}" <<EOF
# Managed by xcv. Remove this file or the Include line in ~/.ssh/config to disable.
Match exec "test -t 0 && test -t 1"
  ControlMaster auto
  ControlPersist 600
  ControlPath ${control_path}
  RemoteForward 127.0.0.1:${XCV_PORT} 127.0.0.1:${XCV_PORT}
  PermitLocalCommand yes
  LocalCommand ${local_xcv} session-hook %n >/dev/null 2>&1 || true
EOF
chmod 0600 "${xcv_ssh_config}"

cat <<EOF
Installed automatic SSH integration.

Updated:
  ${ssh_config}
  ${xcv_ssh_config}

What it does:
  - plain ssh sessions now get the xcv remote forward automatically
  - the local daemon starts on demand
  - remote hosts get the xcv/xclip shim installed on first connect

Next:
  ssh your-host
  codex hotkey flow: ${local_xcv} watch start
  one-shot codex flow: ${local_xcv} paste --copy
EOF
