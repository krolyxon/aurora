#!/usr/bin/env bash
#
# aurora installer (krolyxon's desktop)
#
# READ THIS FIRST:
#   This sets up MY personal desktop (Arch + Hyprland + aurora), built around my own
#   hardware (Lenovo Legion, Intel + NVIDIA hybrid, linux-zen) and my habits.
#   It is NOT a general purpose installer and I'm not trying to make it one.
#
#   Only run it on a FRESHLY INSTALLED, UNCONFIGURED Arch Linux system.
#   It installs a lot of packages, moves your existing configs out of the way,
#   changes your login shell and can enable system services.
#
#   If you just want a piece of the setup, copy the files you like instead.
#
# Usage:
#   ./install.sh           interactive
#   ./install.sh --yes     pre-select everything (still asks the fresh-system question)
#   ./install.sh --check   compare installed packages with packages/*.txt, changes nothing

trap 'log WARN "Interrupted by user"; exit 130' INT

INSTALL_STATUS="none"   # none | partial | complete | failed
AUTO_YES=0
CHECK_ONLY=0
BACKUP_DIR=""

currentDir="$(dirname "$(readlink -f "$0")")"
cd "$currentDir" || exit 1
PKG_DIR="$currentDir/packages"

# shellcheck source=install/lib.sh
source "$currentDir/install/lib.sh"

#######################
## Arguement Parsing ##
#######################
for arg in "$@"; do
    case "$arg" in
        --yes|--ci|--non-interactive)
            AUTO_YES=1
            ;;
        --check)
            CHECK_ONLY=1
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log ERROR "Unknown option: $arg"
            usage
            exit 1
            ;;
    esac
done

if ((CHECK_ONLY)); then
    check_packages
    exit 0
fi

# shellcheck source=install/desktop.sh
source "$currentDir/install/desktop.sh"
