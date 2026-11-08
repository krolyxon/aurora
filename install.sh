#!/usr/bin/env bash
#
# aurora installer (krolyxon's desktop)
#
# READ THIS FIRST:
#   This sets up MY personal desktop (Arch + Hyprland + aurora), built around my own
#   hardware (Lenovo Legion, Intel + NVIDIA hybrid, linux-zen) and my habits.
#   It is NOT a general purpose installer and I'm not trying to make it one.
#
#   From the Arch ISO it installs everything: it ERASES the disk you pick (or uses
#   partitions you pick), installs Arch, GRUB and your user, then the desktop.
#   On an installed system it only does the desktop part. Only run that on a
#   FRESHLY INSTALLED, UNCONFIGURED Arch Linux system: it installs a lot of packages,
#   moves your existing configs out of the way, changes your login shell and can
#   enable system services.
#
#   If you just want a piece of the setup, copy the files you like instead.
#
# Usage:
#   From the Arch ISO (as root, network up):
#     bash <(curl -fsSL https://git.krolyxon.com/aurora/raw/master/install.sh)
#
#   ./install.sh            on the Arch ISO: full install (disk, Arch, desktop)
#                           on an installed Arch: the desktop only (= --desktop)
#   ./install.sh --desktop  desktop only: packages, dotfiles (stow), zsh, services
#   ./install.sh --base     Arch ISO only: disk, Arch, GRUB, user, no desktop
#   ./install.sh --yes      pre-select everything, don't ask (still asks the fresh-system question)
#   ./install.sh --check    compare installed packages with packages/*.txt, changes nothing

trap 'log WARN "Interrupted by user"; exit 130' INT

INSTALL_STATUS="none"   # none | partial | complete | failed
MODE=""                 # full | base | desktop
AUTO_YES=0
CHECK_ONLY=0
PICKS=""                # file with the packages to install instead of the pickers
BACKUP_DIR=""

REPO_URLS=(https://git.krolyxon.com/aurora https://github.com/krolyxon/aurora)

currentDir="$(dirname "$(readlink -f "$0")")"

###############
## Bootstrap ##
###############
# Started without the repo (bash <(curl ...)): clone it and run the clone's install.sh.
# On the ISO the clone is temporary (the full install copies it to the new home);
# elsewhere it's the checkout the dotfiles get stowed from, so it goes to ~/aurora.
if [[ ! -f "$currentDir/install/lib.sh" ]]; then
    if [[ $EUID -eq 0 && -d /run/archiso ]]; then
        dest=/tmp/aurora
        command -v git >/dev/null || pacman -Sy --needed --noconfirm git || exit 1
    else
        dest="$HOME/aurora"
        command -v git >/dev/null || sudo pacman -S --needed --noconfirm git || exit 1
    fi
    if [[ ! -f "$dest/install/lib.sh" ]]; then
        [[ -e "$dest" ]] && { echo "$dest exists but isn't an aurora checkout, move it away first." >&2; exit 1; }
        for url in "${REPO_URLS[@]}"; do
            git clone "$url" "$dest" && break
        done
    fi
    [[ -f "$dest/install/lib.sh" ]] || { echo "Couldn't clone aurora." >&2; exit 1; }
    exec bash "$dest/install.sh" "$@"
fi

cd "$currentDir" || exit 1
PKG_DIR="$currentDir/packages"

# shellcheck source=install/lib.sh
source "$currentDir/install/lib.sh"

#######################
## Arguement Parsing ##
#######################
while (($#)); do
    case "$1" in
        --desktop)
            MODE=desktop
            ;;
        --base)
            MODE=base
            ;;
        --yes|--ci|--non-interactive)
            AUTO_YES=1
            ;;
        --check)
            CHECK_ONLY=1
            ;;
        --picks)
            # internal: the full install hands the pickers' answers to the desktop part
            PICKS="${2:-}"
            shift
            [[ -f "$PICKS" ]] || { log ERROR "--picks: no such file: $PICKS"; exit 1; }
            ;;
        -h|--help)
            usage
            exit 0
            ;;
        *)
            log ERROR "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
    shift
done

if ((CHECK_ONLY)); then
    check_packages
    exit 0
fi

# No mode given: the ISO means a bare machine, anything else already runs Arch
if [[ -z "$MODE" ]]; then
    if [[ $EUID -eq 0 && -d /run/archiso ]]; then MODE=full; else MODE=desktop; fi
fi

case "$MODE" in
    full|base)
        # shellcheck source=install/base.sh
        source "$currentDir/install/base.sh"
        ;;
    desktop)
        # shellcheck source=install/desktop.sh
        source "$currentDir/install/desktop.sh"
        ;;
esac
