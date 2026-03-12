#!/bin/sh
set -eu

REPO="${XCV_REPO:-tthuwng/xcv}"
REF="${XCV_REF:-main}"

in_path() {
    case ":$PATH:" in
        *":$1:"*) return 0 ;;
        *) return 1 ;;
    esac
}

choose_install_dir() {
    if [ -n "${XCV_INSTALL_DIR:-}" ]; then
        printf '%s\n' "${XCV_INSTALL_DIR}"
        return
    fi

    for dir in "$HOME/.local/bin" "$HOME/bin"; do
        if in_path "$dir"; then
            printf '%s\n' "$dir"
            return
        fi
    done

    printf '%s\n' "$HOME/.local/bin"
}

download() {
    url="$1"
    dest="$2"

    if command -v curl >/dev/null 2>&1; then
        curl -fsSL "$url" -o "$dest"
        return
    fi

    if command -v wget >/dev/null 2>&1; then
        wget -qO "$dest" "$url"
        return
    fi

    echo "Error: curl or wget is required." >&2
    exit 1
}

main() {
    install_dir="$(choose_install_dir)"
    raw_base="https://raw.githubusercontent.com/${REPO}/${REF}"
    tmp_dir="$(mktemp -d "${TMPDIR:-/tmp}/xcv-install.XXXXXX")"
    trap 'rm -rf "$tmp_dir"' EXIT HUP INT TERM

    mkdir -p "$install_dir"

    download "${raw_base}/bin/xcv" "${tmp_dir}/xcv"
    download "${raw_base}/bin/xcvd" "${tmp_dir}/xcvd"
    download "${raw_base}/bin/receive-clipboard-image" "${tmp_dir}/receive-clipboard-image"

    chmod 0755 "${tmp_dir}/xcv" "${tmp_dir}/xcvd" "${tmp_dir}/receive-clipboard-image"
    cp "${tmp_dir}/xcv" "${install_dir}/xcv"
    cp "${tmp_dir}/xcvd" "${install_dir}/xcvd"
    cp "${tmp_dir}/receive-clipboard-image" "${install_dir}/receive-clipboard-image"

    if in_path "$install_dir"; then
        xcv_cmd="xcv"
    else
        xcv_cmd="${install_dir}/xcv"
    fi

    echo ""
    echo "xcv installed to ${install_dir}"
    echo ""
    echo "Quick start:"
    echo "  ${xcv_cmd} setup myserver"
    echo ""

    if ! in_path "$install_dir"; then
        echo "Add to your PATH if you want to run \`xcv\` directly:"
        echo "  export PATH=\"${install_dir}:\$PATH\""
        echo ""
    fi
}

main "$@"
