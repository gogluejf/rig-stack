#!/usr/bin/env bash
# scripts/setup/lib/os-guard.sh
#
# Sourced by setup scripts. Validates OS_FAMILY and provides package manager helpers.
#
# Currently supported: ubuntu, debian (both via apt)
# Stub support: macos (exits with clear message), other Linux distros (warns)
#
# OS_FAMILY is read from .env. If not set, auto-detected from /etc/os-release.

_detect_os_family() {
    if [[ -f /etc/os-release ]]; then
        local id
        id=$(. /etc/os-release && echo "${ID}")
        case "${id}" in
            ubuntu) echo "ubuntu" ;;
            debian) echo "debian" ;;
            *) echo "${id}" ;;
        esac
    elif [[ "$(uname)" == "Darwin" ]]; then
        echo "macos"
    else
        echo "unknown"
    fi
}

require_supported_os() {
    local family="${OS_FAMILY:-}"
    if [[ -z "${family}" ]]; then
        family=$(_detect_os_family)
        export OS_FAMILY="${family}"
    fi

    case "${family}" in
        ubuntu|debian)
            # Supported — verify apt is available
            if ! command -v apt-get &>/dev/null; then
                echo "ERROR: OS_FAMILY=${family} but apt-get not found." >&2
                exit 1
            fi
            ;;
        macos)
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            echo "  OS_FAMILY=macos — macOS setup is not yet supported." >&2
            echo "  rig-stack setup scripts currently target Linux only." >&2
            echo "  The Docker Compose stack itself works on macOS;" >&2
            echo "  NVIDIA GPU passthrough requires Linux." >&2
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            exit 1
            ;;
        *)
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            echo "  OS_FAMILY=${family} — unsupported for automated setup." >&2
            echo "  Supported: ubuntu, debian" >&2
            echo "  Set OS_FAMILY in .env to override auto-detection." >&2
            echo "  For other distros, run the steps in install.sh manually." >&2
            echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" >&2
            exit 1
            ;;
    esac
}

# Returns the apt codename for the current OS version
apt_codename() {
    if command -v lsb_release &>/dev/null; then
        lsb_release -cs
    else
        . /etc/os-release && echo "${VERSION_CODENAME:-${UBUNTU_CODENAME:-}}"
    fi
}
