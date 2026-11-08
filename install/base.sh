# shellcheck shell=bash
# Base system from the Arch ISO: disk, Arch, GRUB, user, then (unless --base) the desktop part
# inside the new system's chroot. Sourced by install.sh, runs as root.
#
# Every question comes first and nothing is touched until the summary is confirmed
# (except cfdisk in manual mode, which only writes when you tell it to).
# After that it runs unattended.

LOG=/tmp/aurora-install.log
CRYPT_NAME=cryptroot

##############
## Preflight ##
##############
if [[ $EUID -ne 0 || ! -d /run/archiso ]]; then
    log ERROR "The full install (and --base) only runs from the Arch ISO, as root."
    log INFO "On an installed system use: ./install.sh --desktop"
    exit 1
fi

if [[ "$(cat /sys/firmware/efi/fw_platform_size 2>/dev/null)" != 64 ]]; then
    log ERROR "The ISO isn't booted in 64-bit UEFI mode. Legacy BIOS isn't supported."
    exit 1
fi

if ! curl -fsI --max-time 10 https://archlinux.org >/dev/null; then
    log ERROR "No network."
    cat >&2 <<'EOF'
Ethernet should just work. Wi-Fi:
  iwctl device list
  iwctl station <device> get-networks
  iwctl station <device> connect <SSID>
(Wi-Fi networks you connect to here are carried over to the new system.)
EOF
    exit 1
fi

log INFO "Preparing the live system"
timedatectl set-ntp true
# the ISO fills its keyring at boot: wait for that before using pacman
for _ in {1..60}; do
    systemctl is-active -q pacman-init.service && break
    sleep 1
done
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 15/' /etc/pacman.conf
pacman -Sy --needed --noconfirm archlinux-keyring gum || exit 1


##############
## Helpers ##
##############
abort() {
    log WARN "Aborted, nothing was changed."
    exit 1
}

# ask VAR "Prompt" [default]
ask() {
    local -n _out="$1"
    _out="$(gum input --prompt "$2: " --value "${3:-}")" || abort
}

# ask_secret VAR "Label" [allow_empty]
ask_secret() {
    local -n _out="$1"
    local a b
    while :; do
        a="$(gum input --password --prompt "$2: ")" || abort
        if [[ -z "$a" ]]; then
            if ((${3:-0})); then _out=""; return; fi
            gum_warn "Can't be empty" >&2
            continue
        fi
        b="$(gum input --password --prompt "$2 (again): ")" || abort
        [[ "$a" == "$b" ]] && { _out="$a"; return; }
        gum_warn "They don't match, try again" >&2
    done
}

# yes/no question, VAR=1/0. ask_yn VAR "Question" default(yes|no)
ask_yn() {
    local -n _out="$1"
    local rc
    gum confirm --default="$([[ $3 == yes ]] && echo true || echo false)" "$2"
    rc=$?
    ((rc > 1)) && abort     # ctrl+c / esc
    ((rc == 0)) && _out=1 || _out=0
}

# One lsblk column of one device, without padding
field() {
    lsblk -dno "$1" "$2" | sed 's/^ *//; s/ *$//'
}

# The disk the ISO itself was booted from (a USB stick): never offered
iso_disk="$(lsblk -no PKNAME "$(findmnt -no SOURCE /run/archiso/bootmnt 2>/dev/null)" 2>/dev/null | head -1)"

disk_lines() {
    local name type
    while read -r name type; do
        [[ "$type" == disk && "$name" != /dev/zram* && "$name" != "/dev/$iso_disk" ]] || continue
        printf '%-16s %8s  %s\n' "$name" "$(field SIZE "$name")" "$(field MODEL "$name")"
    done < <(lsblk -dpno NAME,TYPE)
}

part_lines() {
    local name type
    while read -r name type; do
        [[ "$type" == part ]] || continue
        [[ -n "$iso_disk" && "$(field PKNAME "$name")" == "$iso_disk" ]] && continue
        [[ " $* " == *" $name "* ]] && continue      # already picked
        printf '%-16s %8s  %-11s %s\n' "$name" "$(field SIZE "$name")" \
            "$(field FSTYPE "$name")" "$(field PARTTYPENAME "$name")"
    done < <(lsblk -lpno NAME,TYPE)
}

# pick VAR "Header" < <(lines): the first column of the chosen line.
# Not in a pipe: VAR would only be set in the pipe's subshell.
pick() {
    local -n _out="$1"
    local lines line
    lines="$(cat)"
    [[ -n "$lines" ]] || { log ERROR "Nothing to choose from: $2"; exit 1; }
    line="$(gum choose --header "$2" <<< "$lines")" || abort
    _out="${line%% *}"
}

# Run a command on a pseudo-terminal: the output goes through tee into the log, and
# pacman/paru only draw their progress bars on a terminal (silent for minutes otherwise)
with_tty() {
    script -qefc "$(printf '%q ' "$@")" /dev/null
}

STEP=""
step() {
    STEP="$1"
    log INFO "== $1"
}


###############
## Questions ##
###############
gum style --border double --border-foreground 196 --padding "1 2" --bold \
"⚠️  aurora: full install

This installs Arch Linux + MY desktop (Hyprland + aurora), built for MY machine
(Lenovo Legion, Intel + NVIDIA hybrid, linux-zen). It is NOT general purpose.

It will ERASE the disk you pick (or format the partitions you pick).
Nothing happens until you confirm the summary at the end.

Provided AS IS, WITHOUT ANY WARRANTY. Proceed at your OWN RISK."

## Disk ##
DISK_MODE="$(gum choose --header "Partitioning" \
    "auto     erase a whole disk: 1 GiB EFI + the rest for Arch" \
    "manual   partition yourself (cfdisk), then pick the partitions")" || abort
DISK_MODE="${DISK_MODE%% *}"

DISK="" ESP="" ROOT="" FORMAT_ESP=1
if [[ "$DISK_MODE" == auto ]]; then
    pick DISK "Disk to ERASE" < <(disk_lines)
else
    cfdisk_disk=""
    pick cfdisk_disk "Run cfdisk on" < <(disk_lines; echo "skip     (already partitioned)")
    if [[ "$cfdisk_disk" != skip ]]; then
        cfdisk "$cfdisk_disk"
        partprobe "$cfdisk_disk" 2>/dev/null
        udevadm settle
    fi

    pick ESP "EFI system partition (mounted at /boot)" < <(part_lines)
    if (( $(lsblk -bdno SIZE "$ESP") < 500 * 1024 * 1024 )); then
        gum_warn "$ESP is smaller than 500 MiB. /boot holds two kernels + initramfs (~300 MiB)." >&2
        gum confirm --default=false "Use it anyway?" || abort
    fi
    if [[ "$(field FSTYPE "$ESP")" == vfat ]]; then
        # an existing ESP probably boots another OS too: keep it unless asked
        ask_yn FORMAT_ESP "$ESP is already FAT. Format it? (No keeps other systems' boot loaders)" no
    else
        log INFO "$ESP isn't FAT yet, it will be formatted"
    fi

    pick ROOT "Root partition (will be FORMATTED)" < <(part_lines "$ESP")
fi

## Encryption ##
ask_yn LUKS "Encrypt the system with LUKS2? (asks for the passphrase at every boot)" yes
LUKS_PASS=""
((LUKS)) && ask_secret LUKS_PASS "Encryption passphrase"

## Host and user ##
while :; do
    ask HOSTNAME_NEW "Hostname" "arch"
    [[ "$HOSTNAME_NEW" =~ ^[a-z0-9][a-z0-9-]{0,62}$ ]] && break
    gum_warn "Lowercase letters, digits and '-' only" >&2
done
while :; do
    ask USERNAME_NEW "Username"
    [[ "$USERNAME_NEW" =~ ^[a-z_][a-z0-9_-]{0,31}$ ]] && break
    gum_warn "Lowercase letters, digits, '_' and '-', starting with a letter" >&2
done
ask_secret USER_PASS "Password for $USERNAME_NEW"
ask_secret ROOT_PASS "Root password (empty: root login disabled, use sudo)" 1

## Locale ##
TIMEZONE="Asia/Kolkata"
ask_yn tz_ok "Timezone $TIMEZONE?" yes
if ! ((tz_ok)); then
    TIMEZONE="$(timedatectl list-timezones | gum filter --header "Timezone")" || abort
fi
while :; do
    ask LOCALE "Locale" "en_US.UTF-8"
    grep -q "^#\?${LOCALE//./\\.} " /etc/locale.gen && break
    gum_warn "Not in /etc/locale.gen" >&2
done
while :; do
    ask KEYMAP "Console keymap" "us"
    localectl list-keymaps | grep -qx "$KEYMAP" && break
    gum_warn "Unknown keymap" >&2
done

## GRUB ##
ask_yn GRUB_HIDDEN "Skip the GRUB menu at boot? (hold Shift/Esc to see it)" yes
ask_yn OS_PROBER "Add other installed systems (Windows, ...) to GRUB? (os-prober)" no

## Desktop packages ##
SELECTED_PKGS=()
[[ "$MODE" == full ]] && pick_packages

## Summary ##
case "$(grep -m1 -o 'GenuineIntel\|AuthenticAMD' /proc/cpuinfo)" in
    GenuineIntel) UCODE=(intel-ucode) ;;
    AuthenticAMD) UCODE=(amd-ucode) ;;
    *)            UCODE=() ;;
esac

if [[ "$DISK_MODE" == auto ]]; then
    disk_desc="$DISK ($(field SIZE "$DISK") $(field MODEL "$DISK")): ERASED, 1 GiB EFI + Arch"
    CONFIRM_TARGET="$DISK"
else
    disk_desc="EFI $ESP ($( ((FORMAT_ESP)) && echo formatted || echo kept)), Arch on $ROOT (formatted)"
    CONFIRM_TARGET="$ROOT"
fi
if [[ "$MODE" == full ]]; then
    desktop_desc="Hyprland + aurora, $(read_list desktop | wc -l) base + ${#SELECTED_PKGS[@]} picked packages"
else
    desktop_desc="none (--base), run ./install.sh --desktop later"
fi

gum style --border rounded --padding "1 2" \
"Summary

Disk:        $disk_desc
Encryption:  $( ((LUKS)) && echo "LUKS2" || echo "none")
System:      $(read_list base | grep -c .) packages (linux-zen + linux) ${UCODE[*]}, GRUB, zram swap
Host/user:   $HOSTNAME_NEW / $USERNAME_NEW (sudo), root login $( [[ -n $ROOT_PASS ]] && echo enabled || echo disabled)
Locale:      $TIMEZONE, $LOCALE, keymap $KEYMAP
GRUB:        menu $( ((GRUB_HIDDEN)) && echo hidden || echo shown), os-prober $( ((OS_PROBER)) && echo on || echo off)
Desktop:     $desktop_desc"

answer="$(gum input --placeholder "$CONFIRM_TARGET" \
    --header "Type $CONFIRM_TARGET to FORMAT it and start the install")" || abort
[[ "$answer" == "$CONFIRM_TARGET" ]] || abort


##################
## Installation ##
##################
# From here on: unattended, logged, stop at the first error
exec 3>&1 4>&2
exec > >(tee -a "$LOG") 2>&1
set -Eeuo pipefail
trap 'log ERROR "Failed: $STEP (line $LINENO). Log: $LOG. /mnt is still mounted for a look around."' ERR
trap 'rm -f /mnt/etc/sudoers.d/99-aurora-install' EXIT

# A previous attempt may have left things mounted/open
if mountpoint -q /mnt; then umount -R /mnt; fi
if [[ -e "/dev/mapper/$CRYPT_NAME" ]]; then cryptsetup close "$CRYPT_NAME"; fi

if [[ "$DISK_MODE" == auto ]]; then
    step "Partitioning $DISK"
    # old signatures (LUKS headers, filesystems) first, then the partition table
    for p in $(lsblk -lpno NAME,TYPE "$DISK" | awk '$2 == "part" { print $1 }'); do
        wipefs -af "$p"
    done
    wipefs -af "$DISK"
    sgdisk --zap-all "$DISK"
    sgdisk -n1:0:+1G -t1:ef00 -c1:EFI \
           -n2:0:0   -t2:"$( ((LUKS)) && echo 8309 || echo 8304)" -c2:arch "$DISK"
    partprobe "$DISK" || true
    udevadm settle
    # partition paths from lsblk: nvme0n1p1 and sda1 alike
    mapfile -t parts < <(lsblk -lpno NAME,TYPE "$DISK" | awk '$2 == "part" { print $1 }')
    ESP="${parts[0]}"
    ROOT="${parts[1]}"
fi

ROOT_DEV="$ROOT"
if ((LUKS)); then
    step "Encrypting $ROOT"
    printf '%s' "$LUKS_PASS" | cryptsetup luksFormat --type luks2 --batch-mode --key-file=- "$ROOT"
    printf '%s' "$LUKS_PASS" | cryptsetup open --key-file=- "$ROOT" "$CRYPT_NAME"
    ROOT_DEV="/dev/mapper/$CRYPT_NAME"
    LUKS_UUID="$(blkid -s UUID -o value "$ROOT")"
fi

step "Formatting and mounting"
((FORMAT_ESP)) && mkfs.fat -F32 -n EFI "$ESP"
mkfs.ext4 -F -L arch "$ROOT_DEV"
mount "$ROOT_DEV" /mnt
mount --mkdir -o umask=0077 "$ESP" /mnt/boot

step "Installing the base system (pacstrap)"
mapfile -t base_pkgs < <(read_list base)
with_tty pacstrap -K /mnt "${base_pkgs[@]}" "${UCODE[@]}"
genfstab -U /mnt >> /mnt/etc/fstab

step "Configuring the system"
ln -sf "/usr/share/zoneinfo/$TIMEZONE" /mnt/etc/localtime
arch-chroot /mnt hwclock --systohc
sed -i "s/^#\(${LOCALE//./\\.} \)/\1/" /mnt/etc/locale.gen
arch-chroot /mnt locale-gen
echo "LANG=$LOCALE" > /mnt/etc/locale.conf
echo "KEYMAP=$KEYMAP" > /mnt/etc/vconsole.conf
echo "$HOSTNAME_NEW" > /mnt/etc/hostname
cat > /mnt/etc/hosts <<EOF
127.0.0.1       localhost
::1             localhost
127.0.1.1       $HOSTNAME_NEW.localdomain $HOSTNAME_NEW
EOF
sed -i 's/^#\?ParallelDownloads.*/ParallelDownloads = 15/; s/^#Color$/Color/' /mnt/etc/pacman.conf
# swap in compressed RAM instead of a partition/file (no hibernation anyway)
cat > /mnt/etc/systemd/zram-generator.conf <<'EOF'
[zram0]
zram-size = min(ram / 2, 8192)
compression-algorithm = zstd
EOF

CMDLINE=""
if ((LUKS)); then
    step "initramfs with LUKS"
    # Use whatever hooks the installed mkinitcpio defaults to: systemd-based or busybox
    hooks="$(grep '^HOOKS=' /mnt/etc/mkinitcpio.conf)"
    if [[ " ${hooks//[()=]/ } " == *" systemd "* ]]; then
        sed -i '/^HOOKS=/ s/ filesystems/ sd-encrypt filesystems/' /mnt/etc/mkinitcpio.conf
        CMDLINE="rd.luks.name=$LUKS_UUID=$CRYPT_NAME root=/dev/mapper/$CRYPT_NAME"
    else
        sed -i '/^HOOKS=/ s/ filesystems/ encrypt filesystems/' /mnt/etc/mkinitcpio.conf
        CMDLINE="cryptdevice=UUID=$LUKS_UUID:$CRYPT_NAME root=/dev/mapper/$CRYPT_NAME"
    fi
    grep -q '^HOOKS=.*encrypt filesystems' /mnt/etc/mkinitcpio.conf
    arch-chroot /mnt mkinitcpio -P
fi

step "Users"
arch-chroot /mnt useradd -m -G wheel -s /usr/bin/zsh "$USERNAME_NEW"
printf '%s:%s\n' "$USERNAME_NEW" "$USER_PASS" | arch-chroot /mnt chpasswd
if [[ -n "$ROOT_PASS" ]]; then
    printf 'root:%s\n' "$ROOT_PASS" | arch-chroot /mnt chpasswd
else
    arch-chroot /mnt passwd -l root
fi
echo '%wheel ALL=(ALL:ALL) ALL' > /mnt/etc/sudoers.d/10-wheel
chmod 0440 /mnt/etc/sudoers.d/10-wheel
arch-chroot /mnt visudo -cf /etc/sudoers.d/10-wheel

step "GRUB"
arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --bootloader-id=arch
# also EFI/BOOT/BOOTX64.EFI, for firmware that forgets its boot entries; only on a disk that's all ours
[[ "$DISK_MODE" == auto ]] && arch-chroot /mnt grub-install --target=x86_64-efi --efi-directory=/boot --removable
g=/mnt/etc/default/grub
[[ -n "$CMDLINE" ]] && sed -i "s|^GRUB_CMDLINE_LINUX_DEFAULT=\"\(.*\)\"|GRUB_CMDLINE_LINUX_DEFAULT=\"\1 $CMDLINE\"|" "$g"
# zen is the default entry, plain linux stays as the fallback
[[ -f /mnt/boot/vmlinuz-linux-zen ]] && echo 'GRUB_TOP_LEVEL="/boot/vmlinuz-linux-zen"' >> "$g"
if ((GRUB_HIDDEN)); then
    sed -i 's/^GRUB_TIMEOUT=.*/GRUB_TIMEOUT=0/; s/^#\?GRUB_TIMEOUT_STYLE=.*/GRUB_TIMEOUT_STYLE=hidden/' "$g"
fi
((OS_PROBER)) && sed -i 's/^#\?GRUB_DISABLE_OS_PROBER=.*/GRUB_DISABLE_OS_PROBER=false/' "$g"
arch-chroot /mnt grub-mkconfig -o /boot/grub/grub.cfg

step "Services"
arch-chroot /mnt systemctl enable NetworkManager.service systemd-timesyncd.service fstrim.timer

# Wi-Fi networks joined with iwctl on the ISO -> NetworkManager, so the first boot is online
for psk in /var/lib/iwd/*.psk; do
    [[ -f "$psk" ]] || continue
    ssid="$(basename "$psk" .psk)"
    # iwd hex-encodes names with special characters as =<hex>
    [[ "$ssid" == =* ]] && ssid="$(printf '%b' "$(sed 's/../\\x&/g' <<< "${ssid#=}")")"
    key="$(sed -n 's/^Passphrase=//p' "$psk")"
    [[ -n "$key" ]] || key="$(sed -n 's/^PreSharedKey=//p' "$psk")"
    [[ -n "$key" ]] || continue
    mkdir -p /mnt/etc/NetworkManager/system-connections
    conn="/mnt/etc/NetworkManager/system-connections/${ssid//[^A-Za-z0-9._-]/_}.nmconnection"
    cat > "$conn" <<EOF
[connection]
id=$ssid
uuid=$(cat /proc/sys/kernel/random/uuid)
type=wifi

[wifi]
mode=infrastructure
ssid=$ssid

[wifi-security]
key-mgmt=wpa-psk
psk=$key

[ipv4]
method=auto

[ipv6]
method=auto
EOF
    chmod 0600 "$conn"
    log INFO "Wi-Fi \"$ssid\" carried over"
done

step "Copying aurora to /home/$USERNAME_NEW/aurora"
cp -a "$currentDir" "/mnt/home/$USERNAME_NEW/aurora"
arch-chroot /mnt chown -R "$USERNAME_NEW:$USERNAME_NEW" "/home/$USERNAME_NEW/aurora"

DESKTOP_OK=1
if [[ "$MODE" == full ]]; then
    step "Desktop (install.sh --desktop inside the new system)"
    # makepkg/paru call sudo: no password while this runs, the EXIT trap removes it again
    echo "$USERNAME_NEW ALL=(ALL) NOPASSWD: ALL" > /mnt/etc/sudoers.d/99-aurora-install
    chmod 0440 /mnt/etc/sudoers.d/99-aurora-install
    picks="/home/$USERNAME_NEW/.aurora-picks"
    printf '%s\n' "${SELECTED_PKGS[@]}" > "/mnt$picks"
    if ! with_tty arch-chroot /mnt runuser -u "$USERNAME_NEW" -- \
            env HOME="/home/$USERNAME_NEW" USER="$USERNAME_NEW" LOGNAME="$USERNAME_NEW" \
                SHELL=/usr/bin/zsh AURORA_CHROOT=1 \
            bash "/home/$USERNAME_NEW/aurora/install.sh" --desktop --yes --picks "$picks"; then
        DESKTOP_OK=0
        log ERROR "The desktop part failed. After the reboot, log in and run: ~/aurora/install.sh --desktop"
    fi
    rm -f "/mnt$picks" /mnt/etc/sudoers.d/99-aurora-install
fi

step "Finishing"
trap - ERR
set +Eeuo pipefail
exec 1>&3 2>&4 3>&- 4>&-
sleep 1     # let tee write the last lines
install -m 0600 "$LOG" /mnt/var/log/aurora-install.log
umount -R /mnt
((LUKS)) && cryptsetup close "$CRYPT_NAME"

if ((DESKTOP_OK)); then
    gum style --border rounded --border-foreground 42 --padding "1 2" --bold \
"✔ Arch$([[ "$MODE" == full ]] && echo " + aurora") installed.

Remove the install medium and reboot.$([[ "$MODE" == full ]] && echo "
Log in on tty1 as $USERNAME_NEW: Hyprland and aurora start by themselves." || echo "
For the desktop, log in and run: ~/aurora/install.sh --desktop")
The install log is in /var/log/aurora-install.log."
else
    gum style --border rounded --border-foreground 220 --padding "1 2" --bold \
"⚠ Arch is installed, the desktop part failed.

Reboot, log in as $USERNAME_NEW and run: ~/aurora/install.sh --desktop
The install log is in /var/log/aurora-install.log."
fi

gum confirm "Reboot now?" && reboot
exit 0
