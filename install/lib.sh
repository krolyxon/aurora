# shellcheck shell=bash
# Shared helpers, sourced by install.sh.

log() {
    local level="$1"
    shift

    local color reset='\033[0m'
    case "$level" in
        INFO)    color='\033[0;34m' ;; # Blue
        WARN)    color='\033[0;33m' ;; # Yellow
        ERROR)   color='\033[0;31m' ;; # Red
        SUCCESS) color='\033[0;32m' ;; # Green
        *)       color='\033[0m' ;;
    esac

    printf '%b[%s] [%s]%b %s\n' \
        "$color" "$(date '+%H:%M:%S')" "$level" "$reset" "$*" >&2
}

usage() {
    # install.sh's header comment, up to the first line that isn't a comment
    sed -n '3,/^[^#]/s/^# \{0,1\}//p' "$currentDir/install.sh"
}

###################
## Package lists ##
###################
# packages/*.txt: one package per line, '#' comments.
# A trailing '!' (e.g. "blender !") means: listed, but not pre-selected in the picker.

# All packages in a list
read_list() {
    sed 's/#.*//' "$PKG_DIR/$1.txt" | awk 'NF { print $1 }'
}

# Packages of a list that are pre-selected in the picker
preselected() {
    sed 's/#.*//' "$PKG_DIR/$1.txt" | awk 'NF && $2 != "!" { print $1 }'
}

check_packages() {
    local listed installed aur
    listed=$(for f in "$PKG_DIR"/*.txt; do read_list "$(basename "$f" .txt)"; done | sort -u)
    installed=$(pacman -Qqe | sort -u)
    aur=$(pacman -Qqm | sort -u)

    echo "Installed explicitly, but not in any packages/*.txt:"
    comm -23 <(echo "$installed") <(echo "$listed") | while read -r p; do
        if grep -qx "$p" <<< "$aur"; then echo "  $p (aur)"; else echo "  $p"; fi
    done

    echo
    echo "Listed, but not installed:"
    comm -13 <(pacman -Qq | sort -u) <(echo "$listed") | sed 's/^/  /'
}

choose_packages() {
    local list="$1"
    gum choose --no-limit \
        --selected "$(preselected "$list" | paste -sd,)" \
        $(read_list "$list")
}

prompt_style() {
    gum style \
        --border rounded \
        --padding "0 1" \
        "$1"
}

gum_warn(){
    gum style --bold --foreground 196 "⚠ $1"
}

gum_to_array() {
    local -n arr="$1"
    mapfile -t arr
    local cleaned=()
    for item in "${arr[@]}"; do
        [[ -n "$item" ]] && cleaned+=("$item")
    done
    arr=("${cleaned[@]}")
}

confirm() {
    local msg="$1"
    if ((AUTO_YES)); then
        log INFO "[auto] $msg → yes"
        return 0
    fi
    gum confirm --default=false "$msg"
}

# Package pickers -> SELECTED_PKGS (desktop.txt is always installed, it has no picker).
# --picks FILE (from the full install) replaces them.
pick_packages() {
    SELECTED_PKGS=()
    if [[ -n "$PICKS" ]]; then
        gum_to_array SELECTED_PKGS < "$PICKS"
        return
    fi

    local list picked
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
}
