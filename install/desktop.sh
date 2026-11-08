# shellcheck shell=bash
# Desktop part: packages, dotfiles (stow), zsh, services. Sourced by install.sh;
# runs as the user, asks for sudo when it needs it.

#################
## GATEKEEPING ##
#################

## Prevent user from running this script as root
if [[ "$EUID" -eq 0 ]]; then
    log ERROR "This script must NOT be run as root."
    log INFO "If you need elevated privileges, the script will ask for sudo when required."
    exit 1
fi

if [[ ! -f /etc/arch-release ]]; then
    log ERROR "This is not Arch Linux. These dotfiles and this script are for Arch only."
    exit 1
fi

## Does this look like a system that is already set up?
## (configs this repo doesn't provide, or another desktop's config)
check_fresh_system() {
    local foreign=() desktops=() entry
    for entry in "$HOME"/.config/*; do
        [[ -e "$entry" ]] || continue
        entry="$(basename "$entry")"
        [[ -e "$currentDir/.config/$entry" ]] || foreign+=("$entry")
    done
    for entry in i3 sway niri river awesome bspwm openbox qtile xfce4 \
                 kdeglobals plasma-org.kde.plasma.desktop-appletsrc gnome-session; do
        [[ -e "$HOME/.config/$entry" ]] && desktops+=("$entry")
    done

    ((${#foreign[@]} <= 10 && ${#desktops[@]} == 0)) && return 0

    printf '\033[1;31m'
    echo "=================================================================="
    echo " This does NOT look like a fresh Arch install."
    echo
    ((${#desktops[@]})) && echo " Found another desktop's config: ${desktops[*]}"
    ((${#foreign[@]} > 10)) && echo " Found ${#foreign[@]} entries in ~/.config that this repo doesn't provide."
    echo
    echo " This installer is meant for a freshly installed, unconfigured"
    echo " system. On a system you already use it WILL change things you"
    echo " care about: your configs get moved aside, your shell changes, and"
    echo " lots of packages get installed."
    echo "=================================================================="
    printf '\033[0m'
    local answer
    read -rp "Type 'I understand' to continue anyway: " answer
    [[ "$answer" == "I understand" ]] || { log WARN "Aborted."; exit 1; }
}
check_fresh_system


install_prerequisites() {
    sudo pacman -S --needed --noconfirm stow gum git zsh
}

## Installs prerequisites
log INFO "Installing prerequisites: "
install_prerequisites


DISCLAIMER=$(gum style \
  --border double \
  --border-foreground 196 \
  --padding "1 2" \
  --bold \
"⚠️  DISCLAIMER

These are MY personal dotfiles, built for MY machine
(Lenovo Legion, Intel + NVIDIA hybrid, linux-zen) and the way I work.
They are NOT general purpose. They're public as a reference,
or for people who want exactly the same setup.

Only run this on a FRESHLY INSTALLED, UNCONFIGURED Arch system.

This script is provided AS IS, WITHOUT ANY WARRANTY. It will:
• Install a lot of packages (including NVIDIA drivers if selected)
• Move conflicting files in your \$HOME to ~/.aurora-backup/
• Change your login shell to zsh
• Optionally write /etc/keyd and enable keyd
• Optionally write /etc/pam.d/{login,passwd} (GNOME keyring unlock)
• Enable the aurora-shell.service user unit

Proceed at your OWN RISK."
)

confirm "$DISCLAIMER

Do you understand the risks and want to continue?" || exit 1


#######################
## Package selection ##
#######################
SELECTED_PKGS=()
for list in utils dev gpu optional aur; do
    case "$list" in
        utils)    prompt_style "Important utilities (Most likely go with defaults)" ;;
        dev)      prompt_style "Select Development Tools" ;;
        gpu)      prompt_style "Select GPU drivers" ;;
        optional) prompt_style "Select Optional Desktop Packages" ;;
        aur)      prompt_style "Select AUR packages" ;;
    esac

    if ((AUTO_YES)); then
        mapfile -t picked < <(preselected "$list")
    else
        gum_to_array picked < <(choose_packages "$list")
    fi
    SELECTED_PKGS+=("${picked[@]}")
done


##########################
## Configure Everything ##
##########################
WARNING=$(gum style \
  --border double \
  --border-foreground 196 \
  --padding "1 2" \
  --bold \
  "⚠️  Files in your \$HOME that conflict with this repo will be MOVED to
~/.aurora-backup/<date>/ and replaced with symlinks from this repo.")

if confirm "$WARNING

Proceed with system configuration (stow, shell)?"; then
    ###################
    ## Stow dotfiles ##
    ###################
    log INFO "Detecting conflicts..."
    mapfile -t conflicts < <(stow -t "$HOME" . --no-folding -nv 2>&1 | \
        sed -n 's/.*existing target \(.*\) since neither.*/\1/p')

    if ((${#conflicts[@]} == 0)); then
        log INFO "No conflicts. Running stow normally..."
    else
        log WARN "These paths conflict and will be moved to a backup:"
        printf '  %s\n' "${conflicts[@]}"
        if ! confirm "Move these files to ~/.aurora-backup/ ?"; then
            log WARN "Aborted."
            exit 1
        fi

        # Move conflicts (relative to $HOME) into the backup dir, keeping their paths
        BACKUP_DIR="$HOME/.aurora-backup/$(date '+%Y%m%d-%H%M%S')"
        for path in "${conflicts[@]}"; do
            [[ -n "$path" && "$path" != "/" ]] || continue
            mkdir -p "$BACKUP_DIR/$(dirname "$path")"
            mv "$HOME/$path" "$BACKUP_DIR/$path" && log INFO "Backed up $path"
        done
        log INFO "Backups are in $BACKUP_DIR"
    fi

    stow -t "$HOME" . --no-folding \
        && log SUCCESS "Dotfiles stowed successfully" \
        || log ERROR "Stow failed"

    #################################
    ## Change default shell to zsh ##
    #################################
    log INFO "Changing the default shell to ZSH"
    if [[ "$SHELL" != "$(command -v zsh)" ]]; then
        chsh -s "$(command -v zsh)" \
            && log SUCCESS "Default shell successfully set to zsh" \
            || log ERROR "Default shell could not be set to zsh"
    else
        log INFO "Skipping: zsh is already the default shell"
    fi
else
    log ERROR "Aborted stow, didn't configure or install anything"
    exit 1
fi


mapfile -t DESKTOP_PKGS < <(read_list desktop)
ALL_PKGS=(
    "${DESKTOP_PKGS[@]}"
    "${SELECTED_PKGS[@]}"
)

########################
## Install Everything ##
########################
if ((${#ALL_PKGS[@]})); then
    if confirm "Install all the selected packages?"; then
        log INFO "Installing selected packages..."

        ## Installing paru if not installed already
        if ! command -v paru >/dev/null 2>&1; then
            log INFO "Installing Paru (AUR package manager)"
            sudo pacman -S --needed --noconfirm base-devel
            git clone https://aur.archlinux.org/paru.git
            (cd paru && makepkg -sri)
            rm -rf paru
        fi

        if paru -Syu --needed "${ALL_PKGS[@]}"; then
            INSTALL_STATUS="complete"
        else
            INSTALL_STATUS="failed"
        fi
    else
        log WARN "Package installation skipped by user"
        INSTALL_STATUS="partial"
    fi
else
    log WARN "No packages selected"
    INSTALL_STATUS="partial"
fi



################
## Setup Keyd ##
################
if command -v keyd >/dev/null 2>&1; then
    if confirm "Configure and enable keyd? "; then
        log INFO "Copying keyd configuration to /etc/keyd/default.conf"
        sudo cp "$currentDir/system/etc/keyd/default.conf" /etc/keyd/
        sudo systemctl enable --now keyd.service \
            && log SUCCESS "Successfully enabled keyd.service" \
            || log ERROR "Couldn't enable keyd.service"
    fi
fi


############################
## GNOME keyring on login ##
############################
# pam_gnome_keyring unlocks the "login" keyring with the login password (tty login and hyprlock,
# whose PAM file includes login); passwd keeps the keyring password in sync.
if confirm "Unlock GNOME keyring at login (writes /etc/pam.d/login and passwd)?"; then
    log INFO "Copying PAM files to /etc/pam.d"
    sudo cp "$currentDir/system/etc/pam.d/login" "$currentDir/system/etc/pam.d/passwd" /etc/pam.d/ \
        && log SUCCESS "GNOME keyring unlocks at login" \
        || log ERROR "Couldn't write /etc/pam.d"
fi


#########################
## Enable aurora shell ##
#########################
# User unit, stowed to ~/.config/systemd/user. Hyprland starts it at login,
# enabling it also ties it to graphical-session.target. No --now: no session yet.
if [[ -f "$HOME/.config/systemd/user/aurora-shell.service" ]]; then
    if confirm "Enable aurora-shell.service (the desktop shell)?"; then
        systemctl --user daemon-reload
        systemctl --user enable aurora-shell.service \
            && log SUCCESS "Successfully enabled aurora-shell.service" \
            || log ERROR "Couldn't enable aurora-shell.service (run 'systemctl --user enable aurora-shell' after logging in)"
    fi
else
    log WARN "aurora-shell.service is not stowed, skipping"
fi


####################
## Final dialogue ##
####################
BACKUP_NOTE=""
[[ -n "$BACKUP_DIR" ]] && BACKUP_NOTE="

Your old conflicting files are in:
$BACKUP_DIR"

case "$INSTALL_STATUS" in
    complete)
        gum style \
          --border rounded \
          --border-foreground 42 \
          --padding "1 2" \
          --bold \
        "✔ Installation Complete!

All selected packages were installed successfully.
You may now reboot the system for all the changes to apply.$BACKUP_NOTE"
        ;;
    partial)
        gum style \
          --border rounded \
          --border-foreground 220 \
          --padding "1 2" \
          --bold \
        "⚠ Setup Finished (Partial)

Some steps were skipped by user choice.
Your system was NOT fully configured.$BACKUP_NOTE"
        ;;
    failed)
        gum style \
          --border rounded \
          --border-foreground 196 \
          --padding "1 2" \
          --bold \
        "❌ Installation Failed

One or more steps did not complete successfully.
Check the logs above.$BACKUP_NOTE"
        ;;
    *)
        gum style --bold "Finished.$BACKUP_NOTE"
        ;;
esac
